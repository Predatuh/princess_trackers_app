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
      statusTypes: List<String>.from(j['status_types'] ?? []),
      statusColors: Map<String, String>.from(j['status_colors'] ?? {}),
      statusNames: Map<String, String>.from(j['status_names'] ?? {}),
      isActive: j['is_active'] ?? true,
    );
  }
}
