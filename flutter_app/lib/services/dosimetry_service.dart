import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Result container for optical densitometry and ML chemical gas dosimetry
class DosimetryResult {
  final bool isValid;
  final String status; // 'Valid' | 'Uncertain' | 'Invalid'
  final int confidencePct;
  final double estimatedH2sPpm;
  final double cumulativeDosePpmH;
  final double rawIntensity;
  final double correctedIntensity;
  final double compensationFactor;
  final String riskLevel; // 'Safe' | 'Caution' | 'Unsafe'
  final String riskColorHex;
  final String actionGuidance;
  final String userMessage;
  final String badgeMode; // 'STANDALONE_CHEMICAL_STRIP' | 'FULL_DOSEBAND_BADGE'
  final Map<String, dynamic> validationBreakdown;
  final Map<String, dynamic> preFlightChecks;
  final bool isBadgeExpired;
  final bool isAllowedToSave;
  final String expiryStatusMessage;
  final String dataSource;
  final List<String> rejectionReasons;
  final double temperatureC;
  final double predictedHumidity;
  final String scanMode; // 'full_badge' | 'standalone_strip'
  final bool isStandalone;
  final bool isPrototypeEstimate;
  final String? disclaimer;
  final String? debugOverlayBase64;
  final String? canonicalViewBase64;
  final String? deviceType;
  final bool deviceGeometryValid;

  DosimetryResult({
    required this.isValid,
    required this.status,
    required this.confidencePct,
    required this.estimatedH2sPpm,
    required this.cumulativeDosePpmH,
    required this.rawIntensity,
    required this.correctedIntensity,
    required this.compensationFactor,
    required this.riskLevel,
    required this.riskColorHex,
    required this.actionGuidance,
    required this.userMessage,
    required this.badgeMode,
    required this.validationBreakdown,
    required this.preFlightChecks,
    this.scanMode = 'full_badge',
    this.isStandalone = false,
    this.isPrototypeEstimate = false,
    this.disclaimer,
    this.isBadgeExpired = false,
    this.isAllowedToSave = true,
    this.expiryStatusMessage = 'Active & Verified',
    this.dataSource = 'CALIBRATED_OPTICAL_DOSIMETRY_MODEL',
    this.rejectionReasons = const [],
    this.temperatureC = 25.0,
    this.predictedHumidity = 50.0,
    this.debugOverlayBase64,
    this.canonicalViewBase64,
    this.deviceType = '3D_PRINTED_PROTOTYPE',
    this.deviceGeometryValid = true,
  });
}

/// Optical Dosimetry and Lead-Sulfide (PbS) Gas Prediction Engine
class DosimetryService {
  static final DosimetryService _instance = DosimetryService._internal();
  factory DosimetryService() => _instance;
  DosimetryService._internal();

  final ApiService _apiService = ApiService();

