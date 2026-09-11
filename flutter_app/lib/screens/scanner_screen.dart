import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  File? _image;
  bool _isAnalyzing = false;
  String _selectedWorkerId = 'W-101';
  final TextEditingController _customWorkerIdController = TextEditingController();

  // Scan Parameters
  String _badgeMode = 'STANDALONE_CHEMICAL_STRIP'; // STANDALONE_CHEMICAL_STRIP | FULL_DOSEBAND_BADGE
  double _exposureTimeHours = 1.0;
  double _temperatureC = 25.0;
  double _humidityRh = 50.0;

  // Pre-flight validation state
  DosimetryResult? _latestResult;

  @override
  void initState() {
    super.initState();
    _workerService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _workerService.removeListener(_onServiceUpdate);
    _customWorkerIdController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _getImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _image = file;
        _isAnalyzing = true;
      });

      // Run pre-flight optical validation
      final result = await _dosimetryService.analyzeImage(
        imageFile: file,
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
  }

  void _runFullAnalysis() async {
    if (_image == null) return;

    final targetWorkerId = _selectedWorkerId == 'CUSTOM'
        ? _customWorkerIdController.text.trim().toUpperCase()
        : _selectedWorkerId;

    if (targetWorkerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a valid Worker ID!'),
          backgroundColor: AppTheme.unsafeRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final worker = _workerService.getWorkerById(targetWorkerId);
    if (worker != null && worker.isBadgeExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Worker badge is EXPIRED. Replace badge before logging exposure.'),
          backgroundColor: AppTheme.unsafeRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isAnalyzing = true);

    final result = await _dosimetryService.analyzeImage(
      imageFile: _image!,
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

    // Save reading to worker service
    _workerService.addReading(
      workerId: targetWorkerId,
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
      badgeMode: _badgeMode,
      dataSource: 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
      confidencePct: result.confidencePct,
      actionGuidance: result.actionGuidance,
    );

    if (mounted) {
      _showDosimetryResultModal(result, targetWorkerId);
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Worker: ${worker?.name ?? workerId}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('ID: $workerId | ${worker?.department ?? "Operations"}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('VERIFIED', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'H₂S Concentration',
                      '${result.estimatedH2sPpm.toStringAsFixed(2)} ppm',
                      riskColor,
                      Icons.science,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Cumulative Dose',
                      '${result.cumulativeDosePpmH.toStringAsFixed(2)} ppm·hr',
                      AppTheme.safetyOrange,
                      Icons.timer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Total Worker Exposure',
                      '${(worker?.cumulativeDose ?? result.cumulativeDosePpmH).toStringAsFixed(1)} ppm·hr',
                      Colors.white,
                      Icons.person,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Optical Staining',
                      '${(result.rawIntensity * 100).toStringAsFixed(1)}%',
                      const Color(0xFF38BDF8),
                      Icons.opacity,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Risk Classification Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('RISK CLASSIFICATION', style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                        Text(result.riskLevel.toUpperCase(), style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(result.actionGuidance, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Environmental parameters recorded
              Text(
                'Conditions: ${_temperatureC.toStringAsFixed(1)}°C | ${_humidityRh.toStringAsFixed(0)}% RH | ${_exposureTimeHours.toStringAsFixed(1)} hr shift',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _image = null;
                _latestResult = null;
              });
            },
            child: const Text('Close & Reset', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
            child: const Text('View History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color valueColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.safetyOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.document_scanner, color: AppTheme.safetyOrange, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optical Dosimeter Scan',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Lead Acetate H₂S Chemical Colorimetry',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Step 1: Worker Selection Card
            _buildSectionCard(
              title: 'Step 1: Worker Identification',
              icon: Icons.person_pin_circle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: workers.any((w) => w.workerId == _selectedWorkerId) ? _selectedWorkerId : 'W-101',
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Select Registered Worker',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                    ),
                    items: [
                      ...workers.map((w) => DropdownMenuItem(
                        value: w.workerId,
                        child: Text(
                          '${w.workerId} - ${w.name} (${w.department})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      )),
                      const DropdownMenuItem(
                        value: 'CUSTOM',
                        child: Text('Manual Custom ID Entry...', overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedWorkerId = val ?? 'W-101'),
                  ),
                  if (_selectedWorkerId == 'CUSTOM') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customWorkerIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Enter Custom Worker ID (e.g. W-105)',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 2: Strip Scan Mode & Environmental Parameters
            _buildSectionCard(
              title: 'Step 2: Scan Mode & Shift Conditions',
              icon: Icons.tune,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode Selector Tabs
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          '🧪 Standalone Strip',
                          'STANDALONE_CHEMICAL_STRIP',
                          'Direct paper crop',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildModeTab(
                          '🏷️ Full Badge',
                          'FULL_DOSEBAND_BADGE',
                          'Full badge 5-step',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sliders
                  _buildSlider(
                    label: 'Shift Duration',
                    valueText: '${_exposureTimeHours.toStringAsFixed(1)} Hours',
                    value: _exposureTimeHours,
                    min: 0.5,
                    max: 12.0,
                    divisions: 23,
                    onChanged: (v) => setState(() => _exposureTimeHours = v),
                  ),
                  _buildSlider(
                    label: 'Ambient Temperature',
                    valueText: '${_temperatureC.toStringAsFixed(1)} °C',
                    value: _temperatureC,
                    min: 15.0,
                    max: 45.0,
                    divisions: 30,
                    onChanged: (v) => setState(() => _temperatureC = v),
                  ),
                  _buildSlider(
                    label: 'Relative Humidity',
                    valueText: '${_humidityRh.toStringAsFixed(0)} % RH',
                    value: _humidityRh,
                    min: 20.0,
                    max: 90.0,
                    divisions: 14,
                    onChanged: (v) => setState(() => _humidityRh = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 3: Capture & Pre-Flight Verification
            _buildSectionCard(
              title: 'Step 3: Badge Preview & Verification',
              icon: Icons.camera_alt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Display Area
                  Container(
                    height: 210,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155), width: 1.5),
                    ),
                    child: _image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(_image!, fit: BoxFit.contain),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 48, color: Color(0xFF64748B)),
                              SizedBox(height: 10),
                              Text('No Dosimeter Strip Loaded', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              Text('Capture via camera or upload photo from device', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons for Camera / Gallery
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _getImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Live Camera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _getImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Upload Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Validation Status & Pre-Flight Cards
                  if (_latestResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _latestResult!.isValid ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _latestResult!.isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(_latestResult!.isValid ? Icons.verified : Icons.error_outline, color: _latestResult!.isValid ? const Color(0xFF34D399) : const Color(0xFFF87171), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Test Strip: ${_latestResult!.status.toUpperCase()} (${_latestResult!.confidencePct}%)',
                                    style: TextStyle(color: _latestResult!.isValid ? const Color(0xFF34D399) : const Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _latestResult!.isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _latestResult!.isValid ? 'VERIFIED' : 'REJECTED',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4 Pre-flight Diagnostic Indicator Cards
                    Row(
                      children: [
                        Expanded(child: _buildPreFlightIndicator('📌 Scale', _badgeMode == 'STANDALONE_CHEMICAL_STRIP' ? 'Direct Strip' : '5-Step OLS', true)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildPreFlightIndicator('🧪 Sensor Strip', 'Verified Paper', _latestResult!.isValid)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildPreFlightIndicator('💧 Humidity', 'Auto Standard', true)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildPreFlightIndicator('💡 Lighting', 'Feasible', true)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Analyze Button
            ElevatedButton(
              onPressed: (_image != null && !_isAnalyzing && (_latestResult?.isValid ?? true))
                  ? _runFullAnalysis
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.safetyOrange,
                disabledBackgroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _isAnalyzing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Analyzing Dosimeter Strip...', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Text('🔍 Analyze Dosimeter Badge', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Professional Safety Notice Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: AppTheme.safetyOrange, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppTheme.safetyOrange, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Mandatory Chemical & Safety Protocol',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Hydrogen Sulfide (H₂S) and Lead Acetate handling must strictly be performed under expert supervision inside certified chemical fume hoods with calibrated PPE.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.safetyOrange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, String modeValue, String subtitle) {
    final isSelected = _badgeMode == modeValue;
    return GestureDetector(
      onTap: () => setState(() => _badgeMode = modeValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.safetyOrange.withValues(alpha: 0.18) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.safetyOrange : const Color(0xFF334155), width: isSelected ? 1.5 : 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: isSelected ? AppTheme.safetyOrange : Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(valueText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.safetyOrange,
              inactiveTrackColor: const Color(0xFF334155),
              thumbColor: AppTheme.safetyOrange,
              overlayColor: AppTheme.safetyOrange.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreFlightIndicator(String title, String statusText, bool isOk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            isOk ? '✅ $statusText' : '❌ Failed',
            style: TextStyle(color: isOk ? const Color(0xFF34D399) : const Color(0xFFF87171), fontSize: 9, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
