import 'dart:convert';

class Worker {
  final String workerId;
  final String name;
  final String department;
  final String workZone;
  final String shift;
  final String badgeId;
  final String badgeIssueDate;
  final String badgeExpiryDate;
  final String emergencyContact;
  final String status;
  final double cumulativeDose;
  final String riskLevel;
  final bool isBadgeExpired;
  final DateTime? lastScanTime;

  Worker({
    required this.workerId,
    required this.name,
    required this.department,
    this.workZone = 'Zone A - General Area',
    required this.shift,
    this.badgeId = '',
    this.badgeIssueDate = '',
    this.badgeExpiryDate = '',
    this.emergencyContact = '+91 98765 43210',
    this.status = 'Active',
    this.cumulativeDose = 0.0,
    this.riskLevel = 'Safe',
    this.isBadgeExpired = false,
    this.lastScanTime,
  });

  String get effectiveBadgeId => badgeId.isNotEmpty ? badgeId : 'BDG-${workerId.replaceAll('W-', '')}';

  Worker copyWith({
    String? workerId,
    String? name,
    String? department,
    String? workZone,
    String? shift,
    String? badgeId,
    String? badgeIssueDate,
    String? badgeExpiryDate,
    String? emergencyContact,
    String? status,
    double? cumulativeDose,
    String? riskLevel,
    bool? isBadgeExpired,
    DateTime? lastScanTime,
  }) {
    return Worker(
      workerId: workerId ?? this.workerId,
      name: name ?? this.name,
      department: department ?? this.department,
      workZone: workZone ?? this.workZone,
      shift: shift ?? this.shift,
      badgeId: badgeId ?? this.badgeId,
      badgeIssueDate: badgeIssueDate ?? this.badgeIssueDate,
      badgeExpiryDate: badgeExpiryDate ?? this.badgeExpiryDate,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      status: status ?? this.status,
      cumulativeDose: cumulativeDose ?? this.cumulativeDose,
      riskLevel: riskLevel ?? this.riskLevel,
      isBadgeExpired: isBadgeExpired ?? this.isBadgeExpired,
      lastScanTime: lastScanTime ?? this.lastScanTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'worker_id': workerId,
      'name': name,
      'department': department,
      'workZone': workZone,
      'work_zone': workZone,
      'shift': shift,
      'badgeId': badgeId,
      'badge_id': badgeId,
      'badgeIssueDate': badgeIssueDate,
      'badge_issue_date': badgeIssueDate,
      'badgeExpiryDate': badgeExpiryDate,
      'badge_expiry_date': badgeExpiryDate,
      'emergencyContact': emergencyContact,
      'status': status,
      'cumulativeDose': cumulativeDose,
      'cumulative_dose': cumulativeDose,
      'riskLevel': riskLevel,
      'risk_level': riskLevel,
      'isBadgeExpired': isBadgeExpired,
      'is_badge_expired': isBadgeExpired,
      'lastScanTime': lastScanTime?.toIso8601String(),
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    final expDateStr = map['badge_expiry_date']?.toString() ?? map['badgeExpiryDate']?.toString() ?? '';
    bool isExpired = map['is_badge_expired'] == true || map['isBadgeExpired'] == true;
    if (expDateStr.isNotEmpty) {
      try {
        final expD = DateTime.parse(expDateStr);
        if (expD.isBefore(DateTime.now())) {
          isExpired = true;
        }
      } catch (_) {}
    }

    final double dose = (map['cumulative_dose'] ?? map['cumulativeDose'] as num?)?.toDouble() ?? 0.0;
    String risk = map['risk_level'] ?? map['riskLevel'] ?? 'Safe';
    if (risk == 'Safe' && dose >= 50.0) {
      risk = 'Unsafe';
    } else if (risk == 'Safe' && dose >= 10.0) {
      risk = 'Caution';
    }

    return Worker(
      workerId: map['worker_id'] ?? map['workerId'] ?? '',
      name: map['name'] ?? '',
      department: map['department'] ?? '',
      workZone: map['work_zone'] ?? map['workZone'] ?? 'Zone A - General Area',
      shift: map['shift'] ?? 'Shift 1 (06:00 - 14:00)',
      badgeId: map['badge_id'] ?? map['badgeId'] ?? '',
      badgeIssueDate: map['badge_issue_date'] ?? map['badgeIssueDate'] ?? '',
      badgeExpiryDate: expDateStr,
      emergencyContact: map['emergency_contact'] ?? map['emergencyContact'] ?? '+91 98765 43210',
      status: map['status'] ?? 'Active',
      cumulativeDose: dose,
      riskLevel: risk,
      isBadgeExpired: isExpired,
      lastScanTime: map['last_scan_time'] != null
          ? DateTime.tryParse(map['last_scan_time'].toString())
          : (map['lastScanTime'] != null ? DateTime.tryParse(map['lastScanTime'].toString()) : null),
    );
  }

  String toJson() => json.encode(toMap());

  factory Worker.fromJson(String source) => Worker.fromMap(json.decode(source));
}
