import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets/reel_card.dart';
import 'record_reel_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late PageController _pageCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final reels = state.reels;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Reels",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecordReelScreen())),
          ),
        ],
      ),
      body: reels.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off,
                      size: 64, color: Colors.white38),
                  const SizedBox(height: 16),
                  const Text("No reels yet",
                      style: TextStyle(color: Colors.white54, fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.videocam),
                    label: const Text("Record a Reel"),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RecordReelScreen())),
                  ),
                ],
              ),
            )
          : PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              itemCount: reels.length,
              onPageChanged: (i) {
                setState(() => _currentPage = i);
                // Record view
                if (reels[i].id.isNotEmpty) {
                  state.recordReelView(reels[i].id);
                }
              },
              itemBuilder: (context, i) {
                return ReelCard(
                  reel: reels[i],
                  isActive: i == _currentPage,
                );
              },
            ),
    );
  }
}
