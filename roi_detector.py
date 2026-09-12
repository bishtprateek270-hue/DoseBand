"""
DoseBand ROI Detector & Preprocessing Module.

Locates and extracts candidate ROIs from:
1. Physical 3D-Printed DoseBand Watch Enclosure (with perspective rectification & fixed sub-windows)
2. Reference Grayscale Step Wedge (for printed legacy badges)
3. H2S Lead Acetate Sensor Strip ROI (sampled centrally to avoid edge shadows, grille ribs, and text)
4. Humidity Indicator Patch / Circle ROI (sampled centrally to exclude borders)
5. Shelf-Life Expiry Patch ROI

Provides ROI confidence scoring, visualization overlays, and developer debug diagnostics.
"""

from typing import Dict, Tuple, Any, Optional
import cv2
import numpy as np
from doseband_device_detector import (
    detect_doseband_enclosure,
    warp_perspective_to_canonical,
    extract_robust_sensor_features,
    render_developer_debug_overlay,
    CANONICAL_WIDTH,
    CANONICAL_HEIGHT,
    BOTTOM_WINDOW_BOX,
    MIDDLE_WINDOW_BOX,
    TOP_WINDOW_BOX
)


def detect_all_rois(
    image_bgr: np.ndarray,
    min_confidence: float = 0.50,
    scan_mode: str = "full_badge"
) -> Dict[str, Any]:
    """
    Detects all key regions on a DoseBand dosimeter image (physical 3D enclosure, badge, or standalone strip).

    Args:
        image_bgr (np.ndarray): BGR image array.
        min_confidence (float): Minimum confidence threshold for valid ROI detection.
        scan_mode (str): 'full_badge' (enclosure/badge priority) or 'standalone_strip' (guided single strip crop).

    Returns:
        dict: Detection result with bounding boxes, confidence scores, canonical views, and valid flag.
    """
    if image_bgr is None or image_bgr.size == 0:
        return {
            "is_valid": False,
            "badge_mode": "INVALID",
            "overall_confidence": 0.0,
            "ref_scale": {"box": (0, 0, 0, 0), "confidence": 0.0},
            "h2s_strip": {"box": (0, 0, 0, 0), "confidence": 0.0},
            "humidity_indicator": {"box": (0, 0, 0, 0), "confidence": 0.0},
            "expiry_patch": {"box": (0, 0, 0, 0), "confidence": 0.0}
        }

    h, w = image_bgr.shape[:2]
    mode_normalized = scan_mode.lower().strip()
    is_standalone_requested = mode_normalized in ["standalone_strip", "standalone_chemical_strip", "standalone"]

    # -------------------------------------------------------------------------
    # Mode 2: Standalone Chemical Strip (Direct Guided Crop)
    # -------------------------------------------------------------------------
    if is_standalone_requested:
        s_x1 = int(w * 0.12)
        s_y1 = int(h * 0.12)
        s_x2 = int(w * 0.88)
        s_y2 = int(h * 0.88)

        strip_conf = 0.95 if (s_x2 > s_x1 and s_y2 > s_y1) else 0.0
        return {
            "is_valid": strip_conf >= min_confidence,
            "badge_mode": "STANDALONE_CHEMICAL_STRIP",
            "overall_confidence": round(strip_conf, 3),
            "ref_scale": {
                "box": (0, 0, 0, 0),
                "confidence": 0.0
            },
            "h2s_strip": {
                "box": (s_x1, s_y1, s_x2, s_y2),
                "confidence": round(strip_conf, 3)
            },
            "humidity_indicator": {
                "box": (0, 0, 0, 0),
                "confidence": 0.0
            },
            "expiry_patch": {
                "box": (0, 0, 0, 0),
                "confidence": 0.0
            }
        }

    # -------------------------------------------------------------------------
    # Tier 1: Check for Physical 3D-Printed DoseBand Prototype Enclosure
    # -------------------------------------------------------------------------
    enclosure_detected, quad_pts, enc_diag = detect_doseband_enclosure(image_bgr)
    if enclosure_detected and quad_pts is not None:
        warped_canonical = warp_perspective_to_canonical(image_bgr, quad_pts)
        extracted_data = extract_robust_sensor_features(warped_canonical, quad_detected=True)
        
        # Calculate bounding box on original image
        pts = quad_pts.astype(np.int32)
        min_x = int(np.min(pts[:, 0]))
        max_x = int(np.max(pts[:, 0]))
        min_y = int(np.min(pts[:, 1]))
        max_y = int(np.max(pts[:, 1]))

        # Approximate original sensor window location
        bw = max_x - min_x
        bh = max_y - min_y
        h2s_box_orig = (
            min_x + int(bw * 0.15),
            min_y + int(bh * 0.45),
            min_x + int(bw * 0.85),
            min_y + int(bh * 0.92)
        )
        hum_box_orig = (
            min_x + int(bw * 0.20),
            min_y + int(bh * 0.22),
            min_x + int(bw * 0.80),
            min_y + int(bh * 0.40)
        )

        return {
            "is_valid": True,
            "badge_mode": "FULL_3D_DOSEBAND_ENCLOSURE",
            "overall_confidence": 0.95,
            "quad_points": quad_pts.tolist(),
            "canonical_view": warped_canonical,
            "extracted_features": extracted_data,
            "device_box": (min_x, min_y, max_x, max_y),
            "ref_scale": {
                "box": (min_x + int(bw * 0.20), min_y + int(bh * 0.07), min_x + int(bw * 0.80), min_y + int(bh * 0.18)),
                "confidence": 0.90
            },
            "h2s_strip": {
                "box": h2s_box_orig,
                "confidence": 0.95
            },
            "humidity_indicator": {
                "box": hum_box_orig,
                "confidence": 0.90
            },
            "expiry_patch": {
                "box": (min_x + int(bw * 0.65), min_y + int(bh * 0.07), min_x + int(bw * 0.85), min_y + int(bh * 0.18)),
                "confidence": 0.85
            }
        }

    # -------------------------------------------------------------------------
    # Tier 2: Legacy Printed Scale Badge vs Standalone Strip
    # -------------------------------------------------------------------------
    ref_x1 = int(w * 0.03)
    ref_y1 = int(h * 0.08)
    ref_x2 = int(w * 0.32)
    ref_y2 = int(h * 0.90)
    
    ref_crop = image_bgr[ref_y1:ref_y2, ref_x1:ref_x2]
    ref_std = float(np.std(ref_crop)) if ref_crop.size > 0 else 0.0
    ref_conf = min(1.0, max(0.0, (ref_std - 15.0) / 45.0)) if ref_std > 15.0 else 0.20

    h2s_x1 = int(w * 0.36)
    h2s_y1 = int(h * 0.10)
    h2s_x2 = int(w * 0.96)
    h2s_y2 = int(h * 0.68)
    
    h2s_crop = image_bgr[h2s_y1:h2s_y2, h2s_x1:h2s_x2]
    h2s_conf = 0.90 if h2s_crop.size > 0 else 0.0

    hum_x1 = int(w * 0.38)
    hum_y1 = int(h * 0.72)
    hum_x2 = int(w * 0.68)
    hum_y2 = int(h * 0.96)
    
    hum_crop = image_bgr[hum_y1:hum_y2, hum_x1:hum_x2]
    hum_conf = 0.85 if hum_crop.size > 0 else 0.0

    exp_x1 = int(w * 0.72)
    exp_y1 = int(h * 0.72)
    exp_x2 = int(w * 0.98)
    exp_y2 = int(h * 0.98)
    
    exp_crop = image_bgr[exp_y1:exp_y2, exp_x1:exp_x2]
    exp_conf = 0.85 if exp_crop.size > 0 else 0.0

    is_full_badge = ref_conf >= 0.50 and w >= 250 and h >= 150 and (0.8 <= (w / float(h)) <= 2.8)

    if is_full_badge:
        overall_conf = float(np.mean([ref_conf, h2s_conf, hum_conf, exp_conf]))
        is_valid = overall_conf >= min_confidence
        return {
            "is_valid": is_valid,
            "badge_mode": "FULL_DOSEBAND_BADGE",
            "overall_confidence": round(overall_conf, 3),
            "ref_scale": {
                "box": (ref_x1, ref_y1, ref_x2, ref_y2),
                "confidence": round(ref_conf, 3)
            },
            "h2s_strip": {
                "box": (h2s_x1, h2s_y1, h2s_x2, h2s_y2),
                "confidence": round(h2s_conf, 3)
            },
            "humidity_indicator": {
                "box": (hum_x1, hum_y1, hum_x2, hum_y2),
                "confidence": round(hum_conf, 3)
            },
            "expiry_patch": {
                "box": (exp_x1, exp_y1, exp_x2, exp_y2),
                "confidence": round(exp_conf, 3)
            }
        }
    else:
        s_x1 = int(w * 0.08)
        s_y1 = int(h * 0.08)
        s_x2 = int(w * 0.92)
        s_y2 = int(h * 0.92)
        
        strip_conf = 0.92 if (s_x2 > s_x1 and s_y2 > s_y1) else 0.0
        return {
            "is_valid": strip_conf >= min_confidence,
            "badge_mode": "STANDALONE_CHEMICAL_STRIP",
            "overall_confidence": round(strip_conf, 3),
            "ref_scale": {
                "box": (0, 0, 0, 0),
                "confidence": 0.0
            },
            "h2s_strip": {
                "box": (s_x1, s_y1, s_x2, s_y2),
                "confidence": round(strip_conf, 3)
            },
            "humidity_indicator": {
                "box": (0, 0, 0, 0),
                "confidence": 0.0
            },
            "expiry_patch": {
                "box": (0, 0, 0, 0),
                "confidence": 0.0
            }
        }