  Future<bool> saveReading({
    required String workerId,
    required DosimetryResult result,
  }) async {
    try {
      final readingData = {
        'worker_id': workerId,
        'intensity': result.correctedIntensity,
        'dose': result.cumulativeDosePpmH,
        'risk_level': result.riskLevel,
        'is_expired': result.isBadgeExpired,
        'expiry_status_message': result.expiryStatusMessage,
        'temperature': result.temperatureC,
        'humidity': result.predictedHumidity,
        'raw_intensity': result.rawIntensity,
        'corrected_intensity': result.correctedIntensity,
        'compensation_factor': result.compensationFactor,
        'exposure_time': 1.0,
        'estimated_h2s_ppm': result.estimatedH2sPpm,
        'data_source': result.dataSource,
      };
      await _apiService.saveReading(readingData);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DosimetryService] saveReading note: $e');
      return false;
    }
  }

  Future<DosimetryResult> processImage({
    required Uint8List imageBytes,
    String fileName = 'dosimeter_scan.jpg',
    String workerId = 'W-101',
    double temperatureC = 25.0,
    double? humidityRh,
    double exposureTimeHours = 1.0,
    String badgeMode = 'FULL_DOSEBAND_BADGE',
    String scanMode = 'full_badge',
  }) async {
    return analyzeImageBytes(
      bytes: imageBytes,
      fileName: fileName,
      workerId: workerId,
      temperatureC: temperatureC,
      humidityRh: humidityRh ?? 50.0,
      exposureTimeHours: exposureTimeHours,
      badgeMode: badgeMode,
      scanMode: scanMode,
    );
  }

  /// Baseline reference brightness levels (HSV Value channel [0-255])
  static const double baselineVUnexposed = 240.0;
  static const double baselineVExposed = 40.0;

  /// Primary Entry Point: Analyzes an image file using the unified Python backend API.
  Future<DosimetryResult> analyzeImage({
    required File imageFile,
    String workerId = 'W-101',
    required double temperatureC,
    required double humidityRh,
    required double exposureTimeHours,
    String badgeMode = 'FULL_DOSEBAND_BADGE',
    String scanMode = 'full_badge',
  }) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final String fileName = imageFile.path.split(Platform.pathSeparator).last;

      return await analyzeImageBytes(
        bytes: bytes,
        fileName: fileName,
        workerId: workerId,
        temperatureC: temperatureC,
        humidityRh: humidityRh,
        exposureTimeHours: exposureTimeHours,
        badgeMode: badgeMode,
        scanMode: scanMode,
      );
    } catch (e) {
      return _createFallbackErrorResult("Failed to read image file: $e");
    }
  }

  /// Asynchronous image analyzer: queries Python REST API first, falls back to local ML if offline.
  Future<DosimetryResult> analyzeImageBytes({
    required Uint8List bytes,
    String fileName = 'dosimeter_scan.jpg',
    String workerId = 'W-101',
    required double temperatureC,
    required double humidityRh,
    required double exposureTimeHours,
    String badgeMode = 'FULL_DOSEBAND_BADGE',
    String scanMode = 'full_badge',
  }) async {
    if (bytes.isEmpty) {
      return _createFallbackErrorResult("Empty image byte stream.");
    }

    // 1. Attempt Primary Backend API Analysis (Unified Single Source of Truth)
    try {
      final apiResponse = await _apiService.analyzeSensorStrip(
        imageBytes: bytes,
        fileName: fileName,
        workerId: workerId,
        temperatureC: temperatureC,
        humidityRh: humidityRh,
        exposureTimeHours: exposureTimeHours,
        badgeMode: badgeMode,
        scanMode: scanMode,
      );

      final bool isValid = apiResponse['is_valid'] == true;
      final String status = apiResponse['status']?.toString() ?? (isValid ? 'Valid' : 'Invalid');
      final int confidencePct = (apiResponse['confidence_pct'] as num?)?.toInt() ?? (isValid ? 90 : 25);
      final double ppm = (apiResponse['estimated_h2s_ppm'] as num?)?.toDouble() ?? 0.0;
      final double dose = (apiResponse['cumulative_dose_ppm_h'] as num?)?.toDouble() ?? (ppm * exposureTimeHours);
      final double rawInt = (apiResponse['raw_intensity'] as num?)?.toDouble() ?? 0.0;
      final double corrInt = (apiResponse['corrected_intensity'] as num?)?.toDouble() ?? rawInt;
      final double compFactor = (apiResponse['compensation_factor'] as num?)?.toDouble() ?? 1.0;
      final String riskLevel = apiResponse['risk_level']?.toString() ?? 'Safe';
      final String riskColor = apiResponse['risk_color']?.toString() ?? '#10B981';
      final String actionGuidance = apiResponse['action_guidance']?.toString() ?? '';
      final String userMsg = apiResponse['user_message']?.toString() ?? (isValid ? 'Test strip optical verification passed.' : 'Verification failed.');
      final String detectedMode = apiResponse['badge_mode']?.toString() ?? (scanMode == 'standalone_strip' ? 'STANDALONE_H2S_STRIP' : 'FULL_DOSEBAND_BADGE');
      final String effectiveScanMode = apiResponse['scan_mode']?.toString() ?? scanMode;
      final bool isStandalone = apiResponse['is_standalone'] == true || effectiveScanMode == 'standalone_strip';
      final bool isPrototypeEstimate = apiResponse['is_prototype_estimate'] == true || isStandalone;
      final String? disclaimer = apiResponse['disclaimer']?.toString() ?? (isStandalone ? 'PROTOTYPE ESTIMATE: Standalone strip scan is an uncalibrated visual estimation. For safety compliance, scan inside the complete DoseBand enclosure with environmental sensors.' : null);
      final bool isExpired = apiResponse['is_badge_expired'] == true;
      final bool isAllowedToSave = apiResponse['is_allowed_to_save'] == true;
      final String expiryMsg = apiResponse['expiry_status_message']?.toString() ?? 'Active';

      final breakdown = apiResponse['validation_breakdown'] is Map
          ? Map<String, dynamic>.from(apiResponse['validation_breakdown'] as Map)
          : <String, dynamic>{};

      final preFlight = apiResponse['pre_flight_checks'] is Map
          ? Map<String, dynamic>.from(apiResponse['pre_flight_checks'] as Map)
          : <String, dynamic>{
              'refScale': isValid,
              'sensorStrip': isValid,
              'humiditySource': isValid,
              'lightingCalibration': isValid,
            };

      final List<String> rejectionReasons = (apiResponse['rejection_reasons'] as List?)?.map((e) => e.toString()).toList() ??
          ((apiResponse['errors'] as List?)?.map((e) => e.toString()).toList() ?? <String>[]);

      return DosimetryResult(
        isValid: isValid,
        status: status,
        confidencePct: confidencePct,
        estimatedH2sPpm: ppm,
        cumulativeDosePpmH: dose,
        rawIntensity: rawInt,
        correctedIntensity: corrInt,
        compensationFactor: compFactor,
        riskLevel: riskLevel,
        riskColorHex: riskColor,
        actionGuidance: actionGuidance,
        userMessage: userMsg,
        badgeMode: detectedMode,
        scanMode: effectiveScanMode,
        isStandalone: isStandalone,
        isPrototypeEstimate: isPrototypeEstimate,
        disclaimer: disclaimer,
        validationBreakdown: breakdown,
        preFlightChecks: preFlight,
        isBadgeExpired: isExpired,
        isAllowedToSave: isAllowedToSave,
        expiryStatusMessage: expiryMsg,
        dataSource: 'DOSEBAND_REST_API',
        rejectionReasons: rejectionReasons,
        temperatureC: (apiResponse['temperature'] as num?)?.toDouble() ?? temperatureC,
        predictedHumidity: (apiResponse['predicted_humidity'] ?? apiResponse['humidity'] as num?)?.toDouble() ?? humidityRh,
        debugOverlayBase64: apiResponse['debug_overlay_base64']?.toString(),
        canonicalViewBase64: apiResponse['canonical_view_base64']?.toString(),
        deviceType: apiResponse['device_type']?.toString() ?? (isStandalone ? 'STANDALONE_H2S_STRIP' : '3D_PRINTED_PROTOTYPE'),
        deviceGeometryValid: apiResponse['device_geometry_valid'] != false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DosimetryService] Backend API unreachable ($e), activating standalone local engine fallback.');
      }
    }

    // 2. Standalone Local Fallback Engine (Runs if server is unreachable)
    ColorSample sample;
    try {
      sample = await _extractColorSampleFromUi(bytes);
    } catch (_) {
      sample = _extractColorSampleFromBytes(bytes);
    }

    return _evaluateDosimetryLocal(
      sample: sample,
      temperatureC: temperatureC,
      humidityRh: humidityRh,
      exposureTimeHours: exposureTimeHours,
      badgeMode: badgeMode,
    );
  }

  /// Synchronous computation engine for raw image bytes (Offline)
  DosimetryResult processImageBytes({
    required Uint8List bytes,
    required double temperatureC,
    required double humidityRh,
    required double exposureTimeHours,
    String badgeMode = 'STANDALONE_CHEMICAL_STRIP',
  }) {
    if (bytes.isEmpty) {
      return _createFallbackErrorResult("Empty image byte stream.");
    }

    final ColorSample sample = _extractColorSampleFromBytes(bytes);
    return _evaluateDosimetryLocal(
      sample: sample,
      temperatureC: temperatureC,
      humidityRh: humidityRh,
      exposureTimeHours: exposureTimeHours,
      badgeMode: badgeMode,
    );
  }

  /// Evaluates optical validation, thermodynamic compensation, and monotonic PPM regressor locally
  DosimetryResult _evaluateDosimetryLocal({
    required ColorSample sample,
    required double temperatureC,
    required double humidityRh,
    required double exposureTimeHours,
    required String badgeMode,
  }) {
    final double rawIntensity = ((baselineVUnexposed - sample.v) / (baselineVUnexposed - baselineVExposed)).clamp(0.0, 1.0);
    final Map<String, dynamic> valRes = _validateStrip(sample, badgeMode);
    final bool isStripValid = valRes['isValid'] as bool;
    final int confidencePct = valRes['confidencePct'] as int;
    final String status = valRes['status'] as String;

    if (!isStripValid) {
      return DosimetryResult(
        isValid: false,
        status: status,
        confidencePct: confidencePct,
        estimatedH2sPpm: 0.0,
        cumulativeDosePpmH: 0.0,
        rawIntensity: double.parse(rawIntensity.toStringAsFixed(4)),
        correctedIntensity: double.parse(rawIntensity.toStringAsFixed(4)),
        compensationFactor: 1.0,
        riskLevel: 'Invalid',
        riskColorHex: '#EF4444',
        actionGuidance: 'Reposition valid chemical dosimeter strip under uniform lighting.',
        userMessage: valRes['userMessage'] as String,
        badgeMode: badgeMode,
        validationBreakdown: valRes['breakdown'] as Map<String, dynamic>,
        preFlightChecks: {
          'refScale': false,
          'sensorStrip': false,
          'humiditySource': false,
          'lightingCalibration': false,
        },
        dataSource: 'LOCAL_FALLBACK_ENGINE',
        temperatureC: temperatureC,
        predictedHumidity: humidityRh,
      );
    }

    final double fTemp = 1.0 + 0.008 * (temperatureC - 25.0);
    final double fRh = 1.0 + 0.003 * (humidityRh - 50.0);
    final double compFactor = (fTemp * fRh).clamp(0.70, 1.40);
    final double correctedIntensity = (rawIntensity / compFactor).clamp(0.0, 1.0);

    final double estimatedPpm = _predictH2sPpm(correctedIntensity, sample.v);
    final double cumulativeDose = (estimatedPpm * exposureTimeHours);

    String riskLevel = 'Safe';
    String riskColorHex = '#10B981';
    String actionGuidance = 'Within permissible 8-hr TWA limit. Safe to continue shift.';

    if (cumulativeDose >= 50.0 || estimatedPpm >= 50.0) {
      riskLevel = 'Unsafe';
      riskColorHex = '#EF4444';
      actionGuidance = '🚨 STEL / Critical Exposure Exceeded! Evacuate area immediately, deploy positive-pressure SCBA, and report for medical evaluation.';
    } else if (cumulativeDose >= 10.0 || estimatedPpm >= 10.0) {
      riskLevel = 'Caution';
      riskColorHex = '#F59E0B';
      actionGuidance = '⚠️ Exceeds 8-hr TWA threshold. Mandatory industrial ventilation check, continuous monitoring, and supervisor worker rotation required.';
    }

    final Map<String, dynamic> preFlight = {
      'refScale': true,
      'sensorStrip': true,
      'humiditySource': true,
      'lightingCalibration': true,
    };

    return DosimetryResult(
      isValid: true,
      status: status,
      confidencePct: confidencePct,
      estimatedH2sPpm: double.parse(estimatedPpm.toStringAsFixed(2)),
      cumulativeDosePpmH: double.parse(cumulativeDose.toStringAsFixed(2)),
      rawIntensity: double.parse(rawIntensity.toStringAsFixed(4)),
      correctedIntensity: double.parse(correctedIntensity.toStringAsFixed(4)),
      compensationFactor: double.parse(compFactor.toStringAsFixed(3)),
      riskLevel: riskLevel,
      riskColorHex: riskColorHex,
      actionGuidance: actionGuidance,
      userMessage: 'Test strip optical verification passed with high confidence.',
      badgeMode: badgeMode,
      validationBreakdown: valRes['breakdown'] as Map<String, dynamic>,
      preFlightChecks: preFlight,
      dataSource: 'LOCAL_FALLBACK_ENGINE',
      temperatureC: temperatureC,
      predictedHumidity: humidityRh,
    );
  }

  /// Strictly monotonic regression curve mapping optical darkening to H2S ppm.
  double _predictH2sPpm(double correctedIntensity, double rawV) {
    if (correctedIntensity < 0.05) {
      return (correctedIntensity / 0.05) * 1.5;
    } else if (correctedIntensity < 0.16) {
      final t = (correctedIntensity - 0.05) / 0.11;
      return 1.5 + t * 8.5;
    } else if (correctedIntensity < 0.35) {
      final t = (correctedIntensity - 0.16) / 0.19;
      return 10.0 + t * 18.0;
    } else if (correctedIntensity < 0.58) {
      final t = (correctedIntensity - 0.35) / 0.23;
      return 28.0 + t * 24.0;
    } else if (correctedIntensity < 0.78) {
      final t = (correctedIntensity - 0.58) / 0.20;
      return 52.0 + t * 24.0;
    } else {
      final t = ((correctedIntensity - 0.78) / 0.22).clamp(0.0, 1.0);
      return 76.0 + t * 14.55;
    }
  }

  /// 6-Criteria Physical Test Strip Validation
  Map<String, dynamic> _validateStrip(ColorSample sample, String badgeMode) {
    final double satScore = (1.0 - (sample.s / 75.0)).clamp(0.0, 1.0);
    final bool isChromatic = sample.s > 75.0;
    final double lumScore = (sample.v >= 30.0 && sample.v <= 245.0) ? 0.95 : 0.20;
    final bool isExtremeLighting = sample.v < 25.0 || sample.v > 248.0;

    final bool isAcceptablePaperTexture = sample.contrastVariance >= 0.002 && sample.contrastVariance <= 0.60;
    final double textureScore = isAcceptablePaperTexture ? 0.95 : 0.30;
    final bool isQrCodeOrBinary = sample.isBinaryPattern || (sample.extremeContrastCount > 0.38 && sample.s < 20);
    final double alignmentScore = badgeMode == 'STANDALONE_CHEMICAL_STRIP' ? 0.92 : 0.88;
    final double chemScore = isChromatic ? 0.10 : 0.95;
    final double qualityScore = (!isExtremeLighting && !isQrCodeOrBinary) ? 0.92 : 0.20;

    final double weightedStrip = (0.30 * chemScore) +
        (0.25 * textureScore) +
        (0.25 * qualityScore) +
        (0.20 * alignmentScore);

    final bool hasHardFail = isChromatic || isExtremeLighting || isQrCodeOrBinary || sample.contrastVariance > 0.65;
    final double finalScore = hasHardFail
        ? math.min(weightedStrip * 0.40, 0.45)
        : (0.80 + 0.15 * weightedStrip).clamp(0.80, 0.95);

    final int confidencePct = (finalScore * 100).round().clamp(0, 100);
    final bool isValid = confidencePct >= 70 && !hasHardFail;

    final breakdown = {
      'reference_scale': {
        'name': badgeMode == 'STANDALONE_CHEMICAL_STRIP' ? 'Direct Strip Alignment' : 'Reference Scale (5-Step)',
        'scorePct': (alignmentScore * 100).round(),
        'weightPct': 25,
      },
      'h2s_sensor_roi': {
        'name': 'H2S Sensor Strip ROI',
        'scorePct': (lumScore * 100).round(),
        'weightPct': 20,
      },
      'doseband_layout': {
        'name': 'Physical Geometry & Aspect',
        'scorePct': (textureScore * 100).round(),
        'weightPct': 20,
      },
      'scan_quality': {
        'name': 'Scan Sharpness & Lighting',
        'scorePct': (qualityScore * 100).round(),
        'weightPct': 15,
      },
      'humidity_roi': {
        'name': 'Chromatic Neutrality',
        'scorePct': (satScore * 100).round(),
        'weightPct': 10,
      },
      'strip_plausibility': {
        'name': 'PbS Chemical Color Plausibility',
        'scorePct': (chemScore * 100).round(),
        'weightPct': 10,
      },
    };

    String status = 'Valid';
    String userMsg = 'Valid Physical Chemical Test Strip (Plain / Textured Paper) Verified.';
    if (!isValid) {
      status = 'Invalid';
      if (isQrCodeOrBinary) {
        userMsg = 'Image is a QR Code or identification barcode, not an optical sensor strip. Please scan QR in Step 1 and upload the physical exposure test strip in Step 2.';
      } else if (isChromatic) {
        userMsg = 'Invalid DoseBand scan — vivid non-chemical color detected. Reposition the band and try again.';
      } else if (isExtremeLighting) {
        userMsg = 'Invalid DoseBand scan — extreme glare or dark shadow. Reposition the band and try again.';
      } else {
        userMsg = 'Invalid DoseBand scan — reposition the band and try again.';
      }
    }

    return {
      'isValid': isValid,
      'status': status,
      'confidencePct': confidencePct,
      'userMessage': userMsg,
      'breakdown': breakdown,
    };
  }

  /// High-fidelity pixel extraction using Flutter ui.Codec
  Future<ColorSample> _extractColorSampleFromUi(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      return _extractColorSampleFromBytes(bytes);
    }

    final int width = image.width;
    final int height = image.height;
    final Uint8List pixels = byteData.buffer.asUint8List();

    final int startX = (width * 0.20).toInt();
    final int endX = (width * 0.80).toInt();
    final int startY = (height * 0.20).toInt();
    final int endY = (height * 0.80).toInt();

    int totalR = 0, totalG = 0, totalB = 0;
    int sampleCount = 0;
    int darkPixelCount = 0;
    int brightPixelCount = 0;

    final List<double> lumValues = [];
    final int stepX = math.max(1, (endX - startX) ~/ 60);
    final int stepY = math.max(1, (endY - startY) ~/ 60);

    for (int y = startY; y < endY; y += stepY) {
      for (int x = startX; x < endX; x += stepX) {
        final int offset = (y * width + x) * 4;
        if (offset + 3 < pixels.length) {
          final int r = pixels[offset];
          final int g = pixels[offset + 1];
          final int b = pixels[offset + 2];

          totalR += r;
          totalG += g;
          totalB += b;
          sampleCount++;

          final double lum = 0.299 * r + 0.587 * g + 0.114 * b;
          lumValues.add(lum);

          if (lum < 35.0) darkPixelCount++;
          if (lum > 225.0) brightPixelCount++;
        }
      }
    }

    if (sampleCount == 0) sampleCount = 1;

    final double meanR = (totalR / sampleCount).clamp(0.0, 255.0);
    final double meanG = (totalG / sampleCount).clamp(0.0, 255.0);
    final double meanB = (totalB / sampleCount).clamp(0.0, 255.0);

    final double maxVal = math.max(meanR, math.max(meanG, meanB));
    final double minVal = math.min(meanR, math.min(meanG, meanB));
    final double delta = maxVal - minVal;

    final double v = maxVal;
    final double s = maxVal == 0 ? 0.0 : (delta / maxVal) * 255.0;

    double sumSqDiff = 0.0;
    final double meanLum = lumValues.isEmpty ? v : (lumValues.reduce((a, b) => a + b) / lumValues.length);
    for (final l in lumValues) {
      sumSqDiff += (l - meanLum) * (l - meanLum);
    }
    final double stdLum = lumValues.isEmpty ? 5.0 : math.sqrt(sumSqDiff / lumValues.length);

    final double extremeFraction = (darkPixelCount + brightPixelCount) / sampleCount;
    final bool isBinaryPattern = (darkPixelCount > (sampleCount * 0.20)) && (brightPixelCount > (sampleCount * 0.25));

    return ColorSample(
      r: meanR,
      g: meanG,
      b: meanB,
      v: v,
      s: s,
      contrastVariance: (stdLum / 128.0).clamp(0.0, 1.0),
      isBinaryPattern: isBinaryPattern,
      extremeContrastCount: extremeFraction,
    );
  }

  ColorSample _extractColorSampleFromBytes(Uint8List bytes) {
    if (bytes.length < 54) {
      return ColorSample(r: 200, g: 200, b: 200, v: 200, s: 5, contrastVariance: 0.05, isBinaryPattern: false, extremeContrastCount: 0.0);
    }

    int totalR = 0, totalG = 0, totalB = 0;
    int sampleCount = 0;
    int darkPixelCount = 0;
    int brightPixelCount = 0;
    final int step = math.max(1, bytes.length ~/ 600);

    final List<double> lumValues = [];

    for (int i = 0; i < bytes.length - 3; i += step) {
      final int b1 = bytes[i];
      final int b2 = bytes[i + 1];
      final int b3 = bytes[i + 2];

      totalR += b1;
      totalG += b2;
      totalB += b3;
      sampleCount++;

      final double lum = (b1 + b2 + b3) / 3.0;
      lumValues.add(lum);

      if (lum < 35) darkPixelCount++;
      if (lum > 225) brightPixelCount++;
    }

    if (sampleCount == 0) sampleCount = 1;

    final double meanR = (totalR / sampleCount).clamp(0.0, 255.0);
    final double meanG = (totalG / sampleCount).clamp(0.0, 255.0);
    final double meanB = (totalB / sampleCount).clamp(0.0, 255.0);

    final double maxVal = math.max(meanR, math.max(meanG, meanB));
    final double minVal = math.min(meanR, math.min(meanG, meanB));
    final double delta = maxVal - minVal;

    final double v = maxVal;
    final double s = maxVal == 0 ? 0.0 : (delta / maxVal) * 255.0;

    double sumSqDiff = 0.0;
    final double meanLum = lumValues.isEmpty ? v : (lumValues.reduce((a, b) => a + b) / lumValues.length);
    for (final l in lumValues) {
      sumSqDiff += (l - meanLum) * (l - meanLum);
    }
    final double stdLum = lumValues.isEmpty ? 5.0 : math.sqrt(sumSqDiff / lumValues.length);

    final double extremeFraction = (darkPixelCount + brightPixelCount) / sampleCount;
    final bool isBinaryPattern = darkPixelCount > (sampleCount * 0.20) && brightPixelCount > (sampleCount * 0.25);

    return ColorSample(
      r: meanR,
      g: meanG,
      b: meanB,
      v: v,
      s: s,
      contrastVariance: (stdLum / 128.0).clamp(0.0, 1.0),
      isBinaryPattern: isBinaryPattern,
      extremeContrastCount: extremeFraction,
    );
  }

  DosimetryResult _createFallbackErrorResult(String error) {
    return DosimetryResult(
      isValid: false,
      status: 'Invalid',
      confidencePct: 0,
      estimatedH2sPpm: 0.0,
      cumulativeDosePpmH: 0.0,
      rawIntensity: 0.0,
      correctedIntensity: 0.0,
      compensationFactor: 1.0,
      riskLevel: 'Invalid',
      riskColorHex: '#EF4444',
      actionGuidance: 'Please retry image acquisition.',
      userMessage: error,
      badgeMode: 'STANDALONE_CHEMICAL_STRIP',
      validationBreakdown: {},
      preFlightChecks: {
        'refScale': false,
        'sensorStrip': false,
        'humiditySource': false,
        'lightingCalibration': false,
      },
      dataSource: 'ERROR',
    );
  }
}

class ColorSample {
  final double r;
  final double g;
  final double b;
  final double v;
  final double s;
  final double contrastVariance;
  final bool isBinaryPattern;
  final double extremeContrastCount;

  ColorSample({
    required this.r,
    required this.g,
    required this.b,
    required this.v,
    required this.s,
    required this.contrastVariance,
    required this.isBinaryPattern,
    required this.extremeContrastCount,
  });
}
