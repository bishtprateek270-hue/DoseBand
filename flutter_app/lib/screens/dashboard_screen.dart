import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import 'worker_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;
    if (workers.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No active workers registered in system.', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ),
      );
    }

    final activeWorker = _workerService.getWorkerById(_selectedWorkerId) ?? workers.first;
    const double unsafeThreshold = 50.0;
    final double progress = (activeWorker.cumulativeDose / unsafeThreshold).clamp(0.0, 1.0);
    final riskColor = _getRiskColor(activeWorker.riskLevel);
    final riskBg = _getRiskBgColor(activeWorker.riskLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Worker Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Real-Time H₂S Exposure Roster',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceCard,
                      value: workers.any((w) => w.workerId == _selectedWorkerId) ? _selectedWorkerId : workers.first.workerId,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textPrimary, size: 20),
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
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  w.workerId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
              ),
            ],
          ),
          const SizedBox(height: 18),

          // KPI Metric Cards Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'ACTIVE ROSTER',
                  value: '${_workerService.activeWorkersCount}',
                  subtitle: '${workers.where((w) => w.status == 'On Shift').length} On Shift',
                  icon: Icons.badge_outlined,
                  iconColor: AppTheme.accentCyan,
                  bgColor: AppTheme.surfaceCard,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'EXPOSURE RISK',
                  value: '${_workerService.unsafeWorkersCount}',
                  subtitle: 'Requires Action',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppTheme.unsafeRed,
                  bgColor: AppTheme.surfaceCard,
                  valueColor: _workerService.unsafeWorkersCount > 0 ? AppTheme.unsafeRed : AppTheme.safeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Worker Active Exposure Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeWorker.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${activeWorker.workerId}  •  ${activeWorker.department}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Text(
                        activeWorker.riskLevel.toUpperCase(),
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Radial Exposure Gauge
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: AppTheme.surfaceDeep,
                          valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeWorker.cumulativeDose.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: riskColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Text(
                            'ppm • hr',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Safe Threshold Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Safe Threshold: $unsafeThreshold ppm*hr',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // View Details Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: AppTheme.textPrimary,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkerDetailScreen(workerId: activeWorker.workerId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.safetyOrange),
                    label: const Text('View Detailed Worker Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Weekly Trend Chart Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Dosimeter Trend',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
              ),
              const Text(
                '7-Day Average',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.fromLTRB(14, 20, 18, 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 15,
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: AppTheme.borderColor.withValues(alpha: 0.5),
                      strokeWidth: 0.8,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 20,
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt().toString(),
                          style: const TextStyle(color: AppTheme.textFaint, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (val.toInt() >= 0 && val.toInt() < days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                days[val.toInt()],
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: 60,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 4.2),
                        FlSpot(1, 8.5),
                        FlSpot(2, 12.0),
                        FlSpot(3, 24.5),
                        FlSpot(4, 38.0),
                        FlSpot(5, 42.0),
                        FlSpot(6, 45.2),
                      ],
                      isCurved: true,
                      color: AppTheme.accentCyan,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 3.5,
                          color: AppTheme.surfaceCard,
                          strokeWidth: 2,
                          strokeColor: AppTheme.accentCyan,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accentCyan.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: valueColor ?? AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textFaint, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
