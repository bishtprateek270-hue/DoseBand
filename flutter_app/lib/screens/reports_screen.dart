import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    Color statusColor = AppTheme.safeGreen;
    Color statusBg = const Color(0xFFECFDF5);
    if (complianceStatus.startsWith('CRITICAL')) {
      statusColor = AppTheme.unsafeRed;
      statusBg = const Color(0xFFFEF2F2);
    } else if (complianceStatus.startsWith('CAUTION')) {
      statusColor = AppTheme.cautionYellow;
      statusBg = const Color(0xFFFFFBEB);
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Safety Audit Reports',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Regulatory Banner Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.verified_user_rounded, color: statusColor, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'DGMS / OISD COMPLIANCE AUDIT',
                                  style: GoogleFonts.inter(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'AUDITED',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            complianceStatus,
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryNavy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Automated daily regulatory summary based on SQLite persistent database telemetry and OLS colorimetric analysis.',
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Audit Metrics Grid
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppTheme.safetyOrange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Audit Exposure Telemetry',
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _buildReportStatCard('Total Audited Scans', '$totalScans', Icons.receipt_long_outlined, const Color(0xFF0284C7)),
                        _buildReportStatCard('Monitored Roster', '${workers.length} Personnel', Icons.badge_outlined, const Color(0xFF059669)),
                        _buildReportStatCard('Avg Plant Dose', '${avgDose.toStringAsFixed(2)} ppm•h', Icons.cloud_done_outlined, const Color(0xFFD97706)),
                        _buildReportStatCard('Total Gas Inhaled', '${totalDose.toStringAsFixed(1)} ppm•h', Icons.speed_rounded, statusColor),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Worker-Specific Exposure Roster
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryNavy,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Personnel Exposure Audit',
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryNavy,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${workers.length} Total',
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workers.length,
                      itemBuilder: (context, idx) {
                        final w = workers[idx];
                        final isSafe = w.riskLevel == 'Safe';
                        final isCaution = w.riskLevel == 'Caution';
                        final riskColor = isSafe ? AppTheme.safeGreen : (isCaution ? AppTheme.cautionYellow : AppTheme.unsafeRed);
                        final riskBg = isSafe ? const Color(0xFFECFDF5) : (isCaution ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderColor),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primaryNavy, const Color(0xFF1E293B)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  w.workerId.replaceAll('W-', ''),
                                  style: GoogleFonts.inter(
                                    color: AppTheme.safetyOrange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${w.name} (${w.workerId})',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.primaryNavy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${w.department} • ${w.workZone}',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${w.cumulativeDose.toStringAsFixed(2)} ppm•h',
                                    style: GoogleFonts.inter(
                                      color: riskColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: riskBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      w.riskLevel.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: riskColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppTheme.primaryNavy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

