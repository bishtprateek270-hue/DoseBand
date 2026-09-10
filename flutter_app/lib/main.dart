import 'package:flutter/material.dart';
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: AppTheme.safetyOrange, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'DoseBand',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.5),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.3), width: 0.8),
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
                const Icon(Icons.notifications_none_rounded, color: AppTheme.primaryNavy, size: 24),
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
                        ? '🚨 $unsafeCount worker(s) exceeded exposure safety limits!'
                        : '✅ All active personnel are within safe H₂S exposure limits.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppTheme.primaryNavy,
          unselectedItemColor: AppTheme.primaryNavyLight.withValues(alpha: 0.6),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.grid_view_rounded),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.grid_view_rounded, color: AppTheme.primaryNavy),
              ),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unsafeCount > 0,
                label: Text('$unsafeCount'),
                backgroundColor: AppTheme.unsafeRed,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 2.0),
                  child: Icon(Icons.people_outline_rounded),
                ),
              ),
              activeIcon: Badge(
                isLabelVisible: unsafeCount > 0,
                label: Text('$unsafeCount'),
                backgroundColor: AppTheme.unsafeRed,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 2.0),
                  child: Icon(Icons.people_rounded, color: AppTheme.primaryNavy),
                ),
              ),
              label: 'Roster',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.qr_code_scanner_rounded),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.qr_code_scanner_rounded, color: AppTheme.safetyOrange),
              ),
              label: 'Scan Strip',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.assessment_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.assessment_rounded, color: AppTheme.primaryNavy),
              ),
              label: 'Logs',
            ),
          ],
        ),
      ),
    );
  }
}
