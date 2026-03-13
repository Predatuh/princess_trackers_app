class User {
  final int id;
  final String name;
  final String username;
  final bool isAdmin;
  final String role;
  final List<String> permissions;

  User({
    required this.id,
    required this.name,
    required this.username,
    this.isAdmin = false,
    this.role = 'user',
    this.permissions = const [],
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        name: j['name'] ?? '',
        username: j['username'] ?? '',
        isAdmin: j['is_admin'] ?? false,
        role: j['role'] ?? 'user',
        permissions: List<String>.from(j['permissions'] ?? const []),
      );

  bool get canAccessAdmin {
    if (isAdmin || role == 'admin') return true;
    return permissions.contains('admin_settings') ||
        permissions.contains('edit_map');
  }
}

class WorkEntry {
  final int id;
  final String workerName;
  final String taskType;
  final String pbName;
  final String date;

  WorkEntry({
    required this.id,
    required this.workerName,
    required this.taskType,
    required this.pbName,
    required this.date,
  });

  factory WorkEntry.fromJson(Map<String, dynamic> j) => WorkEntry(
        id: j['id'],
        workerName: j['worker_name'] ?? '',
        taskType: j['task_type'] ?? '',
        pbName: j['power_block_name'] ?? '',
        date: j['work_date'] ?? '',
      );
}

class DailyReport {
  final int id;
  final String reportDate;
  final Map<String, dynamic> data;

  DailyReport({required this.id, required this.reportDate, this.data = const {}});

  factory DailyReport.fromJson(Map<String, dynamic> j) => DailyReport(
        id: j['id'],
        reportDate: j['report_date'] ?? '',
        data: j['data'] ?? {},
      );
}

class Worker {
  final int id;
  final String name;
  final bool isActive;

  Worker({required this.id, required this.name, this.isActive = true});

  factory Worker.fromJson(Map<String, dynamic> j) => Worker(
        id: j['id'],
        name: j['name'] ?? '',
        isActive: j['is_active'] ?? true,
      );
}
