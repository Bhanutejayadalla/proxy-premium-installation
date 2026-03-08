import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});
  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppState>(context, listen: false).currentUser!;
    _entries = List<Map<String, dynamic>>.from(
      user.education.map((e) => {
            'institution': e['institution'] ?? '',
            'degree': e['degree'] ?? '',
            'year': e['year'] ?? '',
          }),
    );
  }

  void _add() {
    setState(() {
      _entries.add({'institution': '', 'degree': '', 'year': ''});
    });
  }

  void _remove(int i) => setState(() => _entries.removeAt(i));

  Future<void> _save() async {
    final state = Provider.of<AppState>(context, listen: false);
    final valid = _entries
        .where((e) => (e['institution'] as String).isNotEmpty)
        .toList();
    await state.updateProfile({'education': valid});
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Education updated")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Education"),
        actions: [
          TextButton(
              onPressed: _save,
              child: const Text("Save",
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _entries.isEmpty
          ? const Center(
              child: Text("No education added yet.\nTap + to add.",
                  textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, i) {
                final e = _entries[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Education Entry",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              onPressed: () => _remove(i),
                            ),
                          ],
                        ),
                        TextField(
                          controller:
                              TextEditingController(text: e['institution']),
                          decoration: const InputDecoration(
                              labelText: "Institution",
                              border: OutlineInputBorder()),
                          onChanged: (v) => setState(
                              () => _entries[i] = {...e, 'institution': v}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller:
                              TextEditingController(text: e['degree']),
                          decoration: const InputDecoration(
                              labelText: "Degree / Field of Study",
                              border: OutlineInputBorder()),
                          onChanged: (v) => setState(
                              () => _entries[i] = {...e, 'degree': v}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller:
                              TextEditingController(text: e['year']),
                          decoration: const InputDecoration(
                              labelText: "Graduation Year",
                              border: OutlineInputBorder()),
                          onChanged: (v) => setState(
                              () => _entries[i] = {...e, 'year': v}),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
