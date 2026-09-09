import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import 'worker_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final WorkerService _workerService = WorkerService();
  String _selectedWorkerId = 'W-101';

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

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;
    if (workers.isEmpty) {
      return const Scaffold(body: Center(child: Text('No workers registered.')));
    }

    final activeWorker = _workerService.getWorkerById(_selectedWorkerId) ?? workers.first;
    const double unsafeThreshold = 50.0;
    final double progress = (activeWorker.cumulativeDose / unsafeThreshold).clamp(0.0, 1.0);
    final riskColor = _getRiskColor(activeWorker.riskLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Worker Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Worker Monitoring Dashboard',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Real-time H₂S Dosimetry & Safety Compliance',
                    style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 13),
                  ),
                ],
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: DropdownButton<String>(
                    value: workers.any((w) => w.workerId == _selectedWorkerId) ? _selectedWorkerId : workers.first.workerId,
                    items: workers.map((w) {
                      return DropdownMenuItem<String>(
                        value: w.workerId,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getRiskColor(w.riskLevel),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${w.workerId} (${w.name.split(' ').first})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedWorkerId = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overview Stats Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Active Roster',
                  value: '${_workerService.workers.length}',
                  subtext: '${_workerService.activeWorkersCount} On Shift',
                  icon: Icons.people_alt_outlined,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'High Exposure',
                  value: '${_workerService.unsafeWorkersCount}',
                  subtext: 'Requires Hold',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.unsafeRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Active Risk Banner
          if (activeWorker.riskLevel == 'Unsafe' || activeWorker.cumulativeDose >= unsafeThreshold)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.unsafeRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.unsafeRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.dangerous, color: AppTheme.unsafeRed, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CRITICAL ALERT: ${activeWorker.name} (${activeWorker.workerId})',
                          style: const TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Worker has reached or exceeded 50.0 ppm*hr cumulative limit. Initiate immediate medical check.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Active Worker Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Worker ${activeWorker.workerId} • ${activeWorker.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy),
                        ),
                        Text(
                          '${activeWorker.department} | ${activeWorker.shift}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        activeWorker.riskLevel.toUpperCase(),
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
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
                          activeWorker.cumulativeDose.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                        const Text(
                          'ppm*hr',
                          style: TextStyle(color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Safety Limit: ${unsafeThreshold.toStringAsFixed(1)} ppm*hr',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppTheme.safetyOrange),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerDetailScreen(workerId: activeWorker.workerId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline, color: AppTheme.safetyOrange),
                  label: const Text('View Full Worker Profile', style: TextStyle(color: AppTheme.safetyOrange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Weekly Exposure Trend Chart
          Text(
            'Weekly Cumulative Exposure Trend',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          Container(
            height: 220,
            padding: const EdgeInsets.only(top: 24, right: 24, left: 12, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3.2),
                      FlSpot(1, 8.5),
                      FlSpot(2, 14.0),
                      FlSpot(3, 22.1),
                      FlSpot(4, 34.5),
                      FlSpot(5, 42.0),
                    ],
                    isCurved: true,
                    color: AppTheme.safetyOrange,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.safetyOrange.withOpacity(0.1),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight)),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavyLight)),
        ],
      ),
    );
  }
}
