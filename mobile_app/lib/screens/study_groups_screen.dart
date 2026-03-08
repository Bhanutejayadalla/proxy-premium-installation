import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';

class StudyGroupsScreen extends StatelessWidget {
  const StudyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Groups'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, state),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Create Group'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<StudyGroup>>(
        stream: state.firebase.getStudyGroupsStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.bookOpen, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No study groups yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, i) {
              final g = groups[i];
              final isMember = g.memberIds.contains(state.currentUser?.uid);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.bookOpen, color: color, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(g.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                      if (g.subject.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Subject: ${g.subject}', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                      if (g.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(g.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      if (g.schedule.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(g.schedule, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                      if (g.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(LucideIcons.mapPin, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(g.location, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        children: [
                          Icon(LucideIcons.users, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('${g.memberIds.length}/${g.maxMembers} members',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const Spacer(),
                          if (!isMember && g.memberIds.length < g.maxMembers)
                            ElevatedButton(
                              onPressed: () => state.firebase.joinStudyGroup(g.id, state.currentUser!.uid),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Join'),
                            ),
                          if (isMember && g.creatorId != state.currentUser?.uid)
                            OutlinedButton(
                              onPressed: () => state.firebase.leaveStudyGroup(g.id, state.currentUser!.uid),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Leave'),
                            ),
                          if (g.creatorId == state.currentUser?.uid)
                            OutlinedButton.icon(
                              onPressed: () => _confirmDeleteGroup(ctx, state, g),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(LucideIcons.trash2, size: 14),
                              label: const Text('Delete'),
                            ),
                          if (isMember)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, AppState state, StudyGroup g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Study Group'),
        content: Text('Permanently delete "${g.name}"? All members will lose access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await state.firebase.deleteStudyGroup(g.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '10');
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Study Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group Name *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: scheduleCtrl, decoration: const InputDecoration(labelText: 'Schedule (e.g. Mon/Wed 5pm)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Members', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    state.firebase.createStudyGroup({
                      'name': nameCtrl.text.trim(),
                      'subject': subjectCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'schedule': scheduleCtrl.text.trim(),
                      'location': locationCtrl.text.trim(),
                      'creator_id': state.currentUser!.uid,
                      'creator_username': state.currentUser!.username,
                      'max_members': int.tryParse(maxCtrl.text) ?? 10,
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
