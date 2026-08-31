import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final double cumulativeDose = 12.5;
  final double unsafeThreshold = 50.0;
  final String currentRisk = 'Caution'; 

  Color _getRiskColor() {
    switch (currentRisk) {
      case 'Safe': return AppTheme.safeGreen;
      case 'Caution': return AppTheme.cautionYellow;
      case 'Unsafe': return AppTheme.unsafeRed;
      default: return AppTheme.safeGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = (cumulativeDose / unsafeThreshold).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Worker W-102',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.safetyOrange,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
              CircleAvatar(
                backgroundColor: AppTheme.borderColor,
                radius: 24,
                child: const Icon(Icons.person, color: AppTheme.primaryNavyLight),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Premium Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _getRiskColor().withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: _getRiskColor().withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryNavyLight,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRiskColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentRisk.toUpperCase(),
                        style: TextStyle(
                          color: _getRiskColor(),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: AppTheme.borderColor,
                        color: _getRiskColor(),
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cumulativeDose.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 36,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        Text(
                          'ppm*hr',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Threshold: ${unsafeThreshold.toStringAsFixed(1)} ppm*hr',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryNavyLight,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          Text(
            'Weekly Trend',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          // Chart Section
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
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
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
                      FlSpot(0, 2),
                      FlSpot(1, 4),
                      FlSpot(2, 6.5),
                      FlSpot(3, 7.8),
                      FlSpot(4, 10.2),
                      FlSpot(5, 12.5),
                    ],
                    isCurved: true,
                    color: AppTheme.safetyOrange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.safetyOrange.withOpacity(0.1),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
