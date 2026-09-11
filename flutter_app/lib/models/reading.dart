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
      'worker_id': workerId,
      'timestamp': timestamp.toIso8601String(),
      'dose': dose,
      'intensity': intensity,
      'riskLevel': riskLevel,
      'risk_level': riskLevel,
      'isExpired': isExpired,
      'is_expired': isExpired,
      'expiryStatusMessage': expiryStatusMessage,
      'expiry_status_message': expiryStatusMessage,
      'estimatedH2sPpm': estimatedH2sPpm,
      'estimated_h2s_ppm': estimatedH2sPpm,
      'exposureTime': exposureTime,
      'exposure_time': exposureTime,
      'temperature': temperature,
      'humidity': humidity,
      'badgeMode': badgeMode,
      'badge_mode': badgeMode,
      'dataSource': dataSource,
      'data_source': dataSource,
      'confidencePct': confidencePct,
      'confidence_pct': confidencePct,
      'actionGuidance': actionGuidance,
      'action_guidance': actionGuidance,
    };
  }

  factory Reading.fromMap(Map<String, dynamic> map) {
    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(map['timestamp'].toString());
    } catch (_) {
      parsedTime = DateTime.now();
    }

    final double ppm = (map['estimated_h2s_ppm'] ?? map['estimatedH2sPpm'] ?? map['dose'] as num?)?.toDouble() ?? 0.0;
    final double expTime = (map['exposure_time'] ?? map['exposureTime'] as num?)?.toDouble() ?? 1.0;
    final double calcDose = (map['dose'] as num?)?.toDouble() ?? (ppm * expTime);

    return Reading(
      id: (map['id'] ?? map['reading_id'] ?? '').toString(),
      workerId: (map['worker_id'] ?? map['workerId'] ?? '').toString(),
      timestamp: parsedTime,
      dose: calcDose,
      intensity: (map['intensity'] ?? map['raw_intensity'] ?? map['strip_intensity'] as num?)?.toDouble() ?? 0.0,
      riskLevel: (map['risk_level'] ?? map['riskLevel'] ?? 'Safe').toString(),
      isExpired: map['is_expired'] == 1 || map['is_expired'] == true || map['isExpired'] == true,
      expiryStatusMessage: (map['expiry_status_message'] ?? map['expiryStatusMessage'] ?? 'Active & Verified').toString(),
      estimatedH2sPpm: ppm,
      exposureTime: expTime,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 25.0,
      humidity: (map['predicted_humidity'] ?? map['humidity'] as num?)?.toDouble() ?? 50.0,
      badgeMode: (map['badge_mode'] ?? map['badgeMode'] ?? 'STANDALONE_CHEMICAL_STRIP').toString(),
      dataSource: (map['data_source'] ?? map['dataSource'] ?? 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL').toString(),
      confidencePct: (map['confidence_pct'] ?? map['confidencePct'] as num?)?.toInt() ?? 92,
      actionGuidance: (map['action_guidance'] ?? map['actionGuidance'] ?? 'Maintain standard monitoring protocols.').toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Reading.fromJson(String source) =>
      Reading.fromMap(json.decode(source));
}
