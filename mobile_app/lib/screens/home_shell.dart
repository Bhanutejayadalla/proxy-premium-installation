import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../constants.dart';
import 'feed_screen.dart';
import 'nearby_screen.dart';
import 'create_post_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'jobs_screen.dart';
import 'reels_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  // Formal mode: 6 tabs (Home, Nearby, Post, Jobs, Chat, Profile)
  // Casual mode: 6 tabs (Home, Nearby, Post, Reels, Chat, Profile)
  List<Widget> _getTabs(bool isFormal) {
    if (isFormal) {
      return [
        const FeedScreen(),
        const NearbyScreen(),
        const SizedBox(), // create placeholder
        const JobsScreen(),
        const ChatListScreen(),
        const ProfileScreen(),
      ];
    }
    return [
      const FeedScreen(),
      const NearbyScreen(),
      const SizedBox(),
      const ReelsScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];
  }

  int _getCreateIndex(bool isFormal) => 2;

  List<NavigationDestination> _getDestinations(bool isFormal) {
    if (isFormal) {
      return const [
        NavigationDestination(icon: Icon(LucideIcons.home), label: "Home"),
        NavigationDestination(icon: Icon(LucideIcons.radar), label: "Nearby"),
        NavigationDestination(icon: Icon(LucideIcons.plusSquare), label: "Post"),
        NavigationDestination(icon: Icon(LucideIcons.briefcase), label: "Jobs"),
        NavigationDestination(icon: Icon(LucideIcons.messageCircle), label: "Chat"),
        NavigationDestination(icon: Icon(LucideIcons.user), label: "Profile"),
      ];
    }
    return const [
      NavigationDestination(icon: Icon(LucideIcons.home), label: "Home"),
      NavigationDestination(icon: Icon(LucideIcons.radar), label: "Nearby"),
      NavigationDestination(icon: Icon(LucideIcons.plusSquare), label: "Post"),
      NavigationDestination(icon: Icon(Icons.slow_motion_video), label: "Reels"),
      NavigationDestination(icon: Icon(LucideIcons.messageCircle), label: "Chat"),
      NavigationDestination(icon: Icon(LucideIcons.user), label: "Profile"),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color =
        state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final tabs = _getTabs(state.isFormal);
    final destinations = _getDestinations(state.isFormal);
    final createIdx = _getCreateIndex(state.isFormal);

    // Clamp index if mode switch changed tab count
    if (_idx >= tabs.length) _idx = 0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: state.isFormal ? AppColors.formalBg : null,
          gradient: state.isFormal
              ? null
              : const LinearGradient(
                  colors: [AppColors.casualStart, AppColors.casualEnd]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.radio, color: color),
                    const SizedBox(width: 8),
                    Text("Proxi",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: color)),
                    const SizedBox(width: 10),

                    // MODE TOGGLE CHIP — replaces FAB so it no longer blocks Profile tab
                    GestureDetector(
                      onTap: state.toggleMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              state.isFormal
                                  ? LucideIcons.briefcase
                                  : LucideIcons.partyPopper,
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              state.isFormal ? "PRO" : "SOCIAL",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    IconButton(
                      icon: const Icon(LucideIcons.bell),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen())),
                    ),
                  ],
                ),
              ),

              // CONTENT
              Expanded(
                child: _idx == createIdx ? const SizedBox() : tabs[_idx],
              ),

              // BOTTOM NAV
              NavigationBar(
                selectedIndex: _idx,
                onDestinationSelected: (i) {
                  if (i == createIdx) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreatePostScreen()));
                  } else {
                    setState(() => _idx = i);
                  }
                },
                destinations: destinations,
              ),
            ],
          ),
        ),
      ),
      // FAB REMOVED — mode toggle is now in the header
    );
  }
}