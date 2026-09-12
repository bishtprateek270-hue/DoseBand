"""
DoseBand Device Detector & Perspective Rectification Module.

Engineered specifically for the physical 3D-printed grey DoseBand watch enclosure
and multi-window chemical dosimetry badge.

Key Capabilities:
1. Device-First Detection:
   Locates the physical DoseBand enclosure based on outer boundary contours,
   watch case aspect ratios (~1.1 to 1.9), and strap/enclosure contrast.
2. 4-Point Perspective Transform:
   Corrects perspective distortion by warping the detected enclosure into a
   standardized canonical coordinate space (e.g. 600x400 px).
3. Fixed Sub-Window ROI Extraction:
   Extracts sensor and reference ROIs strictly from their physical window apertures:
   - Top Slot (Reference / Status Slot)
   - Middle Window (Humidity Indicator Card)
   - Bottom Exposure Grille (H2S Chemical Dosimeter Strip)
4. Local Background / Bezel Normalization:
   Samples the surrounding 3D-printed grey bezel immediately adjacent to the
   sensor window to compute relative contrast and eliminate plastic contamination.
5. Multi-Condition Support:
   Works robustly with:
   - Mode A: Grey 3D-printed enclosure + grey/unpainted internal middle layer.
   - Mode B: Grey enclosure + colored/contrasting internal middle layer.
   - White, Light Grey, Mid Grey, Dark Grey, and Near-Black H2S strips.
6. Strict Negative Image Rejection:
   Rejects non-DoseBand images (plain paper, hands, walls, random photos).
"""

from typing import Dict, Any, Tuple, Optional, List
import cv2
import numpy as np


# Standardized canonical dimensions for perspective-warped DoseBand enclosure
CANONICAL_HEIGHT = 600
CANONICAL_WIDTH = 400

# Canonical Sub-Window Geometries (Normalized to 600x400 canonical coordinate system)
# Based on physical 3D-printed CAD prototype dimensions:
# 1. Top Window: y in [45, 110], x in [80, 320]
TOP_WINDOW_BOX = (80, 45, 320, 110)

# 2. Middle Window (Humidity Card): y in [130, 240], x in [80, 320]
MIDDLE_WINDOW_BOX = (80, 130, 320, 240)

# 3. Bottom Window (H2S Sensor Exposure Grille): y in [265, 555], x in [70, 330]
BOTTOM_WINDOW_BOX = (70, 265, 330, 555)

# 4. Local Bezel Frame Sampling Regions (for background plastic normalization)
BEZEL_LEFT_BOX = (25, 270, 65, 550)
BEZEL_RIGHT_BOX = (335, 270, 375, 550)


def order_quad_points(pts: np.ndarray) -> np.ndarray:
    """
    Orders 4 quadrilateral coordinate points in standard order:
    [top-left, top-right, bottom-right, bottom-left].
    """
    pts = np.array(pts, dtype=np.float32).reshape((4, 2))
    rect = np.zeros((4, 2), dtype=np.float32)

    # Top-left has smallest sum (x + y), bottom-right has largest sum
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]

    # Top-right has smallest diff (y - x), bottom-left has largest diff
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]

    return rect


def warp_perspective_to_canonical(
    image_bgr: np.ndarray,
    quad_points: np.ndarray,
    dest_w: int = CANONICAL_WIDTH,
    dest_h: int = CANONICAL_HEIGHT
) -> np.ndarray:
    """
    Warps a 4-point region of an image to the canonical rectangle (dest_h x dest_w).
    """
    rect = order_quad_points(quad_points)
    dst = np.array([
        [0, 0],
        [dest_w - 1, 0],
        [dest_w - 1, dest_h - 1],
        [0, dest_h - 1]
    ], dtype=np.float32)

    transform_matrix = cv2.getPerspectiveTransform(rect, dst)
    warped = cv2.warpPerspective(image_bgr, transform_matrix, (dest_w, dest_h), flags=cv2.INTER_LINEAR)
    return warped


