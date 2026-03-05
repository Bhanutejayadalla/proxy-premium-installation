import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import 'user_detail_screen.dart';

class SkillExchangeScreen extends StatelessWidget {
  const SkillExchangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Exchange'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, state),
        icon: const Icon(LucideIcons.refreshCw),
        label: const Text('Offer Skills'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SkillExchange>>(
        stream: state.firebase.getSkillExchangesStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final exchanges = snap.data ?? [];
          if (exchanges.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.refreshCw, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No skill exchanges yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Post what you can teach and what you want to learn!'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: exchanges.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, i) {
              final ex = exchanges[i];
              final isOwn = ex.userId == state.currentUser?.uid;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final u = await state.firebase.getUser(ex.userId);
                          if (u != null && context.mounted) {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => UserDetailScreen(user: u)));
                          }
                        },
                        child: Row(
                          children: [
                            Icon(LucideIcons.user, size: 18, color: color),
                            const SizedBox(width: 8),
                            Text(ex.username,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(LucideIcons.arrowUpCircle, size: 14, color: Colors.green.shade600),
                                    const SizedBox(width: 4),
                                    Text('Can Teach', style: TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: ex.skillsOffered.map((s) =>
                                    Chip(
                                      label: Text(s, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.green.shade50,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                    )).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(LucideIcons.arrowDownCircle, size: 14, color: Colors.blue.shade600),
                                    const SizedBox(width: 4),
                                    Text('Wants to Learn', style: TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blue.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: ex.skillsWanted.map((s) =>
                                    Chip(
                                      label: Text(s, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.blue.shade50,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                    )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (ex.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(ex.description, style: TextStyle(color: Colors.grey.shade600)),
                      ],
                      if (isOwn) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => state.firebase.closeSkillExchange(ex.id),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Close'),
                          ),
                        ),
                      ],
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

  void _showCreateDialog(BuildContext context, AppState state) {
    final descCtrl = TextEditingController();
    final offeredCtrl = TextEditingController();
    final wantedCtrl = TextEditingController();
    final offered = <String>[];
    final wanted = <String>[];
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
                const Text('Skill Exchange', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Skills You Can Teach:', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(child: TextField(controller: offeredCtrl, decoration: const InputDecoration(hintText: 'e.g. Flutter', border: OutlineInputBorder(), isDense: true))),
                    IconButton(
                      onPressed: () {
                        if (offeredCtrl.text.trim().isNotEmpty) {
                          setModalState(() => offered.add(offeredCtrl.text.trim()));
                          offeredCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Wrap(spacing: 4, children: offered.map((s) =>
                    Chip(label: Text(s), onDeleted: () => setModalState(() => offered.remove(s)),
                        backgroundColor: Colors.green.shade50)).toList()),
                const SizedBox(height: 10),
                const Text('Skills You Want to Learn:', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(child: TextField(controller: wantedCtrl, decoration: const InputDecoration(hintText: 'e.g. Machine Learning', border: OutlineInputBorder(), isDense: true))),
                    IconButton(
                      onPressed: () {
                        if (wantedCtrl.text.trim().isNotEmpty) {
                          setModalState(() => wanted.add(wantedCtrl.text.trim()));
                          wantedCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Wrap(spacing: 4, children: wanted.map((s) =>
                    Chip(label: Text(s), onDeleted: () => setModalState(() => wanted.remove(s)),
                        backgroundColor: Colors.blue.shade50)).toList()),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Additional Details', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (offered.isEmpty && wanted.isEmpty) return;
                      state.firebase.createSkillExchange({
                        'user_id': state.currentUser!.uid,
                        'username': state.currentUser!.username,
                        'skills_offered': offered,
                        'skills_wanted': wanted,
                        'description': descCtrl.text.trim(),
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Post Exchange'),
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
