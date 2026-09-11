import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/worker_directory_screen.dart';
import 'screens/history_screen.dart';
import 'screens/reports_screen.dart';
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
      theme: AppTheme.darkTheme,
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
    ScannerScreen(),
    WorkerDirectoryScreen(),
    HistoryScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unsafeCount = _workerService.unsafeWorkersCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: AppTheme.surfaceDeep,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.safetyOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: AppTheme.safetyOrange, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'DoseBand',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.5, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.safeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Flexible(
                      child: Text(
                        'LIVE',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.safeGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'System Alerts',
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
                        ? '⚠️ $unsafeCount worker(s) currently exceed safety limits or have expired dosimeters!'
                        : '✅ All active personnel are within safe exposure thresholds.',
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
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDeep,
          border: Border(top: BorderSide(color: AppTheme.borderColor, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.surfaceDeep,
          selectedItemColor: AppTheme.safetyOrange,
          unselectedItemColor: AppTheme.textFaint,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_outlined),
              activeIcon: Icon(Icons.qr_code_scanner),
              label: 'Scan Strip',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unsafeCount > 0,
                label: Text('$unsafeCount'),
                backgroundColor: AppTheme.unsafeRed,
                child: const Icon(Icons.people_outline),
              ),
              activeIcon: Badge(
                isLabelVisible: unsafeCount > 0,
                label: Text('$unsafeCount'),
                backgroundColor: AppTheme.unsafeRed,
                child: const Icon(Icons.people),
              ),
              label: 'Roster',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart_outlined_rounded),
              activeIcon: Icon(Icons.insert_chart_rounded),
              label: 'Logs',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.assessment_outlined),
              activeIcon: Icon(Icons.assessment_rounded),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}
