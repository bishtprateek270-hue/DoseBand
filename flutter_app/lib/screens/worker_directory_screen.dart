import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  void _showAddWorkerBottomSheet() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final deptController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedShift = 'Day Shift (08:00 - 16:00)';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.safetyOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.safetyOrange, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Register Worker',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: idController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Worker ID (e.g. W-106)*',
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
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name*',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deptController,
                        decoration: const InputDecoration(
                          labelText: 'Department / Unit*',
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
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Shift',
                          prefixIcon: Icon(Icons.schedule_rounded, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Day Shift (08:00 - 16:00)', child: Text('Day Shift (08:00 - 16:00)')),
                          DropdownMenuItem(value: 'Swing Shift (12:00 - 20:00)', child: Text('Swing Shift (12:00 - 20:00)')),
                          DropdownMenuItem(value: 'Night Shift (20:00 - 04:00)', child: Text('Night Shift (20:00 - 04:00)')),
                        ],
                        onChanged: (val) => setSheetState(() => selectedShift = val!),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.borderColor),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryNavyLight, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryNavy,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
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
                                      content: Text('✅ Worker ${newWorker.workerId} (${newWorker.name}) successfully registered!'),
                                      backgroundColor: AppTheme.safeGreen,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Register Worker'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
        onPressed: _showAddWorkerBottomSheet,
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, size: 19),
        label: const Text('Add Worker', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 18.0, 16.0, 90.0), // 90px bottom padding so FAB never overlaps
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Worker Roster',
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryNavy, letterSpacing: -0.6),
                      ),
                      const SizedBox(height: 2),
                      const Text(
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryNavy),
                      ),
                      const Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.primaryNavyLight, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Metrics Summary Bar
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
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by Name, ID, or Department...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryNavyLight, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Custom Segmented Risk Filters (Never clips or truncates)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCustomFilterChip('All', _workerService.workers.length),
                  const SizedBox(width: 8),
                  _buildCustomFilterChip('Safe', _workerService.workers.where((w) => w.riskLevel == 'Safe').length),
                  const SizedBox(width: 8),
                  _buildCustomFilterChip('Caution', _workerService.workers.where((w) => w.riskLevel == 'Caution').length),
                  const SizedBox(width: 8),
                  _buildCustomFilterChip('Unsafe', _workerService.workers.where((w) => w.riskLevel == 'Unsafe').length),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Workers List
            if (workers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkerDetailScreen(workerId: worker.workerId),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: worker.riskLevel == 'Unsafe' ? AppTheme.unsafeRed.withValues(alpha: 0.35) : AppTheme.borderColor,
                          width: worker.riskLevel == 'Unsafe' ? 1.2 : 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Worker ID Badge Avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: riskBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: riskColor.withValues(alpha: 0.25), width: 1.0),
                            ),
                            child: Center(
                              child: Text(
                                worker.workerId,
                                style: TextStyle(
                                  color: riskColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Worker Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        worker.name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppTheme.primaryNavy,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (worker.isBadgeExpired) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cautionYellowBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.cautionYellow.withValues(alpha: 0.4), width: 0.6),
                                        ),
                                        child: const Text(
                                          'EXPIRED',
                                          style: TextStyle(color: AppTheme.cautionYellow, fontSize: 8.5, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${worker.department} • ${worker.shift.split(' ').first}',
                                  style: const TextStyle(color: AppTheme.primaryNavyLight, fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.speed_rounded, size: 13, color: riskColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Exposure: ${worker.cumulativeDose.toStringAsFixed(1)} ppm·hr',
                                      style: TextStyle(
                                        color: riskColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Risk Badge & Arrow
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
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
                              const SizedBox(height: 8),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 18),
                            ],
                          ),
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
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                child: Icon(icon, color: color, size: 15),
              ),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.primaryNavyLight, letterSpacing: 0.4),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFilterChip(String label, int count) {
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
