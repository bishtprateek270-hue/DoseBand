import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import 'worker_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dosimeter Scan History',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 20,
                    ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Audit-ready record of all worker dosimeter readings',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Filter Row: Worker Dropdown & Risk Filter
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedWorkerFilter,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('Filter: All Workers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))),
                            ...workers.map((w) => DropdownMenuItem(
                                  value: w.workerId,
                                  child: Text('${w.workerId} (${w.name.split(' ').first})', style: const TextStyle(fontSize: 13, color: Colors.white)),
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
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_toggle_off, size: 48, color: Color(0xFF64748B)),
                      SizedBox(height: 12),
                      Text('No readings match your filter criteria.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredReadings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final reading = filteredReadings[index];
                    final riskColor = _getRiskColor(reading.riskLevel);
                    final riskBg = _getRiskBgColor(reading.riskLevel);
                    final worker = _workerService.getWorkerById(reading.workerId);

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          width: 44,
                          height: 44,
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
                              '${reading.estimatedH2sPpm.toStringAsFixed(1)} ppm',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${reading.dose.toStringAsFixed(1)} ppm·hr)',
                              style: const TextStyle(color: AppTheme.safetyOrange, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• ${worker?.name ?? reading.workerId}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${DateFormat('MMM dd, yyyy • HH:mm').format(reading.timestamp)} • ${reading.temperature.toStringAsFixed(0)}°C, ${reading.humidity.toStringAsFixed(0)}% RH • ${reading.exposureTime.toStringAsFixed(1)}h shift',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
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
    final color = label == 'All' ? const Color(0xFF38BDF8) : _getRiskColor(label);

    return GestureDetector(
      onTap: () => setState(() => _selectedRiskFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.4) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
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
