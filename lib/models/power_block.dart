class PowerBlock {
  final int id;
  final String name;
  final int powerBlockNumber;
  final int lbdCount;
  final Map<String, int> lbdSummary;
  final List<LbdItem> lbds;
  final String? claimedBy;
  final String? zone;

  PowerBlock({
    required this.id,
    required this.name,
    required this.powerBlockNumber,
    this.lbdCount = 0,
    this.lbdSummary = const {},
    this.lbds = const [],
    this.claimedBy,
    this.zone,
  });

  factory PowerBlock.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
    final rawSummary = j['lbd_summary'] as Map<String, dynamic>? ?? {};
    final summary = <String, int>{};
    rawSummary.forEach((k, v) => summary[k] = toInt(v));
    return PowerBlock(
      id: toInt(j['id']),
      name: j['name'] ?? '',
      powerBlockNumber: toInt(j['power_block_number']),
      lbdCount: toInt(j['lbd_count']),
      lbdSummary: summary,
      lbds: (j['lbds'] as List? ?? []).map((e) => LbdItem.fromJson(e as Map<String, dynamic>)).toList(),
      claimedBy: j['claimed_by']?.toString(),
      zone: j['zone']?.toString(),
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
