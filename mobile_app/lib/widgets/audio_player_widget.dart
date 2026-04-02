import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Audio player widget for posts and stories with music
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String? songName;
  final String? artist;
  final VoidCallback? onClose;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.songName,
    this.artist,
    this.onClose,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _errorText;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      final resolvedUrl = await _resolveAudioUrl(widget.audioUrl);
      debugPrint('[AudioPlayer] init url=${widget.audioUrl} resolved=$resolvedUrl');

      await _audioPlayer.setUrl(
        resolvedUrl,
        preload: true,
      );
      
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });

      _audioPlayer.durationStream.listen((d) {
        if (mounted) {
          setState(() => _duration = d ?? Duration.zero);
        }
      });

      _audioPlayer.positionStream.listen((p) {
        if (mounted) {
          setState(() => _position = p);
        }
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = null;
        });
      }
    } catch (e) {
      debugPrint('[AudioPlayer] Error initializing audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Unable to load audio';
        });
      }
    }
  }

  Future<String> _resolveAudioUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      throw Exception('Empty audio URL');
    }
    if (url.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final download = await ref.getDownloadURL();
      debugPrint('[AudioPlayer] Resolved gs:// to download URL');
      return download;
    }
    if (url.contains('firebasestorage.googleapis.com')) {
      // Rebuild a fresh signed URL in case token is stale/missing.
      final ref = FirebaseStorage.instance.refFromURL(url);
      final download = await ref.getDownloadURL();
      debugPrint('[AudioPlayer] Refreshed Firebase Storage download URL');
      return download;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    throw Exception('Unsupported URL format: $url');
  }

  void _togglePlayPause() async {
    if (_errorText != null || _isLoading) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('[AudioPlayer] play/pause error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio playback failed')),
        );
      }
    }
  }

  void _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final sliderMax = _duration.inMilliseconds > 0
      ? _duration.inMilliseconds.toDouble()
      : 1.0;
    final sliderValue = _position.inMilliseconds
      .clamp(0, sliderMax.toInt())
      .toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Song info
          if (widget.songName != null || widget.artist != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.songName != null)
                    Text(
                      widget.songName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  if (widget.artist != null)
                    Text(
                      widget.artist!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

          // Progress bar
          Slider(
            min: 0,
            max: sliderMax,
            value: sliderValue,
            inactiveColor: Colors.grey.shade700,
            activeColor: Colors.blue,
            onChanged: (_isLoading || _errorText != null) ? null : (value) {
              _seek(Duration(milliseconds: value.toInt()));
            },
          ),

          // Time display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Loading audio...',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_errorText!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.blue,
                  size: 32,
                ),
                onPressed: _togglePlayPause,
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.grey,
                  ),
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// Compact audio player for story viewer
class CompactAudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String? songName;
  final String? artist;

  const CompactAudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.songName,
    this.artist,
  });

  @override
  State<CompactAudioPlayerWidget> createState() =>
      _CompactAudioPlayerWidgetState();
}

class _CompactAudioPlayerWidgetState extends State<CompactAudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      final resolvedUrl = await _resolveAudioUrl(widget.audioUrl);
      debugPrint('[CompactAudio] init url=${widget.audioUrl} resolved=$resolvedUrl');
      await _audioPlayer.setUrl(resolvedUrl, preload: true);
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = null;
        });
      }
    } catch (e) {
      debugPrint('[CompactAudio] Error initializing audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Music unavailable';
        });
      }
    }
  }

  Future<String> _resolveAudioUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      throw Exception('Empty audio URL');
    }
    if (url.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(url);
      return await ref.getDownloadURL();
    }
    if (url.contains('firebasestorage.googleapis.com')) {
      final ref = FirebaseStorage.instance.refFromURL(url);
      return await ref.getDownloadURL();
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    throw Exception('Unsupported URL format: $url');
  }

  void _togglePlayPause() async {
    if (_isLoading || _errorText != null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('[CompactAudio] play/pause error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            if (_isLoading)
              const Text('Loading...',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            if (_errorText != null)
              Text(_errorText!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            if (widget.songName != null)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.songName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.artist != null)
                      Text(
                        widget.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
