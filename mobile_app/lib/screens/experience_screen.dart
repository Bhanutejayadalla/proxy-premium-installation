import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class ExperienceScreen extends StatefulWidget {
  const ExperienceScreen({super.key});
  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen> {
  List<Map<String, dynamic>> _experiences = [];

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppState>(context, listen: false).currentUser!;
    _experiences = List<Map<String, dynamic>>.from(
      user.experience.map((e) => {
            'title': e['title'] ?? '',
            'company': e['company'] ?? '',
            'start_date': e['start_date'] ?? '',
            'end_date': e['end_date'],
            'description': e['description'] ?? '',
          }),
    );
  }

  void _addEntry() {
    setState(() {
      _experiences.add({
        'title': '',
        'company': '',
        'start_date': '',
        'end_date': null,
        'description': '',
      });
    });
  }

  void _removeEntry(int index) {
    setState(() => _experiences.removeAt(index));
  }

  Future<void> _save() async {
    final state = Provider.of<AppState>(context, listen: false);
    // Filter out empty entries
    final valid = _experiences
        .where((e) =>
            (e['title'] as String).isNotEmpty &&
            (e['company'] as String).isNotEmpty)
        .toList();
    await state.updateProfile({'experience': valid});
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Experience updated")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Work Experience"),
        actions: [
          TextButton(
            onPressed: _save,
            child:
                const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: _experiences.isEmpty
          ? const Center(
              child: Text("No experience added yet.\nTap + to add one.",
                  textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _experiences.length,
              itemBuilder: (context, index) {
                return _ExperienceForm(
                  data: _experiences[index],
                  onChanged: (updated) =>
                      setState(() => _experiences[index] = updated),
                  onRemove: () => _removeEntry(index),
                );
              },
            ),
    );
  }
}

class _ExperienceForm extends StatelessWidget {
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  const _ExperienceForm({
    required this.data,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Position",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            TextField(
              controller: TextEditingController(text: data['title'])
                ..selection = TextSelection.collapsed(
                    offset: (data['title'] as String).length),
              decoration: const InputDecoration(
                  labelText: "Job Title", border: OutlineInputBorder()),
              onChanged: (v) => onChanged({...data, 'title': v}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: data['company'])
                ..selection = TextSelection.collapsed(
                    offset: (data['company'] as String).length),
              decoration: const InputDecoration(
                  labelText: "Company", border: OutlineInputBorder()),
              onChanged: (v) => onChanged({...data, 'company': v}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        TextEditingController(text: data['start_date'])
                          ..selection = TextSelection.collapsed(
                              offset:
                                  (data['start_date'] as String).length),
                    decoration: const InputDecoration(
                        labelText: "Start (YYYY-MM)",
                        border: OutlineInputBorder()),
                    onChanged: (v) =>
                        onChanged({...data, 'start_date': v}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                        text: data['end_date'] ?? '')
                      ..selection = TextSelection.collapsed(
                          offset: (data['end_date'] as String? ?? '')
                              .length),
                    decoration: const InputDecoration(
                        labelText: "End (or empty=Present)",
                        border: OutlineInputBorder()),
                    onChanged: (v) => onChanged(
                        {...data, 'end_date': v.isEmpty ? null : v}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: data['description'])
                ..selection = TextSelection.collapsed(
                    offset: (data['description'] as String).length),
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: "Description", border: OutlineInputBorder()),
              onChanged: (v) => onChanged({...data, 'description': v}),
            ),
          ],
        ),
      ),
    );
  }
}
