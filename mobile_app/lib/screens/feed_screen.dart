import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../constants.dart';
import '../widgets/post_card.dart';
import 'story_view_screen.dart';
import 'create_post_screen.dart';

/// Represents a group of stories from one user.
class _StoryGroup {
  final String authorId;
  final String username;
  final String avatarUrl;
  final List<Map<String, dynamic>> stories;

  _StoryGroup({
    required this.authorId,
    required this.username,
    required this.avatarUrl,
    required this.stories,
  });
}

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  /// Group stories by author so the same person has one circle.
  List<_StoryGroup> _groupStories(List<Map<String, dynamic>> stories) {
    final Map<String, _StoryGroup> grouped = {};
    for (final story in stories) {
      final authorId = story['author_id'] ?? '';
      if (authorId.isEmpty) continue;
      if (grouped.containsKey(authorId)) {
        grouped[authorId]!.stories.add(story);
      } else {
        grouped[authorId] = _StoryGroup(
          authorId: authorId,
          username: story['username'] ?? '',
          avatarUrl: story['author_avatar'] ?? '',
          stories: [story],
        );
      }
    }
    return grouped.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color =
        state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final modeName = state.isFormal ? "Professional" : "Social";

    // Group stories by user
    final storyGroups = _groupStories(state.stories);

    return RefreshIndicator(
      onRefresh: () async => state.refresh(),
      child: CustomScrollView(
        slivers: [
          // MODE LABEL
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text("$modeName Feed",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ),

          // STORIES AREA — grouped by user (one circle per person)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: storyGroups.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) return _addStoryBtn(context, color);

                  final group = storyGroups[i - 1];
                  final hasMultiple = group.stories.length > 1;
                  final avatarImg = group.avatarUrl.isNotEmpty
                      ? group.avatarUrl
                      : (group.stories.first['media_url'] ?? '');

                  return GestureDetector(
                    onTap: () {
                      // Open the first story; if multiple, user can swipe
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryViewScreen(
                            story: group.stories.first,
                            storyGroup: group.stories,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundImage: avatarImg.isNotEmpty
                                    ? NetworkImage(avatarImg)
                                    : null,
                                child: avatarImg.isEmpty
                                    ? Text(
                                        (group.username.isNotEmpty
                                                ? group.username
                                                : '?')[0]
                                            .toUpperCase(),
                                        style: const TextStyle(fontSize: 14))
                                    : null,
                              ),
                            ),
                            if (hasMultiple)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text("${group.stories.length}",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(
                            group.username,
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),

          // FEED POSTS (mode-specific)
          state.feed.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                      child: Text(
                          'No $modeName posts yet.\nBe the first to post!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey))),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => PostCard(post: state.feed[i]),
                    childCount: state.feed.length,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _addStoryBtn(BuildContext context, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CreatePostScreen(initialIsStory: true))),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(Icons.add, color: color),
          ),
          const SizedBox(height: 4),
          const Text("Your Story", style: TextStyle(fontSize: 10)),
        ]),
      ),
    );
  }
}