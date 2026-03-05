import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_state.dart';
import '../constants.dart';

// Import all feature screens
import 'search_students_screen.dart';
import 'recommendations_screen.dart';
import 'projects_screen.dart';
import 'study_groups_screen.dart';
import 'skill_exchange_screen.dart';
import 'communities_screen.dart';
import 'events_screen.dart';
import 'venue_booking_screen.dart';
import 'sports_matching_screen.dart';
import 'campus_map_screen.dart';
import 'resource_sharing_screen.dart';

class CampusHubScreen extends StatelessWidget {
  const CampusHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final bg = state.isFormal ? AppColors.formalBg : null;

    final sections = [
      _HubSection(
        title: 'Discover & Connect',
        icon: LucideIcons.search,
        color: Colors.blue,
        items: [
          _HubItem('Search Students', LucideIcons.searchCheck, Colors.blue.shade700,
              'Find peers by skills, department, interests',
              () => _push(context, const SearchStudentsScreen())),
          _HubItem('Recommendations', LucideIcons.sparkles, Colors.indigo,
              'Personalized peer suggestions',
              () => _push(context, const RecommendationsScreen())),
        ],
      ),
      _HubSection(
        title: 'Collaboration',
        icon: LucideIcons.users,
        color: Colors.green,
        items: [
          _HubItem('Projects', LucideIcons.folder, Colors.green.shade700,
              'Create teams & collaborate on projects',
              () => _push(context, const ProjectsScreen())),
          _HubItem('Study Groups', LucideIcons.bookOpen, Colors.teal,
              'Form study groups for subjects',
              () => _push(context, const StudyGroupsScreen())),
          _HubItem('Skill Exchange', LucideIcons.repeat, Colors.cyan.shade700,
              'Teach & learn skills from peers',
              () => _push(context, const SkillExchangeScreen())),
        ],
      ),
      _HubSection(
        title: 'Communities',
        icon: LucideIcons.globe,
        color: Colors.purple,
        items: [
          _HubItem('Communities', LucideIcons.hash, Colors.purple,
              'Department & interest-based groups',
              () => _push(context, const CommunitiesScreen())),
        ],
      ),
      _HubSection(
        title: 'Campus Life',
        icon: LucideIcons.landmark,
        color: Colors.orange,
        items: [
          _HubItem('Events', LucideIcons.calendar, Colors.orange,
              'Workshops, hackathons, cultural fests',
              () => _push(context, const EventsScreen())),
          _HubItem('Venue Booking', LucideIcons.dumbbell, Colors.red.shade600,
              'Book sports venues & courts',
              () => _push(context, const VenueBookingScreen())),
          _HubItem('Sports Match', LucideIcons.trophy, Colors.amber.shade800,
              'Find peers to play sports',
              () => _push(context, const SportsMatchingScreen())),
          _HubItem('Campus Map', LucideIcons.map, Colors.blue.shade600,
              'Interactive map with all locations',
              () => _push(context, const CampusMapScreen())),
          _HubItem('Resources', LucideIcons.fileText, Colors.deepPurple,
              'Share notes, papers & study material',
              () => _push(context, const ResourceSharingScreen())),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true, snap: true,
            expandedHeight: 120,
            backgroundColor: color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Campus Hub', style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildSection(context, sections[i], i).animate()
                    .fadeIn(delay: Duration(milliseconds: 100 * i))
                    .slideY(begin: 0.1, end: 0),
                childCount: sections.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, _HubSection section, int sectionIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, size: 20, color: section.color),
              const SizedBox(width: 8),
              Text(section.title,
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: section.color)),
            ],
          ),
          const SizedBox(height: 10),
          ...section.items.map((item) => _buildHubTile(context, item)),
        ],
      ),
    );
  }

  Widget _buildHubTile(BuildContext context, _HubItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        onTap: item.onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: item.color.withValues(alpha: 0.12),
          child: Icon(item.icon, color: item.color, size: 20),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(item.subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey.shade400),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _HubSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_HubItem> items;
  const _HubSection({required this.title, required this.icon, required this.color, required this.items});
}

class _HubItem {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;
  const _HubItem(this.title, this.icon, this.color, this.subtitle, this.onTap);
}
