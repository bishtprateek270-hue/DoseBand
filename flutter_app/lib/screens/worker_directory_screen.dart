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

class _WorkerDirectoryScreenState extends State<WorkerDirectoryScreen> with SingleTickerProviderStateMixin {
  final WorkerService _workerService = WorkerService();
  late TabController _tabController;

  // Search & Filters for Tab 1
  String _searchQuery = '';
  String _selectedDept = 'All Departments';
  String _selectedZone = 'All Work Zones';
  String _selectedStatus = 'All Statuses';

  // State for Tab 2: Register Worker
  final _regFormKey = GlobalKey<FormState>();
  final _regIdController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regBadgeController = TextEditingController();
  String _regDept = 'Refinery Operations';
  String _regZone = 'Zone A - Crude Distillation Unit';
  String _regShift = 'Shift 1 (06:00 - 14:00)';
  String _regStatus = 'Active';
  DateTime _regIssueDate = DateTime.now();
  DateTime _regExpiryDate = DateTime.now().add(const Duration(days: 60));
  bool _isRegistering = false;

  // State for Tab 3: Edit Worker
  Worker? _editSelectedWorker;
  final _editFormKey = GlobalKey<FormState>();
  final _editNameController = TextEditingController();
  final _editBadgeController = TextEditingController();
  String _editDept = 'Refinery Operations';
  String _editZone = 'Zone A - Crude Distillation Unit';
  String _editShift = 'Shift 1 (06:00 - 14:00)';
  String _editStatus = 'Active';
  DateTime _editIssueDate = DateTime.now();
  DateTime _editExpiryDate = DateTime.now().add(const Duration(days: 60));
  bool _isEditing = false;

  // State for Tab 4: Delete Worker
  Worker? _delSelectedWorker;
  bool _confirmDelete = false;
  bool _isDeleting = false;

  final List<String> _deptOptions = [
    'Refinery Operations',
    'Pipeline Maintenance',
    'Safety & Inspection',
    'Chemical Laboratory',
    'Drilling & Extraction',
    'Storage & Flare Area',
    'Utilities & Power Plant',
    'Quality Assurance & Control',
  ];

  final List<String> _zoneOptions = [
    'Zone A - Crude Distillation Unit',
    'Zone B - Desulfurization Plant',
    'Zone C - Storage & Flare Area',
    'Zone D - Quality Control Lab',
    'Zone E - Wellhead Platform',
    'Zone F - Effluent Treatment Unit',
    'Zone G - Gas Compressor Station',
  ];

  final List<String> _shiftOptions = [
    'Shift 1 (06:00 - 14:00)',
    'Shift 2 (14:00 - 22:00)',
    'Shift 3 (22:00 - 06:00)',
    'General Shift (09:00 - 17:00)',
  ];

