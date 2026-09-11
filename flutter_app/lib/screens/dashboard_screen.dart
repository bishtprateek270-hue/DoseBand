import 'package:flutter/material.dart';
import '../models/reading.dart';
import '../services/api_service.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final WorkerService _workerService = WorkerService();

  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  String _selectedWorkerFilter = 'All Workers';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getDashboardData();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;
    final readings = _workerService.readings;

    final summary = _dashboardData['summary'] as Map<String, dynamic>? ?? {};
    final int totalWorkers = summary['total_workers'] ?? workers.length;
    final int safePersonnel = summary['safe_personnel'] ?? workers.where((w) => w.riskLevel == 'Safe').length;
    final int warningStatus = summary['warning_status'] ?? workers.where((w) => w.riskLevel == 'Caution').length;
    final int criticalAlerts = summary['critical_alert'] ?? _workerService.unsafeWorkersCount;
    final int badgesNearExpiry = summary['badges_near_expiry'] ?? workers.where((w) => w.isBadgeExpired).length;

    final List<dynamic> attentionList = _dashboardData['workers_requiring_attention'] as List<dynamic>? ?? [];
    final List<dynamic> expiryAlerts = _dashboardData['expiry_alerts'] as List<dynamic>? ?? [];
    final List<dynamic> forecasts = _dashboardData['forecasts'] as List<dynamic>? ?? [];

    final filteredReadings = readings.where((r) {
      if (_selectedWorkerFilter == 'All Workers') return true;
      return r.workerId.toUpperCase() == _selectedWorkerFilter.toUpperCase();
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.safetyOrange))
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              color: AppTheme.safetyOrange,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.safetyOrangeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'PLANT OCCUPATIONAL SAFETY CONSOLE',
                        style: TextStyle(color: AppTheme.safetyOrange, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Industrial Health & Safety Dashboard',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                    ),
                    const Text(
                      'Real-time H₂S occupational dosimetry monitoring, cumulative exposure limits (DGMS / OISD), and badge shelf-life tracking.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),

                    // Top 5 Industrial KPI Cards (Matching Web)
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Total Workers', '$totalWorkers', Icons.people_outline, const Color(0xFF0F172A))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard('Safe Personnel', '$safePersonnel', Icons.check_circle_outline, AppTheme.safeGreen)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard('Warning Tier', '$warningStatus', Icons.warning_amber_rounded, AppTheme.cautionYellow)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Critical Alerts', '$criticalAlerts', Icons.dangerous_outlined, AppTheme.unsafeRed)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard('Badges Near Expiry', '$badgesNearExpiry', Icons.timer_outlined, const Color(0xFF0284C7))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Workers Requiring Attention (Matching Web)
                    const Text('🚨 Workers Requiring Attention', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const Text('Prioritized supervisory action list based on cumulative exposure and badge health.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),

                    if (attentionList.isNotEmpty)
                      ...attentionList.map((item) => _buildAttentionCard(item as Map<String, dynamic>))
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.safeGreenBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: AppTheme.safeGreen, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '✅ All Monitored Personnel in Safe Clearance (operating within permissible PEL limits).',
                                style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Section 2: Exposure Trend Forecasting & Workers At Risk (Matching Web)
                    const Text('📈 Exposure Trend Forecasting & Workers At Risk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const Text('Predictive trend analysis estimating recent daily accumulation rates and projected time to threshold.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(color: Color(0xFF0284C7), width: 3)),
                      ),
                      child: const Text(
                        'ℹ️ STATISTICAL PROJECTION NOTICE: Exposure forecasts are mathematical estimations calculated strictly from chronological SQLite scan intervals.',
                        style: TextStyle(fontSize: 10, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (forecasts.isNotEmpty)
                      ...forecasts.map((f) => _buildForecastCard(f as Map<String, dynamic>))
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Text(
                          'Forecasts will automatically calculate as workers log multiple chronological dosimeter scans.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Section 3: Badge Expiry Alerts
                    if (expiryAlerts.isNotEmpty) ...[
                      const Text('🛡️ Dosimeter Badge Expiry Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      ...expiryAlerts.map((alert) => _buildExpiryAlertCard(alert as Map<String, dynamic>)),
                      const SizedBox(height: 20),
                    ],

                    // Section 4: Logged Dosimeter Readings Table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📋 Dosimeter Scan History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        DropdownButton<String>(
                          value: _selectedWorkerFilter,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                          items: ['All Workers', ...workers.map((w) => w.workerId)].map((id) {
                            return DropdownMenuItem(value: id, child: Text(id));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedWorkerFilter = val!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (filteredReadings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Center(
                          child: Text('No dosimeter scan readings recorded yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ),
                      )
                    else
                      ...filteredReadings.take(15).map((r) => _buildReadingCard(r)),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttentionCard(Map<String, dynamic> item) {
    final String riskStatus = item['risk_status']?.toString() ?? 'WARNING';
    final bool isCritical = riskStatus.contains('CRITICAL') || riskStatus.contains('EXPIRED');
    final Color color = isCritical ? AppTheme.unsafeRed : AppTheme.cautionYellow;
    final Color bg = isCritical ? AppTheme.unsafeRedBg : AppTheme.cautionYellowBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isCritical ? Icons.dangerous_rounded : Icons.warning_amber_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item['name']} (${item['worker_id']})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                    ),
                    Text(
                      '${item['cumulative_dose'] ?? 0.0} ppm•h',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Zone: ${item['work_zone']} • Badge: ${item['badge_status']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Text('Action: ${item['action_needed']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(Map<String, dynamic> f) {
    final String status = f['status']?.toString() ?? '';
    if (status == 'insufficient_data') return const SizedBox.shrink();

    final String name = f['name']?.toString() ?? '';
    final String wid = f['worker_id']?.toString() ?? '';
    final String zone = f['work_zone']?.toString() ?? '';
    final String trendBadge = f['trend_badge']?.toString() ?? 'Stable';
    final String msg = f['forecast_message']?.toString() ?? '';
    final num? dailyRate = f['daily_rate'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$name ($wid)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(trendBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Zone: $zone | Accumulation Rate: ${dailyRate != null ? "+${dailyRate.toStringAsFixed(2)} ppm•h/day" : "—"}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(msg, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildExpiryAlertCard(Map<String, dynamic> alert) {
    final bool isExpired = alert['severity'] == 'EXPIRED';
    final Color color = isExpired ? AppTheme.unsafeRed : AppTheme.cautionYellow;
    final Color bg = isExpired ? AppTheme.unsafeRedBg : AppTheme.cautionYellowBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isExpired ? "❌ BADGE EXPIRED" : "⏳ EXPIRING SOON"}: ${alert['badge_id']}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
              ),
              Text(
                '${alert['days_left']}d',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Assigned to: ${alert['name']} (${alert['worker_id']}) • ${alert['zone']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildReadingCard(Reading r) {
    Color riskColor = AppTheme.safeGreen;
    if (r.riskLevel.startsWith('Unsafe')) {
      riskColor = AppTheme.unsafeRed;
    } else if (r.riskLevel.startsWith('Caution')) {
      riskColor = AppTheme.cautionYellow;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.workerId} • ${r.formattedDate}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text('${r.temperature}°C • ${r.humidity}% RH • Staining: ${(r.intensity * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.dose.toStringAsFixed(2)} ppm•h', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: riskColor)),
              Text(r.riskLevel.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: riskColor)),
            ],
          ),
        ],
      ),
    );
  }
}
