import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/worker.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';

class WorkerDetailScreen extends StatefulWidget {
  final String workerId;
  const WorkerDetailScreen({Key? key, required this.workerId}) : super(key: key);

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

  void _showEmergencyDialog(Worker worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: AppTheme.unsafeRed),
            SizedBox(width: 10),
            Text('Emergency Contact Alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Initiating direct call & SMS broadcast for Worker ${worker.workerId} (${worker.name}).'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📞 Contact: ${worker.emergencyContact}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('🏢 Department: ${worker.department}'),
                  Text('⚠️ Exposure: ${worker.cumulativeDose.toStringAsFixed(1)} ppm*hr'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.unsafeRed),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Emergency alert broadcasted to ${worker.emergencyContact}!'),
                  backgroundColor: AppTheme.unsafeRed,
                ),
              );
            },
            icon: const Icon(Icons.phone),
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
        appBar: AppBar(title: const Text('Worker Details')),
        body: const Center(child: Text('Worker not found.')),
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
            icon: const Icon(Icons.phone_forwarded, color: AppTheme.unsafeRed),
            onPressed: () => _showEmergencyDialog(worker),
            tooltip: 'Call Emergency Contact',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Worker Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryNavy.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white24,
                    child: Text(
                      worker.workerId,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          worker.department,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          worker.shift,
                          style: const TextStyle(color: AppTheme.safetyOrange, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      worker.riskLevel.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Warning Banners
            if (worker.riskLevel == 'Unsafe' || worker.cumulativeDose >= threshold) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.unsafeRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.unsafeRed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppTheme.unsafeRed, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('HIGH CUMULATIVE EXPOSURE ALERT', style: TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Worker exceeds 50.0 ppm*hr safe threshold. Work stoppage and medical review required.', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (worker.isBadgeExpired) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cautionYellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cautionYellow),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('DOSIMETER BADGE EXPIRED', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Passive shelf-life expired. Please issue a new sensor wristband.', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Cumulative Dose Gauge Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cumulative Exposure Dose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Max Limit: 50.0 ppm*hr', style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 140,
                        width: 140,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: AppTheme.borderColor,
                          color: riskColor,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            worker.cumulativeDose.toStringAsFixed(1),
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: riskColor),
                          ),
                          const Text('ppm*hr', style: TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.borderColor,
                    color: riskColor,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Emergency Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.unsafeRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _showEmergencyDialog(worker),
                    icon: const Icon(Icons.phone_in_talk),
                    label: const Text('Emergency Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.primaryNavy),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Safety compliance report generated for Worker ${worker.workerId}.')),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryNavy),
                    label: const Text('Export Report', style: TextStyle(color: AppTheme.primaryNavy)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Worker Scan History Log
            Text('Scan History Log (${readings.length})', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            if (readings.isEmpty)
              const Text('No scan readings recorded for this worker yet.', style: TextStyle(color: AppTheme.primaryNavyLight))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: readings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final reading = readings[index];
                  final rColor = _getRiskColor(reading.riskLevel);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: rColor.withOpacity(0.15),
                        child: Icon(Icons.sensors, color: rColor, size: 20),
                      ),
                      title: Text('${reading.dose.toStringAsFixed(1)} ppm*hr', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${DateFormat('MMM dd, yyyy • HH:mm').format(reading.timestamp)} • ${reading.expiryStatusMessage}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight),
                      ),
                      trailing: Text(
                        reading.riskLevel,
                        style: TextStyle(color: rColor, fontWeight: FontWeight.bold),
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
