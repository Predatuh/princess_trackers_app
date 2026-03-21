class User {
  final int id;
  final String name;
  final String username;
  final String email;
  final String jobSiteName;
  final bool emailVerified;
  final bool isAdmin;
  final String role;
  final List<String> permissions;

  User({
    required this.id,
    required this.name,
    required this.username,
    this.email = '',
    this.jobSiteName = '',
    this.emailVerified = false,
    this.isAdmin = false,
    this.role = 'user',
    this.permissions = const [],
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        name: j['name'] ?? '',
        username: j['username'] ?? '',
        email: j['email'] ?? '',
        jobSiteName: j['job_site_name'] ?? '',
        emailVerified: j['email_verified'] ?? false,
        isAdmin: j['is_admin'] ?? false,
        role: j['role'] ?? 'user',
        permissions: List<String>.from(j['permissions'] ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'job_site_name': jobSiteName,
        'email_verified': emailVerified,
        'is_admin': isAdmin,
        'role': role,
        'permissions': permissions,
      };

  bool get canAccessAdmin {
    if (isAdmin || role == 'admin') return true;
    return permissions.contains('admin_settings') ||
        permissions.contains('edit_map');
  }
}

class AuthFlowResult {
  final User? user;
  final String? error;
  final bool verificationRequired;
  final String? email;
  final String? jobSiteName;
  final String? message;
  final String? previewCode;

  const AuthFlowResult({
    this.user,
    this.error,
    this.verificationRequired = false,
    this.email,
    this.jobSiteName,
    this.message,
    this.previewCode,
  });

  bool get isSuccess => user != null;
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
  final int claimScanCount;
  final String? latestClaimScanImageUrl;
  final String? latestClaimScanPowerBlock;

  DailyReport({
    required this.id,
    required this.reportDate,
    this.data = const {},
    this.claimScanCount = 0,
    this.latestClaimScanImageUrl,
    this.latestClaimScanPowerBlock,
  });

  factory DailyReport.fromJson(Map<String, dynamic> j) => DailyReport(
        id: j['id'],
        reportDate: j['report_date'] ?? '',
        data: j['data'] ?? {},
        claimScanCount: j['claim_scan_count'] ?? 0,
        latestClaimScanImageUrl: j['latest_claim_scan_image_url']?.toString(),
        latestClaimScanPowerBlock: j['latest_claim_scan_power_block']?.toString(),
      );
}

class ReviewEntry {
  final int id;
  final int powerBlockId;
  final String powerBlockName;
  final int lbdId;
  final String lbdName;
  final String lbdIdentifier;
  final String reviewTargetLabel;
  final String reviewResult;
  final String reviewDate;
  final String reviewedBy;
  final String notes;
  final String createdAt;

  ReviewEntry({
    required this.id,
    required this.powerBlockId,
    required this.powerBlockName,
    required this.lbdId,
    this.lbdName = '',
    this.lbdIdentifier = '',
    this.reviewTargetLabel = '',
    required this.reviewResult,
    required this.reviewDate,
    required this.reviewedBy,
    this.notes = '',
    this.createdAt = '',
  });

  factory ReviewEntry.fromJson(Map<String, dynamic> j) => ReviewEntry(
        id: j['id'] ?? 0,
        powerBlockId: j['power_block_id'] ?? 0,
        powerBlockName: j['power_block_name']?.toString() ?? '',
      lbdId: j['lbd_id'] ?? 0,
      lbdName: j['lbd_name']?.toString() ?? '',
      lbdIdentifier: j['lbd_identifier']?.toString() ?? '',
      reviewTargetLabel: j['review_target_label']?.toString() ?? '',
        reviewResult: j['review_result']?.toString() ?? 'fail',
        reviewDate: j['review_date']?.toString() ?? '',
        reviewedBy: j['reviewed_by']?.toString() ?? '',
        notes: j['notes']?.toString() ?? '',
        createdAt: j['created_at']?.toString() ?? '',
      );
}

class ReviewReport {
  final int id;
  final String reportDate;
  final Map<String, dynamic> data;
  final int totalReviews;
  final int passCount;
  final int failCount;
  final List<String> reviewers;
  final List<Map<String, dynamic>> failedBlocks;

  ReviewReport({
    required this.id,
    required this.reportDate,
    this.data = const {},
    this.totalReviews = 0,
    this.passCount = 0,
    this.failCount = 0,
    this.reviewers = const [],
    this.failedBlocks = const [],
  });

  factory ReviewReport.fromJson(Map<String, dynamic> j) => ReviewReport(
        id: j['id'] ?? 0,
        reportDate: j['report_date']?.toString() ?? '',
        data: Map<String, dynamic>.from(j['data'] ?? const {}),
        totalReviews: j['total_reviews'] ?? 0,
        passCount: j['pass_count'] ?? 0,
        failCount: j['fail_count'] ?? 0,
        reviewers: List<String>.from(j['reviewers'] ?? const []),
        failedBlocks: (j['failed_blocks'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(),
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
