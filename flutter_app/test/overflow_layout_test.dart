import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/home_screen.dart';
import 'package:flutter_app/screens/dashboard_screen.dart';
import 'package:flutter_app/screens/scanner_screen.dart';
import 'package:flutter_app/screens/worker_directory_screen.dart';
import 'package:flutter_app/screens/worker_detail_screen.dart';
import 'package:flutter_app/screens/reports_screen.dart';
import 'package:flutter_app/screens/history_screen.dart';
import 'package:flutter_app/widgets/qr_badge_card.dart';
import 'package:flutter_app/models/worker.dart';

void main() {
  const screenWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0, 768.0];
  const textScales = [1.0, 1.1, 1.2, 1.3];

  final testWorker = Worker(
    workerId: 'W-101',
    name: 'Rajesh Kumar Singh',
    department: 'Refinery Crude Distillation Unit Operations',
    workZone: 'Zone A - Primary Distillation Column Platform',
    shift: 'Shift 1 (06:00 - 14:00)',
    badgeId: 'BDG-101',
    badgeIssueDate: '2026-08-01',
    badgeExpiryDate: '2026-11-01',
    cumulativeDose: 14.5,
    status: 'Active',
  );

  Widget createTestWidget(Widget screen, {required double width, required double textScale}) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: screen,
      ),
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('DoseBand Responsive & Overflow-Free Layout Tests', () {
    for (final width in screenWidths) {
      for (final textScale in textScales) {
        testWidgets('HomeScreen width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(HomeScreen(onNavigate: (_) {}), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on HomeScreen at width $width, textScale $textScale');
        });

        testWidgets('DashboardScreen width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(const DashboardScreen(), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on DashboardScreen at width $width, textScale $textScale');
        });

        testWidgets('ScannerScreen width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(const ScannerScreen(), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on ScannerScreen at width $width, textScale $textScale');
        });

        testWidgets('WorkerDirectoryScreen width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(const WorkerDirectoryScreen(), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on WorkerDirectoryScreen at width $width, textScale $textScale');
        });

        testWidgets('WorkerDetailScreen width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(WorkerDetailScreen(worker: testWorker), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on WorkerDetailScreen at width $width, textScale $textScale');
        });

        testWidgets('ReportsScreen width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(const ReportsScreen(), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on ReportsScreen at width $width, textScale $textScale');
        });

        testWidgets('HistoryScreen width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(const HistoryScreen(), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on HistoryScreen at width $width, textScale $textScale');
        });

        testWidgets('QrBadgeCardWidget width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(
              Scaffold(body: Center(child: QrBadgeCardWidget(worker: testWorker, width: width < 340 ? width - 32 : 340))),
              width: width,
              textScale: textScale,
            ),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on QrBadgeCardWidget at width $width, textScale $textScale');
        });

        testWidgets('MainNavigation Dock width: ${width}px, textScale: ${textScale}x - ZERO overflows', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            createTestWidget(const MainNavigation(), width: width, textScale: textScale),
          );
          await pumpScreen(tester);

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on MainNavigation at width $width, textScale $textScale');
        });
      }
    }
  });
}
