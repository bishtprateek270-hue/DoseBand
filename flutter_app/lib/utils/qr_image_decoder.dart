import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../services/api_service.dart';

/// Result object for image-to-QR decoding operations.
class QrDecodeResult {
  final bool detected;
  final String? rawValue;
  final String? decoderUsed;
  final String? error;
  final int barcodesFound;
  final String? imagePath;
  final int? imageSizeBytes;
  final String? imageFormat;
  final int? width;
  final int? height;
  final List<String> debugSteps;

  const QrDecodeResult({
    required this.detected,
    this.rawValue,
    this.decoderUsed,
    this.error,
    this.barcodesFound = 0,
    this.imagePath,
    this.imageSizeBytes,
    this.imageFormat,
    this.width,
    this.height,
    this.debugSteps = const [],
  });

  Map<String, dynamic> toMap() => {
    'detected': detected,
    'rawValue': rawValue,
    'decoderUsed': decoderUsed,
    'error': error,
    'barcodesFound': barcodesFound,
    'imagePath': imagePath,
    'imageSizeBytes': imageSizeBytes,
    'imageFormat': imageFormat,
    'width': width,
    'height': height,
    'debugSteps': debugSteps,
  };

  @override
  String toString() =>
      'QrDecodeResult(detected: $detected, rawValue: $rawValue, decoder: $decoderUsed, barcodes: $barcodesFound)';
}

