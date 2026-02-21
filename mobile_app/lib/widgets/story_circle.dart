import 'package:flutter/material.dart';

class StoryCircle extends StatelessWidget {
  final dynamic story;
  const StoryCircle({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final url = story['media_url'] ?? '';
    final username = story['username'] ?? '';
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            backgroundColor: Colors.grey[200],
            child: url.isEmpty
                ? Text(username.isNotEmpty ? username[0] : '?')
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(username, style: const TextStyle(fontSize: 10))
      ]),
    );
  }
}