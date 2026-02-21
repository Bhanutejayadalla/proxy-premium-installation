import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const _SectionHeader("Account"),
          ListTile(
            leading: const Icon(LucideIcons.user),
            title: const Text("Edit Profile"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Already accessible from profile; pop back
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.shield),
            title: const Text("Privacy"),
            subtitle: const Text("Control who can see your profile"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showPrivacySheet(context);
            },
          ),
          const Divider(),

          const _SectionHeader("Discovery"),
          SwitchListTile(
            secondary: const Icon(LucideIcons.radar),
            title: const Text("Discoverable"),
            subtitle: const Text("Allow others to find you nearby"),
            value: state.currentUser?.discoverable ?? true,
            onChanged: (v) {
              state.updateProfile({'discoverable': v});
            },
          ),
          const Divider(),

          const _SectionHeader("Notifications"),
          ListTile(
            leading: const Icon(LucideIcons.bell),
            title: const Text("Push Notifications"),
            subtitle: const Text("Manage notification preferences"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Placeholder for notification prefs
            },
          ),
          const Divider(),

          const _SectionHeader("About"),
          ListTile(
            leading: const Icon(LucideIcons.info),
            title: const Text("App Version"),
            subtitle: const Text("Proxi 2.0.0"),
          ),
          const Divider(),

          // LOGOUT
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              icon: const Icon(LucideIcons.logOut),
              label: const Text("Log Out"),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                await state.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Privacy Settings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer<AppState>(
              builder: (context, state, _) {
                final vis = state.currentUser?.visibility ?? 'public';
                return Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text("Public"),
                      subtitle:
                          const Text("Anyone can see your profile and posts"),
                      value: 'public',
                      groupValue: vis,
                      onChanged: (v) =>
                          state.updateProfile({'visibility': v}),
                    ),
                    RadioListTile<String>(
                      title: const Text("Connections Only"),
                      subtitle: const Text(
                          "Only your connections can see your profile"),
                      value: 'connections',
                      groupValue: vis,
                      onChanged: (v) =>
                          state.updateProfile({'visibility': v}),
                    ),
                    RadioListTile<String>(
                      title: const Text("Private"),
                      subtitle: const Text(
                          "Only you can see your profile details"),
                      value: 'private',
                      groupValue: vis,
                      onChanged: (v) =>
                          state.updateProfile({'visibility': v}),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600])),
    );
  }
}
