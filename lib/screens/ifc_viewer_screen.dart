import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class IfcViewerScreen extends StatefulWidget {
  const IfcViewerScreen({super.key});

  @override
  State<IfcViewerScreen> createState() => _IfcViewerScreenState();
}

class _IfcViewerScreenState extends State<IfcViewerScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _pdfBytes;
  List<ui.Image> _pageImages = [];

  String _blockName = '';
  int? _pageNumber;
  String? _filename;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _pdfBytes == null && _error == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _blockName = args['block_name']?.toString() ?? '';
        _pageNumber = args['ifc_page_number'] as int?;
        _filename = args['ifc_filename']?.toString();
        final blockId = args['block_id'] as int?;
        if (blockId != null) {
          _loadIfc(blockId);
        } else {
          setState(() {
            _loading = false;
            _error = 'No block ID provided';
          });
        }
      }
    }
  }

  Future<void> _loadIfc(int blockId) async {
    try {
      final api = context.read<AppState>().api;
      final bytes = await api.getIfcPdf(blockId);
      if (!mounted) return;
      if (bytes != null && bytes.isNotEmpty) {
        _pdfBytes = bytes;
        await _rasterizePages(bytes);
      } else {
        setState(() {
          _loading = false;
          _error = 'No IFC drawing available for this power block.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load IFC: $e';
      });
    }
  }

  Future<void> _rasterizePages(Uint8List bytes) async {
    final images = <ui.Image>[];
    // Use the device pixel ratio for crisp rendering
    final dpr = MediaQuery.of(context).devicePixelRatio;
    await for (final page in Printing.raster(bytes, dpi: 150 * dpr)) {
      images.add(await page.toImage());
    }
    if (!mounted) return;
    setState(() {
      _pageImages = images;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final img in _pageImages) {
      img.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (_filename != null) _filename!,
      if (_pageNumber != null) 'Page $_pageNumber',
    ].join(' · ');

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: C.cyan),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_blockName IFC',
                style: AppTheme.font(size: 16, weight: FontWeight.w700)),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  style: AppTheme.font(size: 11, color: C.textSub)),
          ],
        ),
        actions: [
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: C.cyan),
              tooltip: 'Share / Print',
              onPressed: () {
                Printing.sharePdf(
                  bytes: _pdfBytes!,
                  filename: _filename ?? '$_blockName-IFC.pdf',
                );
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, color: C.textDim, size: 64),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: AppTheme.font(size: 14, color: C.textSub)),
              const SizedBox(height: 16),
              NeonButton(
                label: 'GO BACK',
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
                height: 44,
              ),
            ],
          ),
        ),
      );
    }
    if (_pageImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final img in _pageImages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: RawImage(
                  image: img,
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