def extract_center_features(
    image_bgr: np.ndarray,
    box: Tuple[int, int, int, int],
    crop_fraction: float = 0.70
) -> Dict[str, float]:
    """
    Extracts robust statistical features (mean, median, HSV, LAB, local std, percentiles)
    from the interior central portion of an ROI bounding box, avoiding edge shadows and gradients.
    """
    x1, y1, x2, y2 = box
    roi_bgr = image_bgr[y1:y2, x1:x2]
    
    if roi_bgr.size == 0:
        return {
            "mean_r": 128.0, "mean_g": 128.0, "mean_b": 128.0,
            "median_r": 128.0, "median_g": 128.0, "median_b": 128.0,
            "gray": 128.0, "gray_median": 128.0,
            "hue": 0.0, "sat": 0.0, "val": 128.0,
            "lab_l": 50.0, "local_std": 5.0
        }

    rh, rw = roi_bgr.shape[:2]
    margin_y = int(rh * (1.0 - crop_fraction) / 2.0)
    margin_x = int(rw * (1.0 - crop_fraction) / 2.0)

    center_bgr = roi_bgr[margin_y:rh - margin_y, margin_x:rw - margin_x]
    if center_bgr.size == 0:
        center_bgr = roi_bgr

    ch, cw = center_bgr.shape[:2]
    if ch >= 5 and cw >= 5:
        filtered_bgr = cv2.medianBlur(center_bgr, 3)
    else:
        filtered_bgr = center_bgr

    center_rgb = cv2.cvtColor(filtered_bgr, cv2.COLOR_BGR2RGB)
    center_hsv = cv2.cvtColor(filtered_bgr, cv2.COLOR_BGR2HSV)
    center_gray = cv2.cvtColor(filtered_bgr, cv2.COLOR_BGR2GRAY)
    center_lab = cv2.cvtColor(filtered_bgr, cv2.COLOR_BGR2LAB)

    return {
        "mean_r": float(np.mean(center_rgb[:, :, 0])),
        "mean_g": float(np.mean(center_rgb[:, :, 1])),
        "mean_b": float(np.mean(center_rgb[:, :, 2])),
        "median_r": float(np.median(center_rgb[:, :, 0])),
        "median_g": float(np.median(center_rgb[:, :, 1])),
        "median_b": float(np.median(center_rgb[:, :, 2])),
        "gray": float(np.mean(center_gray)),
        "gray_median": float(np.median(center_gray)),
        "hue": float(np.mean(center_hsv[:, :, 0])),
        "sat": float(np.mean(center_hsv[:, :, 1])),
        "val": float(np.mean(center_hsv[:, :, 2])),
        "lab_l": float(np.mean(center_lab[:, :, 0])) * (100.0 / 255.0),
        "local_std": float(np.std(center_gray))
    }


