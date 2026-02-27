import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../constants.dart';
import '../models.dart';
import '../widgets/job_card.dart';
import 'create_job_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _typeFilter = 'all'; // all | full-time | part-time | contract | internship

  static const _jobTypes = ['all', 'full-time', 'part-time', 'contract', 'internship'];

  List<Job> _filteredJobs(List<Job> jobs) {
    var list = jobs;
    // Text search
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((j) {
        return j.title.toLowerCase().contains(q) ||
            j.company.toLowerCase().contains(q) ||
            j.description.toLowerCase().contains(q) ||
            j.location.toLowerCase().contains(q) ||
            j.skills.any((s) => s.toLowerCase().contains(q));
      }).toList();
    }
    // Type filter
    if (_typeFilter != 'all') {
      list = list.where((j) => j.type == _typeFilter).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color =
        state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final filtered = _filteredJobs(state.jobs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs Board'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Post a Job',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateJobScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search jobs by title, company, skill...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // TYPE FILTER CHIPS
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _jobTypes.map((type) {
                final isSelected = _typeFilter == type;
                final label =
                    type == 'all' ? 'All' : type[0].toUpperCase() + type.substring(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.2),
                    checkmarkColor: color,
                    onSelected: (_) =>
                        setState(() => _typeFilter = isSelected ? 'all' : type),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // RESULTS
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.briefcase,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          state.jobs.isEmpty
                              ? 'No jobs posted yet'
                              : 'No jobs match your search',
                          style:
                              const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        if (state.jobs.isEmpty)
                          ElevatedButton.icon(
                            icon: const Icon(LucideIcons.plus),
                            label: const Text('Post a Job'),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CreateJobScreen())),
                          ),
                        if (_query.isNotEmpty || _typeFilter != 'all')
                          TextButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _query = '';
                                _typeFilter = 'all';
                              });
                            },
                            child: const Text('Clear filters'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => JobCard(job: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
