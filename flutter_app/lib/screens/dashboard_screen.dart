import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
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
          child: Text('No active workers registered in system.', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    }

    final activeWorker = _workerService.getWorkerById(_selectedWorkerId) ?? workers.first;
    const double unsafeThreshold = 50.0;
    final double progress = (activeWorker.cumulativeDose / unsafeThreshold).clamp(0.0, 1.0);
    final riskColor = _getRiskColor(activeWorker.riskLevel);
    final riskBg = _getRiskBgColor(activeWorker.riskLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
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
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryNavy, letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Real-Time H₂S Exposure Roster',
                      style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: workers.any((w) => w.workerId == _selectedWorkerId) ? _selectedWorkerId : workers.first.workerId,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryNavy, size: 20),
                    items: workers.map((w) {
                      return DropdownMenuItem<String>(
                        value: w.workerId,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                            Text(
                              w.workerId,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryNavy),
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
          const SizedBox(height: 16),

          // Overview Summary Cards Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'ACTIVE ROSTER',
                  value: '${_workerService.workers.length}',
                  subtext: '${_workerService.activeWorkersCount} On Shift',
                  icon: Icons.people_alt_outlined,
                  accentColor: AppTheme.accentIndigo,
                  bgColor: AppTheme.accentIndigo.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  title: 'EXPOSURE RISK',
                  value: '${_workerService.unsafeWorkersCount}',
                  subtext: _workerService.unsafeWorkersCount > 0 ? 'Requires Action' : 'All Clear',
                  icon: Icons.warning_amber_rounded,
                  accentColor: _workerService.unsafeWorkersCount > 0 ? AppTheme.unsafeRed : AppTheme.safeGreen,
                  bgColor: (_workerService.unsafeWorkersCount > 0 ? AppTheme.unsafeRed : AppTheme.safeGreen).withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Risk Banner (If unsafe)
          if (activeWorker.riskLevel == 'Unsafe' || activeWorker.cumulativeDose >= unsafeThreshold)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.unsafeRedBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.unsafeRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.unsafeRed.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: AppTheme.unsafeRed, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CRITICAL EXPOSURE: ${activeWorker.name} (${activeWorker.workerId})',
                          style: const TextStyle(color: AppTheme.unsafeRed, fontWeight: FontWeight.w800, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Exceeded DGMS/OSHA 50.0 ppm·hr limit. Immediate medical review required.',
                          style: TextStyle(fontSize: 11, color: AppTheme.primaryNavy, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Hero Active Worker Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
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
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.primaryNavy, letterSpacing: -0.4),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${activeWorker.workerId}  •  ${activeWorker.department}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Text(
                        activeWorker.riskLevel.toUpperCase(),
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Radial Exposure Gauge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 156,
                      width: 156,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: riskColor,
                        strokeWidth: 13,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeWorker.cumulativeDose.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: riskColor,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const Text(
                          'ppm • hr',
                          style: TextStyle(color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Standards compliant threshold label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 13, color: riskColor),
                      const SizedBox(width: 5),
                      Text(
                        'Unsafe Threshold: 50.0 ppm·hr',
                        style: TextStyle(fontSize: 11, color: AppTheme.primaryNavy, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkerDetailScreen(workerId: activeWorker.workerId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryNavy, size: 18),
                    label: const Text(
                      'View Detailed Worker Profile',
                      style: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Weekly Exposure Trend Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Weekly Dosimeter Trend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, letterSpacing: -0.3),
              ),
              Text(
                '7-Day Average',
                style: TextStyle(fontSize: 11, color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            height: 210,
            padding: const EdgeInsets.only(top: 20, right: 18, left: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.borderColor.withValues(alpha: 0.6),
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value % 15 == 0) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 10, fontWeight: FontWeight.w500),
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
                      FlSpot(6, 44.5),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppTheme.accentIndigo,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: AppTheme.accentIndigo,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.accentIndigo.withValues(alpha: 0.22),
                          AppTheme.accentIndigo.withValues(alpha: 0.0),
                        ],
                      ),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
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
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryNavyLight, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: accentColor, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
