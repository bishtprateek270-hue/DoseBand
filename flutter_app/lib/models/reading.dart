import 'dart:convert';

class Reading {
  final String id;
  final String workerId;
  final DateTime timestamp;
  final double dose;
  final double intensity;
  final String riskLevel;
  final bool isExpired;
  final String expiryStatusMessage;

  Reading({
    required this.id,
    required this.workerId,
    required this.timestamp,
    required this.dose,
    required this.intensity,
    required this.riskLevel,
    required this.isExpired,
    required this.expiryStatusMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerId': workerId,
      'timestamp': timestamp.toIso8601String(),
      'dose': dose,
      'intensity': intensity,
      'riskLevel': riskLevel,
      'isExpired': isExpired,
      'expiryStatusMessage': expiryStatusMessage,
    };
  }

  factory Reading.fromMap(Map<String, dynamic> map) {
    return Reading(
      id: map['id'] ?? '',
      workerId: map['workerId'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      dose: map['dose']?.toDouble() ?? 0.0,
      intensity: map['intensity']?.toDouble() ?? 0.0,
      riskLevel: map['riskLevel'] ?? '',
      isExpired: map['isExpired'] ?? false,
      expiryStatusMessage: map['expiryStatusMessage'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Reading.fromJson(String source) =>
      Reading.fromMap(json.decode(source));
}
