import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-screen camera with a paper-alignment guide overlay.
/// Returns [Uint8List] image bytes on capture, or null if cancelled.
class ScanCameraScreen extends StatefulWidget {
  const ScanCameraScreen({super.key});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera found';
          _initializing = false;
        });
        return;
      }
      // Prefer back camera
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera error: $e';
        _initializing = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await ctrl.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Capture failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_initializing)
            const Center(
              child: CircularProgressIndicator(color: C.cyan),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _error!,
                  style: AppTheme.font(color: C.pink, size: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_controller != null && _controller!.value.isInitialized)
            Center(child: CameraPreview(_controller!)),

          // Guide overlay
          if (!_initializing && _error == null) _buildGuideOverlay(),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                    const Spacer(),
                    Text(
                      'SCAN CLAIM SHEET',
                      style: AppTheme.displayFont(size: 14, color: C.cyan),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // balance close button
                  ],
                ),
              ),
            ),
          ),

          // Instruction text
          Positioned(
            left: 24,
            right: 24,
            bottom: 140,
            child: Text(
              'Align the claim sheet inside the guide',
              textAlign: TextAlign.center,
              style: AppTheme.font(
                size: 15,
                weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),

          // Capture button
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: _capturing ? null : _capture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _capturing
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                    child: _capturing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: C.cyan,
                              strokeWidth: 3,
                            ),
                          )
                        : Center(
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Draws a semi-transparent overlay with a clear rectangle guide
  /// matching the claim sheet aspect ratio (~letter page: 8.5x11).
  Widget _buildGuideOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // The guide should be as large as practical.
        // Claim sheet is portrait letter: 8.5 x 11 aspect = ~0.773
        const paperAspect = 8.5 / 11.0;
        // Leave padding from edges
        final maxW = screenW * 0.88;
        final maxH = screenH * 0.65;

        double guideW, guideH;
        if (maxW / maxH < paperAspect) {
          guideW = maxW;
          guideH = maxW / paperAspect;
        } else {
          guideH = maxH;
          guideW = maxH * paperAspect;
        }

        final left = (screenW - guideW) / 2;
        // Offset guide slightly upward to leave room for capture button
        final top = (screenH - guideH) / 2 - 30;

        return CustomPaint(
          size: Size(screenW, screenH),
          painter: _GuideOverlayPainter(
            guideRect: Rect.fromLTWH(left, top, guideW, guideH),
          ),
        );
      },
    );
  }
}

class _GuideOverlayPainter extends CustomPainter {
  final Rect guideRect;

  _GuideOverlayPainter({required this.guideRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Semi-transparent dark overlay everywhere EXCEPT the guide area
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Clip out the guide rect
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, overlayPaint);
    // Cut out the guide area
    canvas.drawRect(
      guideRect,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    // Draw corner brackets (cyan neon look)
    final bracketPaint = Paint()
      ..color = C.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 30.0;
    final r = guideRect;

    // Top-left
    canvas.drawLine(Offset(r.left, r.top + len), Offset(r.left, r.top), bracketPaint);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + len, r.top), bracketPaint);

    // Top-right
    canvas.drawLine(Offset(r.right - len, r.top), Offset(r.right, r.top), bracketPaint);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + len), bracketPaint);

    // Bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - len), Offset(r.left, r.bottom), bracketPaint);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + len, r.bottom), bracketPaint);

    // Bottom-right
    canvas.drawLine(Offset(r.right - len, r.bottom), Offset(r.right, r.bottom), bracketPaint);
    canvas.drawLine(Offset(r.right, r.bottom), Offset(r.right, r.bottom - len), bracketPaint);

    // Subtle border around guide
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(guideRect, borderPaint);
  }

  @override
  bool shouldRepaint(_GuideOverlayPainter oldDelegate) =>
      oldDelegate.guideRect != guideRect;
}
