class Tracker {
  final int id;
  final String name;
  final String slug;
  final String itemNameSingular;
  final String itemNamePlural;
  final String statLabel;
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
      icon: j['icon'] ?? '📋',
      statusTypes: List<String>.from(j['status_types'] ?? []),
      statusColors: Map<String, String>.from(j['status_colors'] ?? {}),
      statusNames: Map<String, String>.from(j['status_names'] ?? {}),
      isActive: j['is_active'] ?? true,
    );
  }
}
