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
      title: 'DoseBand - Worker Safety & Monitoring',
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
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: AppTheme.safetyOrange),
            SizedBox(width: 8),
            Text('DoseBand', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 6),
            Text(
              '| Worker Safety System',
              style: TextStyle(fontSize: 12, color: AppTheme.primaryNavyLight, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    unsafeCount > 0
                        ? '🚨 $unsafeCount workers require immediate exposure review!'
                        : '✅ All workers are within safe H₂S exposure limits.',
                  ),
                  backgroundColor: unsafeCount > 0 ? AppTheme.unsafeRed : AppTheme.safeGreen,
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.safetyOrange,
        unselectedItemColor: AppTheme.primaryNavyLight,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
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
            label: 'Workers',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: 'Scan Strip',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
