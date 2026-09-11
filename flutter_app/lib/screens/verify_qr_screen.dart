import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/worker.dart';
import '../services/api_service.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';

class VerifyQrScreen extends StatefulWidget {
  const VerifyQrScreen({super.key});

  @override
  State<VerifyQrScreen> createState() => _VerifyQrScreenState();
}

class _VerifyQrScreenState extends State<VerifyQrScreen> {
  final ApiService _apiService = ApiService();
  final WorkerService _workerService = WorkerService();
  final ImagePicker _picker = ImagePicker();

  String _inputMode = 'Upload Image'; // 'Camera', 'Upload Image', 'Quick Test'
  Uint8List? _badgeImageBytes;
  String? _imageFileName;
  Worker? _selectedTestWorker;

  bool _isVerifying = false;
  Map<String, dynamic>? _verificationResult;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _badgeImageBytes = bytes;
          _imageFileName = picked.name;
          _selectedTestWorker = null;
        });
        _verifyBadge(imageBytes: bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to acquire image: $e'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  Future<void> _verifyBadge({Uint8List? imageBytes, String? rawPayload, String? fileName}) async {
    setState(() => _isVerifying = true);
    try {
      final res = await _workerService.verifyBadge(
        imageBytes: imageBytes,
        rawPayload: rawPayload,
        fileName: fileName ?? _imageFileName,
      );
      setState(() {
        _verificationResult = res;
        _isVerifying = false;
      });
    } catch (e) {
      setState(() {
        _verificationResult = {
          'valid': false,
          'status': 'ERROR',
          'message': 'Verification error: $e',
          'raw_payload': rawPayload ?? 'N/A'
        };
        _isVerifying = false;
      });
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
                  'Select Registered Worker Badge to Authenticate',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                      trailing: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0284C7)),
                      onTap: () {
                        Navigator.pop(ctx);
                        final payload = '{"app":"DoseBand","worker_id":"${w.workerId}","badge_id":"${w.effectiveBadgeId}","version":"1.0"}';
                        _verifyBadge(rawPayload: payload);
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

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;

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
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0284C7), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify Smart QR Badge',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Safety Desk Console — Authenticate worker badges before entry',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  _buildTabButton('Camera', Icons.camera_alt_outlined),
                  _buildTabButton('Upload Image', Icons.file_upload_outlined),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 1: Input Area
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
                  const Text('Step 1: Provide Badge QR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),

                  if (_inputMode == 'Camera') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Capture Badge QR with Camera'),
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7)),
                        label: const Text('Choose QR Image from Gallery', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],

                  if (_badgeImageBytes != null) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_badgeImageBytes!, height: 140, fit: BoxFit.contain),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  const Text(
                    '🔒 Security Note: Only QR codes generated by the DoseBand platform contain the cryptographic signature and JSON schema required for authentication.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: _showQuickSelectDialog,
                      child: const Text(
                        '🧪 Quick Test: Test Registered Worker Badge ›',
                        style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 2: Verification Result Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 2: Authentication Result & Dossier', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),

                  if (_isVerifying) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: AppTheme.safetyOrange),
                      ),
                    ),
                  ] else if (_verificationResult != null) ...[
                    _buildVerificationResultContent(),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Please capture or upload a QR badge above to authenticate.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, IconData icon) {
    final isSelected = _inputMode == title;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _inputMode = title;
            _verificationResult = null;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationResultContent() {
    final res = _verificationResult!;
    final bool isValid = res['valid'] == true;
    final String status = res['status']?.toString() ?? '';
    final String message = res['message']?.toString() ?? '';
    final worker = res['worker'] as Map<String, dynamic>?;
    final rawPayload = res['raw_payload']?.toString() ?? '';

    if (isValid && worker != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.safeGreenBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.safeGreen),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.safeGreen, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Official DoseBand Badge Verified Successfully!',
                    style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Worker Dossier Card (Matching Web)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: const Border(left: BorderSide(color: AppTheme.safeGreen, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F172A),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('👤', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(worker['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(worker['worker_id'] ?? '', style: const TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.safeGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 10),
                _buildDossierRow('🏭 Dept:', worker['department'] ?? 'N/A'),
                _buildDossierRow('📍 Zone:', worker['work_zone'] ?? 'N/A'),
                _buildDossierRow('⏰ Shift:', worker['shift'] ?? 'N/A'),
                _buildDossierRow('🏷️ Badge ID:', worker['badge_id'] ?? 'N/A'),
                _buildDossierRow('📅 Expiry Date:', worker['badge_expiry_date'] ?? 'N/A'),
                _buildDossierRow('📞 Emergency:', worker['emergency_contact'] ?? 'Safety Desk (Ext 101)'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppTheme.safeGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Worker ${worker['name']} is cleared for entry into ${worker['work_zone']}.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (status == 'EXPIRED') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.unsafeRedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.unsafeRed),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dangerous_rounded, color: AppTheme.unsafeRed, size: 22),
                SizedBox(width: 8),
                Text('BADGE EXPIRED', style: TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
            if (worker != null) ...[
              const SizedBox(height: 6),
              Text(
                'Worker: ${worker['name']} (${worker['worker_id']}) — Expired on ${worker['badge_expiry_date']}. Please re-issue a calibrated strip.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      );
    } else {
      // Foreign or non-DoseBand QR
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.unsafeRedBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.unsafeRed),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.block_flipped, color: AppTheme.unsafeRed, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ACCESS REJECTED: Non-DoseBand QR Code Detected',
                    style: TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This QR code was NOT generated by the DoseBand platform. External website links, personal QR codes, WiFi credentials, payment barcodes, and arbitrary barcodes are strictly blocked.',
              style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Intercepted Raw Payload:', style: TextStyle(fontSize: 10, color: Color(0xFF991B1B), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    rawPayload.isNotEmpty ? rawPayload : 'No decodable QR barcode pattern detected.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('🛡️ Security Action: Payload logged and discarded. No database records modified.', style: TextStyle(fontSize: 10, color: Color(0xFF991B1B))),
          ],
        ),
      );
    }
  }

  Widget _buildDossierRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
