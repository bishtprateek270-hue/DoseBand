import 'package:flutter/material.dart';
import '../models/worker.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import 'worker_detail_screen.dart';

class WorkerDirectoryScreen extends StatefulWidget {
  const WorkerDirectoryScreen({Key? key}) : super(key: key);

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
                children: const [
                  Icon(Icons.person_add_alt_1, color: AppTheme.safetyOrange),
                  SizedBox(width: 10),
                  Text('Register New Worker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
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
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deptController,
                        decoration: const InputDecoration(
                          labelText: 'Department*',
                          prefixIcon: Icon(Icons.business_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Department is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Contact*',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Phone number required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Shift',
                          prefixIcon: Icon(Icons.schedule),
                          border: OutlineInputBorder(),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
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
        backgroundColor: AppTheme.safetyOrange,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Worker', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Worker Directory',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monitor industrial personnel exposure & credentials',
                      style: TextStyle(color: AppTheme.primaryNavyLight),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_workerService.workers.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy),
                      ),
                      const Text('Total Workers', style: TextStyle(fontSize: 10, color: AppTheme.primaryNavyLight)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Metrics Summary Bar
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Active',
                    value: '${_workerService.activeWorkersCount}',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.safeGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'High Risk',
                    value: '${_workerService.unsafeWorkersCount}',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.unsafeRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Expired Badges',
                    value: '${_workerService.expiredBadgesCount}',
                    icon: Icons.badge_outlined,
                    color: AppTheme.cautionYellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar & Risk Filters
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by Worker ID, Name, or Dept...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryNavyLight),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Risk Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Safe', 'Caution', 'Unsafe'].map((risk) {
                  final isSelected = _selectedRiskFilter == risk;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(risk),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.primaryNavy,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      selectedColor: risk == 'All'
                          ? AppTheme.primaryNavy
                          : _getRiskColor(risk),
                      backgroundColor: Colors.white,
                      onSelected: (val) => setState(() => _selectedRiskFilter = risk),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

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
                    Icon(Icons.search_off, size: 48, color: AppTheme.primaryNavyLight),
                    SizedBox(height: 12),
                    Text('No workers match your filter.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  final riskColor = _getRiskColor(worker.riskLevel);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: worker.riskLevel == 'Unsafe' ? AppTheme.unsafeRed.withOpacity(0.5) : AppTheme.borderColor,
                        width: worker.riskLevel == 'Unsafe' ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkerDetailScreen(workerId: worker.workerId),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: riskColor.withOpacity(0.15),
                        child: Text(
                          worker.workerId,
                          style: TextStyle(
                            color: riskColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            worker.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          if (worker.isBadgeExpired)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.unsafeRed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'EXPIRED BADGE',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${worker.department} • ${worker.shift}', style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.speed, size: 14, color: riskColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Cum Dose: ${worker.cumulativeDose.toStringAsFixed(1)} ppm*hr',
                                  style: TextStyle(color: riskColor, fontWeight: FontWeight.w600, fontSize: 12),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: riskColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              worker.riskLevel.toUpperCase(),
                              style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryNavyLight),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.primaryNavyLight)),
            ],
          ),
        ],
      ),
    );
  }
}
