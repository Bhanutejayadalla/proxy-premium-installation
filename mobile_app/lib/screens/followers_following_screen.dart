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
    final state = Provider.of<AppState>(context, listen: false);

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(user.username),
          bottom: TabBar(
            tabs: [
              Tab(text: "Followers (${user.followers.length})"),
              Tab(text: "Following (${user.following.length})"),
              Tab(text: "Connections (${state.connectedUids.length})"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Followers tab
            _UserListTab(
              uids: user.followers,
              emptyMessage: "No followers yet",
              isFormal: state.isFormal,
              currentUid: state.currentUser?.uid ?? '',
            ),
            // Following tab
            _UserListTab(
              uids: user.following,
              emptyMessage: "Not following anyone yet",
              isFormal: state.isFormal,
              currentUid: state.currentUser?.uid ?? '',
            ),
            // Connections tab
            _UserListTab(
              uids: state.connectedUids,
              emptyMessage: "No connections yet",
              isFormal: state.isFormal,
              currentUid: state.currentUser?.uid ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListTab extends StatelessWidget {
  final List<String> uids;
  final String emptyMessage;
  final bool isFormal;
  final String currentUid;

  const _UserListTab({
    required this.uids,
    required this.emptyMessage,
    required this.isFormal,
    required this.currentUid,
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
}
