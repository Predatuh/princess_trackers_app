import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/ifc_cache_service.dart';
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
  String? _cachedPdfPath;
  bool _started = false;

  String _blockName = '';
  int? _pageNumber;
  String? _filename;
  int? _pageCount;
  int _currentPage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) {
      setState(() {
        _loading = false;
        _error = 'No IFC file was provided.';
      });
      return;
    }

    _blockName = args['block_name']?.toString() ?? '';
    _pageNumber = args['ifc_page_number'] as int?;
    _filename = args['ifc_filename']?.toString();
    final blockId = args['block_id'] as int?;
    if (blockId == null) {
      setState(() {
        _loading = false;
        _error = 'No block ID provided';
      });
      return;
    }
    _loadIfc(blockId);
  }

  Future<void> _loadIfc(int blockId) async {
    try {
      final api = context.read<AppState>().api;
      File? cachedFile = await IfcCacheService.existingFileForBlock(
        blockId,
        filename: _filename,
      );

      if (cachedFile == null) {
        final bytes = await api.getIfcPdf(blockId);
        if (bytes != null && bytes.isNotEmpty) {
          cachedFile = await IfcCacheService.storePdfBytes(
            blockId,
            bytes,
            filename: _filename,
          );
        }
      }

      if (!mounted) return;
      if (cachedFile != null && await cachedFile.exists()) {
        setState(() {
          _cachedPdfPath = cachedFile!.path;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'No IFC drawing available for this power block or in offline cache.';
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

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (_filename != null) _filename!,
      if (_pageCount != null) 'Pages $_pageCount',
      if (_pageNumber != null) 'Sheet $_pageNumber',
    ].join(' · ');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        backgroundColor: C.bg.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: C.cyan),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_blockName IFC', style: AppTheme.font(size: 16, weight: FontWeight.w700)),
            if (subtitle.isNotEmpty) Text(subtitle, style: AppTheme.font(size: 11, color: C.textSub)),
          ],
        ),
        actions: [
          if (_cachedPdfPath != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: C.cyan),
              tooltip: 'Share / Print',
              onPressed: _shareIfc,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2));
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
              Text(_error!, textAlign: TextAlign.center, style: AppTheme.font(size: 14, color: C.textSub)),
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
    if (_cachedPdfPath == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          color: Colors.white,
          child: Text(
            _pageCount == null ? 'Loading pages...' : 'Page ${_currentPage + 1} of ${_pageCount ?? 1}',
            style: AppTheme.font(size: 12, weight: FontWeight.w700, color: const Color(0xFF2F3B52)),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: PDFView(
              filePath: _cachedPdfPath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              fitPolicy: FitPolicy.BOTH,
              onRender: (pages) {
                if (!mounted) return;
                setState(() => _pageCount = pages);
              },
              onPageChanged: (page, total) {
                if (!mounted) return;
                setState(() {
                  _currentPage = page ?? 0;
                  _pageCount = total ?? _pageCount;
                });
              },
              onError: (error) {
                if (!mounted) return;
                setState(() => _error = error.toString());
              },
              onPageError: (page, error) {
                if (!mounted) return;
                setState(() => _error = 'Failed to render page $page: $error');
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareIfc() async {
    final path = _cachedPdfPath;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    if (!mounted) return;
    await Printing.sharePdf(bytes: bytes, filename: _filename ?? '$_blockName-IFC.pdf');
  }
}