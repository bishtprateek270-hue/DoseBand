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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dosimeter Scan History',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Comprehensive log of all worker dosimeter readings',
                style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Filter Row: Worker Dropdown & Risk Filter
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
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('Filter: All Workers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
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
              const SizedBox(height: 12),

              // Segmented Risk Filter
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.borderColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: ['All', 'Safe', 'Caution', 'Unsafe'].map((filter) {
                    final isSelected = _selectedRiskFilter == filter;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRiskFilter = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryNavy : AppTheme.primaryNavyLight,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
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
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.history_toggle_off, size: 48, color: AppTheme.primaryNavyLight),
                      SizedBox(height: 12),
                      Text('No readings match your filter criteria.', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredReadings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reading = filteredReadings[index];
                    final riskColor = _getRiskColor(reading.riskLevel);
                    final worker = _workerService.getWorkerById(reading.workerId);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              reading.workerId,
                              style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              '${reading.dose.toStringAsFixed(1)} ppm*hr',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${worker?.name ?? 'Worker ${reading.workerId}'})',
                              style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${DateFormat('MMM dd, yyyy • HH:mm').format(reading.timestamp)} • Intensity: ${reading.intensity.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            reading.riskLevel.toUpperCase(),
                            style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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
