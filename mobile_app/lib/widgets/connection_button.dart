import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../screens/connection_requests_screen.dart';

/// Reusable connection button that shows state-aware UI:
/// - "Connect" if no connection exists
/// - "Pending" if request sent
/// - "Connected" if accepted
/// - "Accept" if incoming request (navigates to Connection Requests screen)
class ConnectionButton extends StatelessWidget {
  final String targetUid;
  final String mode;

  const ConnectionButton({
    super.key,
    required this.targetUid,
    this.mode = 'casual',
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    if (state.currentUser == null) return const SizedBox();

    // Use cached connection status from AppState (real-time via streams)
    final status = state.connectionStatusWith(targetUid);

    switch (status) {
      case 'accepted':
        return OutlinedButton.icon(
          icon: const Icon(LucideIcons.check, size: 16),
          label: const Text("Connected"),
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            side: const BorderSide(color: Colors.green),
          ),
        );
      case 'pending_sent':
        return OutlinedButton.icon(
          icon: const Icon(LucideIcons.clock, size: 16),
          label: const Text("Pending"),
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange),
          ),
        );
      case 'pending_received':
        return ElevatedButton.icon(
          icon: const Icon(LucideIcons.userCheck, size: 16),
          label: const Text("Accept"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            // Navigate to Connection Requests screen to accept
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConnectionRequestsScreen(),
              ),
            );
          },
        );
      default:
        return ElevatedButton.icon(
          icon: const Icon(LucideIcons.userPlus, size: 16),
          label: const Text("Connect"),
          onPressed: () {
            state.sendConnectionRequest(targetUid);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Connection request sent")));
          },
        );
    }
  }
}
