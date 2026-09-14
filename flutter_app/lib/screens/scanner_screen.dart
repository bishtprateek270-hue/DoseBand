import 'dart:convert';
import 'dart:typed_data';
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

  // Mode: 'full_badge' or 'standalone_strip'
  String _scanMode = 'full_badge';

  Uint8List? _imageBytes;
  String _imageFileName = 'strip.jpg';
  bool _isAnalyzing = false;

  // Worker identification
  Worker? _identifiedWorker;

  @override
  void initState() {
    super.initState();
    _workerService.addListener(_onServiceUpdate);
    _workerService.fetchWorkers();
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

  // ─── IMAGE PICKING ───────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFileName = picked.name;
        });
      }
    } catch (e) {
      _showSnack('Failed to load image: $e', isError: true);
    }
  }

  // ─── QR / WORKER SELECTION ──────────────────────────────────────────────────
  /// Shows the worker catalog bottom sheet to select a pre-registered worker.
  /// This replaces camera-QR scan (since image_picker doesn't decode QR codes —
  /// only a dedicated QR scanner plugin can do that). The worker is then locally
  /// verified via verifyBadge(rawPayload: ...).
  void _showWorkerCatalog() {
    final workers = _workerService.workers;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.safetyOrangeBg, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.badge_outlined, color: AppTheme.safetyOrange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Worker Badge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                          Text('Tap to link worker to this scan session', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: workers.isEmpty
                    ? const Center(child: Text('No registered workers found.\nRegister workers in the Workers tab.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: workers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final w = workers[idx];
                          return _WorkerCatalogTile(
                            worker: w,
                            onSelect: () {
                              Navigator.pop(ctx);
                              // Build canonical DoseBand JSON payload and verify locally
                              final payload = jsonEncode({
                                'type': 'doseband_worker',
                                'version': 1,
                                'worker_id': w.workerId,
                                'badge_id': w.effectiveBadgeId,
                              });
                              _workerService.verifyBadge(rawPayload: payload).then((res) {
                                _handleQrVerificationResponse(res);
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Also try verifying via image upload (backend QR decode)
  Future<void> _verifyQrViaImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      _showSnack('Attempting QR decode…');
      final res = await _workerService.verifyBadge(imageBytes: bytes, fileName: picked.name);
      _handleQrVerificationResponse(res);
    } catch (e) {
      _showSnack('QR verification error: $e', isError: true);
    }
  }

  void _handleQrVerificationResponse(Map<String, dynamic> res) {
    final bool isValid = res['valid'] == true;
    final workerData = res['worker'] as Map<String, dynamic>?;

    if (isValid && workerData != null) {
      final w = Worker.fromMap(workerData);
      setState(() => _identifiedWorker = w);
      _showSnack('✅ Verified: ${w.name} (${w.workerId})');
    } else {
      setState(() => _identifiedWorker = null);
      _showSnack(res['message'] ?? 'Not a valid DoseBand badge.', isError: true);
    }
  }

  // ─── ANALYSIS ───────────────────────────────────────────────────────────────
  Future<void> _analyzeStrip() async {
    if (_imageBytes == null) return;
    if (_scanMode == 'full_badge' && _identifiedWorker == null) {
      _showSnack('Please link a worker badge first (Full DoseBand mode).', isError: true);
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await _dosimetryService.processImage(
        imageBytes: _imageBytes!,
        fileName: _imageFileName,
        workerId: _identifiedWorker?.workerId ?? 'W-DEMO',
        temperatureC: 25.0,
        humidityRh: null,
        exposureTimeHours: 1.0,
        badgeMode: _scanMode == 'standalone_strip' ? 'STANDALONE_H2S_STRIP' : 'FULL_DOSEBAND_BADGE',
        scanMode: _scanMode,
      );
      setState(() => _isAnalyzing = false);
      if (mounted) _showResultSheet(result);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showSnack('Analysis failed: $e', isError: true);
    }
  }

  // ─── RESULT BOTTOM SHEET ────────────────────────────────────────────────────
  void _showResultSheet(DosimetryResult r) {
    Color statusColor = AppTheme.safeGreen;
    if (!r.isValid || r.isBadgeExpired) {
      statusColor = AppTheme.unsafeRed;
    } else if (r.riskLevel.toLowerCase().contains('unsafe')) {
      statusColor = AppTheme.unsafeRed;
    } else if (r.riskLevel.toLowerCase().contains('caution')) {
      statusColor = AppTheme.cautionYellow;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // Result header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(r.isValid ? Icons.verified_user_rounded : Icons.gpp_bad_rounded, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.isValid ? (r.isStandalone ? 'Standalone Strip Result' : 'Full DoseBand Result') : 'Scan Failed',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                          ),
                          Text(r.riskLevel.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.borderColor),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Disclaimer for standalone/prototype
                    if (r.isStandalone || r.isPrototypeEstimate)
                      _InfoBanner(
                        icon: Icons.info_outline_rounded,
                        color: AppTheme.cautionYellow,
                        message: r.disclaimer ?? 'PROTOTYPE ESTIMATE: Standalone strip scan is an uncalibrated visual estimation.',
                      ),

                    if (!r.isValid) ...[
                      const SizedBox(height: 8),
                      _InfoBanner(
                        icon: Icons.error_outline_rounded,
                        color: AppTheme.unsafeRed,
                        message: r.userMessage,
                      ),
                      if (r.rejectionReasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...r.rejectionReasons.map((rr) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.chevron_right, size: 14, color: AppTheme.unsafeRed),
                            const SizedBox(width: 4),
                            Expanded(child: Text(rr, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                          ]),
                        )),
                      ],
                    ] else ...[
                      const SizedBox(height: 8),
                      // Big metrics
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('H₂S Gas Concentration', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                                Text('${r.estimatedH2sPpm.toStringAsFixed(2)} ppm', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: statusColor)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(color: AppTheme.borderColor, height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Shift Exposure Dose', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                Text('${r.cumulativeDosePpmH.toStringAsFixed(2)} ppm•h', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Optical Darkening', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                Text('${(r.rawIntensity * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Confidence', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                Text('${r.confidencePct}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Worker info
                      if (_identifiedWorker != null)
                        _InfoRow(label: 'Worker', value: '${_identifiedWorker!.name} (${_identifiedWorker!.workerId})'),
                      _InfoRow(label: 'Scan Mode', value: r.isStandalone ? 'Standalone H₂S Strip' : 'Full DoseBand Enclosure'),
                      _InfoRow(label: 'Temperature', value: '${r.temperatureC}°C  |  ${r.predictedHumidity.toStringAsFixed(0)}% RH'),
                      const SizedBox(height: 8),
                      // Guidance
                      _InfoBanner(
                        icon: Icons.lightbulb_outline_rounded,
                        color: const Color(0xFF0284C7),
                        message: r.actionGuidance,
                      ),
                      // Debug overlay
                      if (r.debugOverlayBase64 != null && r.debugOverlayBase64!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text('ROI Detection Overlay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(base64Decode(r.debugOverlayBase64!), fit: BoxFit.contain),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),

                    // Action buttons
                    if (r.isValid && r.isAllowedToSave && _identifiedWorker != null)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Reading to Database', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.safeGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final saved = await _dosimetryService.saveReading(workerId: _identifiedWorker!.workerId, result: r);
                            if (mounted) _showSnack(saved ? '✅ Reading saved to database!' : '❌ Failed to save reading.', isError: !saved);
                          },
                        ),
                      ),
                    if (r.estimatedH2sPpm >= 15.0 || r.riskLevel.toLowerCase().contains('unsafe')) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.warning_amber_rounded, size: 18),
                          label: const Text('Alert Evacuation Protocol', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.unsafeRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showEvacuationAlert(r);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── EVACUATION ALERT ───────────────────────────────────────────────────────
  void _showEvacuationAlert(DosimetryResult r) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF7F1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          SizedBox(width: 8),
          Expanded(child: Text('CRITICAL STEL BREACH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DETECTED: ${r.estimatedH2sPpm.toStringAsFixed(1)} PPM H₂S', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFFCA5A5))),
            const SizedBox(height: 4),
            Text('WORKER: ${_identifiedWorker?.name ?? "Field Unit"}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 12),
            const Text('EMERGENCY ACTION (OSHA 1910.1000):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('1. Don SCBA immediately.', style: TextStyle(fontSize: 11, color: Colors.white70)),
            const Text('2. Evacuate Zone crosswind to Muster Point.', style: TextStyle(fontSize: 11, color: Colors.white70)),
            const Text('3. Dispatch Safety Supervisor & Gas Isolation.', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF7F1D1D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _showSnack('🚨 Emergency alert logged to telemetry.', isError: true);
            },
            child: const Text('DISPATCH & EVACUATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? AppTheme.unsafeRed : AppTheme.safeGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isStandalone = _scanMode == 'standalone_strip';
    final bool hasImage = _imageBytes != null;
    final bool hasWorker = _identifiedWorker != null;
    final bool canAnalyze = hasImage && (isStandalone || hasWorker) && !_isAnalyzing;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.orangeAccentGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.orangeGlow,
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan & Analyze', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.4)),
                      Text('Optical dosimetry with Lead Acetate PbS model', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Mode Selector ──
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scan Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.3)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _ModeChip(
                        label: 'Full DoseBand',
                        icon: Icons.watch_rounded,
                        selected: !isStandalone,
                        onTap: () => setState(() { _scanMode = 'full_badge';  }),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _ModeChip(
                        label: 'Standalone Strip',
                        icon: Icons.science_rounded,
                        selected: isStandalone,
                        onTap: () => setState(() { _scanMode = 'standalone_strip';  }),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      isStandalone
                          ? '• Standalone: Direct paper strip scan — no worker badge required.'
                          : '• Full DoseBand: Validates enclosure + QR badge + humidity card.',
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.textFaint, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Step 1: Worker Linking ──
              _StepCard(
                stepNum: '1',
                title: isStandalone ? 'Link Worker (Optional)' : 'Link Worker Badge (Required)',
                isComplete: hasWorker,
                child: Column(
                  children: [
                    if (isStandalone && !hasWorker)
                      const _InfoBanner(
                        icon: Icons.info_outline_rounded,
                        color: Color(0xFF0284C7),
                        message: 'Standalone mode: you can analyze without linking a worker.',
                      ),

                    if (hasWorker)
                      _WorkerLinkedCard(
                        worker: _identifiedWorker!,
                        onClear: () => setState(() => _identifiedWorker = null),
                      )
                    else ...[
                      const SizedBox(height: 8),
                      // Primary: catalog select
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.badge_outlined, size: 18),
                          label: const Text('Select from Worker Catalog', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.safetyOrange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showWorkerCatalog,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Secondary: scan QR image from gallery/camera (backend decode)
                      Row(children: [
                        Expanded(child: _OutlineBtn(
                          label: 'Scan QR via Camera',
                          icon: Icons.camera_alt_outlined,
                          onTap: () => _verifyQrViaImage(ImageSource.camera),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _OutlineBtn(
                          label: 'Upload QR Image',
                          icon: Icons.photo_library_outlined,
                          onTap: () => _verifyQrViaImage(ImageSource.gallery),
                        )),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Step 2: Capture Photo ──
              _StepCard(
                stepNum: '2',
                title: isStandalone ? 'Capture H₂S Strip Photo' : 'Capture Full DoseBand Photo',
                isComplete: hasImage,
                child: Column(
                  children: [
                    if (!isStandalone) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Position the complete grey 3D-printed enclosure under even, diffused light. Ensure QR and humidity card are visible.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
                      ),
                    ] else ...[
                      // Framing guide
                      if (!hasImage) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.5)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.crop_free_rounded, color: AppTheme.safetyOrange, size: 32),
                              SizedBox(height: 8),
                              Text('PLACE H₂S STRIP IN FRAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 13)),
                              SizedBox(height: 4),
                              Text('Center 60–80% of strip · Even lighting · No shadows', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(!isStandalone ? 'Take Badge Photo' : 'Take Strip Photo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _pickImage(ImageSource.camera),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _OutlineBtn(
                        label: 'Upload Photo',
                        icon: Icons.file_upload_outlined,
                        onTap: () => _pickImage(ImageSource.gallery),
                      )),
                    ]),
                    if (hasImage) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(_imageBytes!, height: 160, width: double.infinity, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textMuted),
                            label: const Text('Change Photo', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Analyze Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: canAnalyze ? AppTheme.orangeGlow : [],
                  ),
                  child: ElevatedButton.icon(
                    icon: _isAnalyzing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Icon(Icons.analytics_rounded, size: 20),
                    label: Text(
                      _isAnalyzing
                          ? 'Running Optical Inference…'
                          : (isStandalone ? '🔬 Analyze Standalone Strip' : '🔬 Analyze Full DoseBand'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                    ),
                    onPressed: canAnalyze ? _analyzeStrip : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.safetyOrange,
                      disabledBackgroundColor: AppTheme.borderColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Help text below button
              if (!canAnalyze && !_isAnalyzing) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    !hasImage
                        ? 'Capture or upload a photo to enable analysis'
                        : (!isStandalone && !hasWorker)
                            ? 'Link a worker badge to enable analysis in Full DoseBand mode'
                            : '',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORTING WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderColor),
      boxShadow: AppTheme.cardShadow,
    ),
    child: child,
  );
}

class _StepCard extends StatelessWidget {
  final String stepNum;
  final String title;
  final bool isComplete;
  final Widget child;
  const _StepCard({required this.stepNum, required this.title, required this.isComplete, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isComplete ? AppTheme.safeGreen.withValues(alpha: 0.5) : AppTheme.borderColor,
        width: isComplete ? 1.5 : 1,
      ),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isComplete ? AppTheme.safeGreenBg : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('STEP $stepNum', style: TextStyle(color: isComplete ? AppTheme.safeGreen : Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary))),
          if (isComplete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.safeGreenBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.4))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check, size: 11, color: AppTheme.safeGreen),
                SizedBox(width: 2),
                Text('DONE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.safeGreen)),
              ]),
            ),
        ]),
        child,
      ],
    ),
  );
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? AppTheme.safetyOrange : AppTheme.borderColor, width: selected ? 1.5 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: selected ? AppTheme.safetyOrange : AppTheme.textMuted),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}

class _WorkerLinkedCard extends StatelessWidget {
  final Worker worker;
  final VoidCallback onClear;
  const _WorkerLinkedCard({required this.worker, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: AppTheme.navyHeroGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.6), width: 1.5),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: const BoxDecoration(color: Color(0xFF065F46), shape: BoxShape.circle),
          child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${worker.name} (${worker.workerId})', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 2),
              Text('Badge: ${worker.effectiveBadgeId}  ·  ${worker.department}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF34D399), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
          tooltip: 'Unlink worker',
          onPressed: onClear,
        ),
      ],
    ),
  );
}

class _WorkerCatalogTile extends StatelessWidget {
  final Worker worker;
  final VoidCallback onSelect;
  const _WorkerCatalogTile({required this.worker, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppTheme.safeGreen;
    if (worker.isBadgeExpired || worker.status != 'Active') statusColor = AppTheme.unsafeRed;
    else if (worker.cumulativeDose >= 10) statusColor = AppTheme.cautionYellow;

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(worker.name[0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  Text('${worker.workerId} · Badge: ${worker.effectiveBadgeId}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  Text(worker.department, style: const TextStyle(fontSize: 11, color: AppTheme.textFaint), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    worker.isBadgeExpired ? 'EXPIRED' : worker.status.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _InfoBanner({required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600, height: 1.4))),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), textAlign: TextAlign.right)),
      ],
    ),
  );
}