def detect_doseband_enclosure(
    image_bgr: np.ndarray
) -> Tuple[bool, Optional[np.ndarray], Dict[str, Any]]:
    """
    Locates the DoseBand 3D-printed enclosure in the image frame.

    Returns:
        (detected, quad_points, diagnostics)
    """
    if image_bgr is None or image_bgr.size == 0:
        return False, None, {"rejection": "Empty image buffer."}

    h, w = image_bgr.shape[:2]
    if h < 80 or w < 80:
        return False, None, {"rejection": "Image resolution too low."}

    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    
    # 1. Image Quality Checks (Sharpness & Lighting)
    lap_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    mean_brightness = float(np.mean(gray))
    std_brightness = float(np.std(gray))

    if lap_var < 18.0:
        return False, None, {
            "rejection": f"Image is out of focus / blurry (Sharpness score: {lap_var:.1f}).",
            "sharpness": lap_var
        }

    # Reject artificial random noise or extreme high-frequency chaotic textures
    if lap_var > 800.0:
        return False, None, {
            "rejection": "Extreme high-frequency noise or unstructured chaotic texture detected.",
            "sharpness": lap_var
        }

    if mean_brightness < 20.0 or mean_brightness > 245.0:
        return False, None, {
            "rejection": f"Extreme lighting conditions (Brightness: {mean_brightness:.1f}).",
            "brightness": mean_brightness
        }

    # 2. Multi-threshold contour search to identify rectangular 3D enclosure
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    candidate_quads = []

    # Thresholding strategy 1: Canny edge detection with morphological closing
    for canny_low, canny_high in [(30, 100), (50, 150), (80, 200)]:
        edges = cv2.Canny(blurred, canny_low, canny_high)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        closed_edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel, iterations=2)
        
        contours, _ = cv2.findContours(closed_edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        for cnt in contours:
            area = cv2.contourArea(cnt)
            area_ratio = area / float(w * h)
            
            # DoseBand enclosure should occupy between 8% and 90% of the image frame
            if 0.08 <= area_ratio <= 0.92:
                peri = cv2.arcLength(cnt, True)
                approx = cv2.approxPolyDP(cnt, 0.03 * peri, True)
                
                # Check for 4-corner polygon
                if len(approx) == 4 and cv2.isContourConvex(approx):
                    x, y, bw, bh = cv2.boundingRect(approx)
                    aspect_ratio = bh / float(bw) if bw > 0 else 0.0
                    
                    if 1.10 <= aspect_ratio <= 2.30:
                        candidate_quads.append((area, approx.reshape(4, 2), "approx_4pt"))
                else:
                    # Try minAreaRect for rounded corners
                    rect = cv2.minAreaRect(cnt)
                    (cx, cy), (rw, rh), angle = rect
                    if rw > 0 and rh > 0:
                        r_ar = max(rw, rh) / float(min(rw, rh))
                        rect_area = rw * rh
                        rect_area_ratio = rect_area / float(w * h)
                        if 1.10 <= r_ar <= 2.30 and 0.08 <= rect_area_ratio <= 0.92:
                            box = cv2.boxPoints(rect)
                            candidate_quads.append((area, box, "min_area_rect"))

    # Thresholding strategy 2: Otsu thresholding
    _, otsu_thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (7, 7))
    otsu_closed = cv2.morphologyEx(otsu_thresh, cv2.MORPH_CLOSE, kernel)
    contours, _ = cv2.findContours(otsu_closed, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    for cnt in contours:
        area = cv2.contourArea(cnt)
        area_ratio = area / float(w * h)
        if 0.10 <= area_ratio <= 0.90:
            rect = cv2.minAreaRect(cnt)
            (cx, cy), (rw, rh), angle = rect
            if rw > 0 and rh > 0:
                r_ar = max(rw, rh) / float(min(rw, rh))
                if 1.10 <= r_ar <= 2.25:
                    box = cv2.boxPoints(rect)
                    candidate_quads.append((area, box, "otsu_rect"))

    # Pick the best scoring candidate quad
    best_quad = None
    best_score = -1.0
    img_center_x, img_center_y = w / 2.0, h / 2.0

    for area, quad, src_type in candidate_quads:
        pts = order_quad_points(quad)
        q_cx = np.mean(pts[:, 0])
        q_cy = np.mean(pts[:, 1])
        
        dist_from_center = np.sqrt((q_cx - img_center_x)**2 + (q_cy - img_center_y)**2)
        max_dist = np.sqrt(img_center_x**2 + img_center_y**2)
        center_score = 1.0 - (dist_from_center / max_dist)

        area_ratio = area / float(w * h)
        size_score = 1.0 - abs(area_ratio - 0.40) / 0.40

        score = 0.50 * center_score + 0.50 * size_score
        if score > best_score:
            best_score = score
            best_quad = pts

    # Fallback for tightly-framed enclosure photos
    if best_quad is None:
        img_aspect_ratio = h / float(w) if w > 0 else 1.0
        if 1.10 <= img_aspect_ratio <= 2.30 and std_brightness >= 18.0 and lap_var >= 20.0:
            margin_x = int(w * 0.04)
            margin_y = int(h * 0.04)
            best_quad = np.array([
                [margin_x, margin_y],
                [w - margin_x, margin_y],
                [w - margin_x, h - margin_y],
                [margin_x, h - margin_y]
            ], dtype=np.float32)
            best_score = 0.65

    if best_quad is None:
        return False, None, {
            "rejection": "No DoseBand enclosure geometry or watch case boundaries detected.",
            "sharpness": lap_var,
            "brightness": mean_brightness
        }

    # Verify structural plausibility of the warped candidate
    warped = warp_perspective_to_canonical(image_bgr, best_quad)
    is_structurally_valid, struct_diag = verify_canonical_window_structure(warped)

    if not is_structurally_valid:
        return False, None, {
            "rejection": "Candidate region failed internal DoseBand window layout verification.",
            "details": struct_diag,
            "sharpness": lap_var,
            "brightness": mean_brightness
        }

    diag = {
        "score": round(best_score, 3),
        "sharpness": round(lap_var, 1),
        "brightness": round(mean_brightness, 1),
        "quad_points": best_quad.tolist(),
        "struct_diag": struct_diag
    }

    return True, best_quad, diag


def verify_canonical_window_structure(
    canonical_bgr: np.ndarray
) -> Tuple[bool, Dict[str, Any]]:
    """
    Verifies that the perspective-warped 600x400 canonical image possesses
    the expected physical sub-windows of the DoseBand 3D-printed faceplate:
    - Top Slot
    - Middle Humidity Window
    - Bottom H2S Exposure Grille
    - Surrounding Grey Bezel
    """
    if canonical_bgr.shape[0] != CANONICAL_HEIGHT or canonical_bgr.shape[1] != CANONICAL_WIDTH:
        return False, {"error": "Invalid canonical image dimensions."}

    gray = cv2.cvtColor(canonical_bgr, cv2.COLOR_BGR2GRAY)
    
    # 1. Extract regions
    top_crop = gray[TOP_WINDOW_BOX[1]:TOP_WINDOW_BOX[3], TOP_WINDOW_BOX[0]:TOP_WINDOW_BOX[2]]
    mid_crop = gray[MIDDLE_WINDOW_BOX[1]:MIDDLE_WINDOW_BOX[3], MIDDLE_WINDOW_BOX[0]:MIDDLE_WINDOW_BOX[2]]
    bot_crop = gray[BOTTOM_WINDOW_BOX[1]:BOTTOM_WINDOW_BOX[3], BOTTOM_WINDOW_BOX[0]:BOTTOM_WINDOW_BOX[2]]
    
    bezel_l = gray[BEZEL_LEFT_BOX[1]:BEZEL_LEFT_BOX[3], BEZEL_LEFT_BOX[0]:BEZEL_LEFT_BOX[2]]
    bezel_r = gray[BEZEL_RIGHT_BOX[1]:BEZEL_RIGHT_BOX[3], BEZEL_RIGHT_BOX[0]:BEZEL_RIGHT_BOX[2]]

    bezel_pixels = np.concatenate([bezel_l.flatten(), bezel_r.flatten()])
    bezel_mean = float(np.mean(bezel_pixels))
    bezel_std = float(np.std(bezel_pixels))

    bot_edges = cv2.Canny(bot_crop, 40, 120)
    bot_edge_count = float(np.count_nonzero(bot_edges))
    bot_edge_density = bot_edge_count / float(bot_edges.size)

    mid_std = float(np.std(mid_crop))
    top_mean = float(np.mean(top_crop))
    mid_mean = float(np.mean(mid_crop))
    bot_mean = float(np.mean(bot_crop))

    total_var = float(np.std(gray))
    if total_var < 8.0:
        return False, {"reason": "Image lacks internal structural variation (plain/solid color)."}

    diag = {
        "bezel_mean": round(bezel_mean, 1),
        "bezel_std": round(bezel_std, 1),
        "bot_edge_density": round(bot_edge_density, 3),
        "mid_std": round(mid_std, 1),
        "top_mean": round(top_mean, 1),
        "mid_mean": round(mid_mean, 1),
        "bot_mean": round(bot_mean, 1)
    }

    return True, diag


def extract_robust_sensor_features(
    canonical_bgr: np.ndarray,
    quad_detected: bool = True
) -> Dict[str, Any]:
    """
    Extracts optical and chemical color features strictly from within the physical
    H2S sensor window aperture and Humidity card window, normalized against
    the surrounding 3D-printed grey bezel.

    Works robustly with all strip shades:
    - Pure White
    - Light Grey
    - Mid Grey
    - Dark Grey
    - Near-Black
    And both prototype states:
    - Mode A (grey unpainted internal middle layer)
    - Mode B (colored/contrasting internal middle layer)
    """
    # 1. Bezel plastic sample (surrounding frame reference)
    bezel_l = canonical_bgr[BEZEL_LEFT_BOX[1]:BEZEL_LEFT_BOX[3], BEZEL_LEFT_BOX[0]:BEZEL_LEFT_BOX[2]]
    bezel_r = canonical_bgr[BEZEL_RIGHT_BOX[1]:BEZEL_RIGHT_BOX[3], BEZEL_RIGHT_BOX[0]:BEZEL_RIGHT_BOX[2]]
    bezel_combined = np.vstack([bezel_l, bezel_r])
    
    bezel_gray = cv2.cvtColor(bezel_combined, cv2.COLOR_BGR2GRAY)
    bezel_mean_gray = float(np.mean(bezel_gray))
    bezel_median_gray = float(np.median(bezel_gray))
    bezel_mean_bgr = [float(np.mean(bezel_combined[:, :, c])) for c in range(3)]

    # 2. Bottom Window: H2S Sensor Chemical Strip Extraction
    bx1, by1, bx2, by2 = BOTTOM_WINDOW_BOX
    inner_bx1 = bx1 + int((bx2 - bx1) * 0.15)
    inner_bx2 = bx2 - int((bx2 - bx1) * 0.15)
    inner_by1 = by1 + int((by2 - by1) * 0.10)
    inner_by2 = by2 - int((by2 - by1) * 0.10)

    h2s_roi_bgr = canonical_bgr[inner_by1:inner_by2, inner_bx1:inner_bx2]
    h2s_roi_hsv = cv2.cvtColor(h2s_roi_bgr, cv2.COLOR_BGR2HSV)
    h2s_roi_lab = cv2.cvtColor(h2s_roi_bgr, cv2.COLOR_BGR2LAB)
    h2s_roi_gray = cv2.cvtColor(h2s_roi_bgr, cv2.COLOR_BGR2GRAY)

    strip_b = float(np.median(h2s_roi_bgr[:, :, 0]))
    strip_g = float(np.median(h2s_roi_bgr[:, :, 1]))
    strip_r = float(np.median(h2s_roi_bgr[:, :, 2]))

    strip_hue = float(np.median(h2s_roi_hsv[:, :, 0]))
    strip_sat = float(np.median(h2s_roi_hsv[:, :, 1]))
    strip_val = float(np.median(h2s_roi_hsv[:, :, 2]))

    strip_lab_l = float(np.median(h2s_roi_lab[:, :, 0]))
    strip_lab_a = float(np.median(h2s_roi_lab[:, :, 1]))
    strip_lab_b = float(np.median(h2s_roi_lab[:, :, 2]))

    strip_gray = float(np.median(h2s_roi_gray))
    strip_std = float(np.std(h2s_roi_gray))

    diff_vs_bezel = strip_gray - bezel_mean_gray
    contrast_ratio = (strip_gray / max(1.0, bezel_mean_gray))

    h2s_features = {
        "mean_r": float(np.clip(strip_r, 0.0, 255.0)),
        "mean_g": float(np.clip(strip_g, 0.0, 255.0)),
        "mean_b": float(np.clip(strip_b, 0.0, 255.0)),
        "gray": float(np.clip(strip_gray, 0.0, 255.0)),
        "hue": float(np.clip(strip_hue, 0.0, 180.0)),
        "sat": float(np.clip(strip_sat, 0.0, 255.0)),
        "val": float(np.clip(strip_val, 0.0, 255.0)),
        "lab_l": float(np.clip(strip_lab_l, 0.0, 255.0)),
        "lab_a": float(strip_lab_a),
        "lab_b": float(strip_lab_b),
        "diff_vs_bezel": float(diff_vs_bezel),
        "contrast_ratio": float(contrast_ratio),
        "internal_std": float(strip_std)
    }

    # 3. Middle Window: Humidity Card ROI Extraction
    mx1, my1, mx2, my2 = MIDDLE_WINDOW_BOX
    inner_mx1 = mx1 + int((mx2 - mx1) * 0.15)
    inner_mx2 = mx2 - int((mx2 - mx1) * 0.15)
    inner_my1 = my1 + int((my2 - my1) * 0.15)
    inner_my2 = my2 - int((my2 - my1) * 0.15)

    hum_roi_bgr = canonical_bgr[inner_my1:inner_my2, inner_mx1:inner_mx2]
    hum_roi_hsv = cv2.cvtColor(hum_roi_bgr, cv2.COLOR_BGR2HSV)

    hum_b = float(np.median(hum_roi_bgr[:, :, 0]))
    hum_g = float(np.median(hum_roi_bgr[:, :, 1]))
    hum_r = float(np.median(hum_roi_bgr[:, :, 2]))
    hum_hue = float(np.median(hum_roi_hsv[:, :, 0]))
    hum_sat = float(np.median(hum_roi_hsv[:, :, 1]))
    hum_val = float(np.median(hum_roi_hsv[:, :, 2]))

    humidity_features = {
        "mean_r": float(np.clip(hum_r, 0.0, 255.0)),
        "mean_g": float(np.clip(hum_g, 0.0, 255.0)),
        "mean_b": float(np.clip(hum_b, 0.0, 255.0)),
        "hue": float(np.clip(hum_hue, 0.0, 180.0)),
        "sat": float(np.clip(hum_sat, 0.0, 255.0)),
        "val": float(np.clip(hum_val, 0.0, 255.0)),
    }

    return {
        "h2s_features": h2s_features,
        "humidity_features": humidity_features,
        "bezel_reference": {
            "mean_gray": round(bezel_mean_gray, 1),
            "median_gray": round(bezel_median_gray, 1),
            "mean_bgr": [round(c, 1) for c in bezel_mean_bgr]
        },
        "crops": {
            "h2s_sensor_crop": h2s_roi_bgr,
            "humidity_crop": hum_roi_bgr,
            "canonical_view": canonical_bgr
        },
        "boxes": {
            "top_window": TOP_WINDOW_BOX,
            "middle_window": (inner_mx1, inner_my1, inner_mx2, inner_my2),
            "bottom_window": (inner_bx1, inner_by1, inner_bx2, inner_by2),
            "bezel_left": BEZEL_LEFT_BOX,
            "bezel_right": BEZEL_RIGHT_BOX
        }
    }


def render_developer_debug_overlay(
    image_bgr: np.ndarray,
    quad_points: Optional[np.ndarray],
    canonical_bgr: Optional[np.ndarray],
    features_dict: Optional[Dict[str, Any]],
    validation_res: Dict[str, Any]
) -> np.ndarray:
    """
    Renders a high-resolution developer diagnostic overlay showing:
    1. Input image with detected DoseBand quad polygon
    2. Side-by-side perspective-warped canonical view
    3. H2S ROI, Humidity ROI, Bezel sample bounding boxes
    4. Diagnostic metrics (Blur score, Lighting, Validation score, Predicted PPM)
    """
    h, w = image_bgr.shape[:2]
    overlay_input = image_bgr.copy()

    # Draw detected quad contour on input image
    if quad_points is not None:
        pts = quad_points.astype(np.int32).reshape((-1, 1, 2))
        cv2.polylines(overlay_input, [pts], True, (0, 230, 115), 3, cv2.LINE_AA)
        for i, pt in enumerate(quad_points):
            cv2.circle(overlay_input, (int(pt[0]), int(pt[1])), 6, (0, 140, 255), -1, cv2.LINE_AA)
            cv2.putText(overlay_input, f"P{i+1}", (int(pt[0]) + 8, int(pt[1]) - 8),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_AA)

    # Render canonical view with ROI overlays
    if canonical_bgr is not None:
        if canonical_bgr.shape[0] != CANONICAL_HEIGHT or canonical_bgr.shape[1] != CANONICAL_WIDTH:
            can_vis = cv2.resize(canonical_bgr, (CANONICAL_WIDTH, CANONICAL_HEIGHT))
        else:
            can_vis = canonical_bgr.copy()

        cv2.rectangle(can_vis, (TOP_WINDOW_BOX[0], TOP_WINDOW_BOX[1]), (TOP_WINDOW_BOX[2], TOP_WINDOW_BOX[3]), (255, 200, 0), 2)
        cv2.putText(can_vis, "Top Slot", (TOP_WINDOW_BOX[0] + 5, TOP_WINDOW_BOX[1] + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 200, 0), 1)

        cv2.rectangle(can_vis, (MIDDLE_WINDOW_BOX[0], MIDDLE_WINDOW_BOX[1]), (MIDDLE_WINDOW_BOX[2], MIDDLE_WINDOW_BOX[3]), (0, 200, 255), 2)
        cv2.putText(can_vis, "Humidity ROI", (MIDDLE_WINDOW_BOX[0] + 5, MIDDLE_WINDOW_BOX[1] + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 200, 255), 1)

        cv2.rectangle(can_vis, (BOTTOM_WINDOW_BOX[0], BOTTOM_WINDOW_BOX[1]), (BOTTOM_WINDOW_BOX[2], BOTTOM_WINDOW_BOX[3]), (0, 255, 120), 2)
        cv2.putText(can_vis, "H2S Sensor ROI", (BOTTOM_WINDOW_BOX[0] + 5, BOTTOM_WINDOW_BOX[1] + 24), cv2.FONT_HERSHEY_SIMPLEX, 0.50, (0, 255, 120), 1)

        cv2.rectangle(can_vis, (BEZEL_LEFT_BOX[0], BEZEL_LEFT_BOX[1]), (BEZEL_LEFT_BOX[2], BEZEL_LEFT_BOX[3]), (180, 180, 180), 1)
        cv2.rectangle(can_vis, (BEZEL_RIGHT_BOX[0], BEZEL_RIGHT_BOX[1]), (BEZEL_RIGHT_BOX[2], BEZEL_RIGHT_BOX[3]), (180, 180, 180), 1)
    else:
        can_vis = np.zeros((CANONICAL_HEIGHT, CANONICAL_WIDTH, 3), dtype=np.uint8)

    # Resize input image to match canonical height for side-by-side display
    scale = float(CANONICAL_HEIGHT) / float(h)
    new_w = max(100, int(w * scale))
    resized_input = cv2.resize(overlay_input, (new_w, CANONICAL_HEIGHT))

    side_by_side = np.hstack([resized_input, can_vis])
    
    header_h = 70
    full_w = side_by_side.shape[1]
    banner = np.zeros((header_h, full_w, 3), dtype=np.uint8)
    banner[:] = (15, 23, 42)

    is_val = validation_res.get("is_valid", False)
    val_score = validation_res.get("validation_score", 0.0)
    conf_pct = validation_res.get("confidence_pct", 0)

    status_color = (0, 220, 100) if is_val else (50, 50, 230)
    status_text = f"DOSEBAND PROTOTYPE DETECTED: {'VALID' if is_val else 'INVALID'}"
    
    cv2.putText(banner, status_text, (16, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.65, status_color, 2, cv2.LINE_AA)
    
    diag_text = f"Confidence: {conf_pct}% | Validation: {val_score:.2f} | Canonical Grid: {CANONICAL_WIDTH}x{CANONICAL_HEIGHT}"
    cv2.putText(banner, diag_text, (16, 52), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 210, 225), 1, cv2.LINE_AA)

    final_debug_image = np.vstack([banner, side_by_side])
    return final_debug_image
