import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../widgets/job_card.dart';
import 'create_job_screen.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jobs Board"),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: "Post a Job",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateJobScreen())),
          ),
        ],
      ),
      body: state.jobs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.briefcase,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("No jobs posted yet",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(LucideIcons.plus),
                    label: const Text("Post a Job"),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateJobScreen())),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.jobs.length,
              itemBuilder: (context, i) {
                return JobCard(job: state.jobs[i]);
              },
            ),
    );
  }
}
