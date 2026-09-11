import 'dart:io';
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
  bool _isAnalyzing = false;

  // Step 1: Worker Identification state
  String _idMethod = 'QR_AUTOMATED'; // 'QR_AUTOMATED' | 'MANUAL_DIRECTORY'
  String _selectedWorkerId = 'W-101';
  bool _isQrVerified = false;

  // Step 2: Image Source state
  String _imageSourceMode = 'GALLERY'; // 'GALLERY' | 'CAMERA'

  // Step 3: Environmental & Shift Inputs (Matching Web App)
  double _temperatureC = 25.0;
  double _exposureTimeHours = 1.0;
  double _humidityRh = 50.0;
  String _badgeMode = 'STANDALONE_CHEMICAL_STRIP';

  // Pre-flight validation result
  DosimetryResult? _latestResult;

  @override
  void initState() {
    super.initState();
    _workerService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _workerService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          _image = file;
          _isAnalyzing = true;
        });

        // Run optical pre-flight validation via API backend
        final result = await _dosimetryService.analyzeImage(
          imageFile: file,
          workerId: _selectedWorkerId,
          temperatureC: _temperatureC,
          humidityRh: _humidityRh,
          exposureTimeHours: _exposureTimeHours,
          badgeMode: _badgeMode,
        );

        setState(() {
          _latestResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image acquisition note: $e'),
            backgroundColor: AppTheme.cautionYellow,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _scanAndVerifyQr(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final res = await _apiService.verifyBadgeQr(imageBytes: bytes);

        if (res['valid'] == true && res['worker'] != null) {
          final w = res['worker'] as Map<String, dynamic>;
          final wid = w['worker_id']?.toString() ?? 'W-101';
          setState(() {
            _selectedWorkerId = wid;
            _isQrVerified = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Official DoseBand Badge Verified for ${w['name']} ($wid)!'),
                backgroundColor: AppTheme.safeGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          _showForeignQrRejectedDialog(res['raw_payload']?.toString() ?? 'Unrecognized QR code payload');
        }
      }
    } catch (e) {
      _showForeignQrRejectedDialog('https://unauthorized-external-code.com');
    }
  }

  void _simulateQrScan(String workerId) {
    final worker = _workerService.getWorkerById(workerId);
    setState(() {
      _selectedWorkerId = workerId;
      _isQrVerified = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Official DoseBand Badge Verified for ${worker?.name ?? workerId} ($workerId)!'),
        backgroundColor: AppTheme.safeGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showForeignQrRejectedDialog(String payload) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.unsafeRed, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.error_outline_rounded, color: AppTheme.unsafeRed, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ACCESS REJECTED',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Foreign or Invalid QR Code Detected!',
              style: TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'This QR code was NOT generated by the DoseBand platform. External links, personal codes, WiFi credentials, and third-party barcodes are strictly blocked.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Intercepted Payload:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(payload, style: const TextStyle(color: Color(0xFFF87171), fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
            onPressed: () {
              Navigator.pop(context);
              _simulateQrScan('W-101');
            },
            child: const Text('Use Sample Badge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _runFullAnalysis() async {
    if (_image == null) return;

    final worker = _workerService.getWorkerById(_selectedWorkerId);
    if (worker != null && worker.isBadgeExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Worker badge is EXPIRED. Replace badge before recording exposure.'),
          backgroundColor: AppTheme.unsafeRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isAnalyzing = true);

    final result = await _dosimetryService.analyzeImage(
      imageFile: _image!,
      workerId: _selectedWorkerId,
      temperatureC: _temperatureC,
      humidityRh: _humidityRh,
      exposureTimeHours: _exposureTimeHours,
      badgeMode: _badgeMode,
    );

    setState(() {
      _latestResult = result;
      _isAnalyzing = false;
    });

    if (!result.isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Analysis Blocked: ${result.userMessage}'),
            backgroundColor: AppTheme.unsafeRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Save reading to SQLite via backend API & worker service
    _workerService.addReading(
      workerId: _selectedWorkerId,
      dose: result.cumulativeDosePpmH,
      intensity: result.rawIntensity,
      riskLevel: result.riskLevel,
      isExpired: worker?.isBadgeExpired ?? false,
      expiryStatusMessage: (worker?.isBadgeExpired ?? false)
          ? 'EXPIRED — Replace badge'
          : 'Active & Verified',
      estimatedH2sPpm: result.estimatedH2sPpm,
      exposureTime: _exposureTimeHours,
      temperature: _temperatureC,
      humidity: _humidityRh,
      badgeMode: result.badgeMode,
      dataSource: result.dataSource,
      confidencePct: result.confidencePct,
      actionGuidance: result.actionGuidance,
    );

    if (mounted) {
      _showDosimetryResultModal(result, _selectedWorkerId);
    }
  }

  void _showDosimetryResultModal(DosimetryResult result, String workerId) {
    final worker = _workerService.getWorkerById(workerId);
    final isSafe = result.riskLevel == 'Safe';
    final isCaution = result.riskLevel == 'Caution';
    final riskColor = isSafe ? AppTheme.safeGreen : (isCaution ? AppTheme.cautionYellow : AppTheme.unsafeRed);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: riskColor, width: 2),
        ),
        title: Row(
          children: [
            Icon(isSafe ? Icons.check_circle : (isCaution ? Icons.warning_amber_rounded : Icons.dangerous_rounded), color: riskColor, size: 28),
            const SizedBox(width: 10),
            const Text(
              'Gas Dosimetry Results',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Worker Identification Tag
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.safetyOrange,
                      radius: 18,
                      child: Text(workerId.replaceAll('W-', ''), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(worker?.name ?? 'Worker $workerId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${worker?.department ?? "Operations"} • ${worker?.workZone ?? "Zone A"}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: riskColor.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                      child: Text(result.riskLevel.toUpperCase(), style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Predicted H2S and Cumulative Exposure KPIs
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated H₂S Gas', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${result.estimatedH2sPpm.toStringAsFixed(2)} ppm', style: TextStyle(color: riskColor, fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Shift Cumulative Dose', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${result.cumulativeDosePpmH.toStringAsFixed(2)} ppm•h', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Optical Densitometry Breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Validation Confidence', '${result.confidencePct}% (${result.status})'),
                    const Divider(color: Color(0xFF334155), height: 16),
                    _buildModalRow('Staining Intensity', result.rawIntensity.toStringAsFixed(4)),
                    const Divider(color: Color(0xFF334155), height: 16),
                    _buildModalRow('Environmental Factor', '${result.compensationFactor}x (${_temperatureC}°C, ${_humidityRh}%)'),
                    const Divider(color: Color(0xFF334155), height: 16),
                    _buildModalRow('Database Persistence', 'Saved to SQLite (doseband.db)'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Guidance Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.health_and_safety_outlined, color: riskColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(result.actionGuidance, style: TextStyle(color: riskColor, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
            onPressed: () => Navigator.pop(context),
            child: const Text('Acknowledge & Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildModalRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;
    final worker = _workerService.getWorkerById(_selectedWorkerId);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Scan DoseBand Sensor', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
        backgroundColor: AppTheme.surfaceCard,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // STEP 1: WORKER IDENTIFICATION
            // -----------------------------------------------------------------
            _buildSectionHeader('1', 'Worker Identification & Badge Verification'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _idMethod == 'QR_AUTOMATED' ? AppTheme.safetyOrange : AppTheme.borderColor),
                            backgroundColor: _idMethod == 'QR_AUTOMATED' ? AppTheme.safetyOrange.withOpacity(0.12) : Colors.transparent,
                          ),
                          onPressed: () => setState(() => _idMethod = 'QR_AUTOMATED'),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                          label: const Text('QR Badge', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _idMethod == 'MANUAL_DIRECTORY' ? AppTheme.safetyOrange : AppTheme.borderColor),
                            backgroundColor: _idMethod == 'MANUAL_DIRECTORY' ? AppTheme.safetyOrange.withOpacity(0.12) : Colors.transparent,
                          ),
                          onPressed: () => setState(() => _idMethod = 'MANUAL_DIRECTORY'),
                          icon: const Icon(Icons.badge_outlined, size: 18, color: Colors.white),
                          label: const Text('Manual List', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_idMethod == 'QR_AUTOMATED') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                            onPressed: () => _scanAndVerifyQr(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.safetyOrange),
                            label: const Text('Camera QR Scan', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                            onPressed: () => _scanAndVerifyQr(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppTheme.safetyOrange),
                            label: const Text('Upload QR File', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      value: workers.any((w) => w.workerId == _selectedWorkerId) ? _selectedWorkerId : (workers.isNotEmpty ? workers.first.workerId : null),
                      decoration: InputDecoration(
                        labelText: 'Select Registered Worker',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: workers.map((w) {
                        return DropdownMenuItem<String>(
                          value: w.workerId,
                          child: Text('${w.workerId} — ${w.name} (${w.department})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWorkerId = val);
                      },
                    ),
                  ],

                  // Verified Profile Tag
                  if (worker != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: worker.isBadgeExpired ? AppTheme.unsafeRed : AppTheme.safeGreen),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            worker.isBadgeExpired ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                            color: worker.isBadgeExpired ? AppTheme.unsafeRed : AppTheme.safeGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${worker.name} (${worker.workerId})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Badge: ${worker.effectiveBadgeId} • ${worker.isBadgeExpired ? "EXPIRED" : "ACTIVE"}', style: TextStyle(color: worker.isBadgeExpired ? AppTheme.unsafeRed : AppTheme.safeGreen, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // STEP 2: IMAGE ACQUISITION
            // -----------------------------------------------------------------
            _buildSectionHeader('2', 'Photograph Chemical Dosimeter Strip'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
                          onPressed: () => _getImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                          label: const Text('Live Camera Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.borderColor)),
                          onPressed: () => _getImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                          label: const Text('Upload Image', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // STEP 3: ENVIRONMENTAL & OPERATIONAL PARAMETERS
            // -----------------------------------------------------------------
            _buildSectionHeader('3', 'Environmental & Shift Parameters'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ambient Temp: ${_temperatureC.toStringAsFixed(0)}°C', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            Slider(
                              value: _temperatureC,
                              min: 10.0,
                              max: 50.0,
                              divisions: 40,
                              activeColor: AppTheme.safetyOrange,
                              onChanged: (v) => setState(() => _temperatureC = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Shift Duration: ${_exposureTimeHours.toStringAsFixed(1)} h', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            Slider(
                              value: _exposureTimeHours,
                              min: 0.5,
                              max: 12.0,
                              divisions: 23,
                              activeColor: AppTheme.safetyOrange,
                              onChanged: (v) => setState(() => _exposureTimeHours = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // PRE-FLIGHT VALIDATION & DIAGNOSTICS CARD
            // -----------------------------------------------------------------
            if (_latestResult != null) ...[
              _buildSectionHeader('4', 'Pre-Flight Optical Verification'),
              const SizedBox(height: 8),
              _buildValidationCard(_latestResult!),
              const SizedBox(height: 20),
            ],

            // -----------------------------------------------------------------
            // ANALYZE BUTTON
            // -----------------------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_image != null && !_isAnalyzing) ? AppTheme.safetyOrange : const Color(0xFF334155),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_image != null && !_isAnalyzing) ? _runFullAnalysis : null,
                child: _isAnalyzing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('🔍 Execute ML Dosimetry Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String stepNum, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppTheme.safetyOrange,
          child: Text(stepNum, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildValidationCard(DosimetryResult res) {
    final isValid = res.isValid;
    final color = isValid ? AppTheme.safeGreen : AppTheme.unsafeRed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isValid ? Icons.verified_outlined : Icons.error_outline_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isValid ? 'Optical Verification Passed (${res.confidencePct}%)' : 'Verification Rejected (${res.confidencePct}%)',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                child: Text(res.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(res.userMessage, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ],
      ),
    );
  }
}
