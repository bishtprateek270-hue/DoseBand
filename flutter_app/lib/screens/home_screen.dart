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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.safetyOrangeBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.45), width: 1.2),
              ),
              child: const Text(
                'SAFETY FIRST • INDUSTRIAL DOSIMETRY',
                style: TextStyle(
                  color: AppTheme.safetyOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Header & Subtitle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('🛡️', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DoseBand',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Industrial H₂S Dosimeter Platform',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Scan your exposure wristband to track cumulative H2S dose.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // Industrial Hero Card (Matching Web Dark Icon Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('⌚️☣️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  const Text(
                    'DoseBand Optical Dosimeter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFB923C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Real-time optical colorimetric dosimetry for field worker safety',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.safetyOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'DEVELOPED BY TEAM DOSEBAND',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFB923C),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Feature Highlights Box (Matching Web Home)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Industrial H₂S Safety Monitoring Platform',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow('🏷️', 'Worker Tracking', 'Automated identification & cumulative exposure dose logging.'),
                  const SizedBox(height: 10),
                  _buildFeatureRow('📸', 'Camera Calibration', 'Per-channel Ordinary Least Squares (OLS) lighting correction.'),
                  const SizedBox(height: 10),
                  _buildFeatureRow('🧪', 'Colorimetric Analytics', 'Perception-aligned HSV Value (V) channel staining score.'),
                  const SizedBox(height: 10),
                  _buildFeatureRow('🚨', 'DGMS / OISD Compliance', 'Automated cumulative limit alerts and SQLite safety database logging.'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Navigation Action Buttons
            const Text('Quick Navigation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.camera_alt_rounded,
                    title: 'Scan Strip',
                    subtitle: 'Dosimeter Analysis',
                    color: AppTheme.safetyOrange,
                    onTap: () => onNavigate(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.badge_outlined,
                    title: 'Workers',
                    subtitle: 'Personnel Registry',
                    color: const Color(0xFF10B981),
                    onTap: () => onNavigate(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard & Analytics',
              subtitle: 'DGMS / OISD Plant Safety Intelligence',
              color: const Color(0xFF8B5CF6),
              onTap: () => onNavigate(3),
            ),
            const SizedBox(height: 24),

            // Offline Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected to unified SQLite backend. Changes sync live across Web and Mobile.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
