import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});
  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _description = TextEditingController();
  final _skills = TextEditingController();
  final _location = TextEditingController(text: "Remote");
  String _type = 'full-time';
  bool _saving = false;

  final _types = ['full-time', 'part-time', 'internship', 'freelance'];

  Future<void> _post() async {
    if (_title.text.isEmpty || _company.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Title and company are required")));
      return;
    }
    setState(() => _saving = true);
    try {
      final state = Provider.of<AppState>(context, listen: false);
      final skills = _skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await state.createJob(
        title: _title.text.trim(),
        company: _company.text.trim(),
        description: _description.text.trim(),
        skills: skills,
        location: _location.text.trim(),
        type: _type,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Job posted!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _description.dispose();
    _skills.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Job"),
        actions: [
          TextButton(
            onPressed: _saving ? null : _post,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Post",
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: "Job Title *", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _company,
              decoration: const InputDecoration(
                  labelText: "Company *", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _skills,
              decoration: const InputDecoration(
                  labelText: "Required Skills",
                  hintText: "Flutter, Dart, Firebase (comma separated)",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                  labelText: "Location", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text("Job Type",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types
                  .map((t) => ChoiceChip(
                        label: Text(t),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
