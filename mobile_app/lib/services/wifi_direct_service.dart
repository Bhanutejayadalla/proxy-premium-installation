import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A Wi-Fi Direct peer discovered by the native WifiP2pManager.
class WifiDirectPeer {
  final String name;
  final String address;
  final String status; // available | invited | connected | failed | unavailable
  final bool isGroupOwner;

  WifiDirectPeer({
    required this.name,
    required this.address,
    required this.status,
    required this.isGroupOwner,
  });

  @override
  String toString() => 'WFDPeer($name, $address, $status)';
}

/// An event from the native Wi-Fi Direct layer.
class WifiDirectEvent {
  final String type;
  final Map<String, dynamic> data;
  WifiDirectEvent(this.type, this.data);

  @override
  String toString() => 'WFDEvent($type, $data)';
}

/// Flutter wrapper for the native Wi-Fi Direct (P2P) platform channel.
///
/// Provides methods to discover peers, connect, send/receive messages
/// over TCP sockets established on top of a Wi-Fi Direct group.
class WifiDirectService {
  static const _method = MethodChannel('com.proxi.wifi_direct');
  static const _events = EventChannel('com.proxi.wifi_direct/events');

  StreamSubscription? _eventSub;
  final _eventCtrl = StreamController<WifiDirectEvent>.broadcast();

  /// Stream of events from the native Wi-Fi Direct layer.
  Stream<WifiDirectEvent> get events => _eventCtrl.stream;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  static void _log(String msg) => debugPrint('[WiFiDirect] $msg');

  /// Initialize the native WifiP2pManager and register the BroadcastReceiver.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      final ok = await _method.invokeMethod<bool>('initialize') ?? false;
      if (ok) {
        _eventSub = _events.receiveBroadcastStream().listen(
          (event) {
            if (event is Map) {
              final map = Map<String, dynamic>.from(event);
              final type = map.remove('type') as String? ?? '';
              _eventCtrl.add(WifiDirectEvent(type, map));
              _log('Event: $type');
            }
          },
          onError: (e) => _log('Event stream error: $e'),
        );
        _initialized = true;
      }
      _log('initialize: $ok');
      return ok;
    } catch (e) {
      _log('initialize error: $e');
      return false;
    }
  }

  /// Start Wi-Fi Direct peer discovery. Peers will arrive via the event stream.
  Future<bool> startDiscovery() async {
    try {
      final ok = await _method.invokeMethod<bool>('startDiscovery') ?? false;
      _log('startDiscovery: $ok');
      return ok;
    } catch (e) {
      _log('startDiscovery error: $e');
      return false;
    }
  }

  /// Stop Wi-Fi Direct peer discovery.
  Future<bool> stopDiscovery() async {
    try {
      return await _method.invokeMethod<bool>('stopDiscovery') ?? false;
    } catch (e) {
      _log('stopDiscovery error: $e');
      return false;
    }
  }

  /// Connect to a Wi-Fi Direct peer by MAC address.
  Future<bool> connectToPeer(String address) async {
    try {
      final ok =
          await _method.invokeMethod<bool>('connectToPeer', {'address': address}) ?? false;
      _log('connectToPeer($address): $ok');
      return ok;
    } catch (e) {
      _log('connectToPeer error: $e');
      return false;
    }
  }

  /// Disconnect from the current Wi-Fi Direct group.
  Future<bool> disconnect() async {
    try {
      return await _method.invokeMethod<bool>('disconnect') ?? false;
    } catch (e) {
      _log('disconnect error: $e');
      return false;
    }
  }

  /// Send a newline-delimited message over an existing socket connection.
  /// If [targetAddress] is null, broadcasts to all connected sockets.
  Future<bool> sendMessage(String message, {String? targetAddress}) async {
    try {
      return await _method.invokeMethod<bool>('sendMessage', {
            'message': message,
            'targetAddress': targetAddress,
          }) ??
          false;
    } catch (e) {
      _log('sendMessage error: $e');
      return false;
    }
  }

  /// Get the current list of discovered Wi-Fi Direct peers.
  Future<List<WifiDirectPeer>> getPeers() async {
    try {
      final result = await _method.invokeMethod<List>('getPeers');
      if (result == null) return [];
      return result.map((p) {
        final m = Map<String, dynamic>.from(p as Map);
        return WifiDirectPeer(
          name: m['name'] as String? ?? '',
          address: m['address'] as String? ?? '',
          status: m['status'] as String? ?? '',
          isGroupOwner: m['isGroupOwner'] == true,
        );
      }).toList();
    } catch (e) {
      _log('getPeers error: $e');
      return [];
    }
  }

  /// Release all native resources.
  Future<void> dispose() async {
    _eventSub?.cancel();
    _eventSub = null;
    if (!_eventCtrl.isClosed) _eventCtrl.close();
    try {
      await _method.invokeMethod('dispose');
    } catch (_) {}
    _initialized = false;
  }
}
