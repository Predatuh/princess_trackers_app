import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tracker.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Map tab — shown inside MainShell
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  bool _loading = true;
  bool _switchingTracker = false;
  bool _showLabels = true;
  String? _error;
  List<dynamic> _areas = [];
  List<dynamic> _statusData = [];
  String? _mapImageUrl;
  double _imgAspect = 1.0;
  String? _selectedZone;   // null = show all zones
  double _mapW = 0;
  double _mapH = 0;
  bool _adminDeleteMode = false;
  Map<String, dynamic>? _lastDeleted; // ignore: unused_field - kept for undo reference
  int? _activeTrackerId;

  final TransformationController _transformCtrl = TransformationController();

  double get _currentScale {
    final matrix = _transformCtrl.value.storage;
    final scaleX = matrix[0].abs();
    final scaleY = matrix[5].abs();
    return math.max(scaleX, scaleY);
  }

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final trackerId = context.watch<AppState>().currentTracker?.id;
    if (_activeTrackerId != null && trackerId != null && trackerId != _activeTrackerId) {
      _loadMap();
    }
    _activeTrackerId = trackerId;
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMap() async {
    setState(() {
      _loading = true;
      _error = null;
      _activeTrackerId = context.read<AppState>().currentTracker?.id;
    });
    try {
      final state = context.read<AppState>();
      final api = state.api;

      final maps = await api.getSiteMaps();
      if (maps.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No map uploaded yet';
        });
        return;
      }

      final map = maps.first;
      final mapId = map['id'];
      _areas = (map['areas'] as List?) ?? [];

      final imgUrl = await api.getMapImageUrl();
      _mapImageUrl = imgUrl;

      _statusData = await api.getMapStatus(mapId);

      if (imgUrl != null) {
        final fullUrl = '${ApiService.baseUrl}$imgUrl';
        _imgAspect = await _getImageAspectRatio(fullUrl);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load map: $e';
      });
    }
  }

  Future<double> _getImageAspectRatio(String url) {
    final c = Completer<double>();
    final provider = NetworkImage(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        c.complete(h > 0 ? w / h : 1.0);
      },
      onError: (e, st) {
        stream.removeListener(listener);
        c.complete(1.5);
      },
    );
    stream.addListener(listener);
    return c.future;
  }

  Future<void> _handleTrackerSwitch(Tracker tracker) async {
    final state = context.read<AppState>();
    if (_switchingTracker || state.currentTracker?.id == tracker.id) {
      return;
    }

    setState(() {
      _switchingTracker = true;
    });

    try {
      await state.switchTracker(tracker);
      if (!mounted) return;
      await _loadMap();
    } finally {
      if (mounted) {
        setState(() {
          _switchingTracker = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trackers = state.trackers;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: C.textDim, size: 64),
            const SizedBox(height: 12),
            Text(_error!, style: AppTheme.font(size: 16, color: C.textDim)),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: NeonButton(
                label: 'RETRY',
                icon: Icons.refresh_rounded,
                onPressed: _loadMap,
                height: 44,
              ),
            ),
          ],
        ),
      );
    }
    if (_mapImageUrl == null) {
      return Center(
        child: Text('No map image available',
            style: AppTheme.font(color: C.textDim)),
      );
    }

    final fullUrl = '${ApiService.baseUrl}$_mapImageUrl';

    final Map<int, Map<String, dynamic>> statusLookup = {};
    for (final s in _statusData) {
      final areaId = _toInt(s['area_id']);
      if (areaId != null) statusLookup[areaId] = s;
    }

    // Filter areas by selected zone
    final visibleAreas = _selectedZone == null
        ? _areas
        : _areas
            .where((a) => a['zone']?.toString() == _selectedZone)
            .toList();

    return Stack(
      children: [
        Column(
          children: [
            if (trackers.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: C.bg.withValues(alpha: 0.92),
                  border: const Border(
                    bottom: BorderSide(color: Color(0x14FFFFFF)),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: C.textDim),
                      const SizedBox(width: 6),
                      Text(
                        'Tracker:',
                        style: AppTheme.font(size: 11, color: C.textSub, weight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      for (final tracker in trackers)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _trackerChip(
                            tracker: tracker,
                            active: state.currentTracker?.id == tracker.id,
                            onTap: () => _handleTrackerSwitch(tracker),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            _buildLegend(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = w / _imgAspect;

                  // Keep track of map dimensions for zone zoom
                  if (_mapW != w || _mapH != h) {
                    _mapW = w;
                    _mapH = h;
                  }

                  return InteractiveViewer(
                    transformationController: _transformCtrl,
                    constrained: false,
                    minScale: 0.3,
                    maxScale: 6.0,
                    boundaryMargin: const EdgeInsets.all(300),
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              fullUrl,
                              fit: BoxFit.fill,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        progress.expectedTotalBytes != null
                                            ? progress
                                                    .cumulativeBytesLoaded /
                                                progress
                                                    .expectedTotalBytes!
                                            : null,
                                    color: C.cyan,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (ctx, err, stack) =>
                                  const Center(
                                child: Icon(Icons.broken_image,
                                    color: Color(0x40FFFFFF), size: 48),
                              ),
                            ),
                          ),
                          for (final area in visibleAreas)
                            if (_toDouble(area['bbox_x']) != null &&
                                _toDouble(area['bbox_y']) != null &&
                                (_toDouble(area['bbox_w']) ?? 0) > 0 &&
                                (_toDouble(area['bbox_h']) ?? 0) > 0 &&
                                (_toDouble(area['bbox_w']) ?? 0) <= 20 &&
                                (_toDouble(area['bbox_h']) ?? 0) <= 20 &&
                                ((_toDouble(area['bbox_w']) ?? 0) * (_toDouble(area['bbox_h']) ?? 0)) <= 80)
                              _buildMarker(
                                area: area,
                                status:
                                    statusLookup[_toInt(area['id'])],
                                mapW: w,
                                mapH: h,
                              ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Floating action buttons
        Positioned(
          right: 12,
          top: 8,
          child: Column(
            children: [
              _floatingGlassButton(
                icon: Icons.refresh_rounded,
                onTap: _loadMap,
              ),
              const SizedBox(height: 8),
              _floatingGlassButton(
                icon: Icons.zoom_out_map_rounded,
                onTap: () =>
                    _transformCtrl.value = Matrix4.identity(),
              ),
              const SizedBox(height: 8),
              _floatingGlassButton(
                icon: _showLabels ? Icons.text_fields_rounded : Icons.text_fields_outlined,
                active: _showLabels,
                onTap: () => setState(() => _showLabels = !_showLabels),
              ),
              // Admin delete mode toggle
              if (_isAdmin) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _adminDeleteMode = !_adminDeleteMode),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _adminDeleteMode
                              ? C.pink.withValues(alpha: 0.3)
                              : C.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _adminDeleteMode ? C.pink : const Color(0x18FFFFFF),
                            width: _adminDeleteMode ? 2 : 1,
                          ),
                          boxShadow: _adminDeleteMode
                              ? [BoxShadow(color: C.pink.withValues(alpha: 0.4), blurRadius: 10)]
                              : [],
                        ),
                        child: Icon(
                          _adminDeleteMode ? Icons.delete_forever_rounded : Icons.delete_outline_rounded,
                          color: _adminDeleteMode ? C.pink : C.cyan,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_switchingTracker)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.18),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: C.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x18FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: C.cyan),
                      ),
                      const SizedBox(width: 10),
                      Text('Switching tracker…', style: AppTheme.font(size: 13, color: C.text)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Delete mode indicator
        if (_adminDeleteMode)
          Positioned(
            left: 12,
            top: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: C.pink.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.pink.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded, color: C.pink, size: 14),
                      const SizedBox(width: 6),
                      Text('DELETE MODE', style: AppTheme.font(size: 11, color: C.pink, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool get _isAdmin {
    final role = context.read<AppState>().user?.role;
    return role == 'admin' || role == 'assistant_admin';
  }

  Widget _floatingGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? C.cyan.withValues(alpha: 0.2)
                  : C.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? C.cyan.withValues(alpha: 0.6) : const Color(0x18FFFFFF),
                width: active ? 1.4 : 1,
              ),
            ),
            child: Icon(icon, color: active ? C.cyan : C.cyan, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMarker({
    required dynamic area,
    Map<String, dynamic>? status,
    required double mapW,
    required double mapH,
  }) {
    final bboxX = _toDouble(area['bbox_x'])!;
    final bboxY = _toDouble(area['bbox_y'])!;
    final bboxW = _toDouble(area['bbox_w']) ?? 2.0;
    final bboxH = _toDouble(area['bbox_h']) ?? 2.0;
    final areaName = area['name']?.toString() ?? '';
    final markerWidth = mapW * bboxW / 100;
    final markerHeight = mapH * bboxH / 100;
    final showLabel = _showLabels || _currentScale >= 1.2 || (markerWidth >= 18 && markerHeight >= 16);

    Color markerColor = Colors.grey;
    String blockName = areaName;

    if (status != null) {
      blockName = status['block_name']?.toString() ?? areaName;
      final isCompleted = status['is_completed'] == true;
      if (isCompleted) {
        markerColor = C.green;
      } else {
        final summary =
            status['lbd_summary'] as Map<String, dynamic>?;
        if (summary != null) {
          final total = _toInt(summary['total']) ?? 0;
          if (total > 0) {
            int completedCount = 0;
            int totalPossible = 0;
            for (final entry in summary.entries) {
              if (entry.key == 'total') continue;
              completedCount += (_toInt(entry.value) ?? 0);
              totalPossible += total;
            }
            final pct = totalPossible > 0
                ? completedCount / totalPossible
                : 0.0;
            if (pct == 0) {
              markerColor = C.pink;
            } else if (pct >= 1.0) {
              markerColor = C.green;
            } else {
              markerColor =
                  Color.lerp(C.pink, C.green, pct) ?? Colors.orange;
            }
          }
        }
      }
    }

    String markerLabel = areaName.trim();
    if (status != null) {
      final rawBlockName = status['block_name']?.toString() ?? blockName;
      final numberMatch = RegExp(r'(\d+)').firstMatch(rawBlockName);
      markerLabel = numberMatch?.group(1) ?? rawBlockName;
    }
    if (markerLabel.isEmpty) {
      markerLabel = blockName;
    }

    return Positioned(
      left: mapW * bboxX / 100,
      top: mapH * bboxY / 100,
      width: markerWidth,
      height: markerHeight,
      child: GestureDetector(
        onTap: () {
          if (_adminDeleteMode) {
            _instantDelete(area);
          } else if (status != null) {
            _onAreaTap(status);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: markerColor,
            border: Border.all(color: markerColor, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: showLabel
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Text(
                      markerLabel,
                      style: TextStyle(
                        color: _hexToColor(area['label_color']) ?? Colors.white,
                        fontSize: markerWidth < 24 ? 8 : 10,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 3)
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final state = context.watch<AppState>();
    final tracker = state.currentTracker;
    if (tracker == null) return const SizedBox.shrink();

    final zones = _zones;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: C.surface.withValues(alpha: 0.8),
            border: const Border(
                bottom: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _legendChip(C.green, 'Complete'),
                const SizedBox(width: 10),
                _legendChip(Colors.orange, 'In Progress'),
                const SizedBox(width: 10),
                _legendChip(C.pink, 'Not Started'),
                const SizedBox(width: 10),
                ...tracker.statusTypes.map((st) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _legendChip(
                        state.getStatusColor(st), state.getStatusName(st)),
                  );
                }),
              ],
            ),
          ),
        ),
        // Zone filter bar (only if zones are configured)
        if (zones.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: C.bg.withValues(alpha: 0.9),
              border: const Border(
                  bottom: BorderSide(color: Color(0x14FFFFFF))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(Icons.layers_rounded,
                      size: 14, color: C.textDim),
                  const SizedBox(width: 6),
                  _zoneFilterChip(null),
                  ...zones.map((z) => _zoneFilterChip(z)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _zoneFilterChip(String? zone) {
    final label = zone ?? 'All';
    final active = _selectedZone == zone;
    return GestureDetector(
      onTap: () => _onZoneTap(zone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? C.cyan.withValues(alpha: 0.2)
              : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? C.cyan : const Color(0x20FFFFFF),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: C.cyan.withValues(alpha: 0.25),
                      blurRadius: 8)
                ]
              : [],
        ),
        child: Text(
          label,
          style: AppTheme.font(
            size: 11,
            color: active ? C.cyan : C.textSub,
            weight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _trackerChip({
    required Tracker tracker,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? C.cyan.withValues(alpha: 0.2) : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? C.cyan : const Color(0x20FFFFFF),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: C.cyan.withValues(alpha: 0.2), blurRadius: 8)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tracker.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              tracker.name,
              style: AppTheme.font(
                size: 11,
                color: active ? C.cyan : C.textSub,
                weight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTheme.font(size: 11, color: C.textSub)),
      ],
    );
  }

  void _onAreaTap(Map<String, dynamic> areaStatus) {
    final pbId = areaStatus['power_block_id'];
    if (pbId == null) return;
    final state = context.read<AppState>();
    final block = state.blocks.where((b) => b.id == pbId).firstOrNull;
    if (block == null) return;

    final hasIfc = areaStatus['has_ifc'] == true || block.hasIfc;

    if (!hasIfc) {
      Navigator.pushNamed(context, '/block', arguments: block);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x30FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(block.name,
                    style: AppTheme.font(size: 16, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.visibility_rounded, color: C.cyan),
                  title: Text('View Block Details',
                      style: AppTheme.font(size: 14, color: C.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/block', arguments: block);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.description_outlined, color: C.gold),
                  title: Text('View IFC Drawing',
                      style: AppTheme.font(size: 14, color: C.text)),
                  subtitle: block.ifcPageNumber != null
                      ? Text('Page ${block.ifcPageNumber}',
                          style: AppTheme.font(size: 11, color: C.textDim))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/ifc', arguments: {
                      'block_id': block.id,
                      'block_name': block.name,
                      'ifc_page_number': block.ifcPageNumber,
                      'ifc_filename': block.ifcFilename,
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _instantDelete(dynamic area) async {
    final areaId = _toInt(area['id']);
    if (areaId == null) return;
    final areaName = area['name']?.toString() ?? 'Area';
    final areaData = Map<String, dynamic>.from(area as Map);

    // Remove from local list immediately
    setState(() {
      _areas.removeWhere((a) => _toInt(a['id']) == areaId);
      _lastDeleted = areaData;
    });

    // Delete from server
    final api = context.read<AppState>().api;
    final ok = await api.deleteSiteArea(areaId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        ok ? 'Deleted "$areaName"' : 'Failed to delete "$areaName"',
        style: AppTheme.font(size: 14),
      ),
      backgroundColor: C.surface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: ok
          ? SnackBarAction(
              label: 'UNDO',
              textColor: C.cyan,
              onPressed: () => _undoDelete(areaData),
            )
          : null,
    ));

    // If delete failed on server, restore locally
    if (!ok && mounted) {
      setState(() => _areas.add(areaData));
    }
  }

  Future<void> _undoDelete(Map<String, dynamic> areaData) async {
    final api = context.read<AppState>().api;
    // Re-create the area on the server with original data
    final restored = await api.createSiteArea(areaData);
    if (restored != null && mounted) {
      // Reload from server to get fresh IDs and data
      await _loadMap();
    } else if (mounted) {
      // Optimistic add if server call failed — then refresh
      setState(() => _areas.add(areaData));
    }
  }

  // ── Zone helpers ─────────────────────────────────────

  List<String> get _zones {
    final seen = <String>{};
    for (final a in _areas) {
      final z = a['zone']?.toString();
      if (z != null && z.isNotEmpty) seen.add(z);
    }
    final list = seen.toList()..sort();
    return list;
  }

  void _onZoneTap(String? zone) {
    setState(() => _selectedZone = zone);
    if (zone == null) {
      _transformCtrl.value = Matrix4.identity();
      return;
    }
    final zoneAreas = _areas
        .where((a) => a['zone']?.toString() == zone)
        .toList();
    _zoomToZone(zoneAreas);
  }

  void _zoomToZone(List<dynamic> zoneAreas) {
    if (zoneAreas.isEmpty || _mapW <= 0 || _mapH <= 0) return;
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final area in zoneAreas) {
      final x = (_toDouble(area['bbox_x']) ?? 0) / 100 * _mapW;
      final y = (_toDouble(area['bbox_y']) ?? 0) / 100 * _mapH;
      final w = (_toDouble(area['bbox_w']) ?? 2) / 100 * _mapW;
      final h = (_toDouble(area['bbox_h']) ?? 2) / 100 * _mapH;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x + w);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y + h);
    }
    const padding = 48.0;
    final regionW = (maxX - minX) + padding * 2;
    final regionH = (maxY - minY) + padding * 2;
    final scaleX = _mapW / regionW;
    final scaleY = _mapH / regionH;
    final scale = math.min(scaleX, scaleY).clamp(0.3, 6.0);
    final imgCX = (minX + maxX) / 2;
    final imgCY = (minY + maxY) / 2;
    final tx = _mapW / 2 - scale * imgCX;
    final ty = _mapH / 2 - scale * imgCY;
    _transformCtrl.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale, scale);
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Color? _hexToColor(dynamic hex) {
    if (hex == null) return null;
    try {
      final h = hex.toString().replaceFirst('#', '');
      final full = h.length == 6 ? 'FF$h' : h;
      return Color(int.parse(full, radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// Keep old name for backward compat
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) => const MapTab();
}
