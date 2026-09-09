import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

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
        const SnackBar(content: Text('Please enter a valid Worker ID!'), backgroundColor: AppTheme.unsafeRed),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulated computer vision & ML analysis

    // Simulated scan results
    const double simulatedDose = 12.5; // ppm*hr
    const double simulatedIntensity = 0.38;
    const String simulatedRisk = 'Caution';
    const bool simulatedExpired = false;
    const String expiryMsg = 'Valid — safe to use';

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
            children: const [
              Icon(Icons.check_circle, color: AppTheme.safeGreen),
              SizedBox(width: 10),
              Text('Dosimeter Analyzed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Worker ID: $targetWorkerId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (updatedWorker != null) Text('Name: ${updatedWorker.name}', style: const TextStyle(color: AppTheme.primaryNavyLight)),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Scanned Dose:'),
                  Text('${simulatedDose.toStringAsFixed(1)} ppm*hr', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.safetyOrange)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Cumulative Exposure:'),
                  Text(
                    '${(updatedWorker?.cumulativeDose ?? simulatedDose).toStringAsFixed(1)} ppm*hr',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Risk Classification:'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cautionYellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(simulatedRisk.toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Badge Status:'),
                  Text('✅ Valid', style: TextStyle(color: AppTheme.safeGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Sensor Wristband',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Select Worker ID and capture photo of exposure badge & reference scale',
            style: TextStyle(color: AppTheme.primaryNavyLight),
          ),
          const SizedBox(height: 24),

          // Worker ID Selector Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.badge, color: AppTheme.safetyOrange, size: 20),
                    SizedBox(width: 8),
                    Text('Select Target Worker ID*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: workers.any((w) => w.workerId == _selectedWorkerId) ? _selectedWorkerId : (workers.isNotEmpty ? workers.first.workerId : 'CUSTOM'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    ...workers.map((w) => DropdownMenuItem(
                          value: w.workerId,
                          child: Text('${w.workerId} — ${w.name} (${w.department})'),
                        )),
                    const DropdownMenuItem(
                      value: 'CUSTOM',
                      child: Text('➕ Enter Custom / New Worker ID'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedWorkerId = val);
                  },
                ),
                if (_selectedWorkerId == 'CUSTOM') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customWorkerIdController,
                    decoration: InputDecoration(
                      hintText: 'Enter Worker ID (e.g. W-106)',
                      prefixIcon: const Icon(Icons.person_add),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Camera Frame / Preview
          if (_image != null) ...[
            Container(
              height: 360,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyzeImage,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
                child: _isAnalyzing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Analyze & Log Reading', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => setState(() => _image = null),
                child: const Text('Retake Photo'),
              ),
            )
          ] else ...[
            GestureDetector(
              onTap: () => _getImage(ImageSource.camera),
              child: Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderColor, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.scaffoldBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 40, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tap to capture sensor wristband photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('Ensure sensor pad and reference bar are visible', style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () => _getImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Upload from gallery'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryNavyLight),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