  final List<String> _statusOptions = ['Active', 'Inactive', 'On Leave'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _workerService.addListener(_onServiceUpdate);
    _workerService.fetchWorkers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _workerService.removeListener(_onServiceUpdate);
    _regIdController.dispose();
    _regNameController.dispose();
    _regBadgeController.dispose();
    _editNameController.dispose();
    _editBadgeController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _populateEditForm(Worker w) {
    setState(() {
      _editSelectedWorker = w;
      _editNameController.text = w.name;
      _editBadgeController.text = w.effectiveBadgeId;
      _editDept = _deptOptions.contains(w.department) ? w.department : _deptOptions.first;
      _editZone = _zoneOptions.contains(w.workZone) ? w.workZone : _zoneOptions.first;
      _editShift = _shiftOptions.contains(w.shift) ? w.shift : _shiftOptions.first;
      _editStatus = _statusOptions.contains(w.status) ? w.status : _statusOptions.first;

      try {
        _editIssueDate = DateTime.parse(w.badgeIssueDate);
      } catch (_) {
        _editIssueDate = DateTime.now();
      }

      try {
        _editExpiryDate = DateTime.parse(w.badgeExpiryDate);
      } catch (_) {
        _editExpiryDate = DateTime.now().add(const Duration(days: 60));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;
    final totalWorkers = workers.length;
    final activeWorkers = workers.where((w) => w.status == 'Active').length;
    final expiredCount = _workerService.unsafeWorkersCount;
    final totalZones = workers.map((w) => w.workZone).toSet().length;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.safetyOrangeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'PERSONNEL & DOSIMETRY LOGISTICS',
                        style: TextStyle(color: AppTheme.safetyOrange, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Worker & Badge Management',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                    ),
                    const Text(
                      'Safety Officer Console — Register, track, update, and manage plant personnel and dosimeter badges.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: [
                        _buildMetricTile('Total Workers', '$totalWorkers', Icons.people_outline, const Color(0xFF0F172A)),
                        _buildMetricTile('Active Personnel', '$activeWorkers', Icons.check_circle_outline, AppTheme.safeGreen),
                        _buildMetricTile('Expired / Expiring', '$expiredCount', Icons.warning_amber_rounded, AppTheme.unsafeRed),
                        _buildMetricTile('Monitored Zones', '$totalZones', Icons.location_on_outlined, const Color(0xFF0284C7)),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarHeaderDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.safetyOrange,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: AppTheme.safetyOrange,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'Directory'),
                    Tab(icon: Icon(Icons.person_add_alt_1_rounded, size: 18), text: 'Register'),
                    Tab(icon: Icon(Icons.edit_outlined, size: 18), text: 'Edit'),
                    Tab(icon: Icon(Icons.delete_outline_rounded, size: 18), text: 'Delete'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDirectoryTab(workers),
            _buildRegisterTab(),
            _buildEditTab(workers),
            _buildDeleteTab(workers),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: WORKER DIRECTORY ---
  Widget _buildDirectoryTab(List<Worker> workers) {
    final filtered = workers.where((w) {
      final matchesSearch = _searchQuery.isEmpty ||
          w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.workerId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.effectiveBadgeId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDept = _selectedDept == 'All Departments' || w.department == _selectedDept;
      final matchesZone = _selectedZone == 'All Work Zones' || w.workZone == _selectedZone;
      final matchesStatus = _selectedStatus == 'All Statuses' || w.status == _selectedStatus;
      return matchesSearch && matchesDept && matchesZone && matchesStatus;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _workerService.fetchWorkers(),
      color: AppTheme.safetyOrange,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by Name, Worker ID, or Badge ID...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Dept: $_selectedDept', () => _showDeptFilterDialog()),
                const SizedBox(width: 8),
                _buildFilterChip('Zone: $_selectedZone', () => _showZoneFilterDialog()),
                const SizedBox(width: 8),
                _buildFilterChip('Status: $_selectedStatus', () => _showStatusFilterDialog()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Showing ${filtered.length} of ${workers.length} registered personnel',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Center(
                child: Text('No personnel matching the active filter criteria.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...filtered.map((w) => _buildWorkerCard(w)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(Worker w) {
    Color riskColor = AppTheme.safeGreen;
    if (w.isBadgeExpired || w.status != 'Active' || w.cumulativeDose >= 50.0) {
      riskColor = AppTheme.unsafeRed;
    } else if (w.cumulativeDose >= 10.0) {
      riskColor = AppTheme.cautionYellow;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => WorkerDetailScreen(worker: w)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF0F172A),
                            child: Text(
                              w.workerId.replaceAll('W-', ''),
                              style: const TextStyle(color: AppTheme.safetyOrange, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                Text('${w.workerId} • ${w.department}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        w.isBadgeExpired ? 'EXPIRED' : (w.status != 'Active' ? w.status.toUpperCase() : 'ACTIVE'),
                        style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Zone: ${w.workZone.split(" - ").first}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      'Dose: ${w.cumulativeDose.toStringAsFixed(2)} ppm•h',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: riskColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Badge: ${w.effectiveBadgeId}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                    Text('Exp: ${w.badgeExpiryDate}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 2: REGISTER WORKER ---
  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _regFormKey,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('➕ Register New Plant Personnel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const Text('All fields are mandatory. Worker ID and Badge ID must be globally unique.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regIdController,
                decoration: const InputDecoration(labelText: 'Worker ID*', hintText: 'e.g. W-106'),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Worker ID is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regNameController,
                decoration: const InputDecoration(labelText: 'Full Name*', hintText: 'e.g. Kavita Sharma'),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Full Name is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _regDept,
                decoration: const InputDecoration(labelText: 'Department*'),
                items: _deptOptions.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _regDept = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _regZone,
                decoration: const InputDecoration(labelText: 'Work Zone / Unit*'),
                items: _zoneOptions.map((z) => DropdownMenuItem(value: z, child: Text(z, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _regZone = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _regShift,
                decoration: const InputDecoration(labelText: 'Shift Assignment*'),
                items: _shiftOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _regShift = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _regStatus,
                decoration: const InputDecoration(labelText: 'Worker Status*'),
                items: _statusOptions.map((st) => DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _regStatus = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regBadgeController,
                decoration: const InputDecoration(labelText: 'Dosimeter Badge ID*', hintText: 'e.g. BDG-106'),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Badge ID is required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('Issue: ${_regIssueDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _regIssueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _regIssueDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_busy_rounded, size: 16),
                      label: Text('Expiry: ${_regExpiryDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _regExpiryDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _regExpiryDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isRegistering
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.shield_rounded),
                  label: const Text('Register Worker & Issue Badge'),
                  onPressed: _isRegistering ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_regFormKey.currentState!.validate()) return;
    setState(() => _isRegistering = true);

    final newWorker = Worker(
      workerId: _regIdController.text.trim(),
      name: _regNameController.text.trim(),
      department: _regDept,
      workZone: _regZone,
      shift: _regShift,
      badgeId: _regBadgeController.text.trim(),
      badgeIssueDate: _regIssueDate.toIso8601String().substring(0, 10),
      badgeExpiryDate: _regExpiryDate.toIso8601String().substring(0, 10),
      status: _regStatus,
    );

    final success = await _workerService.addWorker(newWorker);
    setState(() => _isRegistering = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Worker ${newWorker.name} registered successfully!'), backgroundColor: AppTheme.safeGreen),
        );
        _regIdController.clear();
        _regNameController.clear();
        _regBadgeController.clear();
        _tabController.animateTo(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to register worker. Check duplicate Worker ID or Badge ID.'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  // --- TAB 3: EDIT WORKER ---
  Widget _buildEditTab(List<Worker> workers) {
    if (workers.isEmpty) {
      return const Center(child: Text('No registered workers available to edit.', style: TextStyle(color: AppTheme.textMuted)));
    }

    final currentSelected = _editSelectedWorker ?? workers.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _editFormKey,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✏️ Edit Registered Worker Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<Worker>(
                value: workers.firstWhere((w) => w.workerId == currentSelected.workerId, orElse: () => workers.first),
                decoration: const InputDecoration(labelText: 'Select Worker to Edit'),
                items: workers.map((w) {
                  return DropdownMenuItem(
                    value: w,
                    child: Text('${w.workerId} — ${w.name}', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (w) {
                  if (w != null) _populateEditForm(w);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: currentSelected.workerId,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Worker ID (Immutable)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _editNameController.text.isEmpty ? (TextEditingController(text: currentSelected.name)) : _editNameController,
                decoration: const InputDecoration(labelText: 'Full Name*'),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _editDept,
                decoration: const InputDecoration(labelText: 'Department*'),
                items: _deptOptions.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _editDept = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _editZone,
                decoration: const InputDecoration(labelText: 'Work Zone*'),
                items: _zoneOptions.map((z) => DropdownMenuItem(value: z, child: Text(z, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _editZone = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _editShift,
                decoration: const InputDecoration(labelText: 'Shift Assignment*'),
                items: _shiftOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _editShift = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _editStatus,
                decoration: const InputDecoration(labelText: 'Status*'),
                items: _statusOptions.map((st) => DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _editStatus = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _editBadgeController.text.isEmpty ? (TextEditingController(text: currentSelected.effectiveBadgeId)) : _editBadgeController,
                decoration: const InputDecoration(labelText: 'Badge ID*'),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Badge ID is required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('Issue: ${_editIssueDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _editIssueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _editIssueDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_busy_rounded, size: 16),
                      label: Text('Expiry: ${_editExpiryDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _editExpiryDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setState(() => _editExpiryDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isEditing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save Worker Changes'),
                  onPressed: _isEditing ? null : () => _handleEdit(currentSelected),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleEdit(Worker selected) async {
    setState(() => _isEditing = true);

    final updated = selected.copyWith(
      name: _editNameController.text.trim().isNotEmpty ? _editNameController.text.trim() : selected.name,
      department: _editDept,
      workZone: _editZone,
      shift: _editShift,
      status: _editStatus,
      badgeId: _editBadgeController.text.trim().isNotEmpty ? _editBadgeController.text.trim() : selected.badgeId,
      badgeIssueDate: _editIssueDate.toIso8601String().substring(0, 10),
      badgeExpiryDate: _editExpiryDate.toIso8601String().substring(0, 10),
    );

    final success = await _workerService.updateWorker(updated);
    setState(() => _isEditing = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Profile for ${updated.name} updated!'), backgroundColor: AppTheme.safeGreen),
        );
        _tabController.animateTo(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to update worker profile.'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  // --- TAB 4: DELETE WORKER ---
  Widget _buildDeleteTab(List<Worker> workers) {
    if (workers.isEmpty) {
      return const Center(child: Text('No registered workers available to delete.', style: TextStyle(color: AppTheme.textMuted)));
    }

    final currentSelected = _delSelectedWorker ?? workers.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🗑️ Remove Registered Worker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.unsafeRed)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Worker>(
              value: workers.firstWhere((w) => w.workerId == currentSelected.workerId, orElse: () => workers.first),
              decoration: const InputDecoration(labelText: 'Select Worker to Delete'),
              items: workers.map((w) {
                return DropdownMenuItem(
                  value: w,
                  child: Text('${w.workerId} — ${w.name}', style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (w) {
                if (w != null) setState(() => _delSelectedWorker = w);
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.unsafeRedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.unsafeRed.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ Danger: You are about to permanently delete:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.unsafeRed, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('• Name: ${currentSelected.name} (${currentSelected.workerId})', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                  Text('• Dept: ${currentSelected.department} | Zone: ${currentSelected.workZone}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                  Text('• Cumulative Dose: ${currentSelected.cumulativeDose.toStringAsFixed(2)} ppm•h', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('I confirm permanent removal of worker ${currentSelected.workerId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              value: _confirmDelete,
              onChanged: (v) => setState(() => _confirmDelete = v ?? false),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isDeleting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.delete_forever_rounded),
                label: const Text('Delete Worker Permanently'),
                onPressed: (_confirmDelete && !_isDeleting) ? () => _handleDelete(currentSelected) : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.unsafeRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete(Worker w) async {
    setState(() => _isDeleting = true);
    final success = await _workerService.deleteWorker(w.workerId);
    setState(() {
      _isDeleting = false;
      _confirmDelete = false;
      _delSelectedWorker = null;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Worker ${w.name} (${w.workerId}) deleted.'), backgroundColor: AppTheme.safeGreen),
        );
        _tabController.animateTo(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to delete worker.'), backgroundColor: AppTheme.unsafeRed),
        );
      }
    }
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600), maxLines: 1),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  void _showDeptFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        children: ['All Departments', ..._deptOptions].map((d) {
          return SimpleDialogOption(
            child: Text(d),
            onPressed: () {
              setState(() => _selectedDept = d);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showZoneFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by Work Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        children: ['All Work Zones', ..._zoneOptions].map((z) {
          return SimpleDialogOption(
            child: Text(z),
            onPressed: () {
              setState(() => _selectedZone = z);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        children: ['All Statuses', ..._statusOptions].map((s) {
          return SimpleDialogOption(
            child: Text(s),
            onPressed: () {
              setState(() => _selectedStatus = s);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) => false;
}
