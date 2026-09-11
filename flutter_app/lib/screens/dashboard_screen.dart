import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/app_config.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import 'worker_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final WorkerService _workerService = WorkerService();
  String _selectedWorkerId = 'W-101';
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _workerService.addListener(_onServiceUpdate);
    _workerService.refreshFromBackend();
  }

  @override
  void dispose() {
    _workerService.removeListener(_onServiceUpdate);
    _urlController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Color _getRiskColor(String riskLevel) {
    if (riskLevel.startsWith('Unsafe')) return AppTheme.unsafeRed;
    if (riskLevel == 'Caution') return AppTheme.cautionYellow;
    return AppTheme.safeGreen;
  }

  void _showServerConfigDialog() {
    _urlController.text = AppConfig.apiBaseUrl;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Row(
          children: const [
            Icon(Icons.dns_rounded, color: AppTheme.safetyOrange, size: 24),
            SizedBox(width: 8),
            Text('Server Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure the DoseBand Python REST API base URL for mobile connection:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'API Base URL',
                labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                hintText: 'http://10.0.2.2:8000 or http://192.168.x.x:8000',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Android Emulator: http://10.0.2.2:8000\n• Physical Phone: http://<YOUR_LAN_IP>:8000\n• Production: https://api.yourdomain.com',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppConfig.resetBaseUrl();
              Navigator.pop(context);
              _workerService.refreshFromBackend();
            },
            child: const Text('Reset Default', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safetyOrange),
            onPressed: () {
              if (_urlController.text.isNotEmpty) {
                AppConfig.setRuntimeBaseUrl(_urlController.text);
              }
              Navigator.pop(context);
              _workerService.refreshFromBackend();
            },
            child: const Text('Save & Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workerService.workers;
    final readings = _workerService.readings;
    final isConnected = _workerService.isConnected;

    // Computed plant stats matching Web Dashboard
    final int totalWorkers = workers.length;
    final int activeWorkers = workers.where((w) => w.status == 'Active').length;
    final int totalReadings = readings.length;
    final double avgPpm = readings.isNotEmpty
        ? (readings.map((r) => r.estimatedH2sPpm).reduce((a, b) => a + b) / readings.length)
        : 0.0;
    final int criticalAlerts = readings.where((r) => r.riskLevel.startsWith('Unsafe')).length;
    final double complianceRate = totalReadings > 0
        ? ((1.0 - (criticalAlerts / totalReadings)) * 100).clamp(0.0, 100.0)
        : 100.0;

    final activeWorker = _workerService.getWorkerById(_selectedWorkerId) ?? (workers.isNotEmpty ? workers.first : null);

    return RefreshIndicator(
      onRefresh: () => _workerService.refreshFromBackend(),
      color: AppTheme.safetyOrange,
      backgroundColor: AppTheme.surfaceCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // 1. Live Backend Connection Bar
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.bottom(16),
              decoration: BoxDecoration(
                color: isConnected ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFF7F1D1D).withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isConnected ? AppTheme.safeGreen.withOpacity(0.4) : AppTheme.unsafeRed.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? AppTheme.safeGreen : AppTheme.unsafeRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isConnected
                          ? 'Python REST API Connected • ${AppConfig.apiBaseUrl}'
                          : 'API Disconnected • Local Caching Active',
                      style: TextStyle(
                        color: isConnected ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _showServerConfigDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.settings_outlined, size: 16, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // 2. Header & Plant Safety Title
            // -----------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Plant Safety Dashboard',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'DGMS / OISD H₂S Gas Exposure Monitoring',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.safetyOrange),
                  tooltip: 'Sync with Backend',
                  onPressed: () => _workerService.refreshFromBackend(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // -----------------------------------------------------------------
            // 3. Top KPI Metric Grid (Matching Web App)
            // -----------------------------------------------------------------
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _buildKpiCard('Total Scans', '$totalReadings', 'All shifts recorded', Icons.analytics_outlined, const Color(0xFF38BDF8)),
                _buildKpiCard('Active Workers', '$activeWorkers / $totalWorkers', 'Monitored personnel', Icons.people_alt_outlined, const Color(0xFF34D399)),
                _buildKpiCard('Avg H₂S Level', '${avgPpm.toStringAsFixed(2)} ppm', 'Plant baseline', Icons.cloud_outlined, const Color(0xFFFBBF24)),
                _buildKpiCard('Critical Alerts', '$criticalAlerts', criticalAlerts > 0 ? 'Exceeds STEL limit' : 'Zero exceedances', Icons.warning_amber_rounded, criticalAlerts > 0 ? AppTheme.unsafeRed : AppTheme.safeGreen),
              ],
            ),
            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // 4. Worker Spotlight & Exposure Limit Gauge
            // -----------------------------------------------------------------
            if (activeWorker != null) ...[
              const Text('Worker Exposure Spotlight', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              _buildWorkerSpotlightCard(context, activeWorker, workers),
              const SizedBox(height: 20),
            ],

            // -----------------------------------------------------------------
            // 5. Work Zone Risk Heatmap Cards
            // -----------------------------------------------------------------
            const Text('Work Zone Hazardous Gas Heatmap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            _buildZoneHeatmap(),
            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // 6. Recent Dosimeter Scans Feed
            // -----------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Dosimeter Scans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${readings.length} total', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            if (readings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Center(
                  child: Text('No sensor readings logged yet. Scan a strip to record exposure.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: readings.length > 5 ? 5 : readings.length,
                itemBuilder: (context, index) {
                  final r = readings[index];
                  final w = _workerService.getWorkerById(r.workerId);
                  final riskColor = _getRiskColor(r.riskLevel);
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.sensor_occupied_rounded, color: riskColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${w?.name ?? "Worker"} (${r.workerId})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                '${r.estimatedH2sPpm.toStringAsFixed(2)} ppm H₂S • ${r.exposureTime} hr shift',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: riskColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: riskColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                r.riskLevel.toUpperCase(),
                                style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
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
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            overflow: TextOverflow.ellipsis,
          ),
          Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildWorkerSpotlightCard(BuildContext context, Worker worker, List<Worker> workers) {
    const double unsafeThreshold = 50.0;
    final double progress = (worker.cumulativeDose / unsafeThreshold).clamp(0.0, 1.0);
    final riskColor = _getRiskColor(worker.riskLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
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
                    Text(worker.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('${worker.department} • ${worker.workZone}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: worker.workerId,
                    items: workers.map((w) {
                      return DropdownMenuItem<String>(
                        value: w.workerId,
                        child: Text(w.workerId, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedWorkerId = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('8-Hour Cumulative Exposure:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              Text('${worker.cumulativeDose.toStringAsFixed(2)} / 50.0 ppm•h', style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Badge: ${worker.effectiveBadgeId} (${worker.isBadgeExpired ? "EXPIRED" : "ACTIVE"})',
                style: TextStyle(
                  color: worker.isBadgeExpired ? AppTheme.unsafeRed : AppTheme.safeGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WorkerDetailScreen(worker: worker)),
                  );
                },
                child: Row(
                  children: const [
                    Text('View Full History', style: TextStyle(color: AppTheme.safetyOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.safetyOrange),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneHeatmap() {
    final zones = [
      {'name': 'Zone A - Crude Distillation', 'workers': 2, 'avgPpm': 1.34, 'risk': 'Normal'},
      {'name': 'Zone B - Desulfurization Plant', 'workers': 1, 'avgPpm': 14.20, 'risk': 'Elevated'},
      {'name': 'Zone C - Storage & Flare Area', 'workers': 1, 'avgPpm': 58.40, 'risk': 'Critical'},
      {'name': 'Zone D - Quality Control Lab', 'workers': 1, 'avgPpm': 4.20, 'risk': 'Normal'},
    ];

    return Column(
      children: zones.map((z) {
        final String risk = z['risk'] as String;
        Color riskColor = AppTheme.safeGreen;
        if (risk == 'Critical') riskColor = AppTheme.unsafeRed;
        if (risk == 'Elevated') riskColor = AppTheme.cautionYellow;

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
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(z['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('${z['workers']} active workers assigned', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${z['avgPpm']} ppm', style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(risk, style: TextStyle(color: riskColor, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
