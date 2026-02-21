import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import 'edit_profile_screen.dart';
import 'connection_requests_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Consumer to rebuild when AppState changes (fixes discoverable toggle delay)
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final user = state.currentUser;
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader("Account"),
                  ListTile(
                    leading: const Icon(LucideIcons.user),
                    title: const Text("Edit Profile"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      );
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
                  StreamBuilder<List<Connection>>(
                    stream: state.pendingRequestsStream,
                    builder: (ctx, snap) {
                      final count = snap.data?.length ?? 0;
                      return ListTile(
                        leading: const Icon(LucideIcons.userPlus),
                        title: const Text("Connection Requests"),
                        subtitle: Text(count > 0
                            ? "$count pending request${count == 1 ? '' : 's'}"
                            : "No pending requests"),
                        trailing: count > 0
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Text("$count",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ConnectionRequestsScreen()),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(),

                  // Social Stats — real-time counts
                  const _SectionHeader("Social Stats"),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: LucideIcons.users,
                            label: "Followers",
                            count: user?.followers.length ?? 0,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: LucideIcons.userPlus,
                            label: "Following",
                            count: user?.following.length ?? 0,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<int>(
                            stream: state.firebase
                                .getUserPostsStream(user?.uid ?? '')
                                .map((posts) => posts.length),
                            builder: (ctx, snap) {
                              return _StatCard(
                                icon: LucideIcons.fileText,
                                label: "Posts",
                                count: snap.data ?? 0,
                                color: Colors.orange,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: LucideIcons.award,
                            label: "Skills",
                            count: user?.skills.length ?? 0,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  const _SectionHeader("Discovery"),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.radar),
                    title: const Text("Discoverable"),
                    subtitle: const Text("Allow others to find you nearby"),
                    // Reads directly from Provider-watched state — instant update
                    value: user?.discoverable ?? true,
                    onChanged: (v) async {
                      // Update backend and refresh profile immediately
                      await state.updateProfile({'discoverable': v});
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
                      _showNotificationPrefsSheet(context);
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
                  // Bottom padding to avoid overflow
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
      ),
    );
  }

  void _showNotificationPrefsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Notification Preferences",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Likes"),
                subtitle: const Text("When someone likes your post"),
                value: true,
                onChanged: (v) {},
              ),
              SwitchListTile(
                title: const Text("Comments"),
                subtitle: const Text("When someone comments on your post"),
                value: true,
                onChanged: (v) {},
              ),
              SwitchListTile(
                title: const Text("Connection Requests"),
                subtitle: const Text("When someone wants to connect"),
                value: true,
                onChanged: (v) {},
              ),
              SwitchListTile(
                title: const Text("Messages"),
                subtitle: const Text("When you receive a new message"),
                value: true,
                onChanged: (v) {},
              ),
            ],
          ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$count",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}
