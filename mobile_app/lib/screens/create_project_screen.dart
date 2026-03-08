import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../constants.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});
  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final _maxCtrl = TextEditingController(text: '5');
  String _domain = 'Web';
  final List<String> _skills = [];
  bool _loading = false;

  static const domains = [
    'AI/ML', 'Web', 'Mobile', 'IoT', 'Data Science',
    'Cybersecurity', 'Cloud', 'Blockchain', 'Game Dev', 'Other',
  ];

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    try {
      await state.firebase.createProject({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'creator_id': state.currentUser!.uid,
        'creator_username': state.currentUser!.username,
        'required_skills': _skills,
        'domain': _domain,
        'max_members': int.tryParse(_maxCtrl.text) ?? 5,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Project Title *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _domain,
              decoration: InputDecoration(
                labelText: 'Domain',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: domains.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _domain = v!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _maxCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Max Team Members',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Required Skills', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add a skill',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_skillCtrl.text.trim().isNotEmpty) {
                      setState(() => _skills.add(_skillCtrl.text.trim()));
                      _skillCtrl.clear();
                    }
                  },
                  icon: Icon(LucideIcons.plus, color: color),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: _skills.map((s) =>
                Chip(
                  label: Text(s),
                  onDeleted: () => setState(() => _skills.remove(s)),
                )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Project', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
