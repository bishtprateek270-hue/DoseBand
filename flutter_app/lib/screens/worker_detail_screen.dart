import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/worker.dart';
import '../models/reading.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_badge_card.dart';

class WorkerDetailScreen extends StatefulWidget {
  final Worker worker;
  const WorkerDetailScreen({super.key, required this.worker});

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final WorkerService _workerService = WorkerService();

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

  @override
  Widget build(BuildContext context) {
    // Find latest worker object from service if updated
    final w = _workerService.workers.firstWhere(
      (worker) => worker.workerId == widget.worker.workerId,
      orElse: () => widget.worker,
    );

    final readings = _workerService.getReadingsForWorker(w.workerId);
    final double cumDose = w.cumulativeDose;
    const double limit = 50.0;
    final double progress = (cumDose / limit).clamp(0.0, 1.0);

    Color riskColor = AppTheme.safeGreen;
    if (w.isBadgeExpired || w.status != 'Active' || cumDose >= limit) {
      riskColor = AppTheme.unsafeRed;
    } else if (cumDose >= 10.0) {
      riskColor = AppTheme.cautionYellow;
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('${w.name} (${w.workerId})'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dossier Card (Matching Web Dark Container inside Light Theme)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF1E293B),
                        child: Text('👷', style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${w.workerId} • ${w.department}', style: const TextStyle(color: Color(0xFFFB923C), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: riskColor),
                        ),
                        child: Text(
                          w.isBadgeExpired ? 'EXPIRED' : (w.status != 'Active' ? w.status.toUpperCase() : 'ACTIVE'),
                          style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),

                  // Metadata Grid
                  _buildDossierRow('Department:', w.department),
                  _buildDossierRow('Work Zone:', w.workZone),
                  _buildDossierRow('Shift:', w.shift),
                  _buildDossierRow('Badge ID:', w.effectiveBadgeId),
                  _buildDossierRow('Issue Date:', w.badgeIssueDate),
                  _buildDossierRow('Expiry Date:', w.badgeExpiryDate),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF38BDF8), size: 18),
                      label: const Text('View Official QR Badge Card', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _showBadgeDialog(context, w),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Exposure & Cumulative Dose Card
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
                  const Text('⚡ Exposure & Safety Health', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cumulative H₂S Dose:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      Text('${cumDose.toStringAsFixed(2)} ppm•h', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: riskColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cumDose >= limit
                        ? '🚨 EXCEEDED SAFE LIMIT (50.0 ppm•h) — Medical Review Required'
                        : '${(limit - cumDose).toStringAsFixed(1)} ppm•h remaining before permissible shift limit',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cumDose >= limit ? AppTheme.unsafeRed : AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dosimeter Scan Logs for Worker
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📋 Scan Audit Records', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text('${readings.length} Logged', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (readings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Center(child: Text('No dosimeter scans recorded for this worker yet.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
                    )
                  else
                    ...readings.map((r) => _buildReadingTile(r)),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingTile(Reading r) {
    Color riskColor = AppTheme.safeGreen;
    if (r.riskLevel.startsWith('Unsafe')) {
      riskColor = AppTheme.unsafeRed;
    } else if (r.riskLevel.startsWith('Caution')) {
      riskColor = AppTheme.cautionYellow;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text('${r.temperature}°C • ${r.humidity}% RH • Staining: ${(r.intensity * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.dose.toStringAsFixed(2)} ppm•h', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: riskColor)),
              Text(r.riskLevel.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: riskColor)),
            ],
          ),
        ],
      ),
    );
  }

  void _showBadgeDialog(BuildContext context, Worker w) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrBadgeCardWidget(worker: w),
            const SizedBox(height: 14),
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.safetyOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
