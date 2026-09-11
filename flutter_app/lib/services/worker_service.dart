import 'package:flutter/foundation.dart';
import '../models/worker.dart';
import '../models/reading.dart';

class WorkerService extends ChangeNotifier {
  static final WorkerService _instance = WorkerService._internal();
  factory WorkerService() => _instance;

  WorkerService._internal() {
    _initSeedData();
  }

  final List<Worker> _workers = [];
  final List<Reading> _readings = [];

  List<Worker> get workers => List.unmodifiable(_workers);
  List<Reading> get readings => List.unmodifiable(_readings);

  void _initSeedData() {
    _workers.addAll([
      Worker(
        workerId: 'W-101',
        name: 'Rajesh Kumar',
        department: 'Mines & Extraction',
        shift: 'Day Shift (08:00 - 16:00)',
        emergencyContact: '+91 98765 43210',
        status: 'Active',
        cumulativeDose: 8.5,
        riskLevel: 'Safe',
        isBadgeExpired: false,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Worker(
        workerId: 'W-102',
        name: 'Anita Sharma',
        department: 'Chemical Processing',
        shift: 'Day Shift (08:00 - 16:00)',
        emergencyContact: '+91 98123 45678',
        status: 'Active',
        cumulativeDose: 42.0,
        riskLevel: 'Caution',
        isBadgeExpired: false,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Worker(
        workerId: 'W-103',
        name: 'Vikram Singh',
        department: 'Refining & Storage',
        shift: 'Night Shift (20:00 - 04:00)',
        emergencyContact: '+91 97654 32109',
        status: 'Active',
        cumulativeDose: 58.4,
        riskLevel: 'Unsafe',
        isBadgeExpired: true,
        lastScanTime: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Worker(
        workerId: 'W-104',
        name: 'Suresh Patel',
        department: 'Maintenance & Safety',
        shift: 'Swing Shift (12:00 - 20:00)',
        emergencyContact: '+91 96543 21098',
        status: 'On Shift',
        cumulativeDose: 4.2,
        riskLevel: 'Safe',
        isBadgeExpired: false,
        lastScanTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ]);

    _readings.addAll([
      Reading(
        id: 'R-001',
        workerId: 'W-101',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        dose: 8.5,
        intensity: 0.18,
        riskLevel: 'Safe',
        isExpired: false,
        expiryStatusMessage: 'Valid — safe to use',
        estimatedH2sPpm: 8.5,
        exposureTime: 1.0,
        temperature: 25.0,
        humidity: 50.0,
        badgeMode: 'STANDALONE_CHEMICAL_STRIP',
        dataSource: 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
        confidencePct: 94,
        actionGuidance: 'Within permissible 8-hr TWA limit. Safe to continue shift.',
      ),
      Reading(
        id: 'R-002',
        workerId: 'W-102',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        dose: 14.2,
        intensity: 0.42,
        riskLevel: 'Caution',
        isExpired: false,
        expiryStatusMessage: 'Valid — safe to use',
        estimatedH2sPpm: 14.2,
        exposureTime: 1.0,
        temperature: 26.5,
        humidity: 55.0,
        badgeMode: 'STANDALONE_CHEMICAL_STRIP',
        dataSource: 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
        confidencePct: 92,
        actionGuidance: 'Exceeds 8-hr TWA threshold. Mandatory industrial ventilation check.',
      ),
      Reading(
        id: 'R-003',
        workerId: 'W-103',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        dose: 58.4,
        intensity: 0.88,
        riskLevel: 'Unsafe',
        isExpired: true,
        expiryStatusMessage: 'EXPIRED — replace badge immediately',
        estimatedH2sPpm: 58.4,
        exposureTime: 1.0,
        temperature: 28.0,
        humidity: 60.0,
        badgeMode: 'FULL_DOSEBAND_BADGE',
        dataSource: 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
        confidencePct: 90,
        actionGuidance: 'STEL / Critical Exposure Exceeded! Evacuate area immediately.',
      ),
      Reading(
        id: 'R-004',
        workerId: 'W-104',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        dose: 4.2,
        intensity: 0.12,
        riskLevel: 'Safe',
        isExpired: false,
        expiryStatusMessage: 'Valid — safe to use',
        estimatedH2sPpm: 4.2,
        exposureTime: 1.0,
        temperature: 24.0,
        humidity: 48.0,
        badgeMode: 'STANDALONE_CHEMICAL_STRIP',
        dataSource: 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
        confidencePct: 95,
        actionGuidance: 'Within permissible 8-hr TWA limit. Safe to continue shift.',
      ),
    ]);
  }

  Worker? getWorkerById(String workerId) {
    try {
      return _workers.firstWhere((w) => w.workerId.toUpperCase() == workerId.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  bool addWorker(Worker worker) {
    if (getWorkerById(worker.workerId) != null) {
      return false; // Duplicate ID
    }
    _workers.add(worker);
    notifyListeners();
    return true;
  }

  void addReading({
    required String workerId,
    required double dose,
    required double intensity,
    required String riskLevel,
    required bool isExpired,
    required String expiryStatusMessage,
    double estimatedH2sPpm = 0.0,
    double exposureTime = 1.0,
    double temperature = 25.0,
    double humidity = 50.0,
    String badgeMode = 'STANDALONE_CHEMICAL_STRIP',
    String dataSource = 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
    int confidencePct = 94,
    String actionGuidance = 'Maintain standard monitoring protocols.',
  }) {
    final now = DateTime.now();
    final newReading = Reading(
      id: 'R-${(_readings.length + 1).toString().padLeft(3, '0')}',
      workerId: workerId,
      timestamp: now,
      dose: dose,
      intensity: intensity,
      riskLevel: riskLevel,
      isExpired: isExpired,
      expiryStatusMessage: expiryStatusMessage,
      estimatedH2sPpm: estimatedH2sPpm,
      exposureTime: exposureTime,
      temperature: temperature,
      humidity: humidity,
      badgeMode: badgeMode,
      dataSource: dataSource,
      confidencePct: confidencePct,
      actionGuidance: actionGuidance,
    );

    _readings.insert(0, newReading);

    final workerIndex = _workers.indexWhere((w) => w.workerId.toUpperCase() == workerId.toUpperCase());
    if (workerIndex != -1) {
      final existingWorker = _workers[workerIndex];
      final newCumDose = existingWorker.cumulativeDose + dose;
      
      // Risk classification per DGMS / OISD / OSHA 29 CFR 1910.1000:
      // Safe < 10.0 ppm*hr | Caution 10.0–50.0 ppm*hr | Unsafe >= 50.0 ppm*hr
      String updatedRisk = 'Safe';
      if (newCumDose >= 50.0 || riskLevel == 'Unsafe') {
        updatedRisk = 'Unsafe';
      } else if (newCumDose >= 10.0 || riskLevel == 'Caution') {
        updatedRisk = 'Caution';
      }

      _workers[workerIndex] = existingWorker.copyWith(
        cumulativeDose: newCumDose,
        riskLevel: updatedRisk,
        isBadgeExpired: isExpired || existingWorker.isBadgeExpired,
        lastScanTime: now,
      );
    } else {
      // Auto register unknown worker
      _workers.add(Worker(
        workerId: workerId,
        name: 'Worker $workerId',
        department: 'General Operations',
        shift: 'Standard Shift',
        emergencyContact: 'Not Provided',
        status: 'Active',
        cumulativeDose: dose,
        riskLevel: riskLevel,
        isBadgeExpired: isExpired,
        lastScanTime: now,
      ));
    }

    notifyListeners();
  }

  List<Reading> getReadingsForWorker(String workerId) {
    return _readings.where((r) => r.workerId.toUpperCase() == workerId.toUpperCase()).toList();
  }

  int get activeWorkersCount => _workers.where((w) => w.status == 'Active' || w.status == 'On Shift').length;
  int get unsafeWorkersCount => _workers.where((w) => w.riskLevel == 'Unsafe' || w.cumulativeDose >= 50.0).length;
  int get expiredBadgesCount => _workers.where((w) => w.isBadgeExpired).length;
}
