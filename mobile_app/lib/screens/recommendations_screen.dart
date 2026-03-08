import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import 'user_detail_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<AppUser> _recommended = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.currentUser == null) return;
    try {
      final users = await state.firebase.getRecommendedUsers(state.currentUser!);
      setState(() {
        _recommended = users;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended for You'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recommended.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.sparkles, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No recommendations yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Add skills & interests to your profile\nto get personalized suggestions',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecommendations,
                  child: ListView.builder(
                    itemCount: _recommended.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (ctx, i) {
                      final user = _recommended[i];
                      final commonSkills = state.currentUser!.skills
                          .where((s) => user.skills.contains(s)).toList();
                      final commonInterests = state.currentUser!.interests
                          .where((c) => user.interests.contains(c)).toList();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => UserDetailScreen(user: user))),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: user.getAvatar(state.isFormal).isNotEmpty
                                      ? NetworkImage(user.getAvatar(state.isFormal))
                                      : null,
                                  child: user.getAvatar(state.isFormal).isEmpty
                                      ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                          style: const TextStyle(fontSize: 20))
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.fullName.isNotEmpty ? user.fullName : user.username,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (user.headline.isNotEmpty)
                                        Text(user.headline, maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey.shade600)),
                                      const SizedBox(height: 6),
                                      if (commonSkills.isNotEmpty)
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            Icon(LucideIcons.zap, size: 12, color: color),
                                            ...commonSkills.take(3).map((s) =>
                                              Text(s, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
                                          ],
                                        ),
                                      if (commonInterests.isNotEmpty)
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            const Icon(LucideIcons.heart, size: 12, color: AppColors.casualPrimary),
                                            ...commonInterests.take(3).map((c) =>
                                              Text(c, style: const TextStyle(fontSize: 12, color: AppColors.casualPrimary))),
                                          ],
                                        ),
                                      if (user.department.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(LucideIcons.building, size: 12, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text('${user.department}${user.year.isNotEmpty ? " • ${user.year}" : ""}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(LucideIcons.chevronRight, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
