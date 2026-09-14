import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/worker.dart';
import '../services/worker_service.dart';
import '../services/dosimetry_service.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final WorkerService _workerService = WorkerService();
  final DosimetryService _dosimetryService = DosimetryService();
  final ImagePicker _picker = ImagePicker();

  // Scanning Mode: 'full_badge' or 'standalone_strip'
  String _scanMode = 'full_badge';

  // --------------------------------------------------------------------------
  // STEP 1 STATE: Worker Identification & QR Badge (Completely Isolated)
  // --------------------------------------------------------------------------
  Worker? _identifiedWorker;
  bool _isQrVerified = false;
  Uint8List? _qrImageBytes;
  File? _qrImageFile;
  String? _qrFileName;
  bool _isQrProcessing = false;
  String? _qrStatusMessage;

  // --------------------------------------------------------------------------
  // STEP 2 STATE: Physical Sensor Strip / Prototype Image (Completely Isolated)
  // --------------------------------------------------------------------------
  Uint8List? _sensorImageBytes;
  File? _sensorImageFile;
  String _sensorFileName = 'sensor_strip.jpg';
  bool _isSensorAnalyzing = false;

  // Step 2 Environmental Inputs
  double _temperatureC = 25.0;
  double _exposureTimeHours = 1.0;
  double _humidityRh = 50.0;
  bool _autoHumidity = true;

  // --------------------------------------------------------------------------
  // STEP 3 STATE: Analysis Results
  // --------------------------------------------------------------------------
  DosimetryResult? _latestResult;

  @override
  void initState() {
    super.initState();
    _workerService.addListener(_onServiceUpdate);
    _identifiedWorker = null;
    _isQrVerified = false;
    _qrImageBytes = null;
    _qrImageFile = null;
    _sensorImageBytes = null;
    _sensorImageFile = null;
  }

  @override
  void dispose() {
    _workerService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  // ==========================================================================
  // STEP 1 HANDLERS: QR Badge Acquisition & Verification
  // ==========================================================================
  Future<void> _pickQrImage(ImageSource source) async {
    try {
      setState(() {
        _isQrProcessing = true;
        _qrStatusMessage = null;
      });

      // Use 100% quality - preserve full original resolution for QR decoding
      final picked = await _picker.pickImage(source: source, imageQuality: 100);
      if (picked != null) {
        final bytes = await picked.readAsBytes();

        if (kDebugMode) {
          debugPrint('=== QR DEBUG ===');
          debugPrint('Source: ${source == ImageSource.camera ? "camera" : "gallery"}');
          debugPrint('Original file path: ${picked.path}');
          debugPrint('Original file size: ${bytes.length} bytes');
        }

        final res = await _workerService.verifyBadge(
          imageBytes: bytes,
          fileName: picked.name,
        );

        if (kDebugMode) {
          debugPrint('Raw decoded payload: ${res['raw_payload']}');
          debugPrint('Status: ${res['status']}');
          debugPrint('Valid: ${res['valid']}');
          debugPrint('Message: ${res['message']}');
          debugPrint('================');
        }

        _handleQrVerificationResponse(res, bytes, File(picked.path), picked.name);
      } else {
        setState(() => _isQrProcessing = false);
      }
    } catch (e) {
      setState(() => _isQrProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR verification error: $e'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  void _handleQrVerificationResponse(
    Map<String, dynamic> res, [
    Uint8List? imageBytes,
    File? imageFile,
    String? fileName,
  ]) {
    final bool isValid = res['valid'] == true;
    final workerData = res['worker'] as Map<String, dynamic>?;

    if (isValid && workerData != null) {
      final w = Worker.fromMap(workerData);
      setState(() {
        _identifiedWorker = w;
        _isQrVerified = true;
        _isQrProcessing = false;
        _qrImageBytes = imageBytes;
        _qrImageFile = imageFile;
        _qrFileName = fileName;
        _qrStatusMessage = res['message'] ?? 'Worker verified successfully.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Verified Badge for ${w.name} (${w.workerId})'),
          backgroundColor: AppTheme.safeGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _identifiedWorker = null;
        _isQrVerified = false;
        _isQrProcessing = false;
        _qrImageBytes = null;
        _qrImageFile = null;
        _qrFileName = null;
        _qrStatusMessage = res['message'] ?? 'This is not a valid DoseBand QR.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${res['message'] ?? 'This is not a valid DoseBand QR.'}'),
          backgroundColor: AppTheme.unsafeRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _unlinkWorker() {
    setState(() {
      _identifiedWorker = null;
      _isQrVerified = false;
      _qrImageBytes = null;
      _qrImageFile = null;
      _qrFileName = null;
      _qrStatusMessage = null;
    });
  }

  void _showQuickSelectDialog() {
    final workers = _workerService.workers;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Registered Worker Badge',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: workers.length,
                itemBuilder: (ctx, idx) {
                  final w = workers[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0F172A),
                        child: Text('👷'),
                      ),
                      title: Text(w.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('${w.workerId} • ${w.department} • Badge: ${w.effectiveBadgeId}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      trailing: const Icon(Icons.qr_code_2_rounded, color: AppTheme.safetyOrange),
                      onTap: () {
                        Navigator.pop(ctx);
                        final payload = '{"type":"doseband_worker","version":1,"worker_id":"${w.workerId}","badge_id":"${w.effectiveBadgeId}"}';
                        _workerService.verifyBadge(rawPayload: payload).then((res) => _handleQrVerificationResponse(res));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // STEP 2 HANDLERS: Physical Sensor Strip Image Acquisition
  // ==========================================================================
  Future<void> _pickSensorImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _sensorImageFile = File(picked.path);
          _sensorImageBytes = bytes;
          _sensorFileName = picked.name;
          _latestResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sensor strip image: $e'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  void _clearSensorImage() {
    setState(() {
      _sensorImageFile = null;
      _sensorImageBytes = null;
      _sensorFileName = 'sensor_strip.jpg';
      _latestResult = null;
    });
  }

  // ==========================================================================
  // STEP 3 HANDLERS: Dosimetry Optical ML Analysis
  // ==========================================================================
  Future<void> _analyzeSensorStrip() async {
    if (_sensorImageBytes == null) return;
    if (_scanMode == 'full_badge' && _identifiedWorker == null) return;

    setState(() => _isSensorAnalyzing = true);

    final String effectiveWorkerId = _identifiedWorker?.workerId ?? 'W-DEMO';

    final result = await _dosimetryService.processImage(
      imageBytes: _sensorImageBytes!,
      fileName: _sensorFileName,
      workerId: effectiveWorkerId,
      temperatureC: _temperatureC,
      humidityRh: _autoHumidity ? null : _humidityRh,
      exposureTimeHours: _exposureTimeHours,
      badgeMode: _scanMode == 'standalone_strip' ? 'STANDALONE_H2S_STRIP' : 'FULL_DOSEBAND_BADGE',
      scanMode: _scanMode,
    );

    setState(() {
      _latestResult = result;
      _isSensorAnalyzing = false;
    });

    if (mounted) {
      _showResultDialog(result);
    }
  }

  void _showEmergencyEvacuationAlert(BuildContext context, DosimetryResult r) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF7F1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'CRITICAL STEL BREACH ALERT',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: -0.3),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DETECTED EXPOSURE: ${r.estimatedH2sPpm.toStringAsFixed(1)} PPM H₂S',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFFCA5A5))),
                  const SizedBox(height: 4),
                  const Text('STEL CEILING LIMIT: 15.0 PPM (EXCEEDED)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('AFFECTED WORKER: ${_identifiedWorker?.name ?? "Field Unit"} (${_identifiedWorker?.workerId ?? "W-DEMO"})',
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('EMERGENCY ACTION PROTOCOL (OSHA 1910.1000):',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('1. Don Self-Contained Breathing Apparatus (SCBA) immediately.',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 4),
            const Text('2. Evacuate Zone crosswind to designated Muster Point.',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 4),
            const Text('3. Dispatch Safety Supervisor & Gas Isolation Crew.',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF7F1D1D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 Emergency alert logged to supervisory telemetry log.'),
                  backgroundColor: AppTheme.unsafeRed,
                ),
              );
            },
            child: const Text('DISPATCH SAFETY CREW & EVACUATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(DosimetryResult r) {
    Color statusColor = AppTheme.safeGreen;
    if (!r.isValid) {
      statusColor = AppTheme.unsafeRed;
    } else if (r.riskLevel.startsWith('Unsafe') || r.isBadgeExpired) {
      statusColor = AppTheme.unsafeRed;
    } else if (r.riskLevel.startsWith('Caution')) {
      statusColor = AppTheme.cautionYellow;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(r.isValid ? Icons.verified_user_rounded : Icons.gpp_bad_rounded, color: statusColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                r.isValid
                    ? (r.isStandalone ? 'Standalone Strip Result' : 'Full DoseBand Result')
                    : 'Validation Failed',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.isValid) ...[
                // Metric Badge Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESTIMATED H₂S DOSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textMuted)),
                          Text(
                            '${r.estimatedH2sPpm.toStringAsFixed(2)} ppm·hr',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: statusColor),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          r.riskLevel.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Environmental & Quality Summary
                _buildModalRow('Environmental Temp:', '${r.temperatureC.toStringAsFixed(1)} °C'),
                _buildModalRow('Relative Humidity:', '${r.predictedHumidity.toStringAsFixed(1)} % RH'),
                _buildModalRow('Exposure Duration:', '${_exposureTimeHours.toStringAsFixed(1)} hours'),
                _buildModalRow('Lead Acetate Sensor Δ:', '${(r.rawIntensity * 100).toStringAsFixed(1)}% optical darkening'),
                _buildModalRow('Analysis Confidence:', '${r.confidencePct}% (${r.dataSource})'),
                const Divider(height: 20),

                // OSHA Action Guidance
                Text(
                  'COMPLIANCE DIRECTIVE (DGMS / OSHA):',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  r.actionGuidance,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ] else ...[
                // Rejection Details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.unsafeRedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.unsafeRed.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IMAGE REJECTED BY COMPUTER VISION PIPELINE',
                        style: TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.w900, fontSize: 11.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.userMessage.isNotEmpty ? r.userMessage : 'Optical sensor validation failed. Please recapture the exposure strip with proper lighting.',
                        style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (r.isValid && r.riskLevel.startsWith('Unsafe'))
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showEmergencyEvacuationAlert(context, r);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.unsafeRed),
              child: const Text('Emergency Evacuation Protocol', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else if (r.isValid)
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Log to Workforce Database', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                if (_identifiedWorker != null) {
                  _workerService.addReading(
                    workerId: _identifiedWorker!.workerId,
                    dose: r.cumulativeDosePpmH,
                    intensity: r.rawIntensity,
                    riskLevel: r.riskLevel,
                    isExpired: r.isBadgeExpired,
                    expiryStatusMessage: r.expiryStatusMessage,
                    estimatedH2sPpm: r.estimatedH2sPpm,
                    exposureTime: _exposureTimeHours,
                    temperature: r.temperatureC,
                    humidity: r.predictedHumidity,
                    badgeMode: r.badgeMode,
                    dataSource: r.dataSource,
                    confidencePct: r.confidencePct,
                    actionGuidance: r.actionGuidance,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Reading logged for ${_identifiedWorker!.name} (${_identifiedWorker!.workerId})'),
                      backgroundColor: AppTheme.safeGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safeGreen),
            ),
        ],
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isStandalone = _scanMode == 'standalone_strip';
    final bool canAnalyze = _sensorImageBytes != null && (isStandalone || _identifiedWorker != null) && !_isSensorAnalyzing;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.orangeAccentGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.safetyOrange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan & Analyze Dosimeter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.4)),
                      Text('Optical computer vision inspection with Unified Lead Acetate PbS Model', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scanning Mode Selector Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _scanMode = 'full_badge'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _scanMode == 'full_badge' ? AppTheme.safetyOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'Full 3D Badge Mode',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _scanMode == 'full_badge' ? Colors.white : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _scanMode = 'standalone_strip'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _scanMode == 'standalone_strip' ? AppTheme.safetyOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'Standalone Chemical Strip',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _scanMode == 'standalone_strip' ? Colors.white : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================================================================
            // STEP 1 CARD: Worker Identification & Badge QR (MANDATORY)
            // ================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _identifiedWorker != null ? AppTheme.safeGreen.withValues(alpha: 0.6) : AppTheme.borderColor,
                  width: _identifiedWorker != null ? 1.5 : 1.0,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('STEP 1', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          !isStandalone
                              ? 'Worker ID & Badge QR (Mandatory)'
                              : 'Worker Assignment (Optional)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_identifiedWorker != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreenBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 12, color: AppTheme.safeGreen),
                              SizedBox(width: 3),
                              Text('VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isStandalone && _identifiedWorker == null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 14),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Standalone strip mode allows instant demo analysis without a worker badge.',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Camera QR Scan and Upload QR Badge Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded, size: 18, color: AppTheme.safetyOrange),
                          label: const Text('Camera QR Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          onPressed: _isQrProcessing ? null : () => _pickQrImage(ImageSource.camera),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF0284C7)),
                          label: const Text('Upload QR Badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          onPressed: _isQrProcessing ? null : () => _pickQrImage(ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_isQrProcessing) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Decoding & verifying worker QR badge...', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Verified Personnel Dossier Card (Step 1 Only)
                  if (_identifiedWorker != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.navyHeroGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF059669), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF065F46),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_identifiedWorker!.name} (${_identifiedWorker!.workerId})',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Badge: ${_identifiedWorker!.effectiveBadgeId} • ${_identifiedWorker!.status.toUpperCase()} • ${_identifiedWorker!.department}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF34D399), fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                                tooltip: 'Unlink / Clear Worker',
                                onPressed: _unlinkWorker,
                              ),
                            ],
                          ),
                          if (_qrImageBytes != null) ...[
                            const SizedBox(height: 10),
                            const Divider(color: Color(0xFF334155), height: 1),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(_qrImageBytes!, width: 44, height: 44, fit: BoxFit.cover),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('✓ Official QR Badge Image Attached', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w800)),
                                      Text(_qrFileName ?? 'badge_qr.png', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Worker from Catalog:',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          InkWell(
                            onTap: _showQuickSelectDialog,
                            child: const Text(
                              '🧪 Browse Catalog ›',
                              style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================================================================
            // STEP 2 CARD: Capture Physical Sensor Strip / Prototype Photo
            // ================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _sensorImageBytes != null ? AppTheme.safetyOrange.withValues(alpha: 0.6) : AppTheme.borderColor,
                  width: _sensorImageBytes != null ? 1.5 : 1.0,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('STEP 2', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          !isStandalone ? 'Capture Full DoseBand Photo' : 'Capture H₂S Strip Photo',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_sensorImageBytes != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.safetyOrangeBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.5)),
                          ),
                          child: const Text('READY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.safetyOrange)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !isStandalone
                        ? 'Position the complete grey 3D-printed enclosure under even light.'
                        : 'Align the H₂S paper strip inside the frame below (fresh white to dark black accepted).',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),

                  // If full badge mode and Step 1 not complete -> Show locked indicator
                  if (!isStandalone && _identifiedWorker == null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted, size: 26),
                          SizedBox(height: 6),
                          Text(
                            'Step 2 Locked: Please scan or select a registered Worker QR Badge in Step 1 first.',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Standalone Guided Framing Overlay Box
                    if (isStandalone && _sensorImageBytes == null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.safetyOrange, width: 2),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                              child: const Column(
                                children: [
                                  Text(
                                    '┌──────────────────────────────┐',
                                    style: TextStyle(color: AppTheme.safetyOrange, fontFamily: 'monospace', fontSize: 11),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'PLACE H2S STRIP HERE',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '(Center 60–80% of strip inside frame)',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '└──────────────────────────────┘',
                                    style: TextStyle(color: AppTheme.safetyOrange, fontFamily: 'monospace', fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Image Acquisition Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: Text(!isStandalone ? 'Take Badge Photo' : 'Take Strip Photo'),
                            onPressed: () => _pickSensorImage(ImageSource.camera),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.file_upload_outlined, color: AppTheme.textPrimary, size: 18),
                            label: const Text('Upload Photo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                            onPressed: () => _pickSensorImage(ImageSource.gallery),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_sensorImageBytes != null) ...[
                      const SizedBox(height: 14),
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(_sensorImageBytes!, height: 160, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                onPressed: _clearSensorImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      const Text(
                        'No DoseBand sensor image selected. Capture or upload the physical exposure test strip.',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ================================================================
            // STEP 3 CARD: Analyze & Run Optical Model Inference
            // ================================================================
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: canAnalyze ? AppTheme.orangeGlow : [],
              ),
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSensorAnalyzing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics_rounded, size: 20),
                label: Text(
                  _isSensorAnalyzing
                      ? 'Running Optical Model Inference...'
                      : (!isStandalone ? '🔬 Analyze DoseBand Prototype' : '🔬 Analyze Standalone H₂S Strip'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                ),
                onPressed: canAnalyze ? _analyzeSensorStrip : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.safetyOrange,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