/// Decodes QR code from an image file using multi-stage analysis:
/// 1. Google ML Kit BarcodeScanner on original file directly
/// 2. Google ML Kit with normalized orientation (EXIF bake) & full-res PNG
/// 3. Preprocessing (Grayscale + High Contrast) & Fallback Center Crops
/// 4. Backend C++ ZXing multi-pass engine (if connected)
Future<QrDecodeResult> decodeQrFromImage(File file) async {
  final List<String> debugSteps = [];
  void logStep(String step) {
    debugSteps.add(step);
    debugPrint('[QR_DECODER] $step');
  }

  // 1. Validate File Exists
  if (!await file.exists()) {
    logStep('ERROR: File does not exist at ${file.path}');
    return QrDecodeResult(
      detected: false,
      rawValue: null,
      decoderUsed: 'None',
      error: 'File does not exist: ${file.path}',
      debugSteps: debugSteps,
    );
  }

  final bytes = await file.readAsBytes();
  final imageSize = bytes.length;
  final ext = p.extension(file.path).toLowerCase();
  
  logStep('==================================================');
  logStep('IMAGE PATH: ${file.path}');
  logStep('IMAGE SIZE: $imageSize bytes');
  logStep('IMAGE FORMAT: $ext');

  int? imgWidth;
  int? imgHeight;
  img.Image? decodedBitmap;

  try {
    decodedBitmap = img.decodeImage(bytes);
    if (decodedBitmap != null) {
      imgWidth = decodedBitmap.width;
      imgHeight = decodedBitmap.height;
      logStep('IMAGE DIMENSIONS: ${imgWidth}x$imgHeight');
    }
  } catch (e) {
    logStep('Bitmap decode warning: $e');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ATTEMPT 1: Google ML Kit on Original File Path Directly
  // ───────────────────────────────────────────────────────────────────────────
  logStep('--- ATTEMPT 1: Google ML Kit (Original File) ---');
  try {
    final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    final inputImage = InputImage.fromFilePath(file.path);
    final barcodes = await scanner.processImage(inputImage);
    await scanner.close();

    logStep('DECODER CALLED: Google ML Kit (Original)');
    logStep('NUMBER OF BARCODES FOUND: ${barcodes.length}');

    for (final barcode in barcodes) {
      logStep('RAW: ${barcode.rawValue}');
    }

    if (barcodes.isNotEmpty) {
      final validBarcode = barcodes.firstWhere(
        (b) => b.rawValue != null && b.rawValue!.trim().isNotEmpty,
        orElse: () => barcodes.first,
      );

      if (validBarcode.rawValue != null && validBarcode.rawValue!.trim().isNotEmpty) {
        final raw = validBarcode.rawValue!.trim();
        logStep('✅ ML Kit Success on Original: $raw');
        logStep('FORMAT: ${validBarcode.format}');
        return QrDecodeResult(
          detected: true,
          rawValue: raw,
          decoderUsed: 'MLKit_Original',
          barcodesFound: barcodes.length,
          imagePath: file.path,
          imageSizeBytes: imageSize,
          imageFormat: ext,
          width: imgWidth,
          height: imgHeight,
          debugSteps: debugSteps,
        );
      }
    }
    logStep('ML Kit Attempt 1 returned 0 decodable QR codes.');
  } catch (e) {
    logStep('ML Kit Attempt 1 Exception (e.g. desktop platform fallback): $e');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ATTEMPT 2: Normalize Orientation (EXIF Bake) & Save Uncompressed Full-Res PNG
  // ───────────────────────────────────────────────────────────────────────────
  if (decodedBitmap != null) {
    logStep('--- ATTEMPT 2: ML Kit on Normalized Orientation (EXIF Baked) ---');
    try {
      final baked = img.bakeOrientation(decodedBitmap);
      final pngBytes = Uint8List.fromList(img.encodePng(baked));
      
      final tempDir = Directory.systemTemp;
      final tempFile = File(p.join(tempDir.path, 'temp_qr_normalized_${DateTime.now().millisecondsSinceEpoch}.png'));
      await tempFile.writeAsBytes(pngBytes);

      final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final barcodes = await scanner.processImage(inputImage);
      await scanner.close();

      // Clean up temp file
      try { await tempFile.delete(); } catch (_) {}

      logStep('NUMBER OF BARCODES FOUND: ${barcodes.length}');
      for (final barcode in barcodes) {
        logStep('RAW: ${barcode.rawValue}');
      }

      if (barcodes.isNotEmpty) {
        final validBarcode = barcodes.firstWhere(
          (b) => b.rawValue != null && b.rawValue!.trim().isNotEmpty,
          orElse: () => barcodes.first,
        );

        if (validBarcode.rawValue != null && validBarcode.rawValue!.trim().isNotEmpty) {
          final raw = validBarcode.rawValue!.trim();
          logStep('✅ ML Kit Success on Normalized Image: $raw');
          return QrDecodeResult(
            detected: true,
            rawValue: raw,
            decoderUsed: 'MLKit_Normalized',
            barcodesFound: barcodes.length,
            imagePath: file.path,
            imageSizeBytes: imageSize,
            imageFormat: ext,
            width: imgWidth,
            height: imgHeight,
            debugSteps: debugSteps,
          );
        }
      }
    } catch (e) {
      logStep('ML Kit Attempt 2 Exception: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ATTEMPT 3: Contrast Enhancement & Fallback Center Crop
  // ───────────────────────────────────────────────────────────────────────────
  if (decodedBitmap != null) {
    logStep('--- ATTEMPT 3: Preprocessed High-Contrast & Center Crop ---');
    try {
      final baked = img.bakeOrientation(decodedBitmap);
      
      // 3A: Grayscale + High Contrast
      final highContrast = img.adjustColor(img.grayscale(baked), contrast: 1.8);
      final tempDir = Directory.systemTemp;
      final tempFile1 = File(p.join(tempDir.path, 'temp_qr_contrast_${DateTime.now().millisecondsSinceEpoch}.png'));
      await tempFile1.writeAsBytes(img.encodePng(highContrast));

      final scanner1 = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
      final barcodes1 = await scanner1.processImage(InputImage.fromFilePath(tempFile1.path));
      await scanner1.close();
      try { await tempFile1.delete(); } catch (_) {}

      if (barcodes1.isNotEmpty && barcodes1.first.rawValue != null) {
        final raw = barcodes1.first.rawValue!.trim();
        logStep('✅ ML Kit Success on High Contrast: $raw');
        return QrDecodeResult(
          detected: true,
          rawValue: raw,
          decoderUsed: 'MLKit_HighContrast',
          barcodesFound: barcodes1.length,
          imagePath: file.path,
          imageSizeBytes: imageSize,
          imageFormat: ext,
          width: imgWidth,
          height: imgHeight,
          debugSteps: debugSteps,
        );
      }

      // 3B: Center Crop (for screenshots with top/bottom system bars)
      final w = baked.width;
      final h = baked.height;
      if (w > 200 && h > 200) {
        final cropX = (w * 0.1).round();
        final cropY = (h * 0.1).round();
        final cropW = (w * 0.8).round();
        final cropH = (h * 0.8).round();
        final cropped = img.copyCrop(baked, x: cropX, y: cropY, width: cropW, height: cropH);
        
        final tempFile2 = File(p.join(tempDir.path, 'temp_qr_crop_${DateTime.now().millisecondsSinceEpoch}.png'));
        await tempFile2.writeAsBytes(img.encodePng(cropped));

        final scanner2 = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
        final barcodes2 = await scanner2.processImage(InputImage.fromFilePath(tempFile2.path));
        await scanner2.close();
        try { await tempFile2.delete(); } catch (_) {}

        if (barcodes2.isNotEmpty && barcodes2.first.rawValue != null) {
          final raw = barcodes2.first.rawValue!.trim();
          logStep('✅ ML Kit Success on Center Crop: $raw');
          return QrDecodeResult(
            detected: true,
            rawValue: raw,
            decoderUsed: 'MLKit_CenterCrop',
            barcodesFound: barcodes2.length,
            imagePath: file.path,
            imageSizeBytes: imageSize,
            imageFormat: ext,
            width: imgWidth,
            height: imgHeight,
            debugSteps: debugSteps,
          );
        }
      }
    } catch (e) {
      logStep('ML Kit Attempt 3 Exception: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ATTEMPT 4: Backend C++ ZXing Multi-Pass Engine (Fallback)
  // ───────────────────────────────────────────────────────────────────────────
  logStep('--- ATTEMPT 4: Backend C++ ZXing Multi-Pass Engine ---');
  try {
    final apiService = ApiService();
    final res = await apiService.verifyBadgeQr(imageBytes: bytes);
    logStep('Backend QR Verify Response: ${res['status']} (decoder: ${res['decoder']})');

    final rawPayload = res['raw_payload'] as String?;
    if (rawPayload != null && rawPayload.trim().isNotEmpty) {
      logStep('✅ Backend ZXing Success: $rawPayload');
      return QrDecodeResult(
        detected: true,
        rawValue: rawPayload.trim(),
        decoderUsed: res['decoder'] ?? 'Backend_ZXingCPP',
        barcodesFound: 1,
        imagePath: file.path,
        imageSizeBytes: imageSize,
        imageFormat: ext,
        width: imgWidth,
        height: imgHeight,
        debugSteps: debugSteps,
      );
    }
  } catch (e) {
    logStep('Backend ZXing Fallback note: $e');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ALL ATTEMPTS EXHAUSTED: NO QR FOUND
  // ───────────────────────────────────────────────────────────────────────────
  logStep('==================================================');
  logStep('NUMBER OF BARCODES FOUND: 0');
  logStep('RAW VALUE: null');
  logStep('RESULT: No QR code detected in this image.');
  logStep('==================================================');

  return QrDecodeResult(
    detected: false,
    rawValue: null,
    decoderUsed: 'None',
    error: 'No QR code detected in this image.',
    barcodesFound: 0,
    imagePath: file.path,
    imageSizeBytes: imageSize,
    imageFormat: ext,
    width: imgWidth,
    height: imgHeight,
    debugSteps: debugSteps,
  );
}
