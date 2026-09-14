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

  // Register form
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

  // Edit form
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

  // Delete
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
    _workerService.addListener(_onServiceUpdate);
    _workerService.fetchWorkers();
  }

  @override
  void dispose() {
    _workerService.removeListener(_onServiceUpdate);
    _regIdController.dispose();
    _regNameController.dispose();
    _regBadgeController.dispose();
    _editNameController.dispose();
    _editBadgeController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _populateEditForm(Worker w) {
    _editSelectedWorker = w;
    _editNameController.text = w.name;
    _editBadgeController.text = w.effectiveBadgeId;
    _editDept = _deptOptions.contains(w.department) ? w.department : _deptOptions.first;
    _editZone = _zoneOptions.contains(w.workZone) ? w.workZone : _zoneOptions.first;
    _editShift = _shiftOptions.contains(w.shift) ? w.shift : _shiftOptions.first;
    _editStatus = _statusOptions.contains(w.status) ? w.status : _statusOptions.first;
    try { _editIssueDate = DateTime.parse(w.badgeIssueDate); } catch (_) { _editIssueDate = DateTime.now(); }
    try { _editExpiryDate = DateTime.parse(w.badgeExpiryDate); } catch (_) { _editExpiryDate = DateTime.now().add(const Duration(days: 60)); }
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;
    final activeWorkers = workers.where((w) => w.status == 'Active').length;
    final expiredCount = _workerService.unsafeWorkersCount;

    final filtered = workers.where((w) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return w.name.toLowerCase().contains(q) ||
          w.workerId.toLowerCase().contains(q) ||
          w.effectiveBadgeId.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Worker Directory',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${workers.length} personnel · $activeWorkers active · $expiredCount need attention',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search name, ID or badge…',
                        hintStyle: const TextStyle(color: AppTheme.textFaint, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderColor),

            // ── ACTION BUTTONS (Register / Edit / Delete) ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _ActionButton(
                    label: 'Register',
                    icon: Icons.person_add_alt_1_rounded,
                    color: AppTheme.safetyOrange,
                    onTap: () => _showRegisterSheet(),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF0284C7),
                    onTap: workers.isEmpty ? null : () => _showEditSheet(workers),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    color: AppTheme.unsafeRed,
                    onTap: workers.isEmpty ? null : () => _showDeleteSheet(workers),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderColor),

            // ── WORKER LIST ──
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _workerService.fetchWorkers(),
                color: AppTheme.safetyOrange,
                child: filtered.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 60),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, size: 48, color: AppTheme.textFaint),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty ? 'No workers registered yet.' : 'No results found.',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _WorkerTile(
                          worker: filtered[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => WorkerDetailScreen(worker: filtered[i])),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // REGISTER BOTTOM SHEET
  // ─────────────────────────────────────────────
  void _showRegisterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildSheet(
        title: 'Register New Worker',
        icon: Icons.person_add_alt_1_rounded,
        iconColor: AppTheme.safetyOrange,
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return Form(
            key: _regFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetField(controller: _regIdController, label: 'Worker ID*', hint: 'e.g. W-106'),
                _SheetField(controller: _regNameController, label: 'Full Name*', hint: 'e.g. Kavita Sharma'),
                _SheetDropdown(
                  label: 'Department*', value: _regDept, items: _deptOptions,
                  onChanged: (v) => setSheet(() => _regDept = v!),
                ),
                _SheetDropdown(
                  label: 'Work Zone*', value: _regZone, items: _zoneOptions,
                  onChanged: (v) => setSheet(() => _regZone = v!),
                ),
                _SheetDropdown(
                  label: 'Shift*', value: _regShift, items: _shiftOptions,
                  onChanged: (v) => setSheet(() => _regShift = v!),
                ),
                _SheetDropdown(
                  label: 'Status*', value: _regStatus, items: _statusOptions,
                  onChanged: (v) => setSheet(() => _regStatus = v!),
                ),
                _SheetField(controller: _regBadgeController, label: 'Badge ID*', hint: 'e.g. BDG-106'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _DateTile(
                    label: 'Issue Date',
                    date: _regIssueDate,
                    onTap: () async {
                      final d = await _pickDate(ctx, _regIssueDate);
                      if (d != null) setSheet(() => _regIssueDate = d);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _DateTile(
                    label: 'Expiry Date',
                    date: _regExpiryDate,
                    onTap: () async {
                      final d = await _pickDate(ctx, _regExpiryDate);
                      if (d != null) setSheet(() => _regExpiryDate = d);
                    },
                  )),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.safetyOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isRegistering ? null : () async {
                      if (!_regFormKey.currentState!.validate()) return;
                      setSheet(() => _isRegistering = true);
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
                      final ok = await _workerService.addWorker(newWorker);
                      setSheet(() => _isRegistering = false);
                      if (!mounted) return;
                      Navigator.pop(context);
                      _regIdController.clear();
                      _regNameController.clear();
                      _regBadgeController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '✅ ${newWorker.name} registered!' : '❌ Failed. Check duplicate IDs.'),
                        backgroundColor: ok ? AppTheme.safeGreen : AppTheme.unsafeRed,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                    child: _isRegistering
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Register & Issue Badge', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // EDIT BOTTOM SHEET
  // ─────────────────────────────────────────────
  void _showEditSheet(List<Worker> workers) {
    if (_editSelectedWorker == null) _populateEditForm(workers.first);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildSheet(
        title: 'Edit Worker Profile',
        icon: Icons.edit_outlined,
        iconColor: const Color(0xFF0284C7),
        child: StatefulBuilder(builder: (ctx, setSheet) {
          final selected = _editSelectedWorker ?? workers.first;
          return Form(
            key: _editFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Worker selector
                _SheetDropdown(
                  label: 'Select Worker',
                  value: workers.firstWhere((w) => w.workerId == selected.workerId, orElse: () => workers.first).workerId,
                  items: workers.map((w) => '${w.workerId} — ${w.name}').toList(),
                  rawItems: workers.map((w) => w.workerId).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      final w = workers.firstWhere((x) => x.workerId == v);
                      setSheet(() => _populateEditForm(w));
                    }
                  },
                ),
                _SheetField(controller: _editNameController, label: 'Full Name*', hint: 'Full name'),
                _SheetDropdown(
                  label: 'Department*', value: _editDept, items: _deptOptions,
                  onChanged: (v) => setSheet(() => _editDept = v!),
                ),
                _SheetDropdown(
                  label: 'Work Zone*', value: _editZone, items: _zoneOptions,
                  onChanged: (v) => setSheet(() => _editZone = v!),
                ),
                _SheetDropdown(
                  label: 'Shift*', value: _editShift, items: _shiftOptions,
                  onChanged: (v) => setSheet(() => _editShift = v!),
                ),
                _SheetDropdown(
                  label: 'Status*', value: _editStatus, items: _statusOptions,
                  onChanged: (v) => setSheet(() => _editStatus = v!),
                ),
                _SheetField(controller: _editBadgeController, label: 'Badge ID*', hint: 'Badge ID'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _DateTile(
                    label: 'Issue Date',
                    date: _editIssueDate,
                    onTap: () async {
                      final d = await _pickDate(ctx, _editIssueDate);
                      if (d != null) setSheet(() => _editIssueDate = d);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _DateTile(
                    label: 'Expiry Date',
                    date: _editExpiryDate,
                    onTap: () async {
                      final d = await _pickDate(ctx, _editExpiryDate);
                      if (d != null) setSheet(() => _editExpiryDate = d);
                    },
                  )),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isEditing ? null : () async {
                      setSheet(() => _isEditing = true);
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
                      final ok = await _workerService.updateWorker(updated);
                      setSheet(() => _isEditing = false);
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '✅ ${updated.name} updated!' : '❌ Failed to update.'),
                        backgroundColor: ok ? AppTheme.safeGreen : AppTheme.unsafeRed,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                    child: _isEditing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // DELETE BOTTOM SHEET
  // ─────────────────────────────────────────────
  void _showDeleteSheet(List<Worker> workers) {
    _delSelectedWorker ??= workers.first;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildSheet(
        title: 'Delete Worker',
        icon: Icons.delete_outline_rounded,
        iconColor: AppTheme.unsafeRed,
        child: StatefulBuilder(builder: (ctx, setSheet) {
          final selected = _delSelectedWorker ?? workers.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetDropdown(
                label: 'Select Worker to Remove',
                value: workers.firstWhere((w) => w.workerId == selected.workerId, orElse: () => workers.first).workerId,
                items: workers.map((w) => '${w.workerId} — ${w.name}').toList(),
                rawItems: workers.map((w) => w.workerId).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setSheet(() {
                      _delSelectedWorker = workers.firstWhere((x) => x.workerId == v);
                      _confirmDelete = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.unsafeRedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.unsafeRed.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.unsafeRed)),
                    const SizedBox(height: 4),
                    Text('${selected.workerId} · ${selected.department}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text('Cumulative Dose: ${selected.cumulativeDose.toStringAsFixed(2)} ppm•h', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _confirmDelete,
                    activeColor: AppTheme.unsafeRed,
                    onChanged: (v) => setSheet(() => _confirmDelete = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Confirm permanent removal of ${selected.workerId}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _confirmDelete ? AppTheme.unsafeRed : AppTheme.borderColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_confirmDelete && !_isDeleting) ? () async {
                    setSheet(() => _isDeleting = true);
                    final ok = await _workerService.deleteWorker(selected.workerId);
                    setSheet(() { _isDeleting = false; _confirmDelete = false; _delSelectedWorker = null; });
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? '✅ ${selected.name} deleted.' : '❌ Failed to delete.'),
                      backgroundColor: ok ? AppTheme.safeGreen : AppTheme.unsafeRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  } : null,
                  child: _isDeleting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w800, color: _confirmDelete ? Colors.white : AppTheme.textMuted)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  Future<DateTime?> _pickDate(BuildContext ctx, DateTime initial) => showDatePicker(
    context: ctx,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );

  Widget _buildSheet({required String title, required IconData icon, required Color iconColor, required Widget child}) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.borderColor),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WORKER TILE — Compact & Clickable
// ─────────────────────────────────────────────
class _WorkerTile extends StatelessWidget {
  final Worker worker;
  final VoidCallback onTap;
  const _WorkerTile({required this.worker, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppTheme.safeGreen;
    Color statusBg = AppTheme.safeGreenBg;
    String statusLabel = 'ACTIVE';

    if (worker.isBadgeExpired) {
      statusColor = AppTheme.unsafeRed;
      statusBg = AppTheme.unsafeRedBg;
      statusLabel = 'EXPIRED';
    } else if (worker.cumulativeDose >= 50.0 || worker.status != 'Active') {
      statusColor = AppTheme.unsafeRed;
      statusBg = AppTheme.unsafeRedBg;
      statusLabel = worker.status != 'Active' ? worker.status.toUpperCase() : 'UNSAFE';
    } else if (worker.cumulativeDose >= 10.0) {
      statusColor = AppTheme.cautionYellow;
      statusBg = AppTheme.cautionYellowBg;
      statusLabel = 'CAUTION';
    }

    // Parse shift end time for display
    String shiftEnd = '';
    final shiftStr = worker.shift;
    final dashIdx = shiftStr.indexOf(' - ');
    if (dashIdx != -1) {
      final end = shiftStr.substring(dashIdx + 3).replaceAll(')', '').trim();
      shiftEnd = end;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${worker.workerId} · ${worker.department}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.textFaint),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            shiftEnd.isNotEmpty ? '${worker.shift} · ends $shiftEnd' : worker.shift,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textFaint),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            worker.workZone.split(' - ').first,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${worker.cumulativeDose.toStringAsFixed(1)} ppm•h',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTION BUTTON (Register / Edit / Delete)
// ─────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: disabled ? AppTheme.surfaceElevated : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: disabled ? AppTheme.borderColor : color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: disabled ? AppTheme.textFaint : color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: disabled ? AppTheme.textFaint : color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHEET HELPERS
// ─────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _SheetField({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppTheme.scaffoldBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.safetyOrange, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        validator: (val) => (val == null || val.trim().isEmpty) ? '$label is required' : null,
      ),
    );
  }
}

class _SheetDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final List<String>? rawItems;
  final ValueChanged<String?> onChanged;
  const _SheetDropdown({required this.label, required this.value, required this.items, required this.onChanged, this.rawItems});

  @override
  Widget build(BuildContext context) {
    final values = rawItems ?? items;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : values.first,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppTheme.scaffoldBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.safetyOrange, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          labelStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        items: List.generate(items.length, (i) => DropdownMenuItem(
          value: values[i],
          child: Text(items[i], style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
        )),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.safetyOrange),
              const SizedBox(width: 5),
              Text(date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ]),
          ],
        ),
      ),
    );
  }
}
