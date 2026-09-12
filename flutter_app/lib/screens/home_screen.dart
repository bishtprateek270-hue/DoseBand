import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Capsule
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.safetyOrangeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.35), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.safetyOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'DGMS / OISD COMPLIANT • INDUSTRIAL DOSIMETRY',
                          style: TextStyle(
                            color: AppTheme.safetyOrange,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header Title
            const Text(
              'Industrial Gas Dosimetry Platform',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Precision optical colorimetric quantification & cumulative shift dose tracking for hazardous H₂S environments.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.35),
            ),
            const SizedBox(height: 16),


            // Quick Navigation Grid
            const Text(
              'Operational Modules',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.2),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Scan Strip',
                    badge: 'CAMERA / QR',
                    subtitle: 'Colorimetric optical gas analysis',
                    accentColor: AppTheme.safetyOrange,
                    onTap: () => onNavigate(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.badge_outlined,
                    title: 'Worker Registry',
                    badge: 'PERSONNEL',
                    subtitle: 'Badges & active dosimetry roster',
                    accentColor: const Color(0xFF0284C7),
                    onTap: () => onNavigate(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              icon: Icons.dashboard_outlined,
              title: 'Safety Dashboard & DGMS Analytics',
              badge: 'LIVE TELEMETRY',
              subtitle: 'Supervisory exposure trends, threshold forecasts, and SQLite database audit logs',
              accentColor: AppTheme.accentPurple,
              isFullWidth: true,
              onTap: () => onNavigate(3),
            ),
            const SizedBox(height: 20),

            // Platform Core Capabilities Bento Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.safetyOrangeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.hub_outlined, color: AppTheme.safetyOrange, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Core Safety Architecture',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildBentoItem(
                    emoji: '📸',
                    title: 'Adaptive Lighting Calibration',
                    desc: 'OLS chromatic normalization against reference white fiducials to eliminate environmental color casts.',
                  ),
                  const Divider(color: AppTheme.borderColor, height: 18),
                  _buildBentoItem(
                    emoji: '🧪',
                    title: 'HSV-V Perceptual Staining Metric',
                    desc: 'Evaluates colorimetric chemical shift on sensor substrate to calculate exact parts-per-million (PPM).',
                  ),
                  const Divider(color: AppTheme.borderColor, height: 18),
                  _buildBentoItem(
                    emoji: '🛡️',
                    title: 'Encrypted Offline-Native QR Badges',
                    desc: 'Instant field identification with zero cloud dependency; verifiable on-device via custom matrix renderer.',
                  ),
                  const Divider(color: AppTheme.borderColor, height: 18),
                  _buildBentoItem(
                    emoji: '📊',
                    title: 'DGMS / OISD Regulatory Compliance',
                    desc: 'Automated 8-hour TWA shift tracking and cumulative SQLite audit history logging.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Sync Notice Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.safeGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unified SQLite backend active. Real-time synchronization enabled across mobile & web dashboards.',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }


  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String badge,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: accentColor, letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                maxLines: isFullWidth ? 2 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: accentColor, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoItem({required String emoji, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
