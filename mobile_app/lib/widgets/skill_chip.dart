import 'package:flutter/material.dart';

class SkillChip extends StatelessWidget {
  final String label;
  final bool isFormal;
  final VoidCallback? onDelete;

  const SkillChip({
    super.key,
    required this.label,
    this.isFormal = true,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: isFormal ? Colors.indigo : Colors.deepPurple)),
      backgroundColor:
          (isFormal ? Colors.indigo : Colors.deepPurple).withValues(alpha: 0.1),
      deleteIcon: onDelete != null
          ? const Icon(Icons.close, size: 16)
          : null,
      onDeleted: onDelete,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
