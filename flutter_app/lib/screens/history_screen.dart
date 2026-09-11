import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import 'worker_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final WorkerService _workerService = WorkerService();
  String _selectedRiskFilter = 'All'; // 'All', 'Safe', 'Caution', 'Unsafe'
  String _selectedWorkerFilter = 'All'; // 'All' or specific Worker ID

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
    final readings = _workerService.readings;
    final workers = _workerService.workers;

    final filteredReadings = readings.where((r) {
      final matchesRisk = _selectedRiskFilter == 'All' || r.riskLevel == _selectedRiskFilter;
      final matchesWorker = _selectedWorkerFilter == 'All' || r.workerId.toUpperCase() == _selectedWorkerFilter.toUpperCase();
      return matchesRisk && matchesWorker;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dosimeter Scan History',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryNavy,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Audit-ready record of all worker dosimeter readings',
                style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),

              // Filter Row: Worker Dropdown & Risk Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWorkerFilter,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryNavy, size: 20),
                    items: [
                      const DropdownMenuItem(
                        value: 'All',
                        child: Text('Filter: All Workers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      ...workers.map((w) => DropdownMenuItem(
                            value: w.workerId,
                            child: Text('${w.workerId} - ${w.name}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedWorkerFilter = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Segmented Risk Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', readings.length),
                    const SizedBox(width: 8),
                    _buildFilterChip('Safe', readings.where((r) => r.riskLevel == 'Safe').length),
                    const SizedBox(width: 8),
                    _buildFilterChip('Caution', readings.where((r) => r.riskLevel == 'Caution').length),
                    const SizedBox(width: 8),
                    _buildFilterChip('Unsafe', readings.where((r) => r.riskLevel == 'Unsafe').length),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Readings List
        Expanded(
          child: filteredReadings.isEmpty
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.history_toggle_off_rounded, size: 44, color: AppTheme.primaryNavyLight),
                      SizedBox(height: 12),
                      Text('No readings match your filter criteria.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filteredReadings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final reading = filteredReadings[index];
                    final riskColor = _getRiskColor(reading.riskLevel);
                    final riskBg = _getRiskBgColor(reading.riskLevel);
                    final worker = _workerService.getWorkerById(reading.workerId);

                    return InkWell(
                      onTap: () {
                        if (worker != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkerDetailScreen(workerId: worker.workerId),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: reading.riskLevel == 'Unsafe' ? AppTheme.unsafeRed.withValues(alpha: 0.35) : AppTheme.borderColor,
                            width: reading.riskLevel == 'Unsafe' ? 1.2 : 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Worker ID Badge
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: riskBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: riskColor.withValues(alpha: 0.25), width: 1.0),
                              ),
                              child: Center(
                                child: Text(
                                  reading.workerId,
                                  style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 11.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Main Details (Never overflows)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${reading.estimatedH2sPpm.toStringAsFixed(1)} ppm',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryNavy),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${reading.dose.toStringAsFixed(1)} ppm·hr)',
                                        style: const TextStyle(color: AppTheme.safetyOrange, fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    worker?.name ?? reading.workerId,
                                    style: const TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.w600, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy • HH:mm').format(reading.timestamp),
                                    style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${reading.temperature.toStringAsFixed(0)}°C, ${reading.humidity.toStringAsFixed(0)}% RH • ${reading.exposureTime.toStringAsFixed(1)}h shift',
                                    style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 10.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Risk Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: riskBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 0.8),
                              ),
                              child: Text(
                                reading.riskLevel.toUpperCase(),
                                style: TextStyle(
                                  color: riskColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9.5,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedRiskFilter == label;
    final color = label == 'All' ? AppTheme.primaryNavy : _getRiskColor(label);

    return InkWell(
      onTap: () => setState(() => _selectedRiskFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.primaryNavy,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.22) : AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.primaryNavyLight,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
