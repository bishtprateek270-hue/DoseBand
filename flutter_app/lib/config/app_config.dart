import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Centralized Environment Configuration for DoseBand Mobile Application.
///
/// Configurable at build time or launch time via:
///   flutter run --dart-define=API_BASE_URL=https://your-api-server.com
///   flutter build apk --dart-define=API_BASE_URL=https://your-api-server.com
class AppConfig {
  /// Base API URL passed via compile-time environment variable
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Runtime override if configured dynamically by the user
  static String? _runtimeOverrideUrl;

  /// Default local development fallback port
  static const int defaultPort = 8000;

  /// Returns the active API Base URL with platform-aware fallback
  static String get apiBaseUrl {
    if (_runtimeOverrideUrl != null && _runtimeOverrideUrl!.isNotEmpty) {
      return _runtimeOverrideUrl!;
    }

    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    // Smart local development defaults
    if (kIsWeb) {
      return 'http://127.0.0.1:$defaultPort';
    }

    try {
      if (Platform.isAndroid) {
        // Standard Android Emulator loopback to host development machine
        return 'http://10.0.2.2:$defaultPort';
      } else if (Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        return 'http://127.0.0.1:$defaultPort';
      }
    } catch (_) {
      // Fallback
    }

    return 'http://10.0.2.2:$defaultPort';
  }

  /// Sets runtime custom server URL (e.g. from connection dialog on physical devices)
  static void setRuntimeBaseUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _runtimeOverrideUrl = cleanUrl;
  }

  /// Clears runtime override
  static void resetBaseUrl() {
    _runtimeOverrideUrl = null;
  }

  // --- API Endpoint Routes ---
  static String get healthEndpoint => '$apiBaseUrl/health';
  static String get workersEndpoint => '$apiBaseUrl/workers';
  static String get badgesVerifyEndpoint => '$apiBaseUrl/badges/verify-qr';
  static String get scanAnalyzeEndpoint => '$apiBaseUrl/scan/analyze';
  static String get scanSaveEndpoint => '$apiBaseUrl/scan/save';
  static String get readingsEndpoint => '$apiBaseUrl/readings';
  static String get dashboardEndpoint => '$apiBaseUrl/dashboard';
  static String get reportsSummaryEndpoint => '$apiBaseUrl/reports/summary';

  static String workerEndpoint(String workerId) => '$apiBaseUrl/workers/$workerId';
  static String workerBadgeCardEndpoint(String workerId) => '$apiBaseUrl/workers/$workerId/badge-card';
  static String workerQrEndpoint(String workerId) => '$apiBaseUrl/workers/$workerId/qr';
  static String workerHistoryEndpoint(String workerId) => '$apiBaseUrl/workers/$workerId/history';
  static String badgeEndpoint(String badgeId) => '$apiBaseUrl/badges/$badgeId';
  static String reportPdfDownloadEndpoint(String workerId) => '$apiBaseUrl/reports/download/pdf?worker_id=$workerId';

  // --- Network Timeouts ---
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
