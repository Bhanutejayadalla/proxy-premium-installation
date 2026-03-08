import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final bool autoPlay;

  const VideoPlayerWidget({
    super.key,
    required this.url,
    this.autoPlay = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _ctrl.setLooping(true);
        if (widget.autoPlay) _ctrl.play();
      });
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay && !_ctrl.value.isPlaying) {
      _ctrl.play();
    } else if (!widget.autoPlay && _ctrl.value.isPlaying) {
      _ctrl.pause();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl.value.isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showControls = false);
        });
      },
      onDoubleTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _ctrl.value.size.width,
                height: _ctrl.value.size.height,
                child: VideoPlayer(_ctrl),
              ),
            ),
          ),
          // Pause/Play overlay
          if (_showControls || !_ctrl.value.isPlaying)
            AnimatedOpacity(
              opacity: _showControls || !_ctrl.value.isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          // Progress bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _ctrl,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
