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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dosimeter Scan Logs',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              const Text(
                'Historical log of all sensor wristband scans & readings',
                style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),

              // Filter Controls Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedWorkerFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryNavy),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Personnel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            ...workers.map((w) => DropdownMenuItem(
                                  value: w.workerId,
                                  child: Text('${w.workerId} (${w.name.split(' ').first})', style: const TextStyle(fontSize: 13)),
                                )),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedWorkerFilter = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Risk Filter Tabs
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.borderColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: ['All', 'Safe', 'Caution', 'Unsafe'].map((filter) {
                    final isSelected = _selectedRiskFilter == filter;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRiskFilter = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryNavy : AppTheme.primaryNavyLight,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.history_toggle_off_rounded, size: 40, color: AppTheme.primaryNavyLight),
                      SizedBox(height: 10),
                      Text('No scan records found matching filters.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: filteredReadings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final reading = filteredReadings[index];
                    final riskColor = _getRiskColor(reading.riskLevel);
                    final riskBg = _getRiskBgColor(reading.riskLevel);
                    final worker = _workerService.getWorkerById(reading.workerId);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 0.8),
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
                              '${reading.dose.toStringAsFixed(1)} ppm*hr',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryNavy),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '(${worker?.name ?? 'ID ${reading.workerId}'})',
                                style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Text(
                            DateFormat('MMM dd, yyyy  •  HH:mm').format(reading.timestamp),
                            style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 11),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: riskBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            reading.riskLevel.toUpperCase(),
                            style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
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
    );
  }
}
