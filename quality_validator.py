"""
DoseBand Image Scan Quality & Region Detection Validation Module.

Performs pre-flight diagnostic validation on uploaded dosimeter images:
1. Blur & Sharpness Analysis (Laplacian Variance).
2. Illumination & Dynamic Range Verification (Mean Brightness & Contrast).
3. 5-Swatch Reference Color Scale Detection (Left ROI).
4. Active H2S Sensor Strip Region Detection (Center ROI).
5. Passive Shelf-Life Expiry Patch Detection (Bottom-Right ROI).
6. Lighting Calibration Feasibility (OLS Transformation Solver).
"""

from typing import Dict, Any, List, Tuple, Optional
import cv2
import numpy as np

import calibration
import expiry_checker
import strip_reader

# -----------------------------------------------------------------------------
# QUALITY THRESHOLDS
# -----------------------------------------------------------------------------
MIN_SHARPNESS_PASS: float = 8.0       # Relaxed for chemical strip crops / smooth paper
MIN_SHARPNESS_GOOD: float = 35.0      # Above this is crisp/high quality

MIN_BRIGHTNESS_PASS: float = 15.0     # Below this is pitch dark
MAX_BRIGHTNESS_PASS: float = 248.0    # Above this is severely overexposed
MIN_CONTRAST_PASS: float = 8.0        # Minimum standard deviation of grayscale pixels

MIN_BRIGHTNESS_GOOD: float = 35.0
MAX_BRIGHTNESS_GOOD: float = 225.0
MIN_CONTRAST_GOOD: float = 18.0


