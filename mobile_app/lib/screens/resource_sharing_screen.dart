import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';

class ResourceSharingScreen extends StatefulWidget {
  const ResourceSharingScreen({super.key});
  @override
  State<ResourceSharingScreen> createState() => _ResourceSharingScreenState();
}

class _ResourceSharingScreenState extends State<ResourceSharingScreen> {
  String? _filterSubject;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Resources'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          if (_filterSubject != null)
            IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () => setState(() => _filterSubject = null),
              tooltip: 'Clear filter',
            ),
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context, state),
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.upload),
        label: const Text('Share'),
      ),
      body: StreamBuilder<List<SharedResource>>(
        stream: state.firebase.getSharedResourcesStream(subject: _filterSubject),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final resources = snap.data ?? [];
          if (resources.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.fileText, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No resources shared yet',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Be the first to share notes, papers, or links!'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: resources.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, i) => _ResourceCard(resource: resources[i]),
          );
        },
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final ctrl = TextEditingController(text: _filterSubject ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter by Subject'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Mathematics, DSA, Physics',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _filterSubject = ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showUploadSheet(BuildContext context, AppState state) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String type = 'notes';
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
                const Text('Share a Resource',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject / Topic', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Resource Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'notes', child: Text('Notes')),
                    DropdownMenuItem(value: 'paper', child: Text('Previous Paper')),
                    DropdownMenuItem(value: 'link', child: Text('Useful Link')),
                    DropdownMenuItem(value: 'book', child: Text('Book / PDF')),
                    DropdownMenuItem(value: 'video', child: Text('Video Resource')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL (Google Drive, YouTube, etc.)',
                    border: OutlineInputBorder(),
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      state.firebase.createSharedResource({
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'subject': subjectCtrl.text.trim(),
                        'type': type,
                        'link_url': urlCtrl.text.trim(),
                        'author_id': state.currentUser!.uid,
                        'author_username': state.currentUser!.username,
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Resource shared!')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Share Resource'),
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

class _ResourceCard extends StatelessWidget {
  final SharedResource resource;
  const _ResourceCard({required this.resource});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'notes': return LucideIcons.fileText;
      case 'paper': return LucideIcons.fileBadge;
      case 'link': return LucideIcons.link;
      case 'book': return LucideIcons.bookOpen;
      case 'video': return LucideIcons.video;
      default: return LucideIcons.file;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'notes': return Colors.blue;
      case 'paper': return Colors.orange;
      case 'link': return Colors.teal;
      case 'book': return Colors.purple;
      case 'video': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final liked = resource.likes.contains(state.currentUser?.uid);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _typeColor(resource.type).withValues(alpha: 0.15),
                  child: Icon(_typeIcon(resource.type), color: _typeColor(resource.type), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resource.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('by ${resource.authorUsername} • ${resource.subject}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor(resource.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(resource.type.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                          color: _typeColor(resource.type))),
                ),
              ],
            ),
            if (resource.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(resource.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const Divider(height: 16),
            Row(
              children: [
                InkWell(
                  onTap: () => state.firebase.likeResource(resource.id, state.currentUser!.uid),
                  child: Row(
                    children: [
                      Icon(liked ? Icons.favorite : Icons.favorite_border,
                          size: 18, color: liked ? Colors.red : Colors.grey),
                      const SizedBox(width: 4),
                      Text('${resource.likes.length}'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Icon(LucideIcons.download, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${resource.downloads}'),
                  ],
                ),
                const Spacer(),
                if (resource.linkUrl != null && resource.linkUrl!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      state.firebase.incrementResourceDownloads(resource.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Open: ${resource.linkUrl}')),
                      );
                    },
                    icon: const Icon(LucideIcons.externalLink, size: 16),
                    label: const Text('Open'),
                    style: TextButton.styleFrom(foregroundColor: color),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
