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
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.safetyOrange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1, color: AppTheme.safetyOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Register Worker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary)),
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
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Worker ID (e.g. W-105)*',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.textMuted),
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
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Full Name*',
                          prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deptController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Department*',
                          prefixIcon: Icon(Icons.business_outlined, size: 20, color: AppTheme.textMuted),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Department is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Contact*',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppTheme.textMuted),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Phone number required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedShift,
                        dropdownColor: AppTheme.surfaceCard,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Assigned Shift',
                          prefixIcon: Icon(Icons.schedule, size: 20, color: AppTheme.textMuted),
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
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
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
                      _workerService.addWorker(worker: newWorker);
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
                  child: const Text('Register Worker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Worker Roster',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Personnel dosimeter compliance tracking',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_workerService.workers.length}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          const Text(
                            'TOTAL',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textFaint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Top KPI summary boxes
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat(
                        'ACTIVE',
                        '${_workerService.activeWorkersCount}',
                        Icons.check_circle_outline,
                        AppTheme.safeGreen,
                        AppTheme.safeGreenBg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniStat(
                        'HIGH RISK',
                        '${_workerService.unsafeWorkersCount}',
                        Icons.warning_amber_rounded,
                        AppTheme.unsafeRed,
                        AppTheme.unsafeRedBg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniStat(
                        'EXPIRED',
                        '${_workerService.expiredBadgesCount}',
                        Icons.badge_outlined,
                        AppTheme.cautionYellow,
                        AppTheme.cautionYellowBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Input Field
                TextField(
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by Name, ID, or Department...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Segmented Risk Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', _workerService.workers.length),
                      const SizedBox(width: 6),
                      _buildFilterChip('Safe', _workerService.workers.where((w) => w.riskLevel == 'Safe').length),
                      const SizedBox(width: 6),
                      _buildFilterChip('Caution', _workerService.workers.where((w) => w.riskLevel == 'Caution').length),
                      const SizedBox(width: 6),
                      _buildFilterChip('Unsafe', _workerService.workers.where((w) => w.riskLevel == 'Unsafe').length),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Worker Roster List
          Expanded(
            child: workers.isEmpty
                ? Center(
                    child: Text(
                      'No workers found.',
                      style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: workers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final worker = workers[index];
                      final riskColor = _getRiskColor(worker.riskLevel);
                      final riskBg = _getRiskBgColor(worker.riskLevel);

                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: worker.riskLevel == 'Unsafe' ? AppTheme.unsafeRed.withValues(alpha: 0.5) : AppTheme.borderColor,
                          ),
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
                              Expanded(
                                child: Text(
                                  worker.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: riskBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  worker.riskLevel.toUpperCase(),
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
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${worker.department}  •  ${worker.shift.split(' ').first}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.speed_rounded, size: 13, color: riskColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Exposure: ${worker.cumulativeDose.toStringAsFixed(1)} ppm*hr',
                                      style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                    if (worker.isBadgeExpired) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppTheme.unsafeRedBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('EXPIRED', style: TextStyle(color: AppTheme.unsafeRed, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.textFaint, size: 20),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkerDialog,
        backgroundColor: AppTheme.surfaceDeep,
        icon: const Icon(Icons.person_add, color: AppTheme.safetyOrange),
        label: const Text('Add Worker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
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
