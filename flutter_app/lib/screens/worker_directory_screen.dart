import 'package:flutter/material.dart';
import '../models/worker.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import 'worker_detail_screen.dart';

class WorkerDirectoryScreen extends StatefulWidget {
  const WorkerDirectoryScreen({super.key});

  @override
  State<WorkerDirectoryScreen> createState() => _WorkerDirectoryScreenState();
}

class _WorkerDirectoryScreenState extends State<WorkerDirectoryScreen> {
  final WorkerService _workerService = WorkerService();
  String _searchQuery = '';
  String _selectedRiskFilter = 'All'; // 'All', 'Safe', 'Caution', 'Unsafe'

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

  void _showAddWorkerDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final deptController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedShift = 'Day Shift (08:00 - 16:00)';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.safetyOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1, color: AppTheme.safetyOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Register Worker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: idController,
                        decoration: const InputDecoration(
                          labelText: 'Worker ID (e.g. W-105)*',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Worker ID is required';
                          if (_workerService.getWorkerById(value.trim()) != null) return 'Worker ID already exists';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name*',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deptController,
                        decoration: const InputDecoration(
                          labelText: 'Department*',
                          prefixIcon: Icon(Icons.business_outlined, size: 20),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Department is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Contact*',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Phone number required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Shift',
                          prefixIcon: Icon(Icons.schedule, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Day Shift (08:00 - 16:00)', child: Text('Day Shift (08-16)')),
                          DropdownMenuItem(value: 'Swing Shift (12:00 - 20:00)', child: Text('Swing Shift (12-20)')),
                          DropdownMenuItem(value: 'Night Shift (20:00 - 04:00)', child: Text('Night Shift (20-04)')),
                        ],
                        onChanged: (val) => setDialogState(() => selectedShift = val!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryNavyLight)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final newWorker = Worker(
                        workerId: idController.text.trim().toUpperCase(),
                        name: nameController.text.trim(),
                        department: deptController.text.trim(),
                        shift: selectedShift,
                        emergencyContact: phoneController.text.trim(),
                        status: 'Active',
                      );
                      _workerService.addWorker(newWorker);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Worker ${newWorker.workerId} (${newWorker.name}) registered!'),
                          backgroundColor: AppTheme.safeGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Register Worker'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers.where((w) {
      final matchesSearch = w.workerId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.department.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRisk = _selectedRiskFilter == 'All' || w.riskLevel == _selectedRiskFilter;
      return matchesSearch && matchesRisk;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkerDialog,
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('Add Worker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Worker Roster',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, letterSpacing: -0.5),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Personnel dosimeter compliance tracking',
                        style: TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_workerService.workers.length}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryNavy),
                      ),
                      const Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.primaryNavyLight, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Metrics Summary Bar (Completely Overflow-proof!)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Active',
                    value: '${_workerService.activeWorkersCount}',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppTheme.safeGreen,
                    bgColor: AppTheme.safeGreenBg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    label: 'High Risk',
                    value: '${_workerService.unsafeWorkersCount}',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.unsafeRed,
                    bgColor: AppTheme.unsafeRedBg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Expired',
                    value: '${_workerService.expiredBadgesCount}',
                    icon: Icons.badge_outlined,
                    color: AppTheme.cautionYellow,
                    bgColor: AppTheme.cautionYellowBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by Name, ID, or Department...',
                hintStyle: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryNavyLight, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Segmented Risk Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Safe', 'Caution', 'Unsafe'].map((risk) {
                  final isSelected = _selectedRiskFilter == risk;
                  final riskColor = risk == 'All' ? AppTheme.primaryNavy : _getRiskColor(risk);
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      label: Text(risk),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.primaryNavy,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      selectedColor: riskColor,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? riskColor : AppTheme.borderColor,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) => setState(() => _selectedRiskFilter = risk),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Workers List
            if (workers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.search_off_rounded, size: 40, color: AppTheme.primaryNavyLight),
                    SizedBox(height: 10),
                    Text('No personnel record matches criteria.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  final riskColor = _getRiskColor(worker.riskLevel);
                  final riskBg = _getRiskBgColor(worker.riskLevel);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: worker.riskLevel == 'Unsafe' ? AppTheme.unsafeRed.withValues(alpha: 0.4) : AppTheme.borderColor,
                        width: worker.riskLevel == 'Unsafe' ? 1.2 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkerDetailScreen(workerId: worker.workerId),
                          ),
                        );
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
                            worker.workerId,
                            style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              worker.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryNavy),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (worker.isBadgeExpired) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.unsafeRedBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.unsafeRed.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'EXPIRED',
                                style: TextStyle(color: AppTheme.unsafeRed, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${worker.department} • ${worker.shift.split(' ').first}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.speed_rounded, size: 13, color: riskColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Exposure: ${worker.cumulativeDose.toStringAsFixed(1)} ppm*hr',
                                  style: TextStyle(color: riskColor, fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: riskBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              worker.riskLevel.toUpperCase(),
                              style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primaryNavyLight),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Overflow-proof vertical tile design
  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color, letterSpacing: -0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.primaryNavyLight, letterSpacing: 0.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
