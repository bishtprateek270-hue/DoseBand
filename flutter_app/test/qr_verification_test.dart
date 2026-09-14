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

    test('TEST 10: Null payload returns NO_QR_DETECTED', () async {
      final res = await workerService.verifyBadge();
      expect(res['valid'], isFalse);
      expect(res['status'], 'NO_QR_DETECTED');
      expect(res['message'], 'No QR code detected in this image.');
    });
  });
}
