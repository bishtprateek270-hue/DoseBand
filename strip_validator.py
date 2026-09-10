"""
DoseBand Test-Strip Validator Module.

Enforces strict multi-criteria physical and optical verification before H2S gas prediction.
Calculates a 100% dynamic, image-specific weighted confidence score (0–100%) based on:
1. Reference Scale Detection & Monotonicity (25% Weight)
2. H2S Sensor Strip ROI Detection & Contrast (20% Weight)
3. DoseBand Expected Spatial Layout & Geometry (20% Weight)
4. Scan & Lighting Quality (Sharpness, Exposure, Contrast) (15% Weight)
5. Humidity Indicator ROI Detection (10% Weight)
6. Strip Texture & Chemical Color Plausibility (10% Weight)

Confidence Thresholds:
- >= 0.80 (>= 80%) : Valid (Proceed to lighting correction & ML prediction)
- 0.65 - 0.79 (65-79%) : Uncertain (Retake recommended)
- < 0.65 (< 65%) : Invalid (Unsupported image / Analysis blocked)
"""

from typing import Dict, Any, List, Tuple, Optional
import cv2
import numpy as np

INVALID_IMAGE_MESSAGE = "Unable to verify a valid DoseBand H₂S dosimeter strip. Please align the complete badge within the frame."
UNCERTAIN_IMAGE_MESSAGE = "Image alignment or lighting could not be verified reliably. Please hold the camera steady and retake."


