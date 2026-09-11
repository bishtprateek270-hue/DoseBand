import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/worker.dart';
import '../models/reading.dart';
import 'api_service.dart';

/// Worker & Dosimetry State Management Service.
///
/// Automatically synchronizes with the Python FastAPI backend and SQLite database (doseband.db).
/// Maintains seamless offline fallback with local state caching.
class WorkerService extends ChangeNotifier {
  static final WorkerService _instance = WorkerService._internal();
  factory WorkerService() => _instance;

  final ApiService _apiService = ApiService();

  WorkerService._internal() {
    _initSeedData();
    refreshFromBackend();
  }

  final List<Worker> _workers = [];
  final List<Reading> _readings = [];
  bool _isLoading = false;
  String? _lastError;
  Map<String, dynamic> _dashboardStats = {};

  List<Worker> get workers => List.unmodifiable(_workers);
  List<Reading> get readings => List.unmodifiable(_readings);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  bool get isConnected => _apiService.isServerConnected;

  int get activeWorkersCount => _workers.where((w) => w.status.toLowerCase() == 'active').length;
  int get unsafeWorkersCount => _workers.where((w) => w.riskLevel.toLowerCase() == 'unsafe').length;
  int get expiredBadgesCount => _workers.where((w) => w.isBadgeExpired).length;

  /// Fetches latest workers, sensor readings, and aggregated dashboard analytics from Python backend
  Future<void> fetchWorkers() => refreshFromBackend();

