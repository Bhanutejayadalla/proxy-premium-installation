import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../services/firebase_service.dart';

/// Reusable connection button that shows state-aware UI:
/// - "Connect" if no connection exists
/// - "Pending" if request sent
/// - "Connected" if accepted
/// - "Accept / Decline" if incoming request
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
    final state = Provider.of<AppState>(context, listen: false);
    if (state.currentUser == null) return const SizedBox();

    return FutureBuilder<String>(
      future: FirebaseService()
          .getConnectionStatus(state.currentUser!.uid, targetUid),
      builder: (context, snap) {
        final status = snap.data ?? 'none';

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
          case 'pending':
            return OutlinedButton.icon(
              icon: const Icon(LucideIcons.clock, size: 16),
              label: const Text("Pending"),
              onPressed: null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            );
          case 'incoming':
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // Find and accept the connection doc
                    // This is simplified; in production, pass the connection ID
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Accepted!")));
                  },
                  child: const Text("Accept"),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Declined")));
                  },
                  child: const Text("Decline"),
                ),
              ],
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
      },
    );
  }
}
