import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import 'create_project_screen.dart';
import 'user_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String? _filterDomain;

  static const domains = [
    'AI/ML', 'Web', 'Mobile', 'IoT', 'Data Science',
    'Cybersecurity', 'Cloud', 'Blockchain', 'Game Dev', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects & Teams'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (v) => setState(() => _filterDomain = v.isEmpty ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Domains')),
              ...domains.map((d) => PopupMenuItem(value: d, child: Text(d))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CreateProjectScreen())),
        icon: const Icon(LucideIcons.plus),
        label: const Text('New Project'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Project>>(
        stream: state.firebase.getProjectsStream(domain: _filterDomain),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snap.data ?? [];
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.folderOpen, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No projects yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Create a project to find team members!'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: projects.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, i) => _ProjectCard(project: projects[i]),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  void _confirmDelete(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Permanently delete "${project.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await state.firebase.deleteProject(project.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final isMember = project.memberIds.contains(state.currentUser?.uid);
    final hasApplied = project.applicantIds.contains(state.currentUser?.uid);
    final isCreator = project.creatorId == state.currentUser?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(project.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: project.status == 'open'
                        ? Colors.green.shade50
                        : project.status == 'in-progress'
                            ? Colors.orange.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(project.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: project.status == 'open'
                            ? Colors.green.shade700
                            : project.status == 'in-progress'
                                ? Colors.orange.shade700
                                : Colors.grey.shade600,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final u = await state.firebase.getUser(project.creatorId);
                if (u != null && context.mounted) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => UserDetailScreen(user: u)));
                }
              },
              child: Text('by ${project.creatorUsername}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            ),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(project.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (project.domain.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(project.domain),
                avatar: const Icon(LucideIcons.layers, size: 14),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
            if (project.requiredSkills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: project.requiredSkills.map((s) =>
                  Chip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.proSkills.withValues(alpha: 0.1),
                  )).toList(),
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Icon(LucideIcons.users, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${project.memberIds.length}/${project.maxMembers} members',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                if (project.applicantIds.isNotEmpty && isCreator) ...[
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.userPlus, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('${project.applicantIds.length} applicants',
                      style: const TextStyle(fontSize: 13, color: Colors.orange)),
                ],
                const Spacer(),
                if (!isMember && !hasApplied && project.status == 'open' && !isCreator)
                  ElevatedButton(
                    onPressed: () => state.firebase.applyToProject(project.id, state.currentUser!.uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Apply'),
                  ),
                if (hasApplied)
                  const Chip(label: Text('Applied', style: TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact),
                if (isMember && !isCreator)
                  const Chip(label: Text('Member', style: TextStyle(fontSize: 12)),
                      avatar: Icon(Icons.check_circle, size: 16, color: Colors.green),
                      visualDensity: VisualDensity.compact),
                if (isCreator)
                  OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, state),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('Delete'),
                  ),
              ],
            ),
            // If creator, show applicant management
            if (isCreator && project.applicantIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Applicants:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ...project.applicantIds.map((uid) =>
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(uid, style: const TextStyle(fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => state.firebase.acceptProjectMember(project.id, uid),
                      ),
                    ],
                  ),
                )),
            ],
          ],
        ),
      ),
    );
  }
}
