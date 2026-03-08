import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import 'user_detail_screen.dart';

class SearchStudentsScreen extends StatefulWidget {
  const SearchStudentsScreen({super.key});
  @override
  State<SearchStudentsScreen> createState() => _SearchStudentsScreenState();
}

class _SearchStudentsScreenState extends State<SearchStudentsScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedDepartment;
  String? _selectedYear;
  String? _selectedSkill;
  String? _selectedInterest;
  List<AppUser> _results = [];
  bool _loading = false;

  static const departments = [
    'Computer Science', 'Electronics', 'Mechanical', 'Civil',
    'Electrical', 'Information Technology', 'Chemical', 'Biotechnology',
    'Mathematics', 'Physics', 'MBA', 'Other',
  ];

  static const years = ['1st', '2nd', '3rd', '4th', 'Masters', 'PhD'];

  Future<void> _search() async {
    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    try {
      final results = await state.firebase.searchStudents(
        query: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
        department: _selectedDepartment,
        year: _selectedYear,
        skill: _selectedSkill,
        interest: _selectedInterest,
      );
      setState(() {
        _results = results.where((u) => u.uid != state.currentUser?.uid).toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Students'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, username, bio...',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.searchCheck),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('Department', _selectedDepartment, departments, (v) {
                  setState(() => _selectedDepartment = v);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Year', _selectedYear, years, (v) {
                  setState(() => _selectedYear = v);
                }),
                const SizedBox(width: 8),
                _buildSkillInput('Skill', _selectedSkill, (v) {
                  setState(() => _selectedSkill = v);
                }),
                const SizedBox(width: 8),
                _buildSkillInput('Interest', _selectedInterest, (v) {
                  setState(() => _selectedInterest = v);
                }),
                const SizedBox(width: 8),
                if (_selectedDepartment != null || _selectedYear != null ||
                    _selectedSkill != null || _selectedInterest != null)
                  ActionChip(
                    label: const Text('Clear All'),
                    avatar: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedDepartment = null;
                        _selectedYear = null;
                        _selectedSkill = null;
                        _selectedInterest = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(LucideIcons.search),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Results
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_loading && _results.isEmpty)
            const Expanded(child: Center(child: Text('Search for students above'))),
          if (!_loading && _results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (ctx, i) {
                  final user = _results[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.getAvatar(state.isFormal).isNotEmpty
                            ? NetworkImage(user.getAvatar(state.isFormal))
                            : null,
                        child: user.getAvatar(state.isFormal).isEmpty
                            ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Text(user.fullName.isNotEmpty ? user.fullName : user.username,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user.headline.isNotEmpty) Text(user.headline, maxLines: 1),
                          Row(
                            children: [
                              if (user.department.isNotEmpty) ...[
                                Icon(LucideIcons.building, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(user.department, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(width: 8),
                              ],
                              if (user.year.isNotEmpty) ...[
                                Icon(LucideIcons.graduationCap, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(user.year, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ],
                          ),
                          if (user.skills.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              children: user.skills.take(3).map((s) =>
                                Chip(label: Text(s, style: const TextStyle(fontSize: 10)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                )).toList(),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => UserDetailScreen(user: user))),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? selected, List<String> options, ValueChanged<String?> onChanged) {
    return PopupMenuButton<String>(
      child: Chip(
        label: Text(selected ?? label),
        avatar: Icon(selected != null ? Icons.check_circle : Icons.arrow_drop_down, size: 18),
        backgroundColor: selected != null ? Colors.blue.shade50 : null,
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('Any')),
        ...options.map((o) => PopupMenuItem(value: o, child: Text(o))),
      ],
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
    );
  }

  Widget _buildSkillInput(String label, String? value, ValueChanged<String?> onChanged) {
    return GestureDetector(
      onTap: () async {
        final ctrl = TextEditingController(text: value);
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Filter by $label'),
            content: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'Enter $label')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Clear')),
              TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Apply')),
            ],
          ),
        );
        if (result != null) onChanged(result.isEmpty ? null : result);
      },
      child: Chip(
        label: Text(value ?? label),
        avatar: Icon(value != null ? Icons.check_circle : Icons.edit, size: 18),
        backgroundColor: value != null ? Colors.blue.shade50 : null,
      ),
    );
  }
}
