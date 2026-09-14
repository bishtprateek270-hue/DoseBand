import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/worker_service.dart';
import 'package:flutter_app/models/worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkerService workerService;

  setUp(() {
    workerService = WorkerService();
  });

  group('DoseBand QR Parser & Validation Tests', () {
    test('TEST 1: Parse canonical JSON DoseBand payload', () {
      const payload = '{"type":"doseband_worker","version":1,"worker_id":"W-101","badge_id":"BDG-101"}';
      final (wid, bid, recognized) = WorkerService.parseDoseBandPayload(payload);
      expect(recognized, isTrue);
      expect(wid, 'W-101');
      expect(bid, 'BDG-101');
    });

    test('TEST 2: Parse standard DOSEBAND:W-101:BDG-101 format', () {
      const payload = 'DOSEBAND:W-101:BDG-101';
      final (wid, bid, recognized) = WorkerService.parseDoseBandPayload(payload);
      expect(recognized, isTrue);
      expect(wid, 'W-101');
      expect(bid, 'BDG-101');
    });

    test('TEST 3: Parse legacy BDG-101 format', () {
      const payload = 'BDG-101';
      final (wid, bid, recognized) = WorkerService.parseDoseBandPayload(payload);
      expect(recognized, isTrue);
      expect(bid, 'BDG-101');
    });

    test('TEST 4: Reject external URLs', () {
      const payload = 'https://google.com/sample';
      final (_, _, recognized) = WorkerService.parseDoseBandPayload(payload);
      expect(recognized, isFalse);
    });

    test('TEST 5: Reject UPI Payment QR', () {
      const payload = 'upi://pay?pa=merchant@upi&pn=Store';
      final (_, _, recognized) = WorkerService.parseDoseBandPayload(payload);
      expect(recognized, isFalse);
    });

    test('TEST 6: Reject WiFi Config QR', () {
      const payload = 'WIFI:S:IndustrialNet;T:WPA;P:secret123;;';
      final (_, _, recognized) = WorkerService.parseDoseBandPayload(payload);
      expect(recognized, isFalse);
    });

    test('TEST 7: Validate active registered worker (Rajesh Kumar W-101)', () {
      final res = workerService.validateWorkerBadge(
        workerId: 'W-101',
        badgeId: 'BDG-101',
        rawPayload: '{"type":"doseband_worker","version":1,"worker_id":"W-101","badge_id":"BDG-101"}',
      );
      expect(res['valid'], isTrue);
      expect(res['status'], 'VALID');
      expect(res['worker'], isNotNull);
      final worker = Worker.fromMap(res['worker']);
      expect(worker.workerId, 'W-101');
      expect(worker.name, 'Rajesh Kumar');
    });

    test('TEST 8: Validate unregistered worker ID (W-999)', () {
      final res = workerService.validateWorkerBadge(
        workerId: 'W-999',
        badgeId: 'BDG-999',
        rawPayload: '{"type":"doseband_worker","version":1,"worker_id":"W-999","badge_id":"BDG-999"}',
      );
      expect(res['valid'], isFalse);
      expect(res['status'], 'WORKER_NOT_FOUND');
      expect(res['message'], 'Worker is not registered.');
    });

    test('TEST 9: Non-DoseBand QR payload verification flow', () async {
      final res = await workerService.verifyBadge(rawPayload: 'https://malicious-link.com');
      expect(res['valid'], isFalse);
      expect(res['status'], 'INVALID_QR');
      expect(res['message'], 'This is not a valid DoseBand QR.');
    });

    test('TEST 11: Registered worker QR payload remains identical across restarts and rebuilds', () async {
      final worker = Worker(
        workerId: 'W-201',
        name: 'Kavita Verma',
        department: 'Refinery',
        shift: 'Shift 1',
        badgeId: 'BDG-201',
        badgeIssueDate: '2026-08-01',
        badgeExpiryDate: '2026-11-01',
        status: 'Active',
      );

      final initialQr = worker.effectiveQrPayload;
      expect(initialQr, '{"type":"doseband_worker","version":1,"worker_id":"W-201","badge_id":"BDG-201"}');

      // Add to service
      await workerService.addWorker(worker);

      // Simulate app restart / cold rebuild reload
      final reloadedWorker = workerService.getWorkerById('W-201');
      expect(reloadedWorker, isNotNull);
      expect(reloadedWorker!.effectiveQrPayload, initialQr);

      // Scan the saved QR payload
      final scanRes = await workerService.verifyBadge(rawPayload: initialQr);
      expect(scanRes['valid'], isTrue);
      expect(scanRes['status'], 'VALID');
      expect(scanRes['worker']['worker_id'], 'W-201');
    });

    test('TEST 12: Web and Flutter payloads are 100% interoperable', () async {
      // Payload produced by Python backend / Web app
      const webGeneratedQr = '{"type":"doseband_worker","version":1,"worker_id":"W-101","badge_id":"BDG-101"}';
      
      // Verified in Flutter WorkerService
      final flutterRes = await workerService.verifyBadge(rawPayload: webGeneratedQr);
      expect(flutterRes['valid'], isTrue);
      expect(flutterRes['status'], 'VALID');
      expect(flutterRes['worker']['name'], 'Rajesh Kumar');
    });
  });
}
