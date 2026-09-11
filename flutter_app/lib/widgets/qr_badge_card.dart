import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/worker.dart';
import '../theme/app_theme.dart';
import '../utils/qr_generator.dart';

/// Official DoseBand Smart Badge Card Widget.
/// Renders an authentic industrial ID badge with crisp, scannable QR matrix.
/// 100% offline, zero network dependency, guaranteed instant load.
class QrBadgeCardWidget extends StatelessWidget {
  final Worker worker;
  final double width;

  const QrBadgeCardWidget({
    super.key,
    required this.worker,
    this.width = 340,
  });

  String get payload {
    final map = {
      'app': 'DoseBand',
      'worker_id': worker.workerId,
      'badge_id': worker.effectiveBadgeId,
      'version': '1.0',
    };
    return jsonEncode(map);
  }

  @override
  Widget build(BuildContext context) {
    final matrix = QrCodeGenerator.generateMatrix(payload);
    final isExpired = worker.isBadgeExpired;
    final isActive = worker.status == 'Active' && !isExpired;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark navy industrial chassis
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Industrial Safety Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: AppTheme.safetyOrange, width: 2.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.safetyOrangeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppTheme.safetyOrange, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DOSEBAND • INDUSTRIAL SAFETY BADGE',
                        style: TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'DGMS / OISD H₂S HAZARDOUS GAS COMPLIANCE',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Card Body (Worker Profile Info + Scannable QR Matrix)
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Worker Dossier Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('👷', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  worker.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  worker.workerId,
                                  style: const TextStyle(
                                    color: Color(0xFFFB923C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFF334155), height: 1),
                      const SizedBox(height: 8),

                      _buildInfoRow('DEPT:', worker.department),
                      _buildInfoRow('ZONE:', worker.workZone),
                      _buildInfoRow('SHIFT:', worker.shift),
                      _buildInfoRow('BADGE ID:', worker.effectiveBadgeId, isHighlight: true),
                      _buildInfoRow('EXPIRES:', worker.badgeExpiryDate, isExpiry: true),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right Column: Official Scannable QR Matrix
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            painter: QrCodePainter(
                              matrix: matrix,
                              color: const Color(0xFF0F172A),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SCAN AT SHIFT START',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isActive ? 'STATUS: ACTIVE • VERIFIED' : 'STATUS: EXPIRED / INACTIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, bool isExpiry = false}) {
    Color valColor = Colors.white;
    if (isHighlight) valColor = const Color(0xFF38BDF8);
    if (isExpiry) valColor = worker.isBadgeExpired ? AppTheme.unsafeRed : const Color(0xFFFCD34D);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valColor,
                fontSize: 9.5,
                fontWeight: isHighlight || isExpiry ? FontWeight.w900 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
