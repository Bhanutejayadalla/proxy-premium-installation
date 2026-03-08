import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_state.dart';
import 'chat_detail_screen.dart';
import 'user_detail_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

enum _ScanStatus { idle, scanning, done, error }

class _NearbyScreenState extends State<NearbyScreen> {
  _ScanStatus _status = _ScanStatus.idle;
  String _errorMessage = '';
  final Set<String> _pendingRequests = {};
  bool _bleAdapterOn = false;
  bool _locationServiceOn = false;   // permission granted AND service enabled
  bool _locationServiceEnabled = false; // service switch in system settings

  @override
  void initState() {
    super.initState();
    _refreshAdapterStatus();
    // Auto-start BLE advertising as soon as user opens the Nearby screen.
    // This ensures the device is visible BEFORE the other user taps Scan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<AppState>(context, listen: false);
      if (state.discoveryMode == DiscoveryMode.ble) {
        state.startBleAdvertising();
      }
    });
  }

  Future<void> _refreshAdapterStatus() async {
    final state = Provider.of<AppState>(context, listen: false);
    final bleOn = await state.ble.isBluetoothOn();
    final locServiceOn = await state.location.isLocationServiceEnabled();
    final locPermOk = locServiceOn ? await state.location.requestPermission() : false;
    if (mounted) {
      setState(() {
        _bleAdapterOn = bleOn;
        _locationServiceEnabled = locServiceOn;
        _locationServiceOn = locPermOk;
      });
    }
  }

  Future<bool> _checkPermissions(DiscoveryMode mode) async {
    if (mode == DiscoveryMode.ble) {
      final btScan = await Permission.bluetoothScan.request();
      final btConnect = await Permission.bluetoothConnect.request();
      final btAdvertise = await Permission.bluetoothAdvertise.request();
      final location = await Permission.locationWhenInUse.request();

      if (btScan.isDenied || btConnect.isDenied || btAdvertise.isDenied || location.isDenied) {
        setState(() {
          _status = _ScanStatus.error;
          _errorMessage =
              'Bluetooth and Location permissions are required for BLE scanning.';
        });
        return false;
      }
      if (btScan.isPermanentlyDenied ||
          btConnect.isPermanentlyDenied ||
          btAdvertise.isPermanentlyDenied ||
          location.isPermanentlyDenied) {
        setState(() {
          _status = _ScanStatus.error;
          _errorMessage =
              'Permissions permanently denied. Please enable them in Settings.';
        });
        return false;
      }
    } else {
      final location = await Permission.locationWhenInUse.request();
      if (location.isDenied) {
        setState(() {
          _status = _ScanStatus.error;
          _errorMessage = 'Location permission is required for GPS scanning.';
        });
        return false;
      }
      if (location.isPermanentlyDenied) {
        setState(() {
          _status = _ScanStatus.error;
          _errorMessage =
              'Location permanently denied. Please enable it in Settings.';
        });
        return false;
      }
    }
    return true;
  }

  void _handleScan() async {
    final state = Provider.of<AppState>(context, listen: false);

    // Refresh adapter status
    await _refreshAdapterStatus();

    // Check permissions first
    final ok = await _checkPermissions(state.discoveryMode);
    if (!ok) return;

    setState(() {
      _status = _ScanStatus.scanning;
      _errorMessage = '';
    });

    try {
      await state.scanNearby();

      if (mounted) {
        // Check if BLE scan produced an error
        if (state.bleScanError.isNotEmpty) {
          setState(() {
            _status = _ScanStatus.error;
            _errorMessage = state.bleScanError;
          });
        } else {
          setState(() => _status = _ScanStatus.done);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _ScanStatus.error;
          _errorMessage = 'Scan failed: $e';
        });
      }
    }
  }

  Future<void> _handleConnectionRequest(
      AppState state, String uid) async {
    setState(() => _pendingRequests.add(uid));
    try {
      await state.sendConnectionRequest(uid);
      if (mounted) {
        // Check if it was queued offline
        final wasQueued = state.isConnectionQueuedOffline(uid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasQueued
                ? 'Request queued — will send when online'
                : 'Connection request sent!'),
            backgroundColor: wasQueued ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _pendingRequests.remove(uid));
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Column(
      children: [
        // BLE / GPS TOGGLE
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Bluetooth"),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _bleAdapterOn
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                          _bleAdapterOn ? "Ready" : "Off",
                          style: TextStyle(fontSize: 8,
                              color: _bleAdapterOn ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                avatar: const Icon(Icons.bluetooth, size: 16),
                selected: state.discoveryMode == DiscoveryMode.ble,
                onSelected: (_) => state.setDiscoveryMode(DiscoveryMode.ble),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("GPS"),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _locationServiceOn
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                          _locationServiceOn ? "Ready" : "Off",
                          style: TextStyle(fontSize: 8,
                              color: _locationServiceOn ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                avatar: const Icon(Icons.gps_fixed, size: 16),
                selected: state.discoveryMode == DiscoveryMode.gps,
                onSelected: (_) => state.setDiscoveryMode(DiscoveryMode.gps),
              ),
              const Spacer(),
              // Status indicator
              if (_status == _ScanStatus.scanning)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 6),
                    Text("Scanning...",
                        style: TextStyle(fontSize: 12, color: Colors.blue)),
                  ],
                ),
              if (_status == _ScanStatus.done)
                Text(
                    state.discoveryMode == DiscoveryMode.ble
                        ? "${state.bleProxiUsersDetected} Proxi (${state.bleDevicesDetected} BLE)"
                        : "${state.nearbyUsers.length} found",
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // Radius info banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: state.discoveryMode == DiscoveryMode.ble
                ? Colors.blue.withValues(alpha: 0.08)
                : Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                state.discoveryMode == DiscoveryMode.ble
                    ? Icons.bluetooth
                    : Icons.gps_fixed,
                size: 14,
                color: state.discoveryMode == DiscoveryMode.ble
                    ? Colors.blue
                    : Colors.green,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.discoveryMode == DiscoveryMode.ble
                      ? "BLE range: ~30-50m  \u2022  No internet needed"
                      : "GPS radius: 10 km  \u2022  Requires internet",
                  style: TextStyle(
                    fontSize: 11,
                    color: state.discoveryMode == DiscoveryMode.ble
                        ? Colors.blue[700]
                        : Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Advertising status indicator (BLE mode only)
              if (state.discoveryMode == DiscoveryMode.ble)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: state.isBleAdvertising
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isBleAdvertising ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.isBleAdvertising ? "Visible" : "Hidden",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: state.isBleAdvertising ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Location Services disabled warning
        if (state.discoveryMode == DiscoveryMode.ble && !_locationServiceEnabled)
          GestureDetector(
            onTap: () async {
              await openAppSettings();
              await _refreshAdapterStatus();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_off, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location Services OFF \u2014 BLE scan may not work. Tap to enable.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Advertising not active warning (BLE mode)
        if (state.discoveryMode == DiscoveryMode.ble &&
            !state.isBleAdvertising &&
            _bleAdapterOn)
          GestureDetector(
            onTap: () {
              final s = Provider.of<AppState>(context, listen: false);
              s.startBleAdvertising();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_off, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your device is not visible to others. Tap to start broadcasting.',
                      style: TextStyle(fontSize: 11, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // SCANNER AREA
        GestureDetector(
          onTap: _status == _ScanStatus.scanning ? null : _handleScan,
          child: Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_status == _ScanStatus.scanning) ...[
                  _ripple(100, 0),
                  _ripple(150, 400),
                  _ripple(200, 800),
                ],
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _status == _ScanStatus.scanning
                      ? Colors.blue
                      : _status == _ScanStatus.error
                          ? Colors.red[100]
                          : Colors.grey[200],
                  child: Icon(
                    state.discoveryMode == DiscoveryMode.ble
                        ? LucideIcons.radar
                        : Icons.gps_fixed,
                    color: _status == _ScanStatus.scanning
                        ? Colors.white
                        : _status == _ScanStatus.error
                            ? Colors.red
                            : Colors.black,
                    size: 30,
                  ),
                ),
                if (_status == _ScanStatus.scanning)
                  const Positioned(
                    bottom: 0,
                    child: Text("Searching for people nearby...",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),

        // ERROR MESSAGE
        if (_status == _ScanStatus.error && _errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage,
                          style: const TextStyle(color: Colors.red)),
                    ),
                    TextButton(
                      onPressed: () => openAppSettings(),
                      child: const Text("Settings"),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const Divider(),

        // RESULTS LIST
        Expanded(
          child: state.nearbyUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.radar,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _status == _ScanStatus.done
                            ? "No one found nearby. Try again later."
                            : "Tap the scanner to find people nearby.",
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: state.nearbyUsers.length,
                  itemBuilder: (ctx, i) {
                    final user = state.nearbyUsers[i];
                    final avatar = user.getAvatar(state.isFormal);
                    final isPending = _pendingRequests.contains(user.uid);
                    final connStatus = state.connectionStatusWith(user.uid);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? Text(user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : '?')
                            : null,
                      ),
                      title: Text(user.username),
                      subtitle: Row(
                        children: [
                          if (user.distanceKm != null) ...[
                            // Signal strength icon for BLE discoveries
                            if (state.discoveryMode == DiscoveryMode.ble) ...[
                              Icon(
                                user.distanceKm! < 0.01
                                    ? Icons.signal_cellular_4_bar
                                    : user.distanceKm! < 0.03
                                        ? Icons.signal_cellular_alt
                                        : Icons.signal_cellular_alt_1_bar,
                                size: 12,
                                color: user.distanceKm! < 0.01
                                    ? Colors.green
                                    : user.distanceKm! < 0.03
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                user.distanceKm! < 0.1
                                    ? '${(user.distanceKm! * 1000).toStringAsFixed(0)} m away'
                                    : '${user.distanceKm!.toStringAsFixed(1)} km away',
                              ),
                            ),
                          ] else
                            Flexible(child: Text(user.bio)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.messageCircle,
                                color: Colors.blue),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                    targetUser: user.username,
                                    targetUid: user.uid),
                              ),
                            ),
                          ),
                          if (connStatus == 'accepted')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("Connected",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            )
                          else if (connStatus == 'pending_sent')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("Pending",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            )
                          else if (connStatus == 'pending_received')
                            GestureDetector(
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                // Find the connection and accept it
                                final connId = await state.firebase
                                    .findConnectionId(state.currentUser!.uid, user.uid, mode: state.currentMode);
                                if (connId != null) {
                                  await state.respondToConnection(connId, 'accepted');
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Connection accepted!'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text("Accept?",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold)),
                              ),
                            )
                          else
                            isPending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : IconButton(
                                    icon: const Icon(LucideIcons.userPlus,
                                        color: Colors.green),
                                    onPressed: () =>
                                        _handleConnectionRequest(state, user.uid),
                                  ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDetailScreen(user: user),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _ripple(double size, int delay) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 2),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(duration: 1.5.seconds, delay: delay.ms)
        .fadeOut(duration: 1.5.seconds, delay: delay.ms);
  }
}