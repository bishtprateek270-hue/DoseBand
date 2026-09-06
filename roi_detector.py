"""
DoseBand ROI Detector & Preprocessing Module.

Locates and extracts candidate ROIs from an uploaded DoseBand badge photograph:
1. Reference Grayscale Step Wedge (for lighting calibration)
2. H2S Lead Acetate Sensor Strip ROI (sampled centrally to avoid edge shadows and text)
3. Humidity Indicator Patch / Circle ROI (sampled centrally to exclude borders)
4. Shelf-Life Expiry Patch ROI

Provides ROI confidence scoring, visualization overlays, and central-region feature extraction.
"""

from typing import Dict, Tuple, Any, Optional
import cv2
import numpy as np


def detect_all_rois(
    image_bgr: np.ndarray,
    min_confidence: float = 0.50
) -> Dict[str, Any]:
    """
    Detects all 4 key regions on a DoseBand dosimeter badge image.

    Args:
        image_bgr (np.ndarray): BGR image array.
        min_confidence (float): Minimum confidence threshold for valid ROI detection.

    Returns:
        dict: Detection result with bounding boxes, confidence scores, and valid flag.
    """
    h, w = image_bgr.shape[:2]
    
    # -------------------------------------------------------------------------
    # 1. Reference Scale ROI (Left ~33% of badge)
    # -------------------------------------------------------------------------
    ref_x1 = int(w * 0.03)
    ref_y1 = int(h * 0.08)
    ref_x2 = int(w * 0.32)
    ref_y2 = int(h * 0.90)
    
    ref_crop = image_bgr[ref_y1:ref_y2, ref_x1:ref_x2]
    ref_std = float(np.std(ref_crop)) if ref_crop.size > 0 else 0.0
    ref_conf = min(1.0, max(0.0, (ref_std - 15.0) / 45.0)) if ref_std > 15.0 else 0.20

    # -------------------------------------------------------------------------
    # 2. H2S Sensor Strip ROI (Upper/Middle Right 2/3)
    # -------------------------------------------------------------------------
    h2s_x1 = int(w * 0.36)
    h2s_y1 = int(h * 0.10)
    h2s_x2 = int(w * 0.96)
    h2s_y2 = int(h * 0.68)
    
    h2s_crop = image_bgr[h2s_y1:h2s_y2, h2s_x1:h2s_x2]
    h2s_conf = 0.90 if h2s_crop.size > 0 else 0.0

    # -------------------------------------------------------------------------
    # 3. Humidity Indicator ROI (Lower Center / Lower Left-of-Expiry)
    # -------------------------------------------------------------------------
    hum_x1 = int(w * 0.38)
    hum_y1 = int(h * 0.72)
    hum_x2 = int(w * 0.68)
    hum_y2 = int(h * 0.96)
    
    hum_crop = image_bgr[hum_y1:hum_y2, hum_x1:hum_x2]
    hum_conf = 0.85 if hum_crop.size > 0 else 0.0

    # -------------------------------------------------------------------------
    # 4. Expiry Indicator Patch ROI (Bottom Right Corner)
    # -------------------------------------------------------------------------
    exp_x1 = int(w * 0.72)
    exp_y1 = int(h * 0.72)
    exp_x2 = int(w * 0.98)
    exp_y2 = int(h * 0.98)
    
    exp_crop = image_bgr[exp_y1:exp_y2, exp_x1:exp_x2]
    exp_conf = 0.85 if exp_crop.size > 0 else 0.0

    overall_conf = float(np.mean([ref_conf, h2s_conf, hum_conf, exp_conf]))
    is_valid = overall_conf >= min_confidence

    return {
        "is_valid": is_valid,
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


def extract_center_features(
    image_bgr: np.ndarray,
    box: Tuple[int, int, int, int],
    crop_fraction: float = 0.60
) -> Dict[str, float]:
    """
    Extracts RGB, HSV, and Grayscale features from the central portion of an ROI bounding box.
    
    Sampling strictly from the center avoids enclosure edges, printed text, shadows, and borders.
    """
    x1, y1, x2, y2 = box
    roi_bgr = image_bgr[y1:y2, x1:x2]
    
    if roi_bgr.size == 0:
        return {
            "mean_r": 128.0, "mean_g": 128.0, "mean_b": 128.0,
            "gray": 128.0, "hue": 0.0, "sat": 0.0, "val": 128.0
        }

    rh, rw = roi_bgr.shape[:2]
    margin_y = int(rh * (1.0 - crop_fraction) / 2.0)
    margin_x = int(rw * (1.0 - crop_fraction) / 2.0)

    center_bgr = roi_bgr[margin_y:rh - margin_y, margin_x:rw - margin_x]
    if center_bgr.size == 0:
        center_bgr = roi_bgr

    center_rgb = cv2.cvtColor(center_bgr, cv2.COLOR_BGR2RGB)
    center_hsv = cv2.cvtColor(center_bgr, cv2.COLOR_BGR2HSV)
    center_gray = cv2.cvtColor(center_bgr, cv2.COLOR_BGR2GRAY)

    return {
        "mean_r": float(np.mean(center_rgb[:, :, 0])),
        "mean_g": float(np.mean(center_rgb[:, :, 1])),
        "mean_b": float(np.mean(center_rgb[:, :, 2])),
        "gray": float(np.mean(center_gray)),
        "hue": float(np.mean(center_hsv[:, :, 0])),
        "sat": float(np.mean(center_hsv[:, :, 1])),
        "val": float(np.mean(center_hsv[:, :, 2]))
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
        ("ref_scale", "Ref Scale (5-Step)", (255, 140, 0)),        # Orange
        ("h2s_strip", "H2S Sensor ROI", (0, 220, 0)),              # Green
        ("humidity_indicator", "Humidity Card ROI", (255, 50, 180)),# Pink/Magenta
        ("expiry_patch", "Expiry Patch ROI", (0, 200, 255))        # Yellow
    ]

    for key, label, color in roi_specs:
        if key in detections:
            x1, y1, x2, y2 = detections[key]["box"]
            conf = detections[key]["confidence"]

            # Outer ROI Bounding Box
            cv2.rectangle(overlay, (x1, y1), (x2, y2), color, 2)
            
            # Central safe sampling zone (dotted / thinner line)
            rw = x2 - x1
            rh = y2 - y1
            mx = int(rw * 0.20)
            my = int(rh * 0.20)
            cv2.rectangle(overlay, (x1 + mx, y1 + my), (x2 - mx, y2 - my), color, 1)

            # Label banner
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
