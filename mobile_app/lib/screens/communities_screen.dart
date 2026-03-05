import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import 'community_detail_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});
  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Departments'),
            Tab(text: 'Interests'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, state),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Create'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _CommunityList(type: null),
          _CommunityList(type: 'department'),
          _CommunityList(type: 'interest'),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final tags = <String>[];
    String type = 'interest';
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Community', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Community Name *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'department', child: Text('Department')),
                    DropdownMenuItem(value: 'interest', child: Text('Interest-Based')),
                    DropdownMenuItem(value: 'club', child: Text('Club')),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: tagCtrl, decoration: const InputDecoration(hintText: 'Add tag', border: OutlineInputBorder(), isDense: true))),
                    IconButton(
                      onPressed: () {
                        if (tagCtrl.text.trim().isNotEmpty) {
                          setModalState(() => tags.add(tagCtrl.text.trim()));
                          tagCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Wrap(spacing: 4, children: tags.map((t) =>
                    Chip(label: Text(t), onDeleted: () => setModalState(() => tags.remove(t)))).toList()),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      state.firebase.createCommunity({
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'type': type,
                        'creator_id': state.currentUser!.uid,
                        'tags': tags,
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Create Community'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityList extends StatelessWidget {
  final String? type;
  const _CommunityList({this.type});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return StreamBuilder<List<Community>>(
      stream: state.firebase.getCommunitiesStream(type: type),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final communities = snap.data ?? [];
        if (communities.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.users, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No communities yet', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: communities.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (ctx, i) {
            final c = communities[i];
            final isMember = c.memberIds.contains(state.currentUser?.uid);
            final icon = c.type == 'department'
                ? LucideIcons.building
                : c.type == 'club'
                    ? LucideIcons.award
                    : LucideIcons.heart;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CommunityDetailScreen(community: c))),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (c.description.isNotEmpty)
                              Text(c.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade600)),
                            Row(
                              children: [
                                Icon(LucideIcons.users, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text('${c.memberIds.length} members',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(c.type, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isMember)
                        ElevatedButton(
                          onPressed: () => state.firebase.joinCommunity(c.id, state.currentUser!.uid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Join'),
                        )
                      else
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
