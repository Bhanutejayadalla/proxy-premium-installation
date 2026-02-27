import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/firebase_service.dart';
import 'user_detail_screen.dart';

/// Displays lists of Followers, Following, and Connections for a user.
/// [initialTab] 0 = Followers, 1 = Following, 2 = Connections.
class FollowersFollowingScreen extends StatelessWidget {
  final AppUser user;
  final int initialTab;

  const FollowersFollowingScreen({
    super.key,
    required this.user,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final mode = state.currentMode;
    final isOwnProfile = user.uid == state.currentUser?.uid;

    // Mode-specific data
    final modeFollowers = user.getFollowersForMode(mode);
    final modeFollowing = user.getFollowingForMode(mode);
    final modeLabel = state.isFormal ? 'Pro' : 'Social';

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text("${user.username} ($modeLabel)"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Followers (${modeFollowers.length})"),
              Tab(text: "Following (${modeFollowing.length})"),
              Tab(text: "Connections (${state.connectedUids.length})"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Followers tab
            _UserListTab(
              uids: modeFollowers,
              emptyMessage: "No followers in $modeLabel mode",
              isFormal: state.isFormal,
              currentUid: state.currentUser?.uid ?? '',
              isOwnProfile: isOwnProfile,
              actionType: _ActionType.removeFollower,
            ),
            // Following tab
            _UserListTab(
              uids: modeFollowing,
              emptyMessage: "Not following anyone in $modeLabel mode",
              isFormal: state.isFormal,
              currentUid: state.currentUser?.uid ?? '',
              isOwnProfile: isOwnProfile,
              actionType: _ActionType.unfollow,
            ),
            // Connections tab
            _UserListTab(
              uids: state.connectedUids,
              emptyMessage: "No connections in $modeLabel mode",
              isFormal: state.isFormal,
              currentUid: state.currentUser?.uid ?? '',
              isOwnProfile: isOwnProfile,
              actionType: _ActionType.disconnect,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ActionType { removeFollower, unfollow, disconnect }

class _UserListTab extends StatelessWidget {
  final List<String> uids;
  final String emptyMessage;
  final bool isFormal;
  final String currentUid;
  final bool isOwnProfile;
  final _ActionType actionType;

  const _UserListTab({
    required this.uids,
    required this.emptyMessage,
    required this.isFormal,
    required this.currentUid,
    required this.isOwnProfile,
    required this.actionType,
  });

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: uids.length,
      itemBuilder: (context, i) {
        return FutureBuilder<AppUser?>(
          future: FirebaseService().getUser(uids[i]),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const ListTile(
                leading: CircleAvatar(child: Icon(Icons.person)),
                title: Text("Loading..."),
              );
            }
            final u = snap.data!;
            final avatar = u.getAvatar(isFormal);
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty
                    ? Text(u.username.isNotEmpty
                        ? u.username[0].toUpperCase()
                        : '?')
                    : null,
              ),
              title: Text(
                u.fullName.isNotEmpty ? u.fullName : u.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: u.headline.isNotEmpty
                  ? Text(u.headline,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: u.uid == currentUid
                  ? const Chip(label: Text("You", style: TextStyle(fontSize: 12)))
                  : isOwnProfile
                      ? _buildActionButton(context, u)
                      : null,
              onTap: u.uid == currentUid
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UserDetailScreen(user: u))),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, AppUser targetUser) {
    final state = Provider.of<AppState>(context, listen: false);

    switch (actionType) {
      case _ActionType.removeFollower:
        return TextButton(
          onPressed: () => _confirmAction(
            context,
            "Remove Follower",
            "Remove ${targetUser.username} from your followers?",
            () => state.removeFollower(targetUser.uid),
          ),
          child: const Text("Remove", style: TextStyle(color: Colors.red)),
        );
      case _ActionType.unfollow:
        return TextButton(
          onPressed: () => _confirmAction(
            context,
            "Unfollow",
            "Unfollow ${targetUser.username}?",
            () => state.unfollowUserAction(targetUser.uid),
          ),
          child: const Text("Unfollow", style: TextStyle(color: Colors.orange)),
        );
      case _ActionType.disconnect:
        return TextButton(
          onPressed: () => _confirmAction(
            context,
            "Disconnect",
            "Remove connection with ${targetUser.username}?",
            () => state.removeConnection(targetUser.uid),
          ),
          child: const Text("Remove", style: TextStyle(color: Colors.red)),
        );
    }
  }

  void _confirmAction(BuildContext context, String title, String message,
      Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirm", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$title completed")),
        );
      }
    }
  }
}
