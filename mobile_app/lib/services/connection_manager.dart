import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ble_service.dart';
import 'wifi_direct_service.dart';

/// Connection state for a peer device.
enum PeerConnectionState {
  available,      // Discovered but not connected
  connecting,     // Attempting connection via Wi-Fi Direct
  connected,      // Successfully connected
  failed,         // Connection failed
  disconnected,   // Was connected, now disconnected
}

/// Represents a discovered peer with connection state and transport info.
class ManagedPeer {
  final String uid;
  String name;
  int? rssi;               // BLE signal strength
  double? distanceM;       // Estimated distance
  PeerConnectionState state;     // Current connection state
  String? preferredTransport;    // 'wifi' or 'ble'
  String? wifiDirectAddress;     // MAC address if connected via Wi-Fi Direct
  DateTime lastSeen;

  ManagedPeer({
    required this.uid,
    required this.name,
    this.rssi,
    this.distanceM,
    this.state = PeerConnectionState.available,
    this.preferredTransport = 'ble',
    this.wifiDirectAddress,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  bool get isConnected => 
    state == PeerConnectionState.connected;
  bool get isDirectlyConnected =>
    state == PeerConnectionState.connected && wifiDirectAddress != null;
}

enum WifiDirectConnectionState {
  idle,
  discovering,
  connecting,
  connected,
  failed,
}

/// ConnectionManager — Handles peer discovery, connection attempts, and transport selection.
/// 
/// This service is independent of the mesh relay state. It manages:
/// - BLE continuous discovery
/// - Wi-Fi Direct connection attempts with automatic retry
/// - Fallback to BLE for direct messaging
/// - Connection state tracking per peer
/// - Automatic reconnection on disconnect
class ConnectionManager extends ChangeNotifier {
  final BleService bleService;
  final WifiDirectService wifiDirectService;

  String? _myUid;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Peer management
  final Map<String, ManagedPeer> _peers = {};
  Map<String, ManagedPeer> get peers => Map.unmodifiable(_peers);

  // Connection retry logic
  final Map<String, int> _connectionRetries = {};
  final Map<String, Timer?> _retryTimers = {};
  static const int kMaxRetries = 3;
  static const Duration kRetryDelay = Duration(seconds: 5);

  // Subscriptions
  StreamSubscription<Map<String, BleDiscoveredUser>>? _bleDiscoverySub;
  StreamSubscription<WifiDirectEvent>? _wifiEventSub;

  // Connection tracking
  final Map<String, String> _wifiAddressToUid = {}; // MAC → UID mapping

  WifiDirectConnectionState _wifiState = WifiDirectConnectionState.idle;
  WifiDirectConnectionState get wifiState => _wifiState;

  // State streams
  final _peerStateCtrl = StreamController<ManagedPeer>.broadcast();
  final _connectionFailedCtrl = StreamController<String>.broadcast();
  final _wifiStateCtrl = StreamController<WifiDirectConnectionState>.broadcast();

  /// Emits when a peer's connection state changes.
  Stream<ManagedPeer> get onPeerStateChanged => _peerStateCtrl.stream;
  
  /// Emits UIDs when connection fails (after retries exhausted).
  Stream<String> get onConnectionFailed => _connectionFailedCtrl.stream;

  Stream<WifiDirectConnectionState> get onWifiStateChanged => _wifiStateCtrl.stream;

  ConnectionManager({
    required this.bleService,
    required this.wifiDirectService,
  });

  static void _log(String msg) => debugPrint('[ConnectionManager] $msg');

  /// Initialize the connection manager (call once at app startup).
  Future<bool> initialize(String myUid) async {
    if (_isInitialized) return true;
    _myUid = myUid;

    try {
      // Initialize Wi-Fi Direct
      final wifiOk = await wifiDirectService.initialize();
      if (!wifiOk) {
        _log('Wi-Fi Direct initialization failed');
        return false;
      }

      // Initialize BLE (must be done already in BleService)
      _setupListeners();
      _isInitialized = true;
      _log('ConnectionManager initialized for $_myUid');
      return true;
    } catch (e) {
      _log('Initialization error: $e');
      return false;
    }
  }

  void _setupListeners() {
    // Listen to BLE discoveries
    _bleDiscoverySub = bleService.discoveredUsersStream.listen((users) {
      _updateBleDiscoveries(users);
    });

    // Listen to Wi-Fi Direct events
    _wifiEventSub = wifiDirectService.events.listen((event) {
      _handleWifiDirectEvent(event);
    });
  }

  /// Update peer list from BLE discoveries.
  void _updateBleDiscoveries(Map<String, BleDiscoveredUser> users) {
    for (final entry in users.entries) {
      final uid = entry.key;
      final user = entry.value;

      if (uid == _myUid) continue; // Skip self

      final existing = _peers[uid];
      if (existing == null) {
        // New peer discovered
        final peer = ManagedPeer(
          uid: uid,
          name: user.username.isNotEmpty ? user.username : _shortName(uid),
          rssi: user.rssi,
          distanceM: user.distanceM,
          state: PeerConnectionState.available,
          preferredTransport: 'ble',
        );
        _peers[uid] = peer;
        _log('New peer discovered: ${peer.name} (BLE)');
        _peerStateCtrl.add(peer);

        // Attempt Wi-Fi Direct connection
        if (user.distanceM < 50) { // Only if close enough
          _attemptWifiDirectConnection(uid);
        }
      } else {
        // Update existing peer's signal strength
        existing.rssi = user.rssi;
        existing.distanceM = user.distanceM;
        existing.lastSeen = DateTime.now();
        if (existing.state == PeerConnectionState.available) {
          _peerStateCtrl.add(existing);
        }
      }
    }

    // Remove stale peers (not seen for 2 minutes)
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    final stale = _peers.entries
        .where((e) => e.value.lastSeen.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    for (final uid in stale) {
      _peers.remove(uid);
      _log('Peer removed (stale): $uid');
    }
  }

  /// Attempt to establish Wi-Fi Direct connection to a peer.
  Future<void> _attemptWifiDirectConnection(String uid) async {
    final peer = _peers[uid];
    if (peer == null || peer.isConnected) return;

    // Already have a retry timer or failed too many times
    if (_retryTimers[uid] != null || (_connectionRetries[uid] ?? 0) >= kMaxRetries) {
      return;
    }

    _retryTimers[uid]?.cancel();
    _retryTimers[uid] = null;

    final retryCount = _connectionRetries[uid] ?? 0;
    _log('Attempting Wi-Fi Direct connection to $uid (attempt ${retryCount + 1}/$kMaxRetries)');

    _setPeerState(uid, PeerConnectionState.connecting);
    _setWifiState(WifiDirectConnectionState.discovering);

    try {
      // Start Wi-Fi Direct discovery
      final discoveryOk = await wifiDirectService.startDiscovery();
      if (!discoveryOk) {
        _log('startDiscovery=false for $uid');
        _setWifiState(WifiDirectConnectionState.failed);
        _retryConnection(uid);
        return;
      }
      // Try to actively connect to one available peer to avoid passive stalls.
      final peers = await wifiDirectService.getPeers();
      final available = peers.where((p) => p.address.isNotEmpty && p.status == 'available');
      if (available.isNotEmpty) {
        _setWifiState(WifiDirectConnectionState.connecting);
        final ok = await wifiDirectService.connectToPeer(available.first.address);
        if (!ok) {
          _log('connectToPeer failed for ${available.first.address}');
        }
      }

      // Wait for discovery and connection events (with timeout)
      await Future.delayed(const Duration(seconds: 15));

      // If still connecting after timeout, try again
      if (_peers[uid]?.state == PeerConnectionState.connecting) {
        _setWifiState(WifiDirectConnectionState.failed);
        _retryConnection(uid);
      }
    } catch (e) {
      _log('Wi-Fi Direct connection error for $uid: $e');
      _setWifiState(WifiDirectConnectionState.failed);
      _retryConnection(uid);
    }
  }

  /// Retry a failed connection with exponential backoff.
  void _retryConnection(String uid) {
    final retryCount = (_connectionRetries[uid] ?? 0) + 1;
    _connectionRetries[uid] = retryCount;

    if (retryCount >= kMaxRetries) {
      _log('Connection to $uid failed after $kMaxRetries attempts');
      _setPeerState(uid, PeerConnectionState.failed);
      _connectionFailedCtrl.add(uid);
      return;
    }

    final backoffDelay = Duration(seconds: kRetryDelay.inSeconds * (1 << (retryCount - 1)));
    _log('Scheduling retry for $uid in ${backoffDelay.inSeconds}s');

    _retryTimers[uid]?.cancel();
    _retryTimers[uid] = Timer(backoffDelay, () async {
      _retryTimers[uid] = null;
      if (_peers.containsKey(uid)) {
        await _attemptWifiDirectConnection(uid);
      }
    });
  }

  /// Handle Wi-Fi Direct events from the native layer.
  void _handleWifiDirectEvent(WifiDirectEvent event) {
    switch (event.type) {
      case 'connectionChanged':
        _onWifiConnectionChanged(event.data);
        break;
      case 'peerSocketConnected':
        _onPeerSocketConnected(event.data);
        break;
      case 'peerSocketDisconnected':
        _onPeerSocketDisconnected(event.data);
        break;
      case 'peersChanged':
        // Update via handshake protocol, not directly here
        break;
    }
  }

  void _onWifiConnectionChanged(Map<String, dynamic> data) {
    final connected = data['connected'] == true;
    _log('Wi-Fi Direct connection changed: $connected');
    _setWifiState(
      connected ? WifiDirectConnectionState.connected : WifiDirectConnectionState.idle,
    );
  }

  void _onPeerSocketConnected(Map<String, dynamic> data) {
    final address = data['address'] as String?;
    if (address == null) return;

    _log('Socket connected to $address');
    // Will be associated with UID via handshake protocol
    _sendHandshake(address);
  }

  void _onPeerSocketDisconnected(Map<String, dynamic> data) {
    final address = data['address'] as String?;
    if (address == null) return;

    final uid = _wifiAddressToUid.remove(address);
    if (uid != null) {
      _log('Peer $uid disconnected from Wi-Fi Direct');
      if (_peers[uid]?.state == PeerConnectionState.connected) {
        _setPeerState(uid, PeerConnectionState.disconnected);
        // Try to reconnect
        _connectionRetries[uid] = 0; // Reset retry count
        _attemptWifiDirectConnection(uid);
      }
    }
  }

  /// Send handshake to identify peer UID over socket.
  void _sendHandshake(String address) {
    if (_myUid == null) return;
    try {
      wifiDirectService.sendMessage(
        '{"type":"handshake","uid":"$_myUid"}',
        targetAddress: address,
      );
    } catch (e) {
      _log('Handshake send error to $address: $e');
    }
  }

  /// Update peer connection state and notify listeners.
  void _setPeerState(String uid, PeerConnectionState newState) {
    final peer = _peers[uid];
    if (peer == null) return;

    if (peer.state != newState) {
      peer.state = newState;
      _log('Peer $uid state: $newState');
      _peerStateCtrl.add(peer);
      notifyListeners();
    }
  }

  /// Mark a peer as connected via Wi-Fi Direct.
  /// Called once handshake is complete to associate UID with socket address.
  void markWifiConnected(String uid, String address) {
    final peer = _peers[uid];
    if (peer == null) return;

    _wifiAddressToUid[address] = uid;
    peer.wifiDirectAddress = address;
    peer.preferredTransport = 'wifi';
    _connectionRetries[uid] = 0; // Reset retries on success
    _retryTimers[uid]?.cancel();
    _retryTimers[uid] = null;
    _setPeerState(uid, PeerConnectionState.connected);
    _setWifiState(WifiDirectConnectionState.connected);
    _log('Peer $uid marked connected via Wi-Fi Direct ($address)');
  }

  void _setWifiState(WifiDirectConnectionState state) {
    if (_wifiState == state) return;
    _wifiState = state;
    _wifiStateCtrl.add(state);
    notifyListeners();
  }

  /// Get the best transport for messaging a peer.
  String selectTransport(String uid, {int messageLength = 0}) {
    final peer = _peers[uid];
    if (peer == null) {
      return 'ble'; // Default fallback
    }

    // Prefer Wi-Fi Direct if connected
    if (peer.isDirectlyConnected) {
      return 'wifi';
    }

    // Use BLE if message is small and available
    if (messageLength <= 180 || messageLength == 0) {
      return 'ble';
    }

    // Large message but no Wi-Fi — error case
    return 'ble'; // Still try BLE
  }

  /// Get peer by UID.
  ManagedPeer? getPeer(String uid) => _peers[uid];

  /// Get Wi-Fi Direct address for a peer (if connected).
  String? getWifiDirectAddress(String uid) => _peers[uid]?.wifiDirectAddress;

  String _shortName(String uid) {
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 8)}…';
  }

  /// Start continuous discovery (BLE + Wi-Fi Direct).
  Future<void> startDiscovery() async {
    if (!_isInitialized) {
      _log('Not initialized yet');
      return;
    }
    _log('Starting continuous discovery');
    _setWifiState(WifiDirectConnectionState.discovering);
    await bleService.startContinuousScan(myUid: _myUid);
    final ok = await wifiDirectService.startDiscovery();
    if (!ok) {
      _setWifiState(WifiDirectConnectionState.failed);
    }
  }

  /// Stop discovery.
  Future<void> stopDiscovery() async {
    _log('Stopping discovery');
    await bleService.stopContinuousScan();
    await wifiDirectService.stopDiscovery();
    _setWifiState(WifiDirectConnectionState.idle);
  }

  /// Cleanup and dispose.
  @override
  void dispose() {
    _bleDiscoverySub?.cancel();
    _bleDiscoverySub = null;
    _wifiEventSub?.cancel();
    _wifiEventSub = null;

    for (final timer in _retryTimers.values) {
      timer?.cancel();
    }
    _retryTimers.clear();
    _peers.clear();
    _wifiAddressToUid.clear();

    _peerStateCtrl.close();
    _connectionFailedCtrl.close();
    _wifiStateCtrl.close();

    super.dispose();
  }
}