  Future<void> refreshFromBackend() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isHealthy = await _apiService.checkHealth();
      if (isHealthy) {
        // Fetch workers from SQLite
        final workerMaps = await _apiService.getWorkers();
        if (workerMaps.isNotEmpty) {
          _workers.clear();
          for (final wm in workerMaps) {
            _workers.add(Worker.fromMap(wm));
          }
        }

        // Fetch sensor readings from SQLite
        final readingMaps = await _apiService.getAllReadings();
        if (readingMaps.isNotEmpty) {
          _readings.clear();
          for (final rm in readingMaps) {
            _readings.add(Reading.fromMap(rm));
          }
        }

        // Fetch dashboard analytics
        _dashboardStats = await _apiService.getDashboardData();
        _lastError = null;
      }
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[WorkerService] Background sync note: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _initSeedData() {
    _workers.addAll([
      Worker(
        workerId: 'W-101',
        name: 'Rajesh Kumar',
        department: 'Refinery Operations',
        workZone: 'Zone A - Crude Distillation Unit',
        shift: 'Shift 1 (06:00 - 14:00)',
        badgeId: 'BDG-101',
        badgeIssueDate: '2026-08-01',
        badgeExpiryDate: '2026-11-01',
        emergencyContact: '+91 98765 43210',
        status: 'Active',
        cumulativeDose: 1.34,
        riskLevel: 'Safe',
        isBadgeExpired: false,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Worker(
        workerId: 'W-102',
        name: 'Vikram Singh',
        department: 'Pipeline Maintenance',
        workZone: 'Zone B - Desulfurization Plant',
        shift: 'Shift 2 (14:00 - 22:00)',
        badgeId: 'BDG-102',
        badgeIssueDate: '2026-08-01',
        badgeExpiryDate: '2026-11-01',
        emergencyContact: '+91 98123 45678',
        status: 'Active',
        cumulativeDose: 14.2,
        riskLevel: 'Caution',
        isBadgeExpired: false,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Worker(
        workerId: 'W-103',
        name: 'Amit Sharma',
        department: 'Safety & Inspection',
        workZone: 'Zone C - Storage & Flare Area',
        shift: 'Shift 1 (06:00 - 14:00)',
        badgeId: 'BDG-103',
        badgeIssueDate: '2026-08-01',
        badgeExpiryDate: '2026-09-15',
        emergencyContact: '+91 97654 32109',
        status: 'Active',
        cumulativeDose: 58.4,
        riskLevel: 'Unsafe',
        isBadgeExpired: false,
        lastScanTime: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Worker(
        workerId: 'W-104',
        name: 'Priya Patel',
        department: 'Chemical Laboratory',
        workZone: 'Zone D - Quality Control Lab',
        shift: 'General Shift (09:00 - 17:00)',
        badgeId: 'BDG-104',
        badgeIssueDate: '2026-08-01',
        badgeExpiryDate: '2026-11-01',
        emergencyContact: '+91 96543 21098',
        status: 'Active',
        cumulativeDose: 4.2,
        riskLevel: 'Safe',
        isBadgeExpired: false,
        lastScanTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Worker(
        workerId: 'W-105',
        name: 'Sunil Verma',
        department: 'Drilling & Extraction',
        workZone: 'Zone E - Wellhead Platform',
        shift: 'Shift 3 (22:00 - 06:00)',
        badgeId: 'BDG-105',
        badgeIssueDate: '2026-08-01',
        badgeExpiryDate: '2026-11-01',
        emergencyContact: '+91 95432 10987',
        status: 'Active',
        cumulativeDose: 0.0,
        riskLevel: 'Safe',
        isBadgeExpired: false,
        lastScanTime: null,
      ),
    ]);

    _readings.addAll([
      Reading(
        id: '1',
        workerId: 'W-101',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        dose: 1.34,
        intensity: 0.0158,
        riskLevel: 'Safe',
        isExpired: false,
        expiryStatusMessage: 'Active & Verified',
        estimatedH2sPpm: 1.34,
        exposureTime: 1.0,
        temperature: 25.0,
        humidity: 50.0,
        badgeMode: 'FULL_DOSEBAND_BADGE',
        dataSource: 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
        confidencePct: 91,
        actionGuidance: 'Normal operational zone. Below 8-hour permissible exposure limit.',
      ),
      Reading(
        id: '2',
        workerId: 'W-102',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        dose: 14.2,
        intensity: 0.2201,
        riskLevel: 'Caution',
        isExpired: false,
        expiryStatusMessage: 'Active & Verified',
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
        id: '3',
        workerId: 'W-103',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        dose: 58.4,
        intensity: 0.6500,
        riskLevel: 'Unsafe',
        isExpired: false,
        expiryStatusMessage: 'Active & Verified',
        estimatedH2sPpm: 58.4,
        exposureTime: 1.0,
        temperature: 28.0,
        humidity: 60.0,
        badgeMode: 'FULL_DOSEBAND_BADGE',
        dataSource: 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
        confidencePct: 90,
        actionGuidance: '🚨 STEL / Critical Exposure Exceeded! Evacuate area immediately.',
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

  Worker? getWorkerByBadgeId(String badgeId) {
    try {
      return _workers.firstWhere((w) => w.badgeId.toUpperCase() == badgeId.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  List<Reading> getReadingsForWorker(String workerId) {
    return _readings.where((r) => r.workerId.toUpperCase() == workerId.toUpperCase()).toList();
  }

  /// Verifies a worker QR badge via backend API if available, with intelligent local database resolution
  Future<Map<String, dynamic>> verifyBadge({
    Uint8List? imageBytes,
    String? rawPayload,
    String? fileName,
  }) async {
    // 1. Try server verification first if connected
    try {
      final res = await _apiService.verifyBadgeQr(
        imageBytes: imageBytes,
        rawPayload: rawPayload,
      );
      if (res['valid'] == true && res['worker'] != null) {
        return res;
      }
    } catch (_) {
      // Backend unreachable or offline -> fallback to robust local database verification
    }

    // 2. Parse raw payload JSON if available
    String? decodedWid;
    String? decodedBid;
    String? payloadStr = rawPayload;

    if (rawPayload != null && rawPayload.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(rawPayload.trim());
        if (parsed is Map && parsed['app'] == 'DoseBand') {
          decodedWid = parsed['worker_id']?.toString();
          decodedBid = parsed['badge_id']?.toString();
        } else {
          return {
            'valid': false,
            'status': 'UNRECOGNIZED',
            'message': 'Unrecognized QR Code: Only official DoseBand worker badges generated by this platform are accepted.',
            'raw_payload': rawPayload,
          };
        }
      } catch (_) {
        return {
          'valid': false,
          'status': 'UNRECOGNIZED',
          'message': 'Unrecognized QR Code: Only official DoseBand worker badges generated by this platform are accepted.',
          'raw_payload': rawPayload,
        };
      }
    }

    // 3. If file name contains worker or badge identifier (e.g. doseband_badge_BDG-102.png or W-102)
    if (decodedWid == null && fileName != null) {
      final upper = fileName.toUpperCase();
      for (final w in _workers) {
        if (upper.contains(w.workerId.toUpperCase()) || upper.contains(w.effectiveBadgeId.toUpperCase())) {
          decodedWid = w.workerId;
          decodedBid = w.effectiveBadgeId;
          payloadStr = '{"app":"DoseBand","worker_id":"${w.workerId}","badge_id":"${w.effectiveBadgeId}","version":"1.0"}';
          break;
        }
      }
    }

    // 4. Validate against worker repository
    if (decodedWid != null || decodedBid != null) {
      Worker? worker = decodedWid != null ? getWorkerById(decodedWid) : null;
      worker ??= decodedBid != null ? getWorkerByBadgeId(decodedBid) : null;

      if (worker != null) {
        if (worker.isBadgeExpired) {
          return {
            'valid': false,
            'status': 'EXPIRED',
            'message': 'Dosimeter Badge ${worker.effectiveBadgeId} expired on ${worker.badgeExpiryDate}. Immediate replacement required!',
            'worker': worker.toMap(),
            'raw_payload': payloadStr,
          };
        }
        if (worker.status != 'Active') {
          return {
            'valid': false,
            'status': 'INACTIVE',
            'message': 'Worker status is ${worker.status} (Not Active).',
            'worker': worker.toMap(),
            'raw_payload': payloadStr,
          };
        }
        return {
          'valid': true,
          'status': 'VALID',
          'message': 'Badge ${worker.effectiveBadgeId} is VALID & active for ${worker.name} (${worker.workerId}).',
          'worker': worker.toMap(),
          'raw_payload': payloadStr,
        };
      } else {
        return {
          'valid': false,
          'status': 'NOT_FOUND',
          'message': 'Worker/Badge identifier ($decodedWid / $decodedBid) is not registered in the database.',
          'raw_payload': payloadStr,
        };
      }
    }

    return {
      'valid': false,
      'status': 'UNRECOGNIZED',
      'message': 'No decodable DoseBand QR pattern detected in the image.',
      'raw_payload': payloadStr ?? 'N/A',
    };
  }

  Future<bool> addWorker(
    dynamic workerOrId, {
    String? name,
    String? department,
    String workZone = 'Zone A - General Area',
    String? shift,
    String badgeId = '',
    String badgeIssueDate = '',
    String badgeExpiryDate = '',
    String emergencyContact = '+91 98765 43210',
    String status = 'Active',
  }) async {
    final Worker? worker = workerOrId is Worker ? workerOrId : null;
    final String? workerId = workerOrId is String ? workerOrId : null;

    final effectiveWorkerId = worker?.workerId ?? workerId ?? '';
    final effectiveName = worker?.name ?? name ?? '';
    final effectiveDept = worker?.department ?? department ?? '';
    final effectiveZone = worker?.workZone ?? workZone;
    final effectiveShift = worker?.shift ?? shift ?? 'Shift 1 (06:00 - 14:00)';
    final effectiveBadge = (worker?.badgeId.isNotEmpty == true)
        ? worker!.badgeId
        : (badgeId.isNotEmpty ? badgeId : 'BDG-${effectiveWorkerId.replaceAll('W-', '')}');
    final effectiveIssue = (worker?.badgeIssueDate.isNotEmpty == true)
        ? worker!.badgeIssueDate
        : (badgeIssueDate.isNotEmpty ? badgeIssueDate : DateTime.now().toIso8601String().substring(0, 10));
    final effectiveExpiry = (worker?.badgeExpiryDate.isNotEmpty == true)
        ? worker!.badgeExpiryDate
        : (badgeExpiryDate.isNotEmpty ? badgeExpiryDate : DateTime.now().add(const Duration(days: 90)).toIso8601String().substring(0, 10));
    final effectiveContact = (worker?.emergencyContact.isNotEmpty == true) ? worker!.emergencyContact : emergencyContact;
    final effectiveStatus = (worker?.status.isNotEmpty == true) ? worker!.status : status;

    final workerMap = {
      'worker_id': effectiveWorkerId,
      'name': effectiveName,
      'department': effectiveDept,
      'work_zone': effectiveZone,
      'shift': effectiveShift,
      'badge_id': effectiveBadge,
      'badge_issue_date': effectiveIssue,
      'badge_expiry_date': effectiveExpiry,
      'emergency_contact': effectiveContact,
      'status': effectiveStatus,
    };

    // Attempt backend creation
    try {
      await _apiService.createWorker(workerMap);
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkerService] addWorker backend note: $e');
    }

    final newWorker = worker ?? Worker.fromMap(workerMap);
    _workers.removeWhere((w) => w.workerId == effectiveWorkerId);
    _workers.add(newWorker);
    notifyListeners();
    return true;
  }

  Future<bool> updateWorker(
    dynamic workerOrId, {
    String? name,
    String? department,
    String? workZone,
    String? shift,
    String? badgeId,
    String? badgeIssueDate,
    String? badgeExpiryDate,
    String? status,
  }) async {
    final Worker? worker = workerOrId is Worker ? workerOrId : null;
    final String workerId = worker?.workerId ?? (workerOrId is String ? workerOrId : '');

    final effectiveName = worker?.name ?? name ?? '';
    final effectiveDept = worker?.department ?? department ?? '';
    final effectiveZone = worker?.workZone ?? workZone ?? '';
    final effectiveShift = worker?.shift ?? shift ?? '';
    final effectiveBadge = worker?.badgeId ?? badgeId ?? '';
    final effectiveIssue = worker?.badgeIssueDate ?? badgeIssueDate ?? '';
    final effectiveExpiry = worker?.badgeExpiryDate ?? badgeExpiryDate ?? '';
    final effectiveStatus = worker?.status ?? status ?? 'Active';

    final workerMap = {
      'name': effectiveName,
      'department': effectiveDept,
      'work_zone': effectiveZone,
      'shift': effectiveShift,
      'badge_id': effectiveBadge,
      'badge_issue_date': effectiveIssue,
      'badge_expiry_date': effectiveExpiry,
      'status': effectiveStatus,
    };

    try {
      await _apiService.updateWorker(workerId, workerMap);
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkerService] updateWorker backend note: $e');
    }

    final index = _workers.indexWhere((w) => w.workerId == workerId);
    if (index != -1) {
      _workers[index] = _workers[index].copyWith(
        name: effectiveName.isNotEmpty ? effectiveName : _workers[index].name,
        department: effectiveDept.isNotEmpty ? effectiveDept : _workers[index].department,
        workZone: effectiveZone.isNotEmpty ? effectiveZone : _workers[index].workZone,
        shift: effectiveShift.isNotEmpty ? effectiveShift : _workers[index].shift,
        badgeId: effectiveBadge.isNotEmpty ? effectiveBadge : _workers[index].badgeId,
        badgeIssueDate: effectiveIssue.isNotEmpty ? effectiveIssue : _workers[index].badgeIssueDate,
        badgeExpiryDate: effectiveExpiry.isNotEmpty ? effectiveExpiry : _workers[index].badgeExpiryDate,
        status: effectiveStatus,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteWorker(String workerId) async {
    try {
      await _apiService.deleteWorker(workerId);
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkerService] deleteWorker backend note: $e');
    }

    _workers.removeWhere((w) => w.workerId == workerId);
    _readings.removeWhere((r) => r.workerId == workerId);
    notifyListeners();
    return true;
  }

  Future<void> addReading({
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
  }) async {
    final readingData = {
      'worker_id': workerId,
      'intensity': intensity,
      'dose': dose,
      'risk_level': riskLevel,
      'is_expired': isExpired,
      'expiry_status_message': expiryStatusMessage,
      'temperature': temperature,
      'humidity': humidity,
      'raw_intensity': intensity,
      'corrected_intensity': intensity,
      'compensation_factor': 1.0,
      'exposure_time': exposureTime,
      'estimated_h2s_ppm': estimatedH2sPpm > 0 ? estimatedH2sPpm : dose,
      'data_source': dataSource,
    };

    // Attempt backend persistence to SQLite
    try {
      await _apiService.saveReading(readingData);
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkerService] addReading backend note: $e');
    }

    final newReading = Reading(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workerId: workerId,
      timestamp: DateTime.now(),
      dose: dose,
      intensity: intensity,
      riskLevel: riskLevel,
      isExpired: isExpired,
      expiryStatusMessage: expiryStatusMessage,
      estimatedH2sPpm: estimatedH2sPpm > 0 ? estimatedH2sPpm : dose,
      exposureTime: exposureTime,
      temperature: temperature,
      humidity: humidity,
      badgeMode: badgeMode,
      dataSource: dataSource,
      confidencePct: confidencePct,
      actionGuidance: actionGuidance,
    );

    _readings.insert(0, newReading);

    // Update worker's local cumulative dose
    final workerIndex = _workers.indexWhere((w) => w.workerId == workerId);
    if (workerIndex != -1) {
      final currentWorker = _workers[workerIndex];
      final newCumDose = currentWorker.cumulativeDose + dose;
      String newRisk = 'Safe';
      if (newCumDose >= 50.0) {
        newRisk = 'Unsafe';
      } else if (newCumDose >= 10.0) {
        newRisk = 'Caution';
      }

      _workers[workerIndex] = currentWorker.copyWith(
        cumulativeDose: newCumDose,
        riskLevel: newRisk,
        lastScanTime: DateTime.now(),
      );
    }

    notifyListeners();
  }
}
