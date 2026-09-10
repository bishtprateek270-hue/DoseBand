import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/worker.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';

class WorkerDetailScreen extends StatefulWidget {
  final String workerId;
  const WorkerDetailScreen({super.key, required this.workerId});

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

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Safe':
        return AppTheme.safeGreen;
      case 'Caution':
        return AppTheme.cautionYellow;
      case 'Unsafe':
        return AppTheme.unsafeRed;
      default:
        return AppTheme.safeGreen;
    }
  }

  Color _getRiskBgColor(String riskLevel) {
    switch (riskLevel) {
      case 'Safe':
        return AppTheme.safeGreenBg;
      case 'Caution':
        return AppTheme.cautionYellowBg;
      case 'Unsafe':
        return AppTheme.unsafeRedBg;
      default:
        return AppTheme.safeGreenBg;
    }
  }

  void _showEmergencyDialog(Worker worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.unsafeRedBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.unsafeRed, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Emergency Broadcast', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initiating emergency contact call & SMS alert for Worker ${worker.workerId} (${worker.name}).',
              style: const TextStyle(fontSize: 13, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: AppTheme.primaryNavy),
                      const SizedBox(width: 6),
                      Text('Contact: ${worker.emergencyContact}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('🏢 Department: ${worker.department}', style: const TextStyle(fontSize: 12)),
                  Text('⚠️ Current Exposure: ${worker.cumulativeDose.toStringAsFixed(1)} ppm*hr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.unsafeRed)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryNavyLight)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.unsafeRed),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🚨 Emergency alert transmitted to ${worker.emergencyContact}!'),
                  backgroundColor: AppTheme.unsafeRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
            label: const Text('Confirm Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worker = _workerService.getWorkerById(widget.workerId);

    if (worker == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Worker Profile')),
        body: const Center(child: Text('Personnel record not found.')),
      );
    }

    final readings = _workerService.getReadingsForWorker(worker.workerId);
    final riskColor = _getRiskColor(worker.riskLevel);
    const double threshold = 50.0;
    final double progress = (worker.cumulativeDose / threshold).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Worker ${worker.workerId} Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_forwarded_rounded, color: AppTheme.unsafeRed),
            onPressed: () => _showEmergencyDialog(worker),
            tooltip: 'Call Emergency Contact',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Executive Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavyDark, AppTheme.primaryNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryNavy.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        worker.workerId,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          worker.department,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          worker.shift,
                          style: const TextStyle(color: AppTheme.safetyOrange, fontSize: 11, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      worker.riskLevel.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Emergency Warning Banner
            if (worker.riskLevel == 'Unsafe' || worker.cumulativeDose >= threshold) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.unsafeRedBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.unsafeRed.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: AppTheme.unsafeRed, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('HIGH EXPOSURE WARNING', style: TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.w800, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('Personnel exceeded 50.0 ppm*hr limit. Initiate immediate medical triage.', style: TextStyle(fontSize: 11, color: AppTheme.primaryNavy)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (worker.isBadgeExpired) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cautionYellowBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cautionYellow.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.cautionYellow, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('SENSOR WRISTBAND EXPIRED', style: TextStyle(color: AppTheme.cautionYellow, fontWeight: FontWeight.w800, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('Passive sensor shelf-life ended. Re-issue fresh wristband.', style: TextStyle(fontSize: 11, color: AppTheme.primaryNavy)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Cumulative Gauge Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Cumulative Dose', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryNavy)),
                      Text('Limit: 50.0 ppm*hr', style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 140,
                        width: 140,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: AppTheme.borderColor.withValues(alpha: 0.5),
                          color: riskColor,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              worker.cumulativeDose.toStringAsFixed(1),
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: riskColor, letterSpacing: -1.0),
                            ),
                          ),
                          const Text('ppm*hr', style: TextStyle(fontSize: 11, color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.borderColor.withValues(alpha: 0.5),
                      color: riskColor,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Emergency Action Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.unsafeRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _showEmergencyDialog(worker),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Emergency Call', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.primaryNavy),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Safety compliance report generated for Worker ${worker.workerId}.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.primaryNavy, size: 18),
                    label: const Text('Export Report', style: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scan History Log
            Text('Individual Scan History (${readings.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
            const SizedBox(height: 12),

            if (readings.isEmpty)
              const Text('No scan readings recorded for this worker yet.', style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: readings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final reading = readings[index];
                  final rColor = _getRiskColor(reading.riskLevel);
                  final rBg = _getRiskBgColor(reading.riskLevel);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: rBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.sensors_rounded, color: rColor, size: 18),
                      ),
                      title: Text('${reading.dose.toStringAsFixed(1)} ppm*hr', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryNavy)),
                      subtitle: Text(
                        DateFormat('MMM dd, yyyy  •  HH:mm').format(reading.timestamp),
                        style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavyLight),
                      ),
                      trailing: Text(
                        reading.riskLevel,
                        style: TextStyle(color: rColor, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
