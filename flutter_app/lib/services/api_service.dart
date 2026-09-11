import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Central HTTP Service Client for DoseBand REST API Backend.
///
/// Uses standard dart:io HttpClient for maximum portability, robust multipart uploads,
/// zero external dependency failure risk, and clear developer logging.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final HttpClient _client = HttpClient()
    ..connectionTimeout = AppConfig.connectTimeout;

  bool _isServerConnected = false;
  bool get isServerConnected => _isServerConnected;

  // --- Developer Logging ---
  void _log(String method, String url, int? status, [int? elapsedMs, String? error]) {
    if (kDebugMode) {
      final statusStr = status != null ? '$status' : 'ERROR';
      final elapsedStr = elapsedMs != null ? ' (${elapsedMs}ms)' : '';
      final errStr = error != null ? ' - $error' : '';
      debugPrint('[DoseBand API] $method $url -> $statusStr$elapsedStr$errStr');
    }
  }

  // --- 1. Health & Connectivity ---
  Future<bool> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    final url = AppConfig.healthEndpoint;
    try {
      final uri = Uri.parse(url);
      final request = await _client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 4));
      stopwatch.stop();

      final isOk = response.statusCode == 200;
      _isServerConnected = isOk;
      _log('GET', url, response.statusCode, stopwatch.elapsedMilliseconds);
      return isOk;
    } catch (e) {
      stopwatch.stop();
      _isServerConnected = false;
      _log('GET', url, null, stopwatch.elapsedMilliseconds, e.toString());
      return false;
    }
  }

  // --- 2. Workers CRUD ---
  Future<List<Map<String, dynamic>>> getWorkers() async {
    final res = await _get(AppConfig.workersEndpoint);
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getWorker(String workerId) async {
    try {
      final res = await _get(AppConfig.workerEndpoint(workerId));
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> createWorker(Map<String, dynamic> workerData) async {
    final res = await _postJson(AppConfig.workersEndpoint, workerData);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateWorker(String workerId, Map<String, dynamic> workerData) async {
    final res = await _putJson(AppConfig.workerEndpoint(workerId), workerData);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<bool> deleteWorker(String workerId) async {
    try {
      final stopwatch = Stopwatch()..start();
      final uri = Uri.parse(AppConfig.workerEndpoint(workerId));
      final request = await _client.deleteUrl(uri);
      final response = await request.close().timeout(AppConfig.receiveTimeout);
      stopwatch.stop();
      _log('DELETE', uri.toString(), response.statusCode, stopwatch.elapsedMilliseconds);
      return response.statusCode == 200;
    } catch (e) {
      _log('DELETE', AppConfig.workerEndpoint(workerId), null, null, e.toString());
      return false;
    }
  }

  // --- 3. QR Badge Verification ---
  Future<Map<String, dynamic>> verifyBadgeQr({Uint8List? imageBytes, String? rawPayload}) async {
    final stopwatch = Stopwatch()..start();
    final url = AppConfig.badgesVerifyEndpoint;
    try {
      final uri = Uri.parse(url);
      final boundary = '----DoseBandBoundary${DateTime.now().millisecondsSinceEpoch}';
      final request = await _client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');

      final bodyBytes = <int>[];

      if (rawPayload != null && rawPayload.isNotEmpty) {
        bodyBytes.addAll(utf8.encode('--$boundary\r\n'));
        bodyBytes.addAll(utf8.encode('Content-Disposition: form-data; name="raw_payload"\r\n\r\n'));
        bodyBytes.addAll(utf8.encode('$rawPayload\r\n'));
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        bodyBytes.addAll(utf8.encode('--$boundary\r\n'));
        bodyBytes.addAll(utf8.encode('Content-Disposition: form-data; name="file"; filename="badge_qr.png"\r\n'));
        bodyBytes.addAll(utf8.encode('Content-Type: image/png\r\n\r\n'));
        bodyBytes.addAll(imageBytes);
        bodyBytes.addAll(utf8.encode('\r\n'));
      }

      bodyBytes.addAll(utf8.encode('--$boundary--\r\n'));

      request.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close().timeout(AppConfig.receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      _log('POST', url, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody) as Map<String, dynamic>;
      } else {
        throw _parseError(responseBody, response.statusCode);
      }
    } catch (e) {
      stopwatch.stop();
      _log('POST', url, null, stopwatch.elapsedMilliseconds, e.toString());
      throw _formatException(e);
    }
  }

  // --- 4. Optical Gas Dosimetry & Analysis ---
  Future<Map<String, dynamic>> analyzeSensorStrip({
    required Uint8List imageBytes,
    required String fileName,
    required String workerId,
    required double temperatureC,
    double? humidityRh,
    required double exposureTimeHours,
    String badgeMode = 'STANDALONE_CHEMICAL_STRIP',
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = AppConfig.scanAnalyzeEndpoint;
    try {
      final uri = Uri.parse(url);
      final boundary = '----DoseBandBoundary${DateTime.now().millisecondsSinceEpoch}';
      final request = await _client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');

      final bodyBytes = <int>[];

      // Form Fields
      void addField(String name, String value) {
        bodyBytes.addAll(utf8.encode('--$boundary\r\n'));
        bodyBytes.addAll(utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
        bodyBytes.addAll(utf8.encode('$value\r\n'));
      }

      addField('worker_id', workerId);
      addField('temperature_c', temperatureC.toString());
      if (humidityRh != null) {
        addField('humidity_rh', humidityRh.toString());
      }
      addField('exposure_time_h', exposureTimeHours.toString());
      addField('badge_mode', badgeMode);

      // File Field
      bodyBytes.addAll(utf8.encode('--$boundary\r\n'));
      bodyBytes.addAll(utf8.encode('Content-Disposition: form-data; name="image"; filename="$fileName"\r\n'));
      bodyBytes.addAll(utf8.encode('Content-Type: image/jpeg\r\n\r\n'));
      bodyBytes.addAll(imageBytes);
      bodyBytes.addAll(utf8.encode('\r\n'));

      bodyBytes.addAll(utf8.encode('--$boundary--\r\n'));

      request.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close().timeout(AppConfig.receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      _log('POST', url, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody) as Map<String, dynamic>;
      } else {
        throw _parseError(responseBody, response.statusCode);
      }
    } catch (e) {
      stopwatch.stop();
      _log('POST', url, null, stopwatch.elapsedMilliseconds, e.toString());
      throw _formatException(e);
    }
  }

  // --- 5. Sensor Reading Persistence ---
  Future<Map<String, dynamic>> saveReading(Map<String, dynamic> readingData) async {
    final res = await _postJson(AppConfig.scanSaveEndpoint, readingData);
    return Map<String, dynamic>.from(res as Map);
  }

  // --- 6. Readings & History ---
  Future<List<Map<String, dynamic>>> getWorkerHistory(String workerId) async {
    final res = await _get(AppConfig.workerHistoryEndpoint(workerId));
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getAllReadings() async {
    final res = await _get(AppConfig.readingsEndpoint);
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // --- 7. Dashboard & Reports ---
  Future<Map<String, dynamic>> getDashboardData() async {
    final res = await _get(AppConfig.dashboardEndpoint);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {};
  }

  Future<Map<String, dynamic>> getReportsSummary() async {
    final res = await _get(AppConfig.reportsSummaryEndpoint);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {};
  }

  // --- Generic HTTP Helpers ---
  Future<dynamic> _get(String url) async {
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse(url);
      final request = await _client.getUrl(uri);
      final response = await request.close().timeout(AppConfig.receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      _log('GET', url, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw _parseError(responseBody, response.statusCode);
      }
    } catch (e) {
      stopwatch.stop();
      _log('GET', url, null, stopwatch.elapsedMilliseconds, e.toString());
      throw _formatException(e);
    }
  }

  Future<dynamic> _postJson(String url, Map<String, dynamic> data) async {
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse(url);
      final request = await _client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');

      final bodyStr = json.encode(data);
      request.add(utf8.encode(bodyStr));

      final response = await request.close().timeout(AppConfig.receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      _log('POST', url, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw _parseError(responseBody, response.statusCode);
      }
    } catch (e) {
      stopwatch.stop();
      _log('POST', url, null, stopwatch.elapsedMilliseconds, e.toString());
      throw _formatException(e);
    }
  }

  Future<dynamic> _putJson(String url, Map<String, dynamic> data) async {
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse(url);
      final request = await _client.putUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');

      final bodyStr = json.encode(data);
      request.add(utf8.encode(bodyStr));

      final response = await request.close().timeout(AppConfig.receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      stopwatch.stop();

      _log('PUT', url, response.statusCode, stopwatch.elapsedMilliseconds);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw _parseError(responseBody, response.statusCode);
      }
    } catch (e) {
      stopwatch.stop();
      _log('PUT', url, null, stopwatch.elapsedMilliseconds, e.toString());
      throw _formatException(e);
    }
  }

  // --- Human-Friendly Error Resolution ---
  Exception _parseError(String body, int statusCode) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded.containsKey('detail')) {
        return ApiException(decoded['detail'].toString(), statusCode: statusCode);
      }
    } catch (_) {}

    if (statusCode == 404) {
      return ApiException('Requested resource not found.', statusCode: 404);
    } else if (statusCode >= 500) {
      return ApiException('Server internal error during processing. Please retry.', statusCode: statusCode);
    }
    return ApiException('Request failed with HTTP status $statusCode.', statusCode: statusCode);
  }

  Exception _formatException(dynamic e) {
    if (e is ApiException) return e;
    if (e is SocketException) {
      return ApiException(
        'Unable to reach DoseBand server at ${AppConfig.apiBaseUrl}. Please verify server is running and network is connected.',
        statusCode: 0,
      );
    } else if (e is TimeoutException) {
      return ApiException('Connection to DoseBand server timed out. Please check network speed.', statusCode: 408);
    }
    return ApiException(e.toString().replaceAll('Exception:', '').trim(), statusCode: 0);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}
