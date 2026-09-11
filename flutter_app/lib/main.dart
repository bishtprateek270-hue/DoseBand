import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'screens/worker_directory_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/history_screen.dart';
import 'services/worker_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const DoseBandApp());
}

class DoseBandApp extends StatelessWidget {
  const DoseBandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoseBand - Industrial Dosimetry',
      theme: AppTheme.lightTheme,
      home: const MainNavigation(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final WorkerService _workerService = WorkerService();

  @override
  void initState() {
    super.initState();
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    WorkerDirectoryScreen(),
    ScannerScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unsafeCount = _workerService.unsafeWorkersCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.safetyOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'DoseBand',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 19,
                color: AppTheme.primaryNavy,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.safeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.safeGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Safety System Alerts',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: AppTheme.primaryNavy, size: 20),
                ),
                if (unsafeCount > 0)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.unsafeRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          '$unsafeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    unsafeCount > 0
                        ? '🚨 $unsafeCount worker(s) exceeded exposure safety limits (≥ 50.0 ppm·hr)!'
                        : '✅ All active personnel are within safe H₂S exposure limits (< 10.0 ppm·hr).',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: unsafeCount > 0 ? AppTheme.unsafeRed : AppTheme.primaryNavy,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppTheme.borderColor, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Dashboard'),
                _buildNavItem(1, Icons.people_rounded, Icons.people_outline_rounded, 'Roster', badgeCount: unsafeCount),
                _buildNavItem(2, Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_outlined, 'Scan Strip', isAccent: true),
                _buildNavItem(3, Icons.assessment_rounded, Icons.assessment_outlined, 'Logs'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, {int badgeCount = 0, bool isAccent = false}) {
    final isSelected = _currentIndex == index;
    final activeColor = isAccent ? AppTheme.safetyOrange : AppTheme.primaryNavy;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? activeColor : const Color(0xFF94A3B8),
                  size: 22,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.unsafeRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
