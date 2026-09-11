import 'dart:convert';

class Worker {
  final String workerId;
  final String name;
  final String department;
  final String workZone;
  final String shift;
  final String badgeId;
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
    required this.emergencyContact,
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
      'name': name,
      'department': department,
      'workZone': workZone,
      'shift': shift,
      'badgeId': badgeId,
      'emergencyContact': emergencyContact,
      'status': status,
      'cumulativeDose': cumulativeDose,
      'riskLevel': riskLevel,
      'isBadgeExpired': isBadgeExpired,
      'lastScanTime': lastScanTime?.toIso8601String(),
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      workerId: map['workerId'] ?? '',
      name: map['name'] ?? '',
      department: map['department'] ?? '',
      workZone: map['workZone'] ?? 'Zone A - General Area',
      shift: map['shift'] ?? '',
      badgeId: map['badgeId'] ?? '',
      emergencyContact: map['emergencyContact'] ?? '',
      status: map['status'] ?? 'Active',
      cumulativeDose: (map['cumulativeDose'] as num?)?.toDouble() ?? 0.0,
      riskLevel: map['riskLevel'] ?? 'Safe',
      isBadgeExpired: map['isBadgeExpired'] ?? false,
      lastScanTime: map['lastScanTime'] != null ? DateTime.parse(map['lastScanTime']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Worker.fromJson(String source) => Worker.fromMap(json.decode(source));
}
