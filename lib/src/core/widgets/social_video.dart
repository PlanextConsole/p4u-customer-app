import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/app_theme.dart';
import '../utils/media_url.dart';

export '../utils/media_url.dart' show isVideoUrl, resolveMediaUrl;

/// Inline video player used by the Socio feed. Autoplays muted when it scrolls
/// into view and pauses when it leaves — mirroring the web's IntersectionObserver
/// `FeedVideo`. Tap toggles play/pause; a speaker button toggles mute.
class SocialVideo extends StatefulWidget {
  const SocialVideo({
    required this.url,
    this.height = 280,
    this.autoplay = true,
    super.key,
  });

  final String url;
  final double height;
  final bool autoplay;

  @override
  State<SocialVideo> createState() => _SocialVideoState();
}

class _SocialVideoState extends State<SocialVideo> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _muted = true;
  bool _manuallyPaused = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final resolved = resolveMediaUrl(widget.url);
    if (resolved.isEmpty || !resolved.startsWith('http')) {
      setState(() => _error = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onVisibility(VisibilityInfo info) {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    final visible = info.visibleFraction > 0.6;
    if (visible && widget.autoplay && !_manuallyPaused) {
      if (!controller.value.isPlaying) controller.play();
    } else {
      if (controller.value.isPlaying) controller.pause();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _manuallyPaused = true;
      } else {
        controller.play();
        _manuallyPaused = false;
      }
    });
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _muted = !_muted;
      controller.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_off_rounded, color: Colors.white54),
      );
    }
    if (!_initialized || _controller == null) {
      return Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }
    final controller = _controller!;
    return VisibilityDetector(
      key: Key('social-video-${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          height: widget.height,
          width: double.infinity,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
              if (!controller.value.isPlaying)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleMute,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.primary,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
