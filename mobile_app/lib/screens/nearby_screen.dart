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

  Future<bool> _checkPermissions(DiscoveryMode mode) async {
    if (mode == DiscoveryMode.ble) {
      final btScan = await Permission.bluetoothScan.request();
      final btConnect = await Permission.bluetoothConnect.request();
      final location = await Permission.locationWhenInUse.request();

      if (btScan.isDenied || btConnect.isDenied || location.isDenied) {
        setState(() {
          _status = _ScanStatus.error;
          _errorMessage =
              'Bluetooth and Location permissions are required for BLE scanning.';
        });
        return false;
      }
      if (btScan.isPermanentlyDenied ||
          btConnect.isPermanentlyDenied ||
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

    // Check permissions first
    final ok = await _checkPermissions(state.discoveryMode);
    if (!ok) return;

    setState(() {
      _status = _ScanStatus.scanning;
      _errorMessage = '';
    });

    try {
      state.scanNearby();
      // Wait a reasonable amount for results
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) {
        setState(
            () => _status = _ScanStatus.done);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
                label: const Text("Bluetooth"),
                avatar: const Icon(Icons.bluetooth, size: 16),
                selected: state.discoveryMode == DiscoveryMode.ble,
                onSelected: (_) => state.setDiscoveryMode(DiscoveryMode.ble),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text("GPS"),
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
                    "${state.nearbyUsers.length} found",
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
                ? Colors.blue.withOpacity(0.08)
                : Colors.green.withOpacity(0.08),
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
              Text(
                state.discoveryMode == DiscoveryMode.ble
                    ? "BLE range: ~30-50 meters (RSSI filtered)"
                    : "GPS radius: 10 km",
                style: TextStyle(
                  fontSize: 11,
                  color: state.discoveryMode == DiscoveryMode.ble
                      ? Colors.blue[700]
                      : Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
                      subtitle: Text(user.distanceKm != null
                          ? '${user.distanceKm!.toStringAsFixed(1)} km away'
                          : user.bio),
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
                                color: Colors.green.withOpacity(0.1),
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
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("Pending",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            )
                          else if (connStatus == 'pending_received')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("Accept?",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
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
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(duration: 1.5.seconds, delay: delay.ms)
        .fadeOut(duration: 1.5.seconds, delay: delay.ms);
  }
}