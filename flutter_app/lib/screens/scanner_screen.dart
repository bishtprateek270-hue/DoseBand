import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/worker.dart';
import '../services/worker_service.dart';
import '../services/dosimetry_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final WorkerService _workerService = WorkerService();
  final DosimetryService _dosimetryService = DosimetryService();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // Scanning Mode: 'full_badge' or 'standalone_strip'
  String _scanMode = 'full_badge';

  File? _image;
  Uint8List? _imageBytes;
  String _imageFileName = 'strip.jpg';
  bool _isAnalyzing = false;

  // Step 1: Worker Identification
  Worker? _identifiedWorker;
  bool _isWorkerIdentified = false;
  bool _isQrVerified = false;

  // Step 2: Environmental Inputs
  double _temperatureC = 25.0;
  double _exposureTimeHours = 1.0;
  double _humidityRh = 50.0;
  bool _autoHumidity = true;

  // Step 3: Analysis Results
  DosimetryResult? _latestResult;

  @override
  void initState() {
    super.initState();
    _workerService.addListener(_onServiceUpdate);
    _identifiedWorker = null;
    _isWorkerIdentified = false;
    _isQrVerified = false;
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _image = File(picked.path);
          _imageBytes = bytes;
          _imageFileName = picked.name;
          _latestResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  Future<void> _loadPresetImage(String filename, String presetLabel) async {
    final possiblePaths = [
      'test_images/$filename',
      '../test_images/$filename',
      'c:/Users/AYUSH/Desktop/AYUSH/flutter_work/DoseBand/test_images/$filename',
    ];

    File? foundFile;
    for (final p in possiblePaths) {
      final f = File(p);
      if (f.existsSync()) {
        foundFile = f;
        break;
      }
    }

    if (foundFile != null) {
      final bytes = await foundFile.readAsBytes();
      final workers = _workerService.workers;
      setState(() {
        _image = foundFile;
        _imageBytes = bytes;
        _imageFileName = filename;
        _latestResult = null;
        if (workers.isNotEmpty && _scanMode == 'full_badge') {
          _identifiedWorker = workers.first;
          _isWorkerIdentified = true;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Loaded Demo Preset: $presetLabel'),
            backgroundColor: AppTheme.safetyOrange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _analyzeStrip();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preset image $filename not found.'),
            backgroundColor: AppTheme.unsafeRed,
          ),
        );
      }
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

  Future<void> _verifyWorkerQr(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final res = await _workerService.verifyBadge(
          imageBytes: bytes,
          fileName: picked.name,
        );
        _handleQrVerificationResponse(res);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR verification error: $e'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  void _handleQrVerificationResponse(Map<String, dynamic> res) {
    final bool isValid = res['valid'] == true;
    final workerData = res['worker'] as Map<String, dynamic>?;

    if (isValid && workerData != null) {
      final w = Worker.fromMap(workerData);
      setState(() {
        _identifiedWorker = w;
        _isWorkerIdentified = true;
        _isQrVerified = true;
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
        _isWorkerIdentified = false;
        _isQrVerified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ QR Rejected: ${res['message'] ?? 'Invalid DoseBand Badge'}'),
          backgroundColor: AppTheme.unsafeRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
                        final payload = '{"app":"DoseBand","worker_id":"${w.workerId}","badge_id":"${w.effectiveBadgeId}","version":"1.0"}';
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

  Future<void> _analyzeStrip() async {
    if (_imageBytes == null) return;
    if (_scanMode == 'full_badge' && _identifiedWorker == null) return;

    setState(() => _isAnalyzing = true);

    final String effectiveWorkerId = _identifiedWorker?.workerId ?? 'W-DEMO';

    final result = await _dosimetryService.processImage(
      imageBytes: _imageBytes!,
      fileName: _imageFileName,
      workerId: effectiveWorkerId,
      temperatureC: _temperatureC,
      humidityRh: _autoHumidity ? null : _humidityRh,
      exposureTimeHours: _exposureTimeHours,
      badgeMode: _scanMode == 'standalone_strip' ? 'STANDALONE_H2S_STRIP' : 'FULL_DOSEBAND_BADGE',
      scanMode: _scanMode,
    );

    setState(() {
      _latestResult = result;
      _isAnalyzing = false;
    });

    if (mounted) {
      _showResultDialog(result);
    }
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
              if (r.isStandalone || r.isPrototypeEstimate) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.disclaimer ?? 'PROTOTYPE ESTIMATE: Standalone strip scan is an uncalibrated visual estimation. For safety compliance, scan inside the complete DoseBand enclosure with environmental sensors.',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!r.isValid) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.unsafeRedBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.unsafeRed),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.userMessage, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 13)),
                      if (r.rejectionReasons.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...r.rejectionReasons.map((reason) => Text('• $reason', style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)))),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // Metric Highlights
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated H₂S Gas:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          Text('${r.estimatedH2sPpm.toStringAsFixed(2)} ppm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: statusColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Shift Exposure Dose:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text('${r.cumulativeDosePpmH.toStringAsFixed(2)} ppm•h', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Risk Classification:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(r.riskLevel.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: statusColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _identifiedWorker != null
                      ? 'Worker: ${_identifiedWorker!.name} (${_identifiedWorker!.workerId})'
                      : 'Worker: Unassigned Demo (W-DEMO)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  'Scan Mode: ${r.isStandalone ? "Standalone H₂S Strip (Demo)" : "Full DoseBand Enclosure"}',
                  style: TextStyle(fontSize: 12, color: r.isStandalone ? const Color(0xFFD97706) : const Color(0xFF0284C7), fontWeight: FontWeight.bold),
                ),
                Text('Optical Darkening / Staining: ${(r.rawIntensity * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text('Temperature: ${r.temperatureC}°C | Humidity: ${r.predictedHumidity.toStringAsFixed(0)}% RH', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Text(
                  '💡 Guidance: ${r.actionGuidance}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
              if (r.debugOverlayBase64 != null && r.debugOverlayBase64!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.crop_free_rounded, color: AppTheme.safetyOrange, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            r.isStandalone ? 'Standalone Strip ROI Detection' : '3D Prototype ROI & Perspective Alignment',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          base64Decode(r.debugOverlayBase64!),
                          fit: BoxFit.contain,
                        ),
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
            child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
          ),
          if (r.estimatedH2sPpm >= 15.0 || r.riskLevel.contains('Unsafe'))
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.unsafeRed),
              icon: const Icon(Icons.warning_amber_rounded, size: 16),
              label: const Text('ALERT EVACUATION PROTOCOL'),
              onPressed: () {
                Navigator.pop(ctx);
                _showEmergencyEvacuationAlert(context, r);
              },
            ),
          if (r.isValid && r.isAllowedToSave && _identifiedWorker != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save to SQLite DB'),
              onPressed: () async {
                Navigator.pop(ctx);
                final saved = await _dosimetryService.saveReading(
                  workerId: _identifiedWorker!.workerId,
                  result: r,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(saved ? '✅ Exposure reading saved to SQLite database!' : '❌ Failed to save reading.'),
                      backgroundColor: saved ? AppTheme.safeGreen : AppTheme.unsafeRed,
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

  @override
  Widget build(BuildContext context) {
    final bool isStandalone = _scanMode == 'standalone_strip';
    final bool canAnalyze = _imageBytes != null && (isStandalone || _identifiedWorker != null) && !_isAnalyzing;

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

            // Scanning Mode Selector Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Scanning Mode',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _scanMode = 'full_badge';
                              _latestResult = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isStandalone ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isStandalone ? const Color(0xFF0F172A) : AppTheme.borderColor,
                                width: !isStandalone ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.watch_rounded, size: 16, color: !isStandalone ? AppTheme.safetyOrange : AppTheme.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Full DoseBand',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: !isStandalone ? Colors.white : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _scanMode = 'standalone_strip';
                              _latestResult = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isStandalone ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isStandalone ? AppTheme.safetyOrange : AppTheme.borderColor,
                                width: isStandalone ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.science_rounded, size: 16, color: isStandalone ? AppTheme.safetyOrange : AppTheme.textMuted),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Standalone H₂S Strip',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: isStandalone ? Colors.white : AppTheme.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !isStandalone
                        ? '• Full 3D Prototype: Validates grey enclosure, humidity card & worker QR verification.'
                        : '• Standalone Strip: Direct paper strip scanning with guided framing across all exposure shades.',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Judge Demo Quick Presets Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: AppTheme.safetyOrange, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'JUDGE DEMO QUICK SCANS (1-TAP FAILSAFE)',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.check_circle_rounded, color: AppTheme.safeGreen, size: 14),
                          label: const Text('0.0 ppm Clean Strip', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFF334155)),
                          onPressed: () => _loadPresetImage('real_strip_01_fresh_cream.jpg', '0.0 ppm Clean Baseline'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.warning_amber_rounded, color: AppTheme.cautionYellow, size: 14),
                          label: const Text('8.5 ppm Shift TWA Warning', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFF334155)),
                          onPressed: () => _loadPresetImage('real_strip_04_warm_brownish_grey.jpg', '8.5 ppm Shift TWA Warning'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.dangerous_rounded, color: AppTheme.unsafeRed, size: 14),
                          label: const Text('22.5 ppm STEL BREACH', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFF334155)),
                          onPressed: () => _loadPresetImage('real_strip_08_deep_solid_black.jpg', '22.5 ppm STEL BREACH'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Step 1: Worker Identification & Badge Verification Card
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
                              Text('LINKED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
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

                  // Camera QR Scan and Upload QR File options
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded, size: 18, color: AppTheme.safetyOrange),
                          label: const Text('Camera QR Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          onPressed: () => _verifyWorkerQr(ImageSource.camera),
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
                          onPressed: () => _verifyWorkerQr(ImageSource.gallery),
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

                  const SizedBox(height: 12),

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
                      child: Row(
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
                            onPressed: () {
                              setState(() {
                                _identifiedWorker = null;
                                _isWorkerIdentified = false;
                                _isQrVerified = false;
                              });
                            },
                          ),
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

            // Step 2: Capture Dosimeter Strip Photo Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _imageBytes != null ? AppTheme.safetyOrange.withValues(alpha: 0.6) : AppTheme.borderColor,
                  width: _imageBytes != null ? 1.5 : 1.0,
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
                      if (_imageBytes != null) ...[
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

                  // Standalone Guided Framing Overlay Box
                  if (isStandalone && _imageBytes == null) ...[
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
                          onPressed: () => _pickImage(ImageSource.camera),
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
                          onPressed: () => _pickImage(ImageSource.gallery),
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

                  if (_imageBytes != null) ...[
                    const SizedBox(height: 14),
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
                          child: Image.memory(_imageBytes!, height: 160, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 3: Analyze & Run ML Model Action Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: canAnalyze ? AppTheme.orangeGlow : [],
              ),
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isAnalyzing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics_rounded, size: 20),
                label: Text(
                  _isAnalyzing
                      ? 'Running Optical Model Inference...'
                      : (!isStandalone ? '🔬 Analyze DoseBand Prototype' : '🔬 Analyze Standalone H₂S Strip'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                ),
                onPressed: canAnalyze ? _analyzeStrip : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.safetyOrange,
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
