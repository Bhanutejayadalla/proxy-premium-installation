import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../constants.dart';
import '../widgets/post_card.dart';
import 'story_view_screen.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color =
        state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final modeName = state.isFormal ? "Professional" : "Social";

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

          // STORIES AREA (mode-specific)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.stories.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) return _addStoryBtn(context);
                  final story = state.stories[i - 1];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  StoryViewScreen(story: story)));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: (story['author_avatar'] ??
                                            story['media_url'] ??
                                            '')
                                        .toString()
                                        .isNotEmpty
                                ? NetworkImage(story['author_avatar'] ??
                                    story['media_url'] ??
                                    '')
                                : null,
                            child: (story['author_avatar'] ??
                                            story['media_url'] ??
                                            '')
                                        .toString()
                                        .isEmpty
                                ? Text((story['username'] ?? '?')[0],
                                    style: const TextStyle(fontSize: 14))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(story['username'] ?? '',
                            style: const TextStyle(fontSize: 10)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),

          // FEED POSTS (mode-specific — only shows posts matching current mode)
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

  Widget _addStoryBtn(BuildContext context) {
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
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Icon(Icons.add, color: Colors.blue),
          ),
          const SizedBox(height: 4),
          const Text("Your Story", style: TextStyle(fontSize: 10)),
        ]),
      ),
    );
  }
}