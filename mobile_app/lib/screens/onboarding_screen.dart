import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      icon: LucideIcons.radio,
      title: "Welcome to Proxi",
      subtitle: "The dual-mode social network that connects you\n"
          "with people nearby — professionally and casually.",
      color: Color(0xFF2563EB),
    ),
    _OnboardingPage(
      icon: LucideIcons.briefcase,
      title: "Professional Mode",
      subtitle: "Switch to PRO mode for LinkedIn-style networking.\n"
          "Share your resume, find jobs, and connect professionally.",
      color: Color(0xFF2563EB),
    ),
    _OnboardingPage(
      icon: LucideIcons.partyPopper,
      title: "Social Mode",
      subtitle: "Switch to SOCIAL mode for Instagram-style sharing.\n"
          "Post stories, reels, and vibe with people nearby.",
      color: Color(0xFFEC4899),
    ),
    _OnboardingPage(
      icon: LucideIcons.radar,
      title: "Discover Nearby",
      subtitle: "Use BLE radar for instant proximity discovery\n"
          "or GPS mode to find people within your area.",
      color: Color(0xFF059669),
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // SKIP
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onComplete,
                child: const Text("Skip"),
              ),
            ),

            // PAGES
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _pages[i],
              ),
            ),

            // DOTS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  width: i == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? _pages[_currentPage].color
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _ctrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    } else {
                      widget.onComplete();
                    }
                  },
                  child: Text(
                      _currentPage < _pages.length - 1
                          ? "Next"
                          : "Get Started",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 40),
          Text(title,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 16),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
