import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class PrivacySettingsSheet extends StatelessWidget {
  const PrivacySettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const PrivacySettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final vis = state.currentUser?.visibility ?? 'public';
        final discoverable = state.currentUser?.discoverable ?? true;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Privacy Settings",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // VISIBILITY
              const Text("Profile Visibility",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: const Text("Public"),
                subtitle: const Text("Anyone can see your profile"),
                value: 'public',
                groupValue: vis,
                onChanged: (v) => state.updateProfile({'visibility': v}),
              ),
              RadioListTile<String>(
                title: const Text("Connections Only"),
                subtitle:
                    const Text("Only connections see full profile"),
                value: 'connections',
                groupValue: vis,
                onChanged: (v) => state.updateProfile({'visibility': v}),
              ),
              RadioListTile<String>(
                title: const Text("Private"),
                subtitle: const Text("Only you can see your details"),
                value: 'private',
                groupValue: vis,
                onChanged: (v) => state.updateProfile({'visibility': v}),
              ),

              const Divider(),

              // DISCOVERABLE
              SwitchListTile(
                title: const Text("Discoverable"),
                subtitle:
                    const Text("Appear in nearby search results"),
                value: discoverable,
                onChanged: (v) =>
                    state.updateProfile({'discoverable': v}),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
