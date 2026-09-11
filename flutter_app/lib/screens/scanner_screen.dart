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
    if (_workerService.workers.isNotEmpty) {
      _identifiedWorker = _workerService.workers.first;
    }
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
        final res = await _apiService.verifyBadgeQr(imageBytes: bytes);
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
        SnackBar(content: Text('✅ Verified Badge for ${w.name} (${w.workerId})'), backgroundColor: AppTheme.safeGreen),
      );
    } else {
      setState(() {
        _isWorkerIdentified = false;
        _isQrVerified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ QR Rejected: ${res['message'] ?? 'Invalid DoseBand Badge'}'),
          backgroundColor: AppTheme.unsafeRed,
        ),
      );
    }
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
                Text('Optical Staining Score: ${(r.rawIntensity * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text('Temperature: ${r.temperatureC}°C | Humidity: ${r.predictedHumidity.toStringAsFixed(0)}% RH', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Text(
                  '💡 Guidance: ${r.actionGuidance}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
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
                    color: AppTheme.safetyOrangeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.safetyOrange, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan Sensor Strip', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                      Text('Identify worker via QR badge & analyze colorimetric chemical dosimeter', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 1: Worker Identification & Badge Verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),

                  // Only Camera QR Scan and Upload QR File options
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded, size: 18, color: AppTheme.safetyOrange),
                          label: const Text('Camera QR Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          onPressed: () => _verifyWorkerQr(ImageSource.camera),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF0284C7)),
                          label: const Text('Upload QR File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          onPressed: () => _verifyWorkerQr(ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF059669), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF065F46),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_identifiedWorker!.name} (${_identifiedWorker!.workerId})',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Badge: ${_identifiedWorker!.effectiveBadgeId} • ${_identifiedWorker!.status.toUpperCase()}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF34D399), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Row(
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 2: Capture Dosimeter Strip Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),

                  // Image Acquisition Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Capture Strip'),
                          onPressed: () => _pickImage(ImageSource.camera),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.file_upload_outlined, color: AppTheme.textPrimary),
                          label: const Text('Upload Photo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                          onPressed: () => _pickImage(ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_imageBytes != null) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_imageBytes!, height: 160, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 3: Analyze & Run ML Model
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isAnalyzing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics_rounded, size: 20),
                label: Text(
                  _isAnalyzing ? 'Running ML Inference...' : '🔬 Analyze Dosimeter Strip',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                onPressed: (_imageBytes != null && _identifiedWorker != null && !_isAnalyzing) ? _analyzeStrip : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.safetyOrange,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
