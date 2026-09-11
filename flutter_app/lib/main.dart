import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/verify_qr_screen.dart';
import 'screens/worker_directory_screen.dart';
import 'screens/dashboard_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final unsafeCount = _workerService.unsafeWorkersCount;

    final List<Widget> screens = [
      HomeScreen(onNavigate: (index) => setState(() => _currentIndex = index)),
      const ScannerScreen(),
      const VerifyQrScreen(),
      const WorkerDirectoryScreen(),
      const DashboardScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.safetyOrangeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.safetyOrange.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.shield_rounded, color: AppTheme.safetyOrange, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'DoseBand',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.4,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
              ),
              child: const Text(
                'PASSIVE DOSIMETRY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'System Safety Status',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: AppTheme.textSecondary, size: 24),
                if (unsafeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.unsafeRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unsafeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
                        ? '⚠️ $unsafeCount worker(s) exceed safe limits or hold expired dosimeter badges.'
                        : '✅ All active workforce operates within safe DGMS/OISD limits.',
                  ),
                  backgroundColor: unsafeCount > 0 ? AppTheme.unsafeRed : AppTheme.safeGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderColor, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.safetyOrange,
          unselectedItemColor: AppTheme.textMuted,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              activeIcon: Icon(Icons.camera_alt_rounded),
              label: 'Scan Strip',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_outlined),
              activeIcon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Verify QR',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unsafeCount > 0,
                label: Text('$unsafeCount'),
                backgroundColor: AppTheme.unsafeRed,
                child: const Icon(Icons.badge_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: unsafeCount > 0,
                label: Text('$unsafeCount'),
                backgroundColor: AppTheme.unsafeRed,
                child: const Icon(Icons.badge_rounded),
              ),
              label: 'Workers',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
          ],
        ),
      ),
    );
  }
}
