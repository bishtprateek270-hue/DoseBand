import 'dart:convert';

class Reading {
  final String id;
  final String workerId;
  final DateTime timestamp;
  final double dose; // Cumulative exposure in ppm*hr
  final double intensity; // Optical staining intensity (0.0 to 1.0)
  final String riskLevel; // Safe | Caution | Unsafe
  final bool isExpired;
  final String expiryStatusMessage;
  final double estimatedH2sPpm; // Gas concentration in ppm
  final double exposureTime; // Shift duration in hours
  final double temperature; // Ambient temperature in C
  final double humidity; // Relative humidity %
  final String badgeMode; // FULL_DOSEBAND_BADGE | STANDALONE_CHEMICAL_STRIP
  final String dataSource; // CALIBRATED_OPTICAL_DOSIMETRY_MODEL
  final int confidencePct; // 0 - 100%
  final String actionGuidance;

  Reading({
    required this.id,
    required this.workerId,
    required this.timestamp,
    required this.dose,
    required this.intensity,
    required this.riskLevel,
    required this.isExpired,
    required this.expiryStatusMessage,
    this.estimatedH2sPpm = 0.0,
    this.exposureTime = 1.0,
    this.temperature = 25.0,
    this.humidity = 50.0,
    this.badgeMode = 'STANDALONE_CHEMICAL_STRIP',
    this.dataSource = 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
    this.confidencePct = 94,
    this.actionGuidance = 'Maintain standard monitoring protocols.',
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
      'estimatedH2sPpm': estimatedH2sPpm,
      'exposureTime': exposureTime,
      'temperature': temperature,
      'humidity': humidity,
      'badgeMode': badgeMode,
      'dataSource': dataSource,
      'confidencePct': confidencePct,
      'actionGuidance': actionGuidance,
    };
  }

  factory Reading.fromMap(Map<String, dynamic> map) {
    return Reading(
      id: map['id'] ?? '',
      workerId: map['workerId'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      dose: (map['dose'] as num?)?.toDouble() ?? 0.0,
      intensity: (map['intensity'] as num?)?.toDouble() ?? 0.0,
      riskLevel: map['riskLevel'] ?? 'Safe',
      isExpired: map['isExpired'] ?? false,
      expiryStatusMessage: map['expiryStatusMessage'] ?? '',
      estimatedH2sPpm: (map['estimatedH2sPpm'] as num?)?.toDouble() ?? (map['dose'] as num?)?.toDouble() ?? 0.0,
      exposureTime: (map['exposureTime'] as num?)?.toDouble() ?? 1.0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 25.0,
      humidity: (map['humidity'] as num?)?.toDouble() ?? 50.0,
      badgeMode: map['badgeMode'] ?? 'STANDALONE_CHEMICAL_STRIP',
      dataSource: map['dataSource'] ?? 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
      confidencePct: (map['confidencePct'] as num?)?.toInt() ?? 94,
      actionGuidance: map['actionGuidance'] ?? 'Maintain standard monitoring protocols.',
    );
  }

  String toJson() => json.encode(toMap());

  factory Reading.fromJson(String source) =>
      Reading.fromMap(json.decode(source));
}
