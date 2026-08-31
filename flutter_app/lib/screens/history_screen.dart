import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'All'; // 'All', 'Safe', 'Unsafe'

  // Mock data
  final List<Reading> _allReadings = [
    Reading(
      id: '1',
      workerId: 'W-102',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      dose: 4.2,
      intensity: 0.15,
      riskLevel: 'Safe',
      isExpired: false,
      expiryStatusMessage: 'Valid',
    ),
    Reading(
      id: '2',
      workerId: 'W-102',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      dose: 12.5,
      intensity: 0.45,
      riskLevel: 'Caution',
      isExpired: false,
      expiryStatusMessage: 'Valid',
    ),
    Reading(
      id: '3',
      workerId: 'W-102',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      dose: 55.0,
      intensity: 0.85,
      riskLevel: 'Unsafe',
      isExpired: false,
      expiryStatusMessage: 'Valid',
    ),
  ];

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Safe': return AppTheme.safeGreen;
      case 'Caution': return AppTheme.cautionYellow;
      case 'Unsafe': return AppTheme.unsafeRed;
      default: return AppTheme.safeGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReadings = _allReadings.where((r) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Safe') return r.riskLevel == 'Safe';
      if (_selectedFilter == 'Unsafe') return r.riskLevel == 'Unsafe' || r.riskLevel == 'Caution';
      return true;
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
                'Exposure History',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              
              // Segmented Filter
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.borderColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: ['All', 'Safe', 'Unsafe'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isSelected ? [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                            ] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryNavy : AppTheme.primaryNavyLight,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 14,
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
        
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: filteredReadings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final reading = filteredReadings[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getRiskColor(reading.riskLevel),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    '${reading.dose.toStringAsFixed(1)} ppm*hr',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat('MMM dd, yyyy • HH:mm').format(reading.timestamp),
                      style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 13),
                    ),
                  ),
                  trailing: Text(
                    reading.riskLevel,
                    style: TextStyle(
                      color: _getRiskColor(reading.riskLevel),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
