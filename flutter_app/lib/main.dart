import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/worker_directory_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'screens/landing_screen.dart';
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
      home: const LandingScreen(),
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
  final ApiService _apiService = ApiService();

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

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: AppConfig.apiBaseUrl);
    String testStatus = '';
    Color testColor = AppTheme.textMuted;
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.hub_rounded, color: AppTheme.safetyOrange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Server & Device Connection',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configure the FastAPI backend server URL for this device or your local Wi-Fi network:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Backend API URL',
                    hintText: 'http://192.168.1.X:8000',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Localhost (127.0.0.1)', style: TextStyle(fontSize: 10)),
                      onPressed: () => setDialogState(() => controller.text = 'http://127.0.0.1:8000'),
                    ),
                    ActionChip(
                      label: const Text('Android (10.0.2.2)', style: TextStyle(fontSize: 10)),
                      onPressed: () => setDialogState(() => controller.text = 'http://10.0.2.2:8000'),
                    ),
                  ],
                ),
                if (testStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: testColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: testColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(testStatus.contains('✅') ? Icons.check_circle : Icons.error_outline, size: 16, color: testColor),
                        const SizedBox(width: 6),
                        Expanded(child: Text(testStatus, style: TextStyle(fontSize: 11, color: testColor, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setDialogState(() {
                        isTesting = true;
                        testStatus = 'Pinging backend server...';
                        testColor = const Color(0xFF0284C7);
                      });
                      AppConfig.setRuntimeBaseUrl(controller.text);
                      final ok = await _apiService.checkHealth();
                      setDialogState(() {
                        isTesting = false;
                        if (ok) {
                          testStatus = '✅ Connected! Backend is live.';
                          testColor = AppTheme.safeGreen;
                        } else {
                          testStatus = '❌ Unreachable. Check IP & port.';
                          testColor = AppTheme.unsafeRed;
                        }
                      });
                    },
              child: isTesting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test Ping', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                AppConfig.resetBaseUrl();
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Reset', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.safetyOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                AppConfig.setRuntimeBaseUrl(controller.text);
                Navigator.pop(ctx);
                setState(() {});
                _workerService.fetchWorkers();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Server endpoint set to: ${AppConfig.apiBaseUrl}'),
                    backgroundColor: AppTheme.safeGreen,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save & Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unsafeCount = _workerService.unsafeWorkersCount;

    final List<Widget> screens = [
      HomeScreen(onNavigate: (index) => setState(() => _currentIndex = index)),
      const ScannerScreen(),
      const WorkerDirectoryScreen(),
      const DashboardScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2.0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppTheme.orangeAccentGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.safetyOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'DoseBand',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.4,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO v2.0',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFB923C),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
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
                    const Text(
                      'SQLITE LIVE SYNC',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: IconButton(
              tooltip: 'Server & Wi-Fi Settings',
              iconSize: 20,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.settings_ethernet_rounded, color: AppTheme.textPrimary, size: 20),
              onPressed: _showServerConfigDialog,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: IconButton(
              tooltip: 'System Safety Status',
              iconSize: 22,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary, size: 22),
                  if (unsafeCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: AppTheme.unsafeRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '$unsafeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          unsafeCount > 0 ? Icons.warning_rounded : Icons.verified_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            unsafeCount > 0
                                ? '⚠️ $unsafeCount worker(s) require attention (dose > safe limit or expired badge).'
                                : '✅ All monitored workforce personnel within permissible DGMS limits.',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: unsafeCount > 0 ? AppTheme.unsafeRed : AppTheme.safeGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppTheme.borderColor, width: 1.0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: AppTheme.safetyOrange,
              unselectedItemColor: AppTheme.textMuted,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: [
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2.0),
                    child: Icon(Icons.home_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2.0),
                    child: Icon(Icons.home_rounded),
                  ),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2.0),
                    child: Icon(Icons.camera_alt_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2.0),
                    child: Icon(Icons.camera_alt_rounded),
                  ),
                  label: 'Scan Strip',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Badge(
                      isLabelVisible: unsafeCount > 0,
                      label: Text('$unsafeCount'),
                      backgroundColor: AppTheme.unsafeRed,
                      child: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Badge(
                      isLabelVisible: unsafeCount > 0,
                      label: Text('$unsafeCount'),
                      backgroundColor: AppTheme.unsafeRed,
                      child: const Icon(Icons.badge_rounded),
                    ),
                  ),
                  label: 'Workers',
                ),
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2.0),
                    child: Icon(Icons.dashboard_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2.0),
                    child: Icon(Icons.dashboard_rounded),
                  ),
                  label: 'Dashboard',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
