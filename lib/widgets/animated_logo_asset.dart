import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AnimatedVideoAsset extends StatefulWidget {
  const AnimatedVideoAsset({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
    required this.fallbackAsset,
    this.startDelay = Duration.zero,
    this.fadeDuration = const Duration(milliseconds: 220),
    this.loopWholeVideo = false,
    this.loopStart,
    this.loopEnd,
    this.releaseLoop = true,
    this.onPlaybackComplete,
  });

  final String assetPath;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final String fallbackAsset;
  final Duration startDelay;
  final Duration fadeDuration;
  final bool loopWholeVideo;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool releaseLoop;
  final VoidCallback? onPlaybackComplete;

  @override
  State<AnimatedVideoAsset> createState() => _AnimatedVideoAssetState();
}

class _AnimatedVideoAssetState extends State<AnimatedVideoAsset> {
  VideoPlayerController? _controller;
  bool _showVideo = false;
  bool _didComplete = false;
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.asset(widget.assetPath);
    _controller = controller;
    controller.addListener(_handlePlaybackTick);

    try {
      await controller.initialize();
      await controller.setLooping(
        widget.loopWholeVideo && widget.loopStart == null && widget.loopEnd == null,
      );
      await controller.setVolume(0);
      if (widget.startDelay > Duration.zero) {
        await Future<void>.delayed(widget.startDelay);
      }
      if (!mounted) return;
      await controller.play();
      setState(() {
        _showVideo = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedVideoAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.releaseLoop && widget.releaseLoop) {
      _handlePlaybackTick();
    }
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null || _isSeeking) {
      return;
    }

    _isSeeking = true;
    try {
      await controller.seekTo(position);
      if (!controller.value.isPlaying) {
        await controller.play();
      }
    } finally {
      _isSeeking = false;
    }
  }

  void _handlePlaybackTick() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final value = controller.value;
    if (!value.isInitialized || _isSeeking) {
      return;
    }

    final loopStart = widget.loopStart;
    final loopEnd = widget.loopEnd;
    if (widget.loopWholeVideo && loopStart == null && loopEnd == null) {
      return;
    }

    if (loopStart != null && loopEnd != null && !widget.releaseLoop) {
      if (value.position >= loopEnd - const Duration(milliseconds: 40)) {
        _seekTo(loopStart);
        return;
      }
    }

    if (_didComplete) {
      return;
    }

    final duration = value.duration;
    if (duration <= Duration.zero) {
      return;
    }

    if (value.position >= duration - const Duration(milliseconds: 80)) {
      _didComplete = true;
      widget.onPlaybackComplete?.call();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_handlePlaybackTick);
    controller?.pause();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          widget.fallbackAsset,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
        ),
        if (controller != null && controller.value.isInitialized)
          AnimatedOpacity(
            opacity: _showVideo ? 1 : 0,
            duration: widget.fadeDuration,
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
      ],
    );
  }
}

class AnimatedLogoAsset extends StatelessWidget {
  const AnimatedLogoAsset({
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
    this.fallbackAsset = 'assets/logo.png',
    this.startDelay = Duration.zero,
    this.fadeDuration = const Duration(milliseconds: 220),
    this.loopStart,
    this.loopEnd,
    this.releaseLoop = true,
    this.onPlaybackComplete,
  });

  final BoxFit fit;
  final FilterQuality filterQuality;
  final String fallbackAsset;
  final Duration startDelay;
  final Duration fadeDuration;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool releaseLoop;
  final VoidCallback? onPlaybackComplete;

  @override
  Widget build(BuildContext context) {
    return AnimatedVideoAsset(
      assetPath: 'assets/animations/logo.mp4',
      fallbackAsset: fallbackAsset,
      fit: fit,
      filterQuality: filterQuality,
      startDelay: startDelay,
      fadeDuration: fadeDuration,
      loopStart: loopStart,
      loopEnd: loopEnd,
      releaseLoop: releaseLoop,
      onPlaybackComplete: onPlaybackComplete,
    );
  }
}

class AnimatedCrownAsset extends StatelessWidget {
  const AnimatedCrownAsset({
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
    this.fallbackAsset = 'assets/crown.png',
    this.fadeDuration = const Duration(milliseconds: 180),
  });

  final BoxFit fit;
  final FilterQuality filterQuality;
  final String fallbackAsset;
  final Duration fadeDuration;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return Image.asset(
        fallbackAsset,
        fit: fit,
        filterQuality: filterQuality,
      );
    }

    return AnimatedVideoAsset(
      assetPath: 'assets/animations/crown1.mp4',
      fallbackAsset: fallbackAsset,
      fit: fit,
      filterQuality: filterQuality,
      fadeDuration: fadeDuration,
      loopWholeVideo: true,
    );
  }
}