import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO SECTION
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnimatedEntry(
                      delay: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.safetyOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.35), width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _pulseAnimation.value,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppTheme.safetyOrange,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.safetyOrange.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
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
                    ),
                    const SizedBox(height: 16),
                    _AnimatedEntry(
                      delay: 100,
                      child: const Text(
                        'Industrial Gas Dosimetry Platform',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _AnimatedEntry(
                      delay: 200,
                      child: const Text(
                        'Precision optical colorimetric quantification & cumulative shift dose tracking for hazardous H₂S environments.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // CONTENT SECTION
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility Live Pulse Metric Card
                    _AnimatedEntry(
                      delay: 300,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.3)),
                          boxShadow: AppTheme.elevatedShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.safeGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined, color: AppTheme.safeGreen, size: 14),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'FACILITY SAFETY INDEX: 98.5%',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.safeGreen, letterSpacing: 0.3),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) => Transform.scale(
                                        scale: 0.9 + (_pulseAnimation.value * 0.15),
                                        child: const Icon(Icons.bolt, color: AppTheme.safetyOrange, size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Text(
                                      'LIVE OLS MATRIX',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppTheme.safetyOrange, letterSpacing: 0.4),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 310) {
                                  // 2-row layout for very narrow devices
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('SHIFT HAZARD STATUS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.safeGreen, shape: BoxShape.circle)),
                                                    const SizedBox(width: 5),
                                                    const Flexible(child: Text('NOMINAL (SAFE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(height: 1, color: AppTheme.borderColor),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('STEL CEILING', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
                                                const SizedBox(height: 4),
                                                const Text('15.0 PPM', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.safetyOrange)),
                                              ],
                                            ),
                                          ),
                                          Container(width: 1, height: 28, color: AppTheme.borderColor),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text('8-HR TWA LIMIT', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
                                                const SizedBox(height: 4),
                                                const Text('10.0 PPM', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('SHIFT HAZARD STATUS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(color: AppTheme.safeGreen, shape: BoxShape.circle),
                                              ),
                                              const SizedBox(width: 5),
                                              const Expanded(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    'NOMINAL (SAFE)',
                                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(width: 1, height: 32, color: AppTheme.borderColor, margin: const EdgeInsets.symmetric(horizontal: 4)),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          const Text('STEL CEILING', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('15.0 PPM', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.safetyOrange)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(width: 1, height: 32, color: AppTheme.borderColor, margin: const EdgeInsets.symmetric(horizontal: 4)),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('8-HR TWA LIMIT', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text('10.0 PPM', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _AnimatedEntry(
                      delay: 400,
                      child: const Text(
                        'Operational Modules',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AnimatedEntry(
                      delay: 500,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 280) {
                            // Stack cards vertically on extreme narrow constraints
                            return Column(
                              children: [
                                _InteractiveActionCard(
                                  icon: Icons.camera_alt_rounded,
                                  title: 'Scan Strip',
                                  badge: 'CAMERA / QR',
                                  subtitle: 'Colorimetric optical gas analysis',
                                  accentColor: AppTheme.safetyOrange,
                                  isFullWidth: true,
                                  onTap: () => widget.onNavigate(1),
                                ),
                                const SizedBox(height: 12),
                                _InteractiveActionCard(
                                  icon: Icons.badge_outlined,
                                  title: 'Worker Registry',
                                  badge: 'PERSONNEL',
                                  subtitle: 'Badges & active dosimetry roster',
                                  accentColor: const Color(0xFF0284C7),
                                  isFullWidth: true,
                                  onTap: () => widget.onNavigate(2),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _InteractiveActionCard(
                                  icon: Icons.camera_alt_rounded,
                                  title: 'Scan Strip',
                                  badge: 'CAMERA / QR',
                                  subtitle: 'Colorimetric optical gas analysis',
                                  accentColor: AppTheme.safetyOrange,
                                  onTap: () => widget.onNavigate(1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InteractiveActionCard(
                                  icon: Icons.badge_outlined,
                                  title: 'Worker Registry',
                                  badge: 'PERSONNEL',
                                  subtitle: 'Badges & active dosimetry roster',
                                  accentColor: const Color(0xFF0284C7),
                                  onTap: () => widget.onNavigate(2),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AnimatedEntry(
                      delay: 600,
                      child: _InteractiveActionCard(
                        icon: Icons.dashboard_outlined,
                        title: 'Safety Dashboard & DGMS Analytics',
                        badge: 'LIVE TELEMETRY',
                        subtitle: 'Supervisory exposure trends, threshold forecasts, and SQLite database audit logs',
                        accentColor: AppTheme.accentPurple,
                        isFullWidth: true,
                        onTap: () => widget.onNavigate(3),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ----------------------------------------------------------------------
// WIDGETS
// ----------------------------------------------------------------------

class _AnimatedEntry extends StatelessWidget {
  final Widget child;
  final int delay;

  const _AnimatedEntry({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Ensure delay logic is applied to the animation startup using Future.delayed if needed, 
        // or just rely on a simple curve. To truly delay in TweenAnimationBuilder without extra packages, 
        // we can mathematically adjust the value based on a delayed start, but for simplicity here we just run it.
        // A true delay requires a custom StatefulWidget, so we'll just stagger by using a custom lerp.
        // Instead of true delay, we simulate it by clipping the first portion of the animation.
        final adjustedValue = math.max(0.0, (value - (delay / 1500)) / (1 - (delay / 1500))).clamp(0.0, 1.0);
        return Opacity(
          opacity: adjustedValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - adjustedValue)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _InteractiveActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String badge;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isFullWidth;

  const _InteractiveActionCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  State<_InteractiveActionCard> createState() => _InteractiveActionCardState();
}

class _InteractiveActionCardState extends State<_InteractiveActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.accentColor.withValues(alpha: 0.5) : AppTheme.borderColor,
            ),
            boxShadow: _isHovered 
              ? [BoxShadow(color: widget.accentColor.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))] 
              : AppTheme.cardShadow,
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
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.accentColor, size: 20),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.badge,
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: widget.accentColor, letterSpacing: 0.3),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
                maxLines: widget.isFullWidth ? 2 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: widget.accentColor, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
