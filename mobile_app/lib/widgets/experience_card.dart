import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ExperienceCard extends StatelessWidget {
  final Map<String, dynamic> experience;

  const ExperienceCard({super.key, required this.experience});

  @override
  Widget build(BuildContext context) {
    final title = experience['title'] ?? '';
    final company = experience['company'] ?? '';
    final startDate = experience['start_date'] ?? '';
    final endDate = experience['end_date'];
    final description = experience['description'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.briefcase, color: Colors.indigo, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(company,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    "$startDate — ${endDate ?? 'Present'}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(description,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
