import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';
import 'user_detail_screen.dart';

class SportsMatchingScreen extends StatefulWidget {
  const SportsMatchingScreen({super.key});
  @override
  State<SportsMatchingScreen> createState() => _SportsMatchingScreenState();
}

class _SportsMatchingScreenState extends State<SportsMatchingScreen> {
  String? _selectedSport;
  List<AppUser> _peers = [];
  bool _loading = false;

  static const sports = [
    'Basketball', 'Football', 'Tennis', 'Badminton',
    'Cricket', 'Volleyball', 'Table Tennis', 'Swimming',
    'Running', 'Gym', 'Yoga', 'Chess',
  ];

  void _findPeers() async {
    if (_selectedSport == null) return;
    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    final results = await state.firebase.findSportsPeers(_selectedSport!, state.currentUser?.uid ?? '');
    if (!mounted) return;
    setState(() {
      _peers = results.where((u) => u.uid != state.currentUser?.uid).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Sports Partners'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Sport selector
          Container(
            padding: const EdgeInsets.all(16),
            color: color.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a sport to find partners',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sports.map((s) {
                    final selected = _selectedSport == s;
                    return ChoiceChip(
                      label: Text(s),
                      selected: selected,
                      selectedColor: color.withValues(alpha: 0.2),
                      onSelected: (_) {
                        setState(() => _selectedSport = s);
                        _findPeers();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _selectedSport == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.trophy, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('Pick a sport to see available partners',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                          ],
                        ),
                      )
                    : _peers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.userX, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('No $_selectedSport partners found yet',
                                    style: TextStyle(color: Colors.grey.shade600)),
                                const SizedBox(height: 6),
                                const Text('Encourage your friends to update their sports preferences!'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _peers.length,
                            padding: const EdgeInsets.all(12),
                            itemBuilder: (ctx, i) => _SportsPeerCard(user: _peers[i], sport: _selectedSport!),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SportsPeerCard extends StatelessWidget {
  final AppUser user;
  final String sport;
  const _SportsPeerCard({required this.user, required this.sport});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.getAvatar(state.isFormal).isNotEmpty
              ? NetworkImage(user.getAvatar(state.isFormal))
              : null,
          backgroundColor: color.withValues(alpha: 0.2),
          child: user.getAvatar(state.isFormal).isEmpty
              ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?')
              : null,
        ),
        title: Row(
          children: [
            Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (user.department.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('• ${user.department}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ],
        ),
        subtitle: Wrap(
          spacing: 4,
          children: user.sportsPreferences.map((s) {
            final isTarget = s.toLowerCase() == sport.toLowerCase();
            return Chip(
              label: Text(s, style: TextStyle(fontSize: 10, color: isTarget ? Colors.white : null)),
              backgroundColor: isTarget ? color : null,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            );
          }).toList(),
        ),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
        ),
      ),
    );
  }
}
