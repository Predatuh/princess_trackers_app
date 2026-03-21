const Set<String> _retiredStatusTypes = {'quality_check', 'quality_docs', 'fix'};

class Tracker {
  final int id;
  final String name;
  final String slug;
  final String itemNameSingular;
  final String itemNamePlural;
  final String statLabel;
  final String dashboardProgressLabel;
  final String dashboardBlocksLabel;
  final String dashboardOpenLabel;
  final String icon;
  final List<String> statusTypes;
  final Map<String, String> statusColors;
  final Map<String, String> statusNames;
  final bool isActive;

  Tracker({
    required this.id,
    required this.name,
    required this.slug,
    this.itemNameSingular = 'Item',
    this.itemNamePlural = 'Items',
    this.statLabel = 'Total Items',
    this.dashboardProgressLabel = 'Complete',
    this.dashboardBlocksLabel = 'Power Blocks',
    this.dashboardOpenLabel = 'Open Tracker',
    this.icon = '📋',
    this.statusTypes = const [],
    this.statusColors = const {},
    this.statusNames = const {},
    this.isActive = true,
  });

  factory Tracker.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
    final statusTypes = List<String>.from(j['status_types'] ?? [])
        .where((statusType) => !_retiredStatusTypes.contains(statusType))
        .toList();
    final statusColors = Map<String, String>.from(j['status_colors'] ?? {})
      ..removeWhere((key, _) => _retiredStatusTypes.contains(key));
    final statusNames = Map<String, String>.from(j['status_names'] ?? {})
      ..removeWhere((key, _) => _retiredStatusTypes.contains(key));
    return Tracker(
      id: toInt(j['id']),
      name: j['name'] ?? '',
      slug: j['slug'] ?? '',
      itemNameSingular: j['item_name_singular'] ?? 'Item',
      itemNamePlural: j['item_name_plural'] ?? 'Items',
      statLabel: j['stat_label'] ?? 'Total Items',
      dashboardProgressLabel: j['dashboard_progress_label'] ?? 'Complete',
      dashboardBlocksLabel: j['dashboard_blocks_label'] ?? 'Power Blocks',
      dashboardOpenLabel: j['dashboard_open_label'] ?? 'Open Tracker',
      icon: j['icon'] ?? '📋',
      statusTypes: statusTypes,
      statusColors: statusColors,
      statusNames: statusNames,
      isActive: j['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'item_name_singular': itemNameSingular,
        'item_name_plural': itemNamePlural,
        'stat_label': statLabel,
        'dashboard_progress_label': dashboardProgressLabel,
        'dashboard_blocks_label': dashboardBlocksLabel,
        'dashboard_open_label': dashboardOpenLabel,
        'icon': icon,
        'status_types': statusTypes,
        'status_colors': statusColors,
        'status_names': statusNames,
        'is_active': isActive,
      };

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    final stripped = trimmed.replaceFirst(RegExp(r'\s+tracker$', caseSensitive: false), '').trim();
    return stripped.isNotEmpty ? stripped : trimmed;
  }
}
