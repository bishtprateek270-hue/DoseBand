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

  File? _image;
  Uint8List? _imageBytes;
  String _imageFileName = 'strip.jpg';
  bool _isAnalyzing = false;

  // Step 1: Worker Identification
  String _idMethod = 'QR_AUTOMATED'; // 'QR_AUTOMATED' or 'MANUAL_DIRECTORY'
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
    // Start with no worker selected — worker is strictly determined by the scanned badge
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
    if (mounted) setState(() {});
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
    if (_imageBytes == null || _identifiedWorker == null) return;
    setState(() => _isAnalyzing = true);

    final result = await _dosimetryService.processImage(
      imageBytes: _imageBytes!,
      fileName: _imageFileName,
      workerId: _identifiedWorker!.workerId,
      temperatureC: _temperatureC,
      humidityRh: _autoHumidity ? null : _humidityRh,
      exposureTimeHours: _exposureTimeHours,
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
                r.isValid ? 'Dosimetry Analysis Result' : 'Validation Failed',
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
                Text('Worker: ${_identifiedWorker?.name} (${_identifiedWorker?.workerId})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text('Enclosure / Method: ${r.deviceType ?? "3D_PRINTED_PROTOTYPE"}', style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                Text('Optical Staining Score: ${(r.rawIntensity * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
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
                      const Row(
                        children: [
                          Icon(Icons.crop_free_rounded, color: AppTheme.safetyOrange, size: 14),
                          SizedBox(width: 6),
                          Text(
                            '3D Prototype ROI & Perspective Alignment',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 12),
              const Text(
                '⚠️ Prototype Notice: Ambient temperature and humidity compensation factors reflect an experimental kinetic prototype model.',
                style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
          ),
          if (r.isValid && r.isAllowedToSave)
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
                      Text('Optical computer vision inspection with Ordinary Least Squares (OLS) calibration', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          const Text(
                            'Worker Identification & Badge QR',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      if (_identifiedWorker != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreenBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check, size: 12, color: AppTheme.safeGreen),
                              SizedBox(width: 3),
                              Text('VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

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
                            tooltip: 'Unlink / Scan Another Badge',
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textMuted, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Please scan or upload an official DoseBand worker QR badge to identify the worker.',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: _showQuickSelectDialog,
                              child: const Text(
                                '🧪 Quick Test: Select Worker from Catalog ›',
                                style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w900),
                              ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          const Text('Capture Dosimeter Strip Photo', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        ],
                      ),
                      if (_imageBytes != null)
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
                  ),
                  const SizedBox(height: 14),

                  // Image Acquisition Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Take Strip Photo'),
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
                boxShadow: (_imageBytes != null && _identifiedWorker != null && !_isAnalyzing) ? AppTheme.orangeGlow : [],
              ),
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isAnalyzing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics_rounded, size: 20),
                label: Text(
                  _isAnalyzing ? 'Running Optical Model Inference...' : '🔬 Analyze Dosimeter Strip',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                ),
                onPressed: (_imageBytes != null && _identifiedWorker != null && !_isAnalyzing) ? _analyzeStrip : null,
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
