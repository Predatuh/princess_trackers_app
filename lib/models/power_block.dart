class PowerBlock {
  final int id;
  final String name;
  final int powerBlockNumber;
  final int lbdCount;
  final Map<String, int> lbdSummary;
  final List<LbdItem> lbds;
  final String? claimedBy;
  final List<String> claimedPeople;
  final Map<String, List<int>> claimAssignments;
  final String? claimedAt;
  final String? zone;

  PowerBlock({
    required this.id,
    required this.name,
    required this.powerBlockNumber,
    this.lbdCount = 0,
    this.lbdSummary = const {},
    this.lbds = const [],
    this.claimedBy,
    this.claimedPeople = const [],
    this.claimAssignments = const {},
    this.claimedAt,
    this.zone,
  });

  factory PowerBlock.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
    final rawSummary = j['lbd_summary'] as Map<String, dynamic>? ?? {};
    final summary = <String, int>{};
    rawSummary.forEach((k, v) => summary[k] = toInt(v));
    final people = (j['claimed_people'] as List? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final rawAssignments = j['claim_assignments'] as Map<String, dynamic>? ?? {};
    final assignments = <String, List<int>>{};
    rawAssignments.forEach((key, value) {
      final ids = (value as List? ?? const [])
          .map((entry) => toInt(entry))
          .where((entry) => entry > 0)
          .toList();
      if (ids.isNotEmpty) {
        assignments[key] = ids;
      }
    });
    return PowerBlock(
      id: toInt(j['id']),
      name: j['name'] ?? '',
      powerBlockNumber: toInt(j['power_block_number']),
      lbdCount: toInt(j['lbd_count']),
      lbdSummary: summary,
      lbds: (j['lbds'] as List? ?? []).map((e) => LbdItem.fromJson(e as Map<String, dynamic>)).toList(),
      claimedBy: j['claimed_by']?.toString(),
      claimedPeople: people,
      claimAssignments: assignments,
      claimedAt: j['claimed_at']?.toString(),
      zone: j['zone']?.toString(),
    );
  }

  bool get isClaimed => claimedPeople.isNotEmpty || claimedBy != null;

  String? get claimedLabel {
    if (claimedPeople.isNotEmpty) return claimedPeople.join(', ');
    return claimedBy;
  }

  PowerBlock copyWith({
    String? claimedBy,
    List<String>? claimedPeople,
    Map<String, List<int>>? claimAssignments,
    String? claimedAt,
    Map<String, int>? lbdSummary,
    List<LbdItem>? lbds,
  }) {
    return PowerBlock(
      id: id,
      name: name,
      powerBlockNumber: powerBlockNumber,
      lbdCount: lbdCount,
      lbdSummary: lbdSummary ?? this.lbdSummary,
      lbds: lbds ?? this.lbds,
      claimedBy: claimedBy,
      claimedPeople: claimedPeople ?? this.claimedPeople,
      claimAssignments: claimAssignments ?? this.claimAssignments,
      claimedAt: claimedAt,
      zone: zone,
    );
  }
}

class LbdItem {
  final int id;
  final String? name;
  final String? identifier;
  final String? inventoryNumber;
  final List<LbdStatus> statuses;

  LbdItem({
    required this.id,
    this.name,
    this.identifier,
    this.inventoryNumber,
    this.statuses = const [],
  });

  factory LbdItem.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
    return LbdItem(
      id: toInt(j['id']),
      name: j['name']?.toString(),
      identifier: j['identifier']?.toString(),
      inventoryNumber: j['inventory_number']?.toString(),
      statuses:
          (j['statuses'] as List? ?? []).map((e) => LbdStatus.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class LbdStatus {
  final String statusType;
  bool isCompleted;

  LbdStatus({required this.statusType, this.isCompleted = false});

  factory LbdStatus.fromJson(Map<String, dynamic> j) => LbdStatus(
        statusType: j['status_type'] ?? '',
        isCompleted: j['is_completed'] ?? false,
      );
}