def extract_humidity_card_features(
    image_bgr: np.ndarray,
    box: Tuple[int, int, int, int]
) -> Dict[str, float]:
    """
    Extracts RGB and HSV features from the circular colored disc of the humidity indicator card.
    """
    x1, y1, x2, y2 = box
    crop_bgr = image_bgr[y1:y2, x1:x2]
    
    if crop_bgr.size == 0:
        return {
            "mean_r": 128.0, "mean_g": 128.0, "mean_b": 128.0,
            "hue": 0.0, "sat": 0.0, "val": 128.0
        }
    
    ch, cw = crop_bgr.shape[:2]
    cx, cy = cw // 2, ch // 2
    r_sample = max(5, int(min(ch, cw) // 2 - 10))
    
    yy, xx = np.ogrid[:ch, :cw]
    dist = np.sqrt((xx - cx)**2 + (yy - cy)**2)
    circle_mask = dist <= r_sample
    
    disc_pixels_bgr = crop_bgr[circle_mask]
    
    valid_pixels = []
    for px in disc_pixels_bgr:
        b, g, r = float(px[0]), float(px[1]), float(px[2])
        is_white = (r > 225 and g > 225 and b > 225 and max(abs(r - g), abs(g - b), abs(r - b)) < 18)
        is_black = (r < 40 and g < 40 and b < 40)
        if not is_white and not is_black:
            valid_pixels.append(px)
            
    if len(valid_pixels) >= 12:
        sampled_bgr = np.array(valid_pixels, dtype=np.uint8)
    else:
        core_mask = dist <= max(4, r_sample // 2)
        sampled_bgr = crop_bgr[core_mask]
        if sampled_bgr.size == 0:
            sampled_bgr = crop_bgr
            
    clean_rgb = sampled_bgr[:, [2, 1, 0]]
    rgb_reshaped = clean_rgb.reshape(-1, 1, 3)
    hsv_reshaped = cv2.cvtColor(rgb_reshaped, cv2.COLOR_RGB2HSV)
    
    return {
        "mean_r": float(np.mean(clean_rgb[:, 0])),
        "mean_g": float(np.mean(clean_rgb[:, 1])),
        "mean_b": float(np.mean(clean_rgb[:, 2])),
        "hue": float(np.mean(hsv_reshaped[:, 0, 0])),
        "sat": float(np.mean(hsv_reshaped[:, 0, 1])),
        "val": float(np.mean(hsv_reshaped[:, 0, 2]))
    }


def draw_roi_visual_overlay(
    image_bgr: np.ndarray,
    detections: Dict[str, Any]
) -> np.ndarray:
    """
    Renders an annotated diagnostic image highlighting all detected ROIs and inner sampling zones.
    """
    overlay = image_bgr.copy()
    font = cv2.FONT_HERSHEY_SIMPLEX

    roi_specs = [
        ("ref_scale", "Ref Scale (5-Step)", (255, 140, 0)),
        ("h2s_strip", "H2S Sensor ROI", (0, 220, 0)),
        ("humidity_indicator", "Humidity Card ROI", (255, 50, 180)),
        ("expiry_patch", "Expiry Patch ROI", (0, 200, 255))
    ]

    for key, label, color in roi_specs:
        if key in detections:
            x1, y1, x2, y2 = detections[key]["box"]
            conf = detections[key]["confidence"]

            cv2.rectangle(overlay, (x1, y1), (x2, y2), color, 2)
            
            rw = x2 - x1
            rh = y2 - y1
            mx = int(rw * 0.20)
            my = int(rh * 0.20)
            cv2.rectangle(overlay, (x1 + mx, y1 + my), (x2 - mx, y2 - my), color, 1)

            cv2.putText(
                overlay,
                f"{label} ({int(conf * 100)}%)",
                (x1 + 4, max(18, y1 - 6)),
                font,
                0.42,
                color,
                1,
                cv2.LINE_AA
            )

    return overlay