def evaluate_image_quality(image_bgr: np.ndarray) -> Dict[str, Any]:
    """
    Runs complete pre-flight scan quality validation on a raw BGR image.

    Args:
        image_bgr (np.ndarray): OpenCV BGR image array.

    Returns:
        Dict[str, Any]: Comprehensive diagnostic dictionary containing:
            - quality_status: 'Good' | 'Acceptable' | 'Retake Required'
            - is_valid_for_analysis: bool (True if Good or Acceptable)
            - sharpness_score: float
            - is_sharp: bool
            - brightness_score: float
            - is_lighting_adequate: bool
            - contrast_score: float
            - ref_scale_detected: bool
            - sensor_strip_detected: bool
            - expiry_patch_detected: bool
            - calibration_successful: bool
            - reasons: List[str] (Explanatory failure messages)
            - warnings: List[str] (Non-blocking improvement suggestions)
    """
    if image_bgr is None or image_bgr.size == 0:
        return {
            "quality_status": "Retake Required",
            "is_valid_for_analysis": False,
            "sharpness_score": 0.0,
            "is_sharp": False,
            "brightness_score": 0.0,
            "is_lighting_adequate": False,
            "contrast_score": 0.0,
            "ref_scale_detected": False,
            "sensor_strip_detected": False,
            "expiry_patch_detected": False,
            "calibration_successful": False,
            "reasons": ["Invalid or corrupted image data provided."],
            "warnings": []
        }

    h, w = image_bgr.shape[:2]
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)

    reasons: List[str] = []
    warnings: List[str] = []

    # -------------------------------------------------------------------------
    # 1. BLUR & SHARPNESS ANALYSIS
    # -------------------------------------------------------------------------
    sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    is_sharp_pass = sharpness >= MIN_SHARPNESS_PASS
    is_sharp_good = sharpness >= MIN_SHARPNESS_GOOD

    if not is_sharp_pass:
        reasons.append(
            f"Image is out of focus / blurry (Sharpness: {sharpness:.1f} / min required: {MIN_SHARPNESS_PASS:.1f}). "
            "Please hold the camera steady and retake."
        )
    elif not is_sharp_good:
        warnings.append(f"Image sharpness is slightly soft ({sharpness:.1f}), but sufficient for analysis.")

    # -------------------------------------------------------------------------
    # 2. LIGHTING & EXPOSURE ANALYSIS
    # -------------------------------------------------------------------------
    brightness = float(np.mean(gray))
    contrast = float(np.std(gray))

    is_lighting_pass = (MIN_BRIGHTNESS_PASS <= brightness <= MAX_BRIGHTNESS_PASS) and (contrast >= MIN_CONTRAST_PASS)
    is_lighting_good = (MIN_BRIGHTNESS_GOOD <= brightness <= MAX_BRIGHTNESS_GOOD) and (contrast >= MIN_CONTRAST_GOOD)

    if brightness < MIN_BRIGHTNESS_PASS:
        reasons.append(
            f"Image is severely underexposed / too dark (Brightness: {brightness:.1f}/255). "
            "Please ensure adequate ambient or flashlight lighting."
        )
    elif brightness > MAX_BRIGHTNESS_PASS:
        reasons.append(
            f"Image is severely overexposed / washed out (Brightness: {brightness:.1f}/255). "
            "Please avoid direct flash glare on the strip."
        )
    elif contrast < MIN_CONTRAST_PASS:
        reasons.append(
            f"Image contrast is too low (Contrast: {contrast:.1f}). "
            "Please position strip against a clean contrasting background."
        )
    elif not is_lighting_good:
        warnings.append(f"Lighting is slightly non-uniform (Brightness: {brightness:.1f}, Contrast: {contrast:.1f}).")

    # -------------------------------------------------------------------------
    # 3. 5-SWATCH REFERENCE COLOR SCALE DETECTION
    # -------------------------------------------------------------------------
    ref_scale_detected = False
    try:
        swatches = calibration.detect_reference_scale(image_bgr)
        if swatches and len(swatches) == 5:
            # Calculate grayscale luminance for each swatch: 0.114*B + 0.587*G + 0.299*R
            luminances = [0.114 * s[0] + 0.587 * s[1] + 0.299 * s[2] for s in swatches]
            # Valid reference scale MUST have a clear gradient from White (~255) to Black (~0)
            lum_diff = luminances[0] - luminances[-1]
            lum_std = float(np.std(luminances))
            
            # Swatch 0 must be significantly brighter than Swatch 4, and swatches must not be uniform
            if lum_diff >= 45.0 and lum_std >= 20.0:
                ref_scale_detected = True
            else:
                ref_scale_detected = False
    except calibration.ReferenceScaleNotFoundError:
        ref_scale_detected = False
    except Exception:
        ref_scale_detected = False

    if not ref_scale_detected:
        reasons.append(
            "Reference Color Scale Not Detected: The 5-swatch printed reference scale (White to Black) "
            "was not found or lacks required contrast in the left frame. Ensure the full scale is in frame."
        )

    # -------------------------------------------------------------------------
    # 4. ACTIVE SENSOR STRIP REGION DETECTION
    # -------------------------------------------------------------------------
    sensor_strip_detected = False
    try:
        strip_crop = strip_reader.extract_strip_region(image_bgr)
        sh, sw = strip_crop.shape[:2]
        # Valid strip region should be large enough and contain non-zero content
        if sh >= 30 and sw >= 30 and np.std(strip_crop) > 3.0:
            sensor_strip_detected = True
        else:
            sensor_strip_detected = False
    except Exception:
        sensor_strip_detected = False

    if not sensor_strip_detected:
        reasons.append(
            "Sensor Strip Region Not Detected: The active H2S indicator paper region is missing, "
            "occluded, or cut off from the camera view."
        )

    # -------------------------------------------------------------------------
    # 5. PASSIVE EXPIRY PATCH DETECTION
    # -------------------------------------------------------------------------
    expiry_patch_detected = False
    try:
        patch_crop = expiry_checker.extract_expiry_patch(image_bgr)
        ph, pw = patch_crop.shape[:2]
        if ph >= 15 and pw >= 15 and np.std(patch_crop) > 2.0:
            expiry_patch_detected = True
        else:
            expiry_patch_detected = False
    except Exception:
        expiry_patch_detected = False

    if not expiry_patch_detected:
        reasons.append(
            "Badge Expiry Patch Not Detected: The shelf-life indicator patch in the bottom-right corner "
            "was not detected or is cut off."
        )

    # -------------------------------------------------------------------------
    # 6. LIGHTING CALIBRATION OLS FEASIBILITY
    # -------------------------------------------------------------------------
    calibration_successful = False
    if ref_scale_detected:
        try:
            calibrated = calibration.calibrate_image(image_bgr)
            if calibrated is not None and calibrated.shape == image_bgr.shape:
                calibration_successful = True
        except Exception:
            calibration_successful = False

    if ref_scale_detected and not calibration_successful:
        reasons.append(
            "Lighting Calibration Matrix Failed: Could not solve per-channel OLS illumination correction "
            "due to extreme non-linear color clipping."
        )

    # -------------------------------------------------------------------------
    # 7. OVERALL QUALITY STATUS DETERMINATION
    # -------------------------------------------------------------------------
    critical_failures = (
        not is_sharp_pass or
        not is_lighting_pass or
        not ref_scale_detected or
        not sensor_strip_detected or
        not expiry_patch_detected or
        not calibration_successful
    )

    if critical_failures:
        quality_status = "Retake Required"
        is_valid_for_analysis = False
    elif is_sharp_good and is_lighting_good:
        quality_status = "Good"
        is_valid_for_analysis = True
    else:
        quality_status = "Acceptable"
        is_valid_for_analysis = True

    return {
        "quality_status": quality_status,
        "is_valid_for_analysis": is_valid_for_analysis,
        "sharpness_score": round(sharpness, 1),
        "is_sharp": is_sharp_pass,
        "brightness_score": round(brightness, 1),
        "is_lighting_adequate": is_lighting_pass,
        "contrast_score": round(contrast, 1),
        "ref_scale_detected": ref_scale_detected,
        "sensor_strip_detected": sensor_strip_detected,
        "expiry_patch_detected": expiry_patch_detected,
        "calibration_successful": calibration_successful,
        "reasons": reasons,
        "warnings": warnings
    }


if __name__ == "__main__":
    print("--- Testing Scan Quality Validator ---")
    sample_img = cv2.imread("test_images/base_normal.jpg")
    if sample_img is not None:
        diag = evaluate_image_quality(sample_img)
        print("Normal Sample Diagnosis:")
        for k, v in diag.items():
            print(f"  {k}: {v}")
    else:
        print("base_normal.jpg not found, please generate test assets.")
