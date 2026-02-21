import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

class JobCard extends StatelessWidget {
  final Job job;
  const JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final hasApplied = job.applicants.contains(state.currentUser?.uid);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER ROW
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.building2,
                      color: Colors.indigo, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(job.company,
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                ),
                _typeBadge(job.type),
              ],
            ),
            const SizedBox(height: 12),

            // DESCRIPTION
            if (job.description.isNotEmpty)
              Text(job.description,
                  maxLines: 3, overflow: TextOverflow.ellipsis),

            // SKILLS
            if (job.skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: job.skills
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.indigo)),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 12),

            // FOOTER
            Row(
              children: [
                Icon(LucideIcons.mapPin, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(job.location,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Spacer(),
                Text("${job.applicants.length} applicants",
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: hasApplied
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text("Applied"),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        state.applyToJob(job.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Application submitted!")));
                      },
                      child: const Text("Apply Now"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    final colors = {
      'full-time': Colors.green,
      'part-time': Colors.orange,
      'internship': Colors.blue,
      'freelance': Colors.purple,
    };
    final c = colors[type] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(type,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
    );
  }
}
