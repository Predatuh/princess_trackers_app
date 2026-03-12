import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class VideoTransitionScreen extends StatefulWidget {
  const VideoTransitionScreen({super.key});

  @override
  State<VideoTransitionScreen> createState() => _VideoTransitionScreenState();
}

class _VideoTransitionScreenState extends State<VideoTransitionScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoCtrl;
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;
  bool _videoReady = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeIn);

    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoCtrl = VideoPlayerController.asset('assets/loading_video.mp4');
    try {
      await _videoCtrl.initialize();
      _videoCtrl.setLooping(false);
      _videoCtrl.setVolume(0);
      setState(() => _videoReady = true);
      _videoCtrl.play();

      // Listen for video completion
      _videoCtrl.addListener(_onVideoUpdate);
    } catch (e) {
      // If video fails to load, just navigate after a delay
      debugPrint('Video load failed: $e');
      await Future.delayed(const Duration(milliseconds: 1500));
      _navigateToApp();
    }
  }

  void _onVideoUpdate() {
    if (_navigating) return;
    final pos = _videoCtrl.value.position;
    final dur = _videoCtrl.value.duration;
    if (dur.inMilliseconds > 0 && pos >= dur - const Duration(milliseconds: 200)) {
      _triggerFlashAndNavigate();
    }
  }

  void _triggerFlashAndNavigate() {
    if (_navigating) return;
    _navigating = true;
    _flashCtrl.forward().then((_) {
      _navigateToApp();
    });
  }

  void _navigateToApp() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _videoCtrl.removeListener(_onVideoUpdate);
    _videoCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video (fills screen)
          if (_videoReady)
            Center(
              child: AspectRatio(
                aspectRatio: _videoCtrl.value.aspectRatio,
                child: VideoPlayer(_videoCtrl),
              ),
            )
          else
            // Fallback while video loads
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: C.cyan.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'INITIALIZING',
                    style: AppTheme.displayFont(
                      size: 12,
                      color: C.textDim,
                    ),
                  ),
                ],
              ),
            ),

          // White flash overlay at end
          FadeTransition(
            opacity: _flashAnim,
            child: Container(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
