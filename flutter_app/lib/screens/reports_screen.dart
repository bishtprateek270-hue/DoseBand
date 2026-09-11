import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _apiService = ApiService();
  final WorkerService _workerService = WorkerService();

  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};
  String _selectedWorkerFilter = 'All Workers';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getReportsSummary();
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readings = _workerService.readings;
    final workers = _workerService.workers;

    final int totalScans = _reportData['total_scans'] ?? readings.length;
    final double totalDose = (_reportData['total_dose'] as num?)?.toDouble() ??
        (readings.isNotEmpty ? readings.map((r) => r.dose).reduce((a, b) => a + b) : 0.0);
    final double avgDose = (_reportData['avg_dose'] as num?)?.toDouble() ??
        (readings.isNotEmpty ? totalDose / readings.length : 0.0);
    final String complianceStatus = _reportData['overall_compliance']?.toString() ??
        (readings.any((r) => r.dose >= 50.0) ? 'CRITICAL NON-COMPLIANCE' : 'COMPLIANT (Within Safe DGMS Limits)');
    final String complianceColorHex = _reportData['compliance_color']?.toString() ??
        (complianceStatus.startsWith('CRITICAL') ? '#EF4444' : '#10B981');

    Color statusColor = AppTheme.safeGreen;
    if (complianceStatus.startsWith('CRITICAL')) {
      statusColor = AppTheme.unsafeRed;
    } else if (complianceStatus.startsWith('CAUTION')) {
      statusColor = AppTheme.cautionYellow;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Safety Audit Reports', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
        backgroundColor: AppTheme.surfaceCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.safetyOrange),
            onPressed: _loadReport,
            tooltip: 'Refresh Audit Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.safetyOrange))
          : RefreshIndicator(
              onRefresh: _loadReport,
              color: AppTheme.safetyOrange,
              backgroundColor: AppTheme.surfaceCard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compliance Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: statusColor, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'DGMS / OISD COMPLIANCE AUDIT',
                                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            complianceStatus,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Automated daily regulatory summary based on SQLite persistent database telemetry.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Audit Metrics Grid
                    const Text('Audit Exposure Telemetry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.7,
                      children: [
                        _buildReportStatCard('Total Audited Scans', '$totalScans', Icons.receipt_long_outlined, const Color(0xFF38BDF8)),
                        _buildReportStatCard('Monitored Roster', '${workers.length} Personnel', Icons.badge_outlined, const Color(0xFF34D399)),
                        _buildReportStatCard('Avg Plant Dose', '${avgDose.toStringAsFixed(2)} ppm•h', Icons.cloud_done_outlined, const Color(0xFFFBBF24)),
                        _buildReportStatCard('Total Gas Inhaled', '${totalDose.toStringAsFixed(1)} ppm•h', Icons.speed_rounded, statusColor),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Worker-Specific Exposure Roster
                    const Text('Personnel Exposure Audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workers.length,
                      itemBuilder: (context, idx) {
                        final w = workers[idx];
                        final isSafe = w.riskLevel == 'Safe';
                        final isCaution = w.riskLevel == 'Caution';
                        final riskColor = isSafe ? AppTheme.safeGreen : (isCaution ? AppTheme.cautionYellow : AppTheme.unsafeRed);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF0F172A),
                                child: Text(w.workerId.replaceAll('W-', ''), style: const TextStyle(color: AppTheme.safetyOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${w.name} (${w.workerId})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${w.department} • ${w.workZone}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${w.cumulativeDose.toStringAsFixed(2)} ppm•h', style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 13)),
                                  Text(w.riskLevel.toUpperCase(), style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
