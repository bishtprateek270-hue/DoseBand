import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Cinematic Sub-Animations
  late Animation<double> _introScale;
  late Animation<double> _introFade;
  late Animation<double> _axisRotationZ;
  late Animation<double> _axisRotationX;
  late Animation<double> _explodeProgress;
  late Animation<double> _convergeProgress;
  late Animation<double> _outroFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );

    // 1. Intro Entrance Scale & Fade (0ms - 800ms)
    _introScale = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOutCubic),
      ),
    );

    _introFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    // 2. Vertical to Horizontal 3D Axis Rotation (0ms - 1600ms)
    // Starts at vertical angle (pi / 2 = 1.5708 rad) and rotates to horizontal angle (0.08 rad)
    _axisRotationZ = Tween<double>(begin: math.pi / 2, end: 0.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.32, curve: Curves.easeInOutCubic),
      ),
    );

    _axisRotationX = Tween<double>(begin: -0.05, end: -0.48).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.32, curve: Curves.easeInOutCubic),
      ),
    );

    // 3. 3-Layer Opening Explosion (1600ms - 3640ms)
    _explodeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.68, curve: Curves.fastOutSlowIn),
      ),
    );

    // 4. Layer Convergence Back to Complete Wristband (3900ms - 4680ms)
    _convergeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 0.90, curve: Curves.easeInOutCubic),
      ),
    );

    // 5. Outro Fade (4780ms - 5200ms)
    _outroFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.92, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _proceedToMain();
      }
    });

    _controller.forward();
  }

  void _proceedToMain() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigation(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeTransition = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          final scaleTransition = Tween<double>(begin: 0.98, end: 1.0).animate(fadeTransition);

          return FadeTransition(
            opacity: fadeTransition,
            child: ScaleTransition(
              scale: scaleTransition,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _proceedToMain, // Tap to skip anytime
      child: Scaffold(
        backgroundColor: const Color(0xFF070B12), // Pure dark slate canvas
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double explodeVal = _explodeProgress.value;
            final double convergeVal = _convergeProgress.value;
            final double openFactor = explodeVal * (1.0 - convergeVal);

            return Opacity(
              opacity: _outroFade.value,
              child: Stack(
                children: [
                  // Subtle Radial Glow Background Canvas
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0.0, 0.0),
                          radius: 1.35,
                          colors: [
                            Color(0x38EA580C), // Soft safety orange ambient glow
                            Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Pure 3D Wristband Animation (NO TEXT OVERLAYS)
                  Center(
                    child: Transform.scale(
                      scale: _introScale.value,
                      child: Opacity(
                        opacity: _introFade.value,
                        child: SizedBox(
                          width: 360,
                          height: 420,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 3D Dynamic Matrix Transformation (Axis rotates from Vertical to Horizontal)
                              Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0016) // Perspective depth
                                  ..rotateX(_axisRotationX.value) // Rotates tilt angle
                                  ..rotateZ(_axisRotationZ.value), // Rotates axis from vertical (90°) to horizontal
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // -------------------------------------------------------------
                                    // LAYER 3: BASE OF THE BAND & EXTENDING STRAPS (Bottom)
                                    // -------------------------------------------------------------
                                    Transform.translate(
                                      offset: Offset(0, 110 * openFactor),
                                      child: _buildLayer3BaseAndStraps(),
                                    ),

                                    // -------------------------------------------------------------
                                    // LAYER 2: H2S STRIP AND QR CODE (Middle)
                                    // -------------------------------------------------------------
                                    Transform.translate(
                                      offset: Offset(0, -10 * openFactor),
                                      child: _buildLayer2H2sStripAndQR(),
                                    ),

                                    // -------------------------------------------------------------
                                    // LAYER 1: A CASING (Top Protective Cover)
                                    // -------------------------------------------------------------
                                    Transform.translate(
                                      offset: Offset(0, -130 * openFactor),
                                      child: _buildLayer1Casing(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // LAYER 3: BASE OF THE BAND WITH EXTENDING LEFT & RIGHT WRIST STRAPS
  // ===========================================================================
  Widget _buildLayer3BaseAndStraps() {
    return SizedBox(
      width: 320,
      height: 75,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LEFT STRAP
              Container(
                width: 78,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border.all(color: const Color(0xFF334155), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(-4, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStrapHole(),
                    _buildStrapHole(),
                    _buildStrapHole(),
                    Container(width: 4, color: AppTheme.safetyOrange),
                  ],
                ),
              ),

              // CENTER BASE MODULE
              Container(
                width: 164,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF475569), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAlignmentPin(),
                        Container(
                          width: 80,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        _buildAlignmentPin(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.safeGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 50,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreen.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // RIGHT STRAP
              Container(
                width: 78,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(color: const Color(0xFF334155), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(width: 4, color: AppTheme.safetyOrange),
                    Container(
                      width: 14,
                      height: 24,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrapHole() {
    return Container(
      width: 5,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF070B12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
    );
  }

  Widget _buildAlignmentPin() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF94A3B8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }

  // ===========================================================================
  // LAYER 2: H2S STRIP AND A QR CODE (Middle)
  // ===========================================================================
  Widget _buildLayer2H2sStripAndQR() {
    return Container(
      width: 156,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.safetyOrange, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.safetyOrange.withValues(alpha: 0.4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // H2S Colorimetric Chemical Paper Patch
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _buildStripSwatch(const Color(0xFFFEF3C7)),
                    _buildStripSwatch(const Color(0xFFFBBF24)),
                    _buildStripSwatch(const Color(0xFFD97706)),
                    _buildStripSwatch(const Color(0xFF78350F)),
                  ],
                ),
              ],
            ),

            // Divider
            Container(width: 1.2, height: 42, color: const Color(0xFFD97706).withValues(alpha: 0.4)),

            // QR CODE BADGE
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStripSwatch(Color c) {
    return Container(
      width: 16,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black26, width: 0.6),
      ),
    );
  }

  // ===========================================================================
  // LAYER 1: A CASING (Top Protective Cover Bezel)
  // ===========================================================================
  Widget _buildLayer1Casing() {
    return Container(
      width: 164,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppTheme.orangeAccentGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.safetyOrange.withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Clear Optical Window Cutout in the center of the casing
          Container(
            width: 140,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.crop_free_rounded, color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
