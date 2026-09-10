import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final WorkerService _workerService = WorkerService();
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isAnalyzing = false;
  String _selectedWorkerId = 'W-101';
  final TextEditingController _customWorkerIdController = TextEditingController();

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
      setState(() => _image = File(pickedFile.path));
    }
  }

  void _analyzeImage() async {
    if (_image == null) return;

    final targetWorkerId = _selectedWorkerId == 'CUSTOM'
        ? _customWorkerIdController.text.trim().toUpperCase()
        : _selectedWorkerId;

    if (targetWorkerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Worker ID!'),
          backgroundColor: AppTheme.unsafeRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulated optical dosimetry ML inference

    // Simulated scan metrics
    const double simulatedDose = 12.5; // ppm*hr
    const double simulatedIntensity = 0.38;
    const String simulatedRisk = 'Caution';
    const bool simulatedExpired = false;
    const String expiryMsg = 'Valid — sensor safe';

    _workerService.addReading(
      workerId: targetWorkerId,
      dose: simulatedDose,
      intensity: simulatedIntensity,
      riskLevel: simulatedRisk,
      isExpired: simulatedExpired,
      expiryStatusMessage: expiryMsg,
    );

    setState(() => _isAnalyzing = false);

    final updatedWorker = _workerService.getWorkerById(targetWorkerId);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.safeGreen, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Dosimeter Analyzed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Worker ID: $targetWorkerId', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryNavy)),
              if (updatedWorker != null)
                Text('Personnel: ${updatedWorker.name}', style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12)),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Scanned Incremental Dose:', style: TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight)),
                  Text('${simulatedDose.toStringAsFixed(1)} ppm*hr', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.safetyOrange, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Cumulative Exposure:', style: TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight)),
                  Text(
                    '${(updatedWorker?.cumulativeDose ?? simulatedDose).toStringAsFixed(1)} ppm*hr',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Risk Classification:', style: TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.cautionYellowBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cautionYellow.withValues(alpha: 0.3)),
                    ),
                    child: Text(simulatedRisk.toUpperCase(), style: const TextStyle(color: AppTheme.cautionYellow, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Badge Status:', style: TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight)),
                  Text('✅ Active & Safe', style: TextStyle(color: AppTheme.safeGreen, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _image = null);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan Sensor Wristband',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          const Text(
            'Optical dosimetry colorimetric evaluation & AI reading log',
            style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),

          // Worker Target Selection Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.badge_outlined, color: AppTheme.primaryNavy, size: 18),
                    SizedBox(width: 8),
                    Text('Select Target Personnel ID*', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryNavy)),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: workers.any((w) => w.workerId == _selectedWorkerId) ? _selectedWorkerId : (workers.isNotEmpty ? workers.first.workerId : 'CUSTOM'),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    ...workers.map((w) => DropdownMenuItem(
                          value: w.workerId,
                          child: Text(
                            '${w.workerId} — ${w.name} (${w.department})',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                    const DropdownMenuItem(
                      value: 'CUSTOM',
                      child: Text(
                        '➕ Enter Custom / New Worker ID',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.safetyOrange),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedWorkerId = val);
                  },
                ),
                if (_selectedWorkerId == 'CUSTOM') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customWorkerIdController,
                    decoration: const InputDecoration(
                      hintText: 'Enter Worker ID (e.g. W-106)',
                      prefixIcon: Icon(Icons.person_add_outlined, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Camera Viewfinder Box
          if (_image != null) ...[
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryNavy, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isAnalyzing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Analyze & Log Dosimeter Reading', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _image = null),
                child: const Text('Retake Wristband Photo', style: TextStyle(color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w600)),
              ),
            )
          ] else ...[
            GestureDetector(
              onTap: () => _getImage(ImageSource.camera),
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Corner targeting brackets UI overlay
                    Positioned(top: 20, left: 20, child: _buildTargetCorner(top: true, left: true)),
                    Positioned(top: 20, right: 20, child: _buildTargetCorner(top: true, left: false)),
                    Positioned(bottom: 20, left: 20, child: _buildTargetCorner(top: false, left: true)),
                    Positioned(bottom: 20, right: 20, child: _buildTargetCorner(top: false, left: false)),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 36, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Tap to Capture Sensor Wristband',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Align sensor bar & color reference window',
                          style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _getImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose photo from device gallery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryNavyLight),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetCorner({required bool top, required bool left}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: AppTheme.safetyOrange, width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: AppTheme.safetyOrange, width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: AppTheme.safetyOrange, width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: AppTheme.safetyOrange, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