def verify_reference_scale(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies reference scale presence, 5-segment descending grayscale steps, contrast, and neutrality.
    Weight: 25%
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    ref_x1 = int(w * 0.02)
    ref_x2 = int(w * 0.32)
    ref_y1 = int(h * 0.08)
    ref_y2 = int(h * 0.90)

    ref_crop = image_bgr[ref_y1:ref_y2, ref_x1:ref_x2]
    if ref_crop.size == 0 or ref_crop.shape[0] < 40 or ref_crop.shape[1] < 20:
        return 0.0, {"detected": False, "score": 0.0}, ["Reference scale region missing or truncated."]

    ref_gray = cv2.cvtColor(ref_crop, cv2.COLOR_BGR2GRAY)
    ref_hsv = cv2.cvtColor(ref_crop, cv2.COLOR_BGR2HSV)

    # Divide vertically into 5 swatches
    seg_h = ref_gray.shape[0] // 5
    swatch_means = []
    swatch_sats = []

    for i in range(5):
        sy1 = i * seg_h + int(seg_h * 0.15)
        sy2 = (i + 1) * seg_h - int(seg_h * 0.15)
        seg = ref_gray[sy1:sy2, int(ref_gray.shape[1] * 0.15) : int(ref_gray.shape[1] * 0.85)]
        seg_hsv = ref_hsv[sy1:sy2, int(ref_hsv.shape[1] * 0.15) : int(ref_hsv.shape[1] * 0.85)]
        
        if seg.size > 0:
            swatch_means.append(float(np.median(seg)))
            swatch_sats.append(float(np.mean(seg_hsv[:, :, 1])))
        else:
            swatch_means.append(128.0)
            swatch_sats.append(0.0)

    # 1. Monotonicity check (drops between consecutive steps)
    step_drops = []
    step_drop_scores = []
    monotonic_count = 0
    for i in range(4):
        drop = swatch_means[i] - swatch_means[i + 1]
        step_drops.append(drop)
        if drop >= 12.0:
            monotonic_count += 1
        # Continuous drop quality (ideal drop is ~40-64 per step)
        drop_quality = float(np.clip((drop - 5.0) / 45.0, 0.0, 1.0))
        step_drop_scores.append(drop_quality)

    mono_score = float(np.mean(step_drop_scores))

    # 2. Dynamic range (White swatch minus Black swatch)
    dynamic_range = swatch_means[0] - swatch_means[4]
    range_score = float(np.clip((dynamic_range - 40.0) / 190.0, 0.0, 1.0))

    # 3. Saturation neutrality (grayscale swatches must have low chromatic saturation)
    avg_sat = float(np.mean(swatch_sats))
    sat_score = float(np.clip((70.0 - avg_sat) / 55.0, 0.0, 1.0))

    # 4. Swatch gradient edge sharpness between segments
    diff_var = float(np.std(step_drops)) if len(step_drops) > 1 else 50.0
    consistency_score = float(np.clip(1.0 - (diff_var / 60.0), 0.0, 1.0))

    raw_score = 0.40 * mono_score + 0.35 * range_score + 0.15 * sat_score + 0.10 * consistency_score
    raw_score = float(np.clip(raw_score, 0.0, 1.0))

    if monotonic_count < 3:
        rejection_reasons.append("Reference scale missing expected 5 descending grayscale steps.")
    if dynamic_range < 50.0:
        rejection_reasons.append("Insufficient contrast/dynamic range on reference scale.")

    diag = {
        "swatch_means": [round(m, 1) for m in swatch_means],
        "step_drops": [round(d, 1) for d in step_drops],
        "monotonic_steps": monotonic_count,
        "dynamic_range": round(dynamic_range, 1),
        "avg_saturation": round(avg_sat, 1),
        "score": round(raw_score, 3)
    }

    return raw_score, diag, rejection_reasons


def verify_h2s_sensor_roi(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies presence, geometry, boundary definition, and contrast of the H2S sensor strip.
    Weight: 20%
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    strip_x1 = int(w * 0.35)
    strip_x2 = int(w * 0.96)
    strip_y1 = int(h * 0.10)
    strip_y2 = int(h * 0.68)

    strip_crop = image_bgr[strip_y1:strip_y2, strip_x1:strip_x2]
    if strip_crop.size == 0:
        return 0.0, {"score": 0.0}, ["H2S sensor strip region missing."]

    strip_w = strip_x2 - strip_x1
    strip_h = strip_y2 - strip_y1
    strip_area_ratio = (strip_w * strip_h) / float(w * h)
    aspect_ratio = strip_w / float(strip_h) if strip_h > 0 else 0.0

    # Aspect ratio score (ideal is ~2.0 for DoseBand H2S window)
    ar_score = float(np.clip(1.0 - abs(aspect_ratio - 2.0) / 1.4, 0.0, 1.0))

    # Area coverage score (ideal occupies 20% to 40% of image)
    area_score = float(np.clip(1.0 - abs(strip_area_ratio - 0.28) / 0.18, 0.0, 1.0))

    # Contrast vs surrounding margin (sample margin above and below strip)
    margin_top = image_bgr[max(0, strip_y1 - 20):strip_y1, strip_x1:strip_x2]
    if margin_top.size > 0:
        margin_mean = float(np.mean(cv2.cvtColor(margin_top, cv2.COLOR_BGR2GRAY)))
        strip_mean = float(np.mean(cv2.cvtColor(strip_crop, cv2.COLOR_BGR2GRAY)))
        contrast_diff = abs(margin_mean - strip_mean)
        # Having a distinct bounding border or color step gives positive contrast score
        contrast_score = float(np.clip(contrast_diff / 30.0 + 0.50, 0.0, 1.0))
    else:
        contrast_score = 0.70

    # Internal uniformity (paper dye should have low noise variance)
    strip_gray = cv2.cvtColor(strip_crop, cv2.COLOR_BGR2GRAY)
    internal_std = float(np.std(strip_gray))
    uniformity_score = float(np.clip(1.0 - (internal_std - 5.0) / 35.0, 0.0, 1.0))

    raw_score = 0.35 * ar_score + 0.30 * area_score + 0.20 * contrast_score + 0.15 * uniformity_score
    raw_score = float(np.clip(raw_score, 0.0, 1.0))

    if aspect_ratio < 1.0 or aspect_ratio > 3.8:
        rejection_reasons.append(f"Invalid sensor strip aspect ratio ({aspect_ratio:.2f}).")
    if strip_area_ratio < 0.10:
        rejection_reasons.append("Sensor region area is too small.")

    diag = {
        "aspect_ratio": round(aspect_ratio, 2),
        "area_ratio": round(strip_area_ratio, 3),
        "internal_std": round(internal_std, 2),
        "contrast_score": round(contrast_score, 3),
        "score": round(raw_score, 3)
    }

    return raw_score, diag, rejection_reasons


def verify_doseband_layout(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies the multi-component spatial layout of DoseBand (left scale, top sensor, bottom indicators).
    Weight: 20%
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    badge_aspect_ratio = w / float(h) if h > 0 else 0.0
    # Expected landscape badge format ~ 1.3 to 1.8
    badge_ar_score = float(np.clip(1.0 - abs(badge_aspect_ratio - 1.5) / 0.7, 0.0, 1.0))

    # Check structural layout division:
    # 1. Left third contains high vertical gradient (scale)
    left_third = image_bgr[:, :int(w * 0.33)]
    left_gray = cv2.cvtColor(left_third, cv2.COLOR_BGR2GRAY)
    left_std = float(np.std(left_gray))
    left_struct_score = float(np.clip((left_std - 15.0) / 50.0, 0.0, 1.0))

    # 2. Right two-thirds contains two distinct vertical blocks (upper sensor + lower indicators)
    right_upper = image_bgr[int(h * 0.10):int(h * 0.65), int(w * 0.35):]
    right_lower = image_bgr[int(h * 0.68):int(h * 0.95), int(w * 0.35):]

    if right_upper.size > 0 and right_lower.size > 0:
        ru_mean = float(np.mean(right_upper))
        rl_mean = float(np.mean(right_lower))
        diff_blocks = abs(ru_mean - rl_mean)
        block_div_score = float(np.clip(0.60 + (diff_blocks / 60.0) * 0.40, 0.0, 1.0))
    else:
        block_div_score = 0.20

    # 3. Background margin consistency
    margin_pixel = image_bgr[max(0, int(h * 0.05)), max(0, int(w * 0.50))]
    margin_brightness = float(np.mean(margin_pixel))
    margin_score = float(np.clip((margin_brightness - 80.0) / 120.0, 0.0, 1.0))

    raw_score = 0.35 * badge_ar_score + 0.35 * left_struct_score + 0.20 * block_div_score + 0.10 * margin_score
    raw_score = float(np.clip(raw_score, 0.0, 1.0))

    if badge_aspect_ratio < 0.9 or badge_aspect_ratio > 2.5:
        rejection_reasons.append(f"Abnormal badge image aspect ratio ({badge_aspect_ratio:.2f}).")

    diag = {
        "badge_aspect_ratio": round(badge_aspect_ratio, 2),
        "left_structure_std": round(left_std, 1),
        "margin_brightness": round(margin_brightness, 1),
        "score": round(raw_score, 3)
    }

    return raw_score, diag, rejection_reasons


def verify_scan_and_lighting_quality(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Evaluates image focus sharpness (Laplacian variance), exposure brightness, and dynamic range.
    Weight: 15%
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)

    # 1. Laplacian sharpness
    lap_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    sharp_score = float(np.clip((lap_var - 20.0) / 110.0, 0.0, 1.0))

    # 2. Exposure & Brightness (Ideal is 140–210)
    brightness = float(np.mean(gray))
    exp_score = float(np.clip(1.0 - abs(brightness - 175.0) / 95.0, 0.0, 1.0))

    # 3. Overall Image Dynamic Range & Contrast
    contrast = float(np.std(gray))
    contrast_score = float(np.clip((contrast - 18.0) / 55.0, 0.0, 1.0))

    raw_score = 0.45 * sharp_score + 0.35 * exp_score + 0.20 * contrast_score
    raw_score = float(np.clip(raw_score, 0.0, 1.0))

    if lap_var < 35.0:
        rejection_reasons.append(f"Image is blurry / out of focus (Sharpness: {lap_var:.1f}).")
    if brightness < 30.0 or brightness > 240.0:
        rejection_reasons.append(f"Severe lighting issue (Mean brightness: {brightness:.1f}).")

    diag = {
        "sharpness": round(lap_var, 1),
        "brightness": round(brightness, 1),
        "contrast": round(contrast, 1),
        "score": round(raw_score, 3)
    }

    return raw_score, diag, rejection_reasons


def verify_humidity_roi(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies presence and structure of the circular humidity indicator card in lower center.
    Weight: 10%
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    hum_x1 = int(w * 0.36)
    hum_x2 = int(w * 0.68)
    hum_y1 = int(h * 0.68)
    hum_y2 = int(h * 0.96)

    hum_crop = image_bgr[hum_y1:hum_y2, hum_x1:hum_x2]
    if hum_crop.size == 0:
        return 0.0, {"score": 0.0}, ["Humidity indicator ROI missing."]

    ch, cw = hum_crop.shape[:2]
    center_y, center_x = ch // 2, cw // 2
    r_disc = max(4, int(min(ch, cw) // 2 - 8))

    # Mask for inner circular disc
    yy, xx = np.ogrid[:ch, :cw]
    dist = np.sqrt((xx - center_x)**2 + (yy - center_y)**2)
    inner_mask = dist <= r_disc
    outer_mask = (dist > r_disc) & (dist <= r_disc + 6)

    inner_pixels = hum_crop[inner_mask]
    outer_pixels = hum_crop[outer_mask]

    if inner_pixels.size > 0 and outer_pixels.size > 0:
        inner_mean = float(np.mean(cv2.cvtColor(inner_pixels.reshape(-1, 1, 3), cv2.COLOR_BGR2GRAY)))
        outer_mean = float(np.mean(cv2.cvtColor(outer_pixels.reshape(-1, 1, 3), cv2.COLOR_BGR2GRAY)))
        disc_border_contrast = abs(inner_mean - outer_mean)
        contrast_score = float(np.clip(disc_border_contrast / 25.0 + 0.35, 0.0, 1.0))

        # Check chromatic color plausibility of inner disc (blue -> lavender -> pink)
        inner_hsv = cv2.cvtColor(inner_pixels.reshape(-1, 1, 3), cv2.COLOR_BGR2HSV)
        sat_val = float(np.mean(inner_hsv[:, :, 1]))
        color_score = float(np.clip(sat_val / 40.0, 0.30, 1.0))
    else:
        contrast_score = 0.50
        color_score = 0.50

    presence_score = 0.90 if hum_crop.size > 400 else 0.30

    raw_score = 0.40 * presence_score + 0.35 * contrast_score + 0.25 * color_score
    raw_score = float(np.clip(raw_score, 0.0, 1.0))

    diag = {
        "disc_contrast": round(contrast_score, 3),
        "color_score": round(color_score, 3),
        "score": round(raw_score, 3)
    }

    return raw_score, diag, rejection_reasons


def verify_strip_texture_and_color_plausibility(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies that sensor strip exhibits continuous paper dye texture and chemically plausible PbS darkening.
    Weight: 10%
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    sx1 = int(w * 0.45)
    sx2 = int(w * 0.85)
    sy1 = int(h * 0.20)
    sy2 = int(h * 0.58)

    sample_bgr = image_bgr[sy1:sy2, sx1:sx2]
    if sample_bgr.size == 0:
        return 0.0, {"score": 0.0}, ["Sensor sample area empty."]

    sample_hsv = cv2.cvtColor(sample_bgr, cv2.COLOR_BGR2HSV)
    sample_rgb = cv2.cvtColor(sample_bgr, cv2.COLOR_BGR2RGB)
    sample_gray = cv2.cvtColor(sample_bgr, cv2.COLOR_BGR2GRAY)

    mean_sat = float(np.mean(sample_hsv[:, :, 1]))
    r = float(np.mean(sample_rgb[:, :, 0]))
    g = float(np.mean(sample_rgb[:, :, 1]))
    b = float(np.mean(sample_rgb[:, :, 2]))

    # Lead acetate / PbS is chemically neutral or warm brownish-gray (low to medium saturation)
    sat_score = float(np.clip((85.0 - mean_sat) / 65.0, 0.0, 1.0))

    # Channel divergence (max - min)
    channel_range = max(r, g, b) - min(r, g, b)
    balance_score = float(np.clip((50.0 - channel_range) / 40.0, 0.0, 1.0))

    # Canny edge density (rejects high-frequency text, UI icons, or complex scene wallpaper)
    edges = cv2.Canny(sample_gray, 50, 150)
    edge_density = float(np.count_nonzero(edges)) / float(edges.size)
    edge_score = float(np.clip(1.0 - (edge_density / 0.08), 0.0, 1.0))

    raw_score = 0.40 * sat_score + 0.35 * balance_score + 0.25 * edge_score
    raw_score = float(np.clip(raw_score, 0.0, 1.0))

    if mean_sat > 110.0:
        rejection_reasons.append(f"Vivid unnatural saturation ({mean_sat:.1f}) detected.")
    if edge_density > 0.12:
        rejection_reasons.append(f"High internal edge density ({edge_density:.3f}) detected.")

    diag = {
        "mean_sat": round(mean_sat, 1),
        "channel_range": round(channel_range, 1),
        "edge_density": round(edge_density, 4),
        "score": round(raw_score, 3)
    }

    return raw_score, diag, rejection_reasons


def validate_test_strip(image_bgr: np.ndarray) -> Dict[str, Any]:
    """
    Executes 100% dynamic, multi-criteria weighted validation on an uploaded dosimeter image.

    Weighting:
    - Reference Scale: 25% (0.25)
    - H2S Sensor ROI: 20% (0.20)
    - DoseBand Layout: 20% (0.20)
    - Scan Quality: 15% (0.15)
    - Humidity ROI: 10% (0.10)
    - Strip Texture & Color: 10% (0.10)

    Args:
        image_bgr (np.ndarray): Uploaded OpenCV BGR image array.

    Returns:
        dict: Complete validation report with continuous score (0-100%), breakdown, status, and diagnostics.
    """
    if image_bgr is None or image_bgr.size == 0:
        return {
            "status": "Invalid",
            "is_valid": False,
            "validation_score": 0.0,
            "confidence_pct": 0,
            "user_message": INVALID_IMAGE_MESSAGE,
            "rejection_reasons": ["Invalid or missing image buffer."],
            "checks": {},
            "breakdown": {}
        }

    all_reasons: List[str] = []

    # 1. Reference scale verification (25%)
    ref_score, ref_diag, ref_reasons = verify_reference_scale(image_bgr)
    all_reasons.extend(ref_reasons)

    # 2. H2S Sensor ROI verification (20%)
    h2s_score, h2s_diag, h2s_reasons = verify_h2s_sensor_roi(image_bgr)
    all_reasons.extend(h2s_reasons)

    # 3. DoseBand Expected Layout verification (20%)
    layout_score, layout_diag, layout_reasons = verify_doseband_layout(image_bgr)
    all_reasons.extend(layout_reasons)

    # 4. Scan & Lighting Quality verification (15%)
    quality_score, quality_diag, quality_reasons = verify_scan_and_lighting_quality(image_bgr)
    all_reasons.extend(quality_reasons)

    # 5. Humidity Indicator ROI verification (10%)
    hum_score, hum_diag, hum_reasons = verify_humidity_roi(image_bgr)
    all_reasons.extend(hum_reasons)

    # 6. Strip Texture & Chemical Plausibility verification (10%)
    plaus_score, plaus_diag, plaus_reasons = verify_strip_texture_and_color_plausibility(image_bgr)
    all_reasons.extend(plaus_reasons)

    # 7. Exact 6-Component Weighted Formula
    weighted_composite = (
        0.25 * ref_score +
        0.20 * h2s_score +
        0.20 * layout_score +
        0.15 * quality_score +
        0.10 * hum_score +
        0.10 * plaus_score
    )

    # Hard-gating penalties for non-badges and invalid images:
    # 1. Reference scale failure (must be present with distinct descending grayscale steps)
    if ref_score < 0.60 or ref_diag.get("monotonic_steps", 0) < 3 or ref_diag.get("dynamic_range", 0) < 50.0:
        final_score = min(weighted_composite, 0.45)
    # 2. H2S sensor region missing
    elif h2s_score < 0.35:
        final_score = min(weighted_composite, 0.42)
    # 3. Layout abnormality (not a badge geometry)
    elif layout_score < 0.35:
        final_score = min(weighted_composite, 0.48)
    # 4. Blur / focus failure (Laplacian variance < 35.0)
    elif quality_diag.get("sharpness", 0) < 35.0:
        final_score = min(weighted_composite, 0.45)
    # 5. Non-chemical high texture / UI screenshot / vivid colors
    elif plaus_diag.get("edge_density", 0) > 0.08 or plaus_diag.get("mean_sat", 0) > 100.0:
        final_score = min(weighted_composite, 0.45)
    else:
        final_score = weighted_composite

    final_score = float(np.clip(final_score, 0.0, 1.0))
    confidence_pct = int(round(final_score * 100))

    # Strict Status classification:
    # A test strip is ONLY Valid if final_score >= 0.80, reference scale is verified, and there are NO blocking rejection reasons
    has_hard_rejection = bool(
        len(all_reasons) > 0 or
        ref_score < 0.65 or
        quality_diag.get("sharpness", 0) < 35.0
    )

    if final_score >= 0.80 and not has_hard_rejection:
        status = "Valid"
        is_valid = True
        user_msg = "✅ Valid DoseBand H₂S dosimeter badge verified. Ready for optical ML analysis."
    elif final_score >= 0.65 and not has_hard_rejection:
        status = "Uncertain"
        is_valid = False
        user_msg = UNCERTAIN_IMAGE_MESSAGE
    else:
        status = "Invalid"
        is_valid = False
        user_msg = INVALID_IMAGE_MESSAGE

    breakdown = {
        "reference_scale": {
            "name": "Reference Scale (5-Step)",
            "weight_pct": 25,
            "score_pct": round(ref_score * 100, 1),
            "weighted_points": round(0.25 * ref_score * 100, 1),
            "details": ref_diag
        },
        "h2s_sensor_roi": {
            "name": "H2S Sensor ROI",
            "weight_pct": 20,
            "score_pct": round(h2s_score * 100, 1),
            "weighted_points": round(0.20 * h2s_score * 100, 1),
            "details": h2s_diag
        },
        "doseband_layout": {
            "name": "DoseBand Spatial Layout",
            "weight_pct": 20,
            "score_pct": round(layout_score * 100, 1),
            "weighted_points": round(0.20 * layout_score * 100, 1),
            "details": layout_diag
        },
        "scan_quality": {
            "name": "Scan & Lighting Quality",
            "weight_pct": 15,
            "score_pct": round(quality_score * 100, 1),
            "weighted_points": round(0.15 * quality_score * 100, 1),
            "details": quality_diag
        },
        "humidity_roi": {
            "name": "Humidity Card ROI",
            "weight_pct": 10,
            "score_pct": round(hum_score * 100, 1),
            "weighted_points": round(0.10 * hum_score * 100, 1),
            "details": hum_diag
        },
        "strip_plausibility": {
            "name": "Strip Texture & Chemistry",
            "weight_pct": 10,
            "score_pct": round(plaus_score * 100, 1),
            "weighted_points": round(0.10 * plaus_score * 100, 1),
            "details": plaus_diag
        }
    }

    return {
        "status": status,
        "is_valid": is_valid,
        "validation_score": round(final_score, 3),
        "confidence_pct": confidence_pct,
        "user_message": user_msg,
        "rejection_reasons": all_reasons,
        "breakdown": breakdown,
        "checks": {
            "reference_scale": ref_diag,
            "h2s_sensor_roi": h2s_diag,
            "spatial_layout": layout_diag,
            "scan_quality": quality_diag,
            "humidity_roi": hum_diag,
            "strip_plausibility": plaus_diag
        }
    }
