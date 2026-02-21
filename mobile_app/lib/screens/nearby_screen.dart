import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_state.dart';
import 'chat_detail_screen.dart';
import 'user_detail_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  bool _isScanning = false;

  void _handleScan() async {
    setState(() => _isScanning = true);
    final state = Provider.of<AppState>(context, listen: false);
    state.scanNearby();
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _isScanning = false);
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
            ],
          ),
        ),

        // SCANNER AREA
        GestureDetector(
          onTap: _isScanning ? null : _handleScan,
          child: Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isScanning) ...[
                  _ripple(100, 0),
                  _ripple(150, 400),
                  _ripple(200, 800),
                ],
                CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      _isScanning ? Colors.blue : Colors.grey[200],
                  child: Icon(
                      state.discoveryMode == DiscoveryMode.ble
                          ? LucideIcons.radar
                          : Icons.gps_fixed,
                      color: _isScanning ? Colors.white : Colors.black,
                      size: 30),
                ),
                if (_isScanning)
                  const Positioned(
                      bottom: 0,
                      child: Text("Scanning...",
                          style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),

        const Divider(),

        // RESULTS LIST
        Expanded(
          child: state.nearbyUsers.isEmpty
              ? const Center(child: Text("Tap to scan for people nearby."))
              : ListView.builder(
                  itemCount: state.nearbyUsers.length,
                  itemBuilder: (ctx, i) {
                    final user = state.nearbyUsers[i];
                    final avatar = user.getAvatar(state.isFormal);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
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
                                        targetUid: user.uid))),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.userPlus,
                                color: Colors.green),
                            onPressed: () =>
                                state.sendConnectionRequest(user.uid),
                          ),
                        ],
                      ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailScreen(user: user))),
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
          border: Border.all(
              color: Colors.blue.withOpacity(0.5), width: 2)),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(duration: 1.5.seconds, delay: delay.ms)
        .fadeOut(duration: 1.5.seconds, delay: delay.ms);
  }
}