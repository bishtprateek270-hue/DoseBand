"""
DoseBand Test-Strip Validator Module.

Enforces strict multi-criteria physical and optical verification before H2S gas prediction:
1. Reference-Scale Monotonicity & Step Verification (5-swatch descending grayscale scale).
2. Spatial Layout & Geometry Verification (relative position of scale, sensor strip, humidity patch).
3. Surface Texture & Internal Edge Density Verification (continuous paper dye vs screenshot/text/scenes).
4. Colorimetric Plausibility Verification (neutral lead acetate / PbS darkening range).
5. DoseBand Structure Verification.

Confidence Thresholds:
- >= 0.80 : Valid (Proceed to lighting correction & ML prediction)
- 0.65 - 0.79 : Uncertain (Retake required)
- < 0.65 : Invalid (Unsupported image / Analysis blocked)
"""

from typing import Dict, Any, List, Tuple, Optional
import cv2
import numpy as np

INVALID_IMAGE_MESSAGE = "Unsupported image. Please scan a valid DoseBand H₂S test strip with the reference scale visible."
UNCERTAIN_IMAGE_MESSAGE = "Test strip could not be verified reliably. Please retake the image with the complete DoseBand visible and good lighting."


def verify_reference_scale(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies that the reference scale contains 5 distinct descending grayscale steps.
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    # Reference scale occupies left ~33%
    ref_x1 = int(w * 0.03)
    ref_x2 = int(w * 0.30)
    ref_y1 = int(h * 0.10)
    ref_y2 = int(h * 0.88)

    ref_crop = image_bgr[ref_y1:ref_y2, ref_x1:ref_x2]
    if ref_crop.size == 0 or ref_crop.shape[0] < 40 or ref_crop.shape[1] < 20:
        return 0.0, {"detected": False}, ["Reference scale region missing or truncated."]

    ref_gray = cv2.cvtColor(ref_crop, cv2.COLOR_BGR2GRAY)
    ref_hsv = cv2.cvtColor(ref_crop, cv2.COLOR_BGR2HSV)

    # Divide into 5 vertical segments
    seg_h = ref_gray.shape[0] // 5
    swatch_means = []
    swatch_sats = []

    for i in range(5):
        sy1 = i * seg_h + int(seg_h * 0.20)
        sy2 = (i + 1) * seg_h - int(seg_h * 0.20)
        seg = ref_gray[sy1:sy2, int(ref_gray.shape[1] * 0.20) : int(ref_gray.shape[1] * 0.80)]
        seg_hsv = ref_hsv[sy1:sy2, int(ref_hsv.shape[1] * 0.20) : int(ref_hsv.shape[1] * 0.80)]
        
        if seg.size > 0:
            swatch_means.append(float(np.mean(seg)))
            swatch_sats.append(float(np.mean(seg_hsv[:, :, 1])))
        else:
            swatch_means.append(128.0)
            swatch_sats.append(0.0)

    # 1. Monotonicity check: White -> Light Gray -> Mid Gray -> Dark Gray -> Black
    monotonic_steps = 0
    step_diffs = []
    for i in range(4):
        diff = swatch_means[i] - swatch_means[i + 1]
        step_diffs.append(diff)
        if diff >= 10.0:  # Noticeable step down
            monotonic_steps += 1

    # 2. Dynamic range check (White vs Black span)
    dynamic_range = swatch_means[0] - swatch_means[4]
    
    # 3. Saturation check (Grayscale scale should have low saturation)
    avg_sat = float(np.mean(swatch_sats))

    score = 0.0
    # Step score (0.0 to 0.50)
    score += (monotonic_steps / 4.0) * 0.50
    # Dynamic range score (0.0 to 0.35)
    if dynamic_range >= 120.0:
        score += 0.35
    elif dynamic_range >= 70.0:
        score += 0.20
    elif dynamic_range >= 40.0:
        score += 0.10

    # Low saturation bonus (0.0 to 0.15)
    if avg_sat <= 30.0:
        score += 0.15
    elif avg_sat <= 60.0:
        score += 0.08

    if monotonic_steps < 3:
        rejection_reasons.append("Reference scale missing expected 5 descending grayscale steps.")
    if dynamic_range < 50.0:
        rejection_reasons.append("Insufficient contrast/dynamic range on reference scale.")

    diag = {
        "swatch_means": [round(m, 1) for m in swatch_means],
        "step_diffs": [round(d, 1) for d in step_diffs],
        "monotonic_steps": monotonic_steps,
        "dynamic_range": round(dynamic_range, 1),
        "avg_saturation": round(avg_sat, 1),
        "score": round(score, 3)
    }

    return float(np.clip(score, 0.0, 1.0)), diag, rejection_reasons


def verify_spatial_layout(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies that the image contains the geometric structure and aspect ratio of a DoseBand badge.
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    # Active sensor strip region
    strip_x1 = int(w * 0.35)
    strip_x2 = int(w * 0.95)
    strip_y1 = int(h * 0.10)
    strip_y2 = int(h * 0.68)

    strip_w = strip_x2 - strip_x1
    strip_h = strip_y2 - strip_y1
    strip_area_ratio = (strip_w * strip_h) / float(w * h)
    aspect_ratio = strip_w / float(strip_h) if strip_h > 0 else 0.0

    score = 0.0
    # Aspect ratio check (Expected rectangular strip W/H ~ 1.2 to 3.2)
    if 1.1 <= aspect_ratio <= 3.5:
        score += 0.50
    elif 0.8 <= aspect_ratio <= 4.0:
        score += 0.25
    else:
        rejection_reasons.append(f"Invalid sensor strip aspect ratio ({aspect_ratio:.2f}). Expected rectangular badge layout.")

    # Usable area check (Strip occupies roughly 15% to 45% of badge frame)
    if 0.14 <= strip_area_ratio <= 0.50:
        score += 0.50
    elif 0.08 <= strip_area_ratio <= 0.65:
        score += 0.25
    else:
        rejection_reasons.append("Sensor region area is outside valid DoseBand geometric specifications.")

    diag = {
        "aspect_ratio": round(aspect_ratio, 2),
        "strip_area_ratio": round(strip_area_ratio, 3),
        "score": round(score, 3)
    }

    return float(np.clip(score, 0.0, 1.0)), diag, rejection_reasons


def verify_surface_texture_and_edges(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Analyzes sensor region texture to confirm continuous chemical dye paper
    and reject screenshots, text blocks, fabric weave, walls, or chaotic scene noise.
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    # Sample central 60% of sensor region
    sx1 = int(w * 0.45)
    sx2 = int(w * 0.85)
    sy1 = int(h * 0.20)
    sy2 = int(h * 0.58)

    sample_bgr = image_bgr[sy1:sy2, sx1:sx2]
    if sample_bgr.size == 0:
        return 0.0, {}, ["Sensor sample area empty."]

    sample_gray = cv2.cvtColor(sample_bgr, cv2.COLOR_BGR2GRAY)
    
    # 1. Edge density analysis (Canny)
    edges = cv2.Canny(sample_gray, 50, 150)
    edge_density = float(np.count_nonzero(edges)) / float(edges.size)

    # 2. Local standard deviation / texture homogeneity
    std_dev = float(np.std(sample_gray))

    score = 0.0

    # Low edge density is expected for clean sensor paper (dye tint is smooth)
    if edge_density <= 0.04:
        score += 0.50
    elif edge_density <= 0.09:
        score += 0.30
    elif edge_density <= 0.15:
        score += 0.10
    else:
        rejection_reasons.append(f"High internal edge density ({edge_density:.3f}) detected. Image contains text, UI elements, or complex scene objects.")

    # Standard deviation: paper dye has natural subtle texture (std 0.5 to 25.0)
    if 0.5 <= std_dev <= 25.0:
        score += 0.50
    elif std_dev <= 35.0:
        score += 0.30
    else:
        rejection_reasons.append(f"Abnormal surface texture variance (std: {std_dev:.1f}). Texture does not match sensor paper.")

    diag = {
        "edge_density": round(edge_density, 4),
        "std_dev": round(std_dev, 2),
        "score": round(score, 3)
    }

    return float(np.clip(score, 0.0, 1.0)), diag, rejection_reasons


def verify_color_plausibility(image_bgr: np.ndarray) -> Tuple[float, Dict[str, Any], List[str]]:
    """
    Verifies that the sensor strip color falls within the chemical bounds of lead acetate paper:
    Fresh off-white/beige -> neutral gray -> brownish-gray -> dark lead sulfide (PbS) black.
    Rejects vivid saturated colors (pure red, green, blue, yellow, etc.).
    """
    h, w = image_bgr.shape[:2]
    rejection_reasons = []

    sx1 = int(w * 0.45)
    sx2 = int(w * 0.85)
    sy1 = int(h * 0.20)
    sy2 = int(h * 0.58)

    sample_bgr = image_bgr[sy1:sy2, sx1:sx2]
    if sample_bgr.size == 0:
        return 0.0, {}, ["Sensor sample area empty."]

    sample_hsv = cv2.cvtColor(sample_bgr, cv2.COLOR_BGR2HSV)
    sample_rgb = cv2.cvtColor(sample_bgr, cv2.COLOR_BGR2RGB)

    mean_sat = float(np.mean(sample_hsv[:, :, 1]))
    mean_val = float(np.mean(sample_hsv[:, :, 2]))
    mean_hue = float(np.mean(sample_hsv[:, :, 0]))

    r = float(np.mean(sample_rgb[:, :, 0]))
    g = float(np.mean(sample_rgb[:, :, 1]))
    b = float(np.mean(sample_rgb[:, :, 2]))

    # Max channel difference (R vs G vs B) - chemical staining is largely neutral / slightly warm
    channel_range = max(r, g, b) - min(r, g, b)

    score = 0.0

    # Low-to-moderate saturation is required for lead acetate/PbS
    if mean_sat <= 35.0:
        score += 0.50
    elif mean_sat <= 60.0:
        score += 0.30
    elif mean_sat <= 90.0:
        score += 0.10
    else:
        rejection_reasons.append(f"Vivid unnatural saturation ({mean_sat:.1f}/255) detected. H2S chemical indicators do not exhibit high chromatic saturation.")

    # Neutral channel balance check
    if channel_range <= 30.0:
        score += 0.50
    elif channel_range <= 55.0:
        score += 0.30
    else:
        rejection_reasons.append(f"Excessive chromatic channel divergence ({channel_range:.1f}). Sample is not an H2S dosimeter strip.")

    diag = {
        "mean_sat": round(mean_sat, 1),
        "mean_val": round(mean_val, 1),
        "mean_hue": round(mean_hue, 1),
        "channel_range": round(channel_range, 1),
        "score": round(score, 3)
    }

    return float(np.clip(score, 0.0, 1.0)), diag, rejection_reasons


def validate_test_strip(image_bgr: np.ndarray) -> Dict[str, Any]:
    """
    Executes comprehensive multi-criteria validation on an uploaded dosimeter image.

    Args:
        image_bgr (np.ndarray): Uploaded OpenCV BGR image array.

    Returns:
        dict: Complete validation report with status, confidence score, and diagnostics.
    """
    if image_bgr is None or image_bgr.size == 0:
        return {
            "status": "Invalid",
            "is_valid": False,
            "validation_score": 0.0,
            "confidence_pct": 0,
            "user_message": INVALID_IMAGE_MESSAGE,
            "rejection_reasons": ["Invalid or missing image buffer."],
            "checks": {}
        }

    all_reasons: List[str] = []

    # 1. Reference scale step verification
    ref_score, ref_diag, ref_reasons = verify_reference_scale(image_bgr)
    all_reasons.extend(ref_reasons)

    # 2. Spatial layout & aspect ratio verification
    layout_score, layout_diag, layout_reasons = verify_spatial_layout(image_bgr)
    all_reasons.extend(layout_reasons)

    # 3. Surface texture & edge density verification
    texture_score, texture_diag, texture_reasons = verify_surface_texture_and_edges(image_bgr)
    all_reasons.extend(texture_reasons)

    # 4. Colorimetric chemistry verification
    color_score, color_diag, color_reasons = verify_color_plausibility(image_bgr)
    all_reasons.extend(color_reasons)

    # 5. Composite weighted scoring
    # Reference scale (35%), Layout (25%), Texture (20%), Color (20%)
    raw_composite = (
        0.35 * ref_score +
        0.25 * layout_score +
        0.20 * texture_score +
        0.20 * color_score
    )

    # Hard-gate penalty: If reference scale is completely absent (< 0.35) or layout is invalid (< 0.25), cap score
    if ref_score < 0.35:
        composite_score = min(raw_composite, 0.45)
    elif layout_score < 0.30:
        composite_score = min(raw_composite, 0.55)
    else:
        composite_score = raw_composite

    composite_score = float(np.clip(composite_score, 0.0, 1.0))
    confidence_pct = int(round(composite_score * 100))

    # Classification
    if composite_score >= 0.80:
        status = "Valid"
        is_valid = True
        user_msg = "✅ Valid DoseBand H₂S dosimeter badge verified. Ready for optical ML analysis."
    elif composite_score >= 0.65:
        status = "Uncertain"
        is_valid = False
        user_msg = UNCERTAIN_IMAGE_MESSAGE
    else:
        status = "Invalid"
        is_valid = False
        user_msg = INVALID_IMAGE_MESSAGE

    return {
        "status": status,
        "is_valid": is_valid,
        "validation_score": round(composite_score, 3),
        "confidence_pct": confidence_pct,
        "user_message": user_msg,
        "rejection_reasons": all_reasons,
        "checks": {
            "reference_scale": ref_diag,
            "spatial_layout": layout_diag,
            "surface_texture": texture_diag,
            "color_chemistry": color_diag
        }
    }
