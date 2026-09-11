import 'package:flutter/material.dart';
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

    return Container(
      color: AppTheme.scaffoldBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dosimeter Scan History',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Audit-ready record of all worker dosimeter readings',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),

                // Filter Row: Worker Dropdown & Risk Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWorkerFilter,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('Filter: All Workers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textPrimary))),
                        ...workers.map((w) => DropdownMenuItem(
                              value: w.workerId,
                              child: Text('${w.workerId} (${w.name.split(' ').first})', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 44, color: AppTheme.textFaint),
                        SizedBox(height: 12),
                        Text('No readings match your filter criteria.', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filteredReadings.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final reading = filteredReadings[index];
                      final riskColor = _getRiskColor(reading.riskLevel);
                      final riskBg = _getRiskBgColor(reading.riskLevel);
                      final worker = _workerService.getWorkerById(reading.workerId);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: riskBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1.0),
                            ),
                            child: Center(
                              child: Text(
                                reading.workerId,
                                style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${reading.estimatedH2sPpm.toStringAsFixed(1)} ppm',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${reading.dose.toStringAsFixed(1)} ppm·hr)',
                                style: const TextStyle(color: AppTheme.safetyOrange, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '• ${worker?.name ?? reading.workerId}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: Text(
                              '${DateFormat('MMM dd, yyyy • HH:mm').format(reading.timestamp)} • ${reading.temperature.toStringAsFixed(0)}°C, ${reading.humidity.toStringAsFixed(0)}% RH • ${reading.exposureTime.toStringAsFixed(1)}h shift',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: riskBg,
                              borderRadius: BorderRadius.circular(6),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedRiskFilter == label;
    final color = label == 'All' ? AppTheme.safetyOrange : _getRiskColor(label);

    return GestureDetector(
      onTap: () => setState(() => _selectedRiskFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? color : AppTheme.textMuted,
                  fontWeight: FontWeight.w900,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
