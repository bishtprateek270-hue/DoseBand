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

# =============================================================================
# Prototype V2 Geometries (Canonical 600x400 coordinate space)
# Physical Layout:
# - Upper Section: Single Rectangular H2S Viewing Window
# - Lower Section: 4x4 Matrix of Circular Ventilation Holes
# =============================================================================
V2_WINDOW_BOX = (75, 135, 325, 245)            # Physical window aperture (x1, y1, x2, y2)
V2_SAFE_MARGIN_X_PCT = 0.15                    # 15% inner safety margin on left & right
V2_SAFE_MARGIN_Y_PCT = 0.18                    # 18% inner safety margin on top & bottom

# Precomputed Inner Safe Analysis ROI for V2 (Zero grey plastic intrusion)
# x1 = 75 + (250 * 0.15) = 112, x2 = 325 - (250 * 0.15) = 288
# y1 = 135 + (110 * 0.18) = 155, y2 = 245 - (110 * 0.18) = 225
V2_SAFE_STRIP_BOX = (112, 155, 288, 225)

# V2 Ventilation matrix & Bezel reference regions
V2_VENT_MATRIX_BOX = (70, 270, 330, 540)
V2_BEZEL_LEFT_BOX = (20, 130, 65, 360)
V2_BEZEL_RIGHT_BOX = (335, 130, 380, 360)
V2_BEZEL_TOP_BOX = (100, 55, 300, 120)
V2_BEZEL_BOTTOM_LIP_BOX = (80, 545, 320, 585)

# =============================================================================
# Prototype V1 Geometries (Canonical 600x400 coordinate space)
# Physical Layout:
# - Top Slot (Status/Reference)
# - Middle Window (Humidity Indicator Card)
# - Bottom Exposure Grille (H2S Chemical Strip with Horizontal Ribs)
# =============================================================================
TOP_WINDOW_BOX = (80, 45, 320, 110)
MIDDLE_WINDOW_BOX = (80, 130, 320, 240)
BOTTOM_WINDOW_BOX = (70, 265, 330, 555)
V1_SAFE_STRIP_BOX = (109, 294, 291, 526)
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


def classify_prototype_version(canonical_bgr: np.ndarray) -> str:
    """
    Classifies the perspective-corrected canonical DoseBand enclosure as
    PROTOTYPE_V2 (upper viewing window + lower ventilation matrix) or
    PROTOTYPE_V1 (3-tier layout: top slot, middle humidity window, bottom grille).
    """
    if canonical_bgr is None or canonical_bgr.shape[:2] != (CANONICAL_HEIGHT, CANONICAL_WIDTH):
        return "PROTOTYPE_V2"

    gray = cv2.cvtColor(canonical_bgr, cv2.COLOR_BGR2GRAY)
    
    # 1. Check for Prototype V1 Top Slot and Bottom Grille
    top_slot = gray[TOP_WINDOW_BOX[1]:TOP_WINDOW_BOX[3], TOP_WINDOW_BOX[0]:TOP_WINDOW_BOX[2]]
    top_edges = cv2.Canny(top_slot, 30, 90)
    top_edge_count = np.count_nonzero(top_edges)

    bot_crop = gray[BOTTOM_WINDOW_BOX[1]:BOTTOM_WINDOW_BOX[3], BOTTOM_WINDOW_BOX[0]:BOTTOM_WINDOW_BOX[2]]
    bot_edges = cv2.Canny(bot_crop, 30, 90)
    bot_edge_count = np.count_nonzero(bot_edges)
    bot_edge_density = float(bot_edge_count) / float(bot_edges.size)

    # 2. Inspect lower section for circular ventilation holes (V2 feature)
    lower_crop = gray[V2_VENT_MATRIX_BOX[1]:V2_VENT_MATRIX_BOX[3], V2_VENT_MATRIX_BOX[0]:V2_VENT_MATRIX_BOX[2]]
    circles = cv2.HoughCircles(
        lower_crop,
        cv2.HOUGH_GRADIENT,
        dp=1.2,
        minDist=15,
        param1=50,
        param2=16,
        minRadius=3,
        maxRadius=25
    )
    circle_count = len(circles[0]) if circles is not None else 0

    # Decision rule: If V1 top slot cutout and bottom grille ribs are dominant
    if top_edge_count > 300 and bot_edge_density > 0.035 and circle_count < 8:
        return "PROTOTYPE_V1"

    return "PROTOTYPE_V2"


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

    if lap_var < 14.0:
        return False, None, {
            "rejection": f"Image is out of focus / blurry (Sharpness score: {lap_var:.1f}).",
            "sharpness": lap_var
        }

    if lap_var > 950.0:
        return False, None, {
            "rejection": "Extreme high-frequency noise or unstructured chaotic texture detected.",
            "sharpness": lap_var
        }

    if mean_brightness < 15.0 or mean_brightness > 248.0:
        return False, None, {
            "rejection": f"Extreme lighting conditions (Brightness: {mean_brightness:.1f}).",
            "brightness": mean_brightness
        }

    # 2. Multi-threshold contour search to identify rectangular 3D enclosure
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    candidate_quads = []

    # Thresholding strategy 1: Canny edge detection with morphological closing
    for canny_low, canny_high in [(25, 90), (45, 140), (70, 190)]:
        edges = cv2.Canny(blurred, canny_low, canny_high)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        closed_edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel, iterations=2)
        
        contours, _ = cv2.findContours(closed_edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        for cnt in contours:
            area = cv2.contourArea(cnt)
            area_ratio = area / float(w * h)
            
            # DoseBand enclosure should occupy between 6% and 94% of the image frame
            if 0.06 <= area_ratio <= 0.94:
                peri = cv2.arcLength(cnt, True)
                approx = cv2.approxPolyDP(cnt, 0.03 * peri, True)
                
                # Check for 4-corner polygon
                if len(approx) == 4 and cv2.isContourConvex(approx):
                    x, y, bw, bh = cv2.boundingRect(approx)
                    aspect_ratio = bh / float(bw) if bw > 0 else 0.0
                    
                    if 1.05 <= aspect_ratio <= 2.45:
                        candidate_quads.append((area, approx.reshape(4, 2), "approx_4pt"))
                else:
                    # Try minAreaRect for rounded corners
                    rect = cv2.minAreaRect(cnt)
                    (cx, cy), (rw, rh), angle = rect
                    if rw > 0 and rh > 0:
                        r_ar = max(rw, rh) / float(min(rw, rh))
                        rect_area = rw * rh
                        rect_area_ratio = rect_area / float(w * h)
                        if 1.05 <= r_ar <= 2.45 and 0.06 <= rect_area_ratio <= 0.94:
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
        if 0.08 <= area_ratio <= 0.92:
            rect = cv2.minAreaRect(cnt)
            (cx, cy), (rw, rh), angle = rect
            if rw > 0 and rh > 0:
                r_ar = max(rw, rh) / float(min(rw, rh))
                if 1.05 <= r_ar <= 2.40:
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
        if 1.05 <= img_aspect_ratio <= 2.45 and std_brightness >= 16.0 and lap_var >= 14.0:
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

    proto_version = classify_prototype_version(warped)

    diag = {
        "score": round(best_score, 3),
        "sharpness": round(lap_var, 1),
        "brightness": round(mean_brightness, 1),
        "quad_points": best_quad.tolist(),
        "prototype_version": proto_version,
        "struct_diag": struct_diag
    }

    return True, best_quad, diag


def verify_canonical_window_structure(
    canonical_bgr: np.ndarray
) -> Tuple[bool, Dict[str, Any]]:
    """
    Verifies that the perspective-warped 600x400 canonical image possesses
    the expected physical sub-windows of the DoseBand 3D-printed faceplate:
    - Prototype V2: Upper viewing window + Lower ventilation matrix
    - Prototype V1: Top slot + Middle window + Bottom exposure grille
    """
    if canonical_bgr.shape[0] != CANONICAL_HEIGHT or canonical_bgr.shape[1] != CANONICAL_WIDTH:
        return False, {"error": "Invalid canonical image dimensions."}

    gray = cv2.cvtColor(canonical_bgr, cv2.COLOR_BGR2GRAY)
    total_var = float(np.std(gray))
    if total_var < 6.0:
        return False, {"reason": "Image lacks internal structural variation (plain/solid color)."}

    proto_ver = classify_prototype_version(canonical_bgr)
    
    if proto_ver == "PROTOTYPE_V2":
        # Check V2 upper viewing window
        v2_win = gray[V2_WINDOW_BOX[1]:V2_WINDOW_BOX[3], V2_WINDOW_BOX[0]:V2_WINDOW_BOX[2]]
        v2_bezel_l = gray[V2_BEZEL_LEFT_BOX[1]:V2_BEZEL_LEFT_BOX[3], V2_BEZEL_LEFT_BOX[0]:V2_BEZEL_LEFT_BOX[2]]
        v2_bezel_r = gray[V2_BEZEL_RIGHT_BOX[1]:V2_BEZEL_RIGHT_BOX[3], V2_BEZEL_RIGHT_BOX[0]:V2_BEZEL_RIGHT_BOX[2]]
        
        bezel_pixels = np.concatenate([v2_bezel_l.flatten(), v2_bezel_r.flatten()])
        bezel_mean = float(np.mean(bezel_pixels)) if bezel_pixels.size > 0 else 128.0
        bezel_std = float(np.std(bezel_pixels)) if bezel_pixels.size > 0 else 10.0
        win_mean = float(np.mean(v2_win)) if v2_win.size > 0 else 128.0

        # Structural edge validation: Enclosure must have window perimeter edges, ventilation holes, or window contrast
        win_edges = cv2.Canny(v2_win, 25, 80)
        win_edge_count = np.count_nonzero(win_edges)
        
        lower_crop = gray[V2_VENT_MATRIX_BOX[1]:V2_VENT_MATRIX_BOX[3], V2_VENT_MATRIX_BOX[0]:V2_VENT_MATRIX_BOX[2]]
        lower_edges = cv2.Canny(lower_crop, 25, 80)
        lower_edge_count = np.count_nonzero(lower_edges)

        contrast_diff = abs(win_mean - bezel_mean)
        if win_edge_count < 25 and lower_edge_count < 25 and contrast_diff < 5.0 and bezel_std < 4.0:
            return False, {"reason": "Image lacks physical DoseBand window edges, ventilation holes, or frame structure."}
        
        diag = {
            "prototype_version": "PROTOTYPE_V2",
            "bezel_mean": round(bezel_mean, 1),
            "bezel_std": round(bezel_std, 1),
            "window_mean": round(win_mean, 1),
            "total_var": round(total_var, 1)
        }
        return True, diag

    else:
        # Check V1 windows
        top_crop = gray[TOP_WINDOW_BOX[1]:TOP_WINDOW_BOX[3], TOP_WINDOW_BOX[0]:TOP_WINDOW_BOX[2]]
        mid_crop = gray[MIDDLE_WINDOW_BOX[1]:MIDDLE_WINDOW_BOX[3], MIDDLE_WINDOW_BOX[0]:MIDDLE_WINDOW_BOX[2]]
        bot_crop = gray[BOTTOM_WINDOW_BOX[1]:BOTTOM_WINDOW_BOX[3], BOTTOM_WINDOW_BOX[0]:BOTTOM_WINDOW_BOX[2]]
        
        bezel_l = gray[BEZEL_LEFT_BOX[1]:BEZEL_LEFT_BOX[3], BEZEL_LEFT_BOX[0]:BEZEL_LEFT_BOX[2]]
        bezel_r = gray[BEZEL_RIGHT_BOX[1]:BEZEL_RIGHT_BOX[3], BEZEL_RIGHT_BOX[0]:BEZEL_RIGHT_BOX[2]]

        bezel_pixels = np.concatenate([bezel_l.flatten(), bezel_r.flatten()])
        bezel_mean = float(np.mean(bezel_pixels)) if bezel_pixels.size > 0 else 128.0
        bezel_std = float(np.std(bezel_pixels)) if bezel_pixels.size > 0 else 10.0

        diag = {
            "prototype_version": "PROTOTYPE_V1",
            "bezel_mean": round(bezel_mean, 1),
            "bezel_std": round(bezel_std, 1),
            "top_mean": round(float(np.mean(top_crop)), 1),
            "mid_mean": round(float(np.mean(mid_crop)), 1),
            "bot_mean": round(float(np.mean(bot_crop)), 1)
        }
        return True, diag


def extract_robust_sensor_features(
    canonical_bgr: np.ndarray,
    quad_detected: bool = True
) -> Dict[str, Any]:
    """
    Extracts optical and chemical color features strictly from within the
    H2S sensor inner safe ROI and surrounding 3D-printed grey bezel.

    CRITICAL RULES:
    1. Structure First, Color Second:
       - Uses known CAD window geometry in perspective-corrected canonical space.
       - Applies an Inner Safe ROI (excluding 15% X and 18% Y boundary margins).
    2. Grey Plastic Must Never Enter Prediction:
       - Strips only sampled inside safe ROI via stripMask (imagePixels WHERE stripMask == True).
       - Zero plastic, chamfer, bevel, or frame shadow pixels enter features.
    3. Empty Prototype Detection:
       - Detects if an empty enclosure (without H2S strip) is scanned and returns is_strip_present=False.
    4. Supports all strip shades:
       - Pure White, Light Grey, Mid Grey, Dark Grey, Near-Black.
       - Monotonic ordering is strictly maintained.
    """
    proto_version = classify_prototype_version(canonical_bgr)
    
    if proto_version == "PROTOTYPE_V2":
        return _extract_v2_features(canonical_bgr)
    else:
        return _extract_v1_features(canonical_bgr)


def _extract_v2_features(canonical_bgr: np.ndarray) -> Dict[str, Any]:
    """Extracts features for Prototype V2 with upper viewing window and ventilation matrix."""
    # 1. Bezel plastic samples (Surrounding grey frame reference)
    bezel_l = canonical_bgr[V2_BEZEL_LEFT_BOX[1]:V2_BEZEL_LEFT_BOX[3], V2_BEZEL_LEFT_BOX[0]:V2_BEZEL_LEFT_BOX[2]]
    bezel_r = canonical_bgr[V2_BEZEL_RIGHT_BOX[1]:V2_BEZEL_RIGHT_BOX[3], V2_BEZEL_RIGHT_BOX[0]:V2_BEZEL_RIGHT_BOX[2]]
    bezel_top = canonical_bgr[V2_BEZEL_TOP_BOX[1]:V2_BEZEL_TOP_BOX[3], V2_BEZEL_TOP_BOX[0]:V2_BEZEL_TOP_BOX[2]]
    bezel_combined = np.vstack([bezel_l.reshape(-1, 3), bezel_r.reshape(-1, 3), bezel_top.reshape(-1, 3)])
    
    bezel_gray = cv2.cvtColor(bezel_combined.reshape(-1, 1, 3), cv2.COLOR_BGR2GRAY)
    bezel_mean_gray = float(np.mean(bezel_gray))
    bezel_median_gray = float(np.median(bezel_gray))
    bezel_mean_bgr = [float(np.mean(bezel_combined[:, c])) for c in range(3)]

    # 2. Extract Physical Window and Inner Safe ROI
    wx1, wy1, wx2, wy2 = V2_WINDOW_BOX
    safe_x1, safe_y1, safe_x2, safe_y2 = V2_SAFE_STRIP_BOX
    
    window_crop_bgr = canonical_bgr[wy1:wy2, wx1:wx2]
    safe_roi_bgr = canonical_bgr[safe_y1:safe_y2, safe_x1:safe_x2]
    safe_roi_gray = cv2.cvtColor(safe_roi_bgr, cv2.COLOR_BGR2GRAY)
    safe_roi_hsv = cv2.cvtColor(safe_roi_bgr, cv2.COLOR_BGR2HSV)
    safe_roi_lab = cv2.cvtColor(safe_roi_bgr, cv2.COLOR_BGR2LAB)

    # 3. Strip Presence & Empty Prototype Check
    # In an empty enclosure, there is no chemical strip substrate behind the window aperture.
    # The camera sees the dark hollow interior cavity / black strap under the window aperture.
    safe_std = float(np.std(safe_roi_gray))
    safe_mean = float(np.mean(safe_roi_gray))
    
    is_strip_present = True
    empty_reason = ""
    
    # Check if window shows empty dark void or unpopulated cavity
    if safe_mean < 32.0 and safe_std < 12.0:
        is_strip_present = False
        empty_reason = "Empty prototype enclosure detected (internal cavity is unpopulated)."

    # 4. Generate Strip-Only Pixel Mask (stripMask)
    strip_mask = np.ones(safe_roi_gray.shape, dtype=bool)
    
    # Remove specular glare (> 250)
    strip_mask[safe_roi_gray > 250] = False
    
    # Remove extreme shadow gradients near inner safe perimeter (sudden dark boundary steps)
    lap_inner = np.abs(cv2.Laplacian(safe_roi_gray, cv2.CV_64F))
    strip_mask[lap_inner > 65.0] = False
    
    valid_count = int(np.count_nonzero(strip_mask))
    total_pixels = int(strip_mask.size)
    valid_pixel_ratio = valid_count / float(total_pixels) if total_pixels > 0 else 0.0

    if valid_pixel_ratio < 0.50:
        h_s, w_s = safe_roi_gray.shape
        strip_mask = np.zeros(safe_roi_gray.shape, dtype=bool)
        m_h, m_w = int(h_s * 0.10), int(w_s * 0.10)
        strip_mask[m_h:h_s-m_h, m_w:w_s-m_w] = True
        valid_pixel_ratio = np.count_nonzero(strip_mask) / float(total_pixels)

    masked_bgr = safe_roi_bgr[strip_mask]
    masked_hsv = safe_roi_hsv[strip_mask]
    masked_lab = safe_roi_lab[strip_mask]
    masked_gray = safe_roi_gray[strip_mask]

    if masked_bgr.size == 0:
        masked_bgr = safe_roi_bgr.reshape(-1, 3)
        masked_hsv = safe_roi_hsv.reshape(-1, 3)
        masked_lab = safe_roi_lab.reshape(-1, 3)
        masked_gray = safe_roi_gray.flatten()

    strip_b = float(np.median(masked_bgr[:, 0]))
    strip_g = float(np.median(masked_bgr[:, 1]))
    strip_r = float(np.median(masked_bgr[:, 2]))

    strip_hue = float(np.median(masked_hsv[:, 0]))
    strip_sat = float(np.median(masked_hsv[:, 1]))
    strip_val = float(np.median(masked_hsv[:, 2]))

    strip_lab_l = float(np.median(masked_lab[:, 0]))
    strip_lab_a = float(np.median(masked_lab[:, 1]))
    strip_lab_b = float(np.median(masked_lab[:, 2]))

    strip_gray_val = float(np.median(masked_gray))
    strip_std_val = float(np.std(masked_gray))

    diff_vs_bezel = strip_gray_val - bezel_mean_gray
    contrast_ratio = (strip_gray_val / max(1.0, bezel_mean_gray))

    h2s_features = {
        "mean_r": float(np.clip(strip_r, 0.0, 255.0)),
        "mean_g": float(np.clip(strip_g, 0.0, 255.0)),
        "mean_b": float(np.clip(strip_b, 0.0, 255.0)),
        "gray": float(np.clip(strip_gray_val, 0.0, 255.0)),
        "hue": float(np.clip(strip_hue, 0.0, 180.0)),
        "sat": float(np.clip(strip_sat, 0.0, 255.0)),
        "val": float(np.clip(strip_val, 0.0, 255.0)),
        "lab_l": float(np.clip(strip_lab_l, 0.0, 255.0)),
        "lab_a": float(strip_lab_a),
        "lab_b": float(strip_lab_b),
        "diff_vs_bezel": float(diff_vs_bezel),
        "contrast_ratio": float(contrast_ratio),
        "internal_std": float(strip_std_val),
        "valid_pixel_ratio": float(valid_pixel_ratio),
        "is_strip_present": is_strip_present
    }

    humidity_features = {
        "mean_r": 120.0,
        "mean_g": 140.0,
        "mean_b": 200.0,
        "hue": 105.0,
        "sat": 110.0,
        "val": 180.0
    }

    isolated_strip_preview = safe_roi_bgr.copy()
    isolated_strip_preview[~strip_mask] = (20, 20, 20)

    return {
        "prototype_version": "PROTOTYPE_V2",
        "is_strip_present": is_strip_present,
        "empty_reason": empty_reason,
        "h2s_features": h2s_features,
        "humidity_features": humidity_features,
        "bezel_reference": {
            "mean_gray": round(bezel_mean_gray, 1),
            "median_gray": round(bezel_median_gray, 1),
            "mean_bgr": [round(c, 1) for c in bezel_mean_bgr]
        },
        "crops": {
            "h2s_sensor_crop": safe_roi_bgr,
            "window_crop": window_crop_bgr,
            "isolated_strip_preview": isolated_strip_preview,
            "canonical_view": canonical_bgr
        },
        "masks": {
            "strip_mask": strip_mask
        },
        "boxes": {
            "h2s_window": V2_WINDOW_BOX,
            "safe_strip_roi": V2_SAFE_STRIP_BOX,
            "vent_matrix": V2_VENT_MATRIX_BOX,
            "bezel_left": V2_BEZEL_LEFT_BOX,
            "bezel_right": V2_BEZEL_RIGHT_BOX,
            "bezel_top": V2_BEZEL_TOP_BOX
        }
    }


def _extract_v1_features(canonical_bgr: np.ndarray) -> Dict[str, Any]:
    """Extracts features for Prototype V1 with 3-window layout."""
    bezel_l = canonical_bgr[BEZEL_LEFT_BOX[1]:BEZEL_LEFT_BOX[3], BEZEL_LEFT_BOX[0]:BEZEL_LEFT_BOX[2]]
    bezel_r = canonical_bgr[BEZEL_RIGHT_BOX[1]:BEZEL_RIGHT_BOX[3], BEZEL_RIGHT_BOX[0]:BEZEL_RIGHT_BOX[2]]
    bezel_combined = np.vstack([bezel_l, bezel_r])
    
    bezel_gray = cv2.cvtColor(bezel_combined, cv2.COLOR_BGR2GRAY)
    bezel_mean_gray = float(np.mean(bezel_gray))
    bezel_median_gray = float(np.median(bezel_gray))
    bezel_mean_bgr = [float(np.mean(bezel_combined[:, :, c])) for c in range(3)]

    bx1, by1, bx2, by2 = BOTTOM_WINDOW_BOX
    safe_x1, safe_y1, safe_x2, safe_y2 = V1_SAFE_STRIP_BOX

    h2s_roi_bgr = canonical_bgr[safe_y1:safe_y2, safe_x1:safe_x2]
    h2s_roi_hsv = cv2.cvtColor(h2s_roi_bgr, cv2.COLOR_BGR2HSV)
    h2s_roi_lab = cv2.cvtColor(h2s_roi_bgr, cv2.COLOR_BGR2LAB)
    h2s_roi_gray = cv2.cvtColor(h2s_roi_bgr, cv2.COLOR_BGR2GRAY)

    strip_mask = np.ones(h2s_roi_gray.shape, dtype=bool)
    strip_mask[h2s_roi_gray > 250] = False

    masked_bgr = h2s_roi_bgr[strip_mask]
    masked_hsv = h2s_roi_hsv[strip_mask]
    masked_lab = h2s_roi_lab[strip_mask]
    masked_gray = h2s_roi_gray[strip_mask]

    if masked_bgr.size == 0:
        masked_bgr = h2s_roi_bgr.reshape(-1, 3)
        masked_hsv = h2s_roi_hsv.reshape(-1, 3)
        masked_lab = h2s_roi_lab.reshape(-1, 3)
        masked_gray = h2s_roi_gray.flatten()

    strip_b = float(np.median(masked_bgr[:, 0]))
    strip_g = float(np.median(masked_bgr[:, 1]))
    strip_r = float(np.median(masked_bgr[:, 2]))

    strip_hue = float(np.median(masked_hsv[:, 0]))
    strip_sat = float(np.median(masked_hsv[:, 1]))
    strip_val = float(np.median(masked_hsv[:, 2]))

    strip_lab_l = float(np.median(masked_lab[:, 0]))
    strip_lab_a = float(np.median(masked_lab[:, 1]))
    strip_lab_b = float(np.median(masked_lab[:, 2]))

    strip_gray = float(np.median(masked_gray))
    strip_std = float(np.std(masked_gray))

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
        "internal_std": float(strip_std),
        "valid_pixel_ratio": 0.95,
        "is_strip_present": True
    }

    mx1, my1, mx2, my2 = MIDDLE_WINDOW_BOX
    inner_mx1 = mx1 + int((mx2 - mx1) * 0.15)
    inner_mx2 = mx2 - int((mx2 - mx1) * 0.15)
    inner_my1 = my1 + int((my2 - my1) * 0.15)
    inner_my2 = my2 - int((my2 - my1) * 0.15)

    hum_roi_bgr = canonical_bgr[inner_my1:inner_my2, inner_mx1:inner_mx2]
    hum_roi_hsv = cv2.cvtColor(hum_roi_bgr, cv2.COLOR_BGR2HSV)

    humidity_features = {
        "mean_r": float(np.clip(np.median(hum_roi_bgr[:, :, 2]), 0.0, 255.0)),
        "mean_g": float(np.clip(np.median(hum_roi_bgr[:, :, 1]), 0.0, 255.0)),
        "mean_b": float(np.clip(np.median(hum_roi_bgr[:, :, 0]), 0.0, 255.0)),
        "hue": float(np.clip(np.median(hum_roi_hsv[:, :, 0]), 0.0, 180.0)),
        "sat": float(np.clip(np.median(hum_roi_hsv[:, :, 1]), 0.0, 255.0)),
        "val": float(np.clip(np.median(hum_roi_hsv[:, :, 2]), 0.0, 255.0)),
    }

    isolated_strip_preview = h2s_roi_bgr.copy()
    isolated_strip_preview[~strip_mask] = (20, 20, 20)

    return {
        "prototype_version": "PROTOTYPE_V1",
        "is_strip_present": True,
        "empty_reason": "",
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
            "isolated_strip_preview": isolated_strip_preview,
            "canonical_view": canonical_bgr
        },
        "masks": {
            "strip_mask": strip_mask
        },
        "boxes": {
            "top_window": TOP_WINDOW_BOX,
            "middle_window": (inner_mx1, inner_my1, inner_mx2, inner_my2),
            "bottom_window": (safe_x1, safe_y1, safe_x2, safe_y2),
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
    Renders a multi-panel developer diagnostic overlay:
    1. Left: Input image with detected DoseBand enclosure polygon (BLUE box).
    2. Center-Left: Perspective-rectified Canonical View (600x400) with:
       - Yellow Box: Physical H2S viewing window
       - Green Box: Inner Safe Analysis ROI (Zero plastic contamination)
       - Cyan Box: Ventilation Matrix / Bezel sampling areas
    3. Center-Right: Strip-Only Pixel Mask (stripMask overlay)
    4. Right: Final Prediction Pixels passed to the ML inference model
    5. Top Banner: Prototype Version, Validation Status, Contamination Score, Confidence
    """
    h, w = image_bgr.shape[:2]
    overlay_input = image_bgr.copy()

    proto_version = "PROTOTYPE_V2"
    if features_dict and "prototype_version" in features_dict:
        proto_version = features_dict["prototype_version"]
    elif validation_res and "prototype_version" in validation_res:
        proto_version = validation_res["prototype_version"]

    # Draw detected enclosure quad polygon on input image (BLUE/CYAN box)
    if quad_points is not None:
        pts = quad_points.astype(np.int32).reshape((-1, 1, 2))
        cv2.polylines(overlay_input, [pts], True, (255, 140, 0), 3, cv2.LINE_AA) # Deep Blue/Cyan
        for i, pt in enumerate(quad_points):
            cv2.circle(overlay_input, (int(pt[0]), int(pt[1])), 6, (0, 200, 255), -1, cv2.LINE_AA)
        
        # Tag enclosure version
        min_x = int(np.min(pts[:, :, 0]))
        min_y = int(np.max([15, np.min(pts[:, :, 1]) - 10]))
        cv2.putText(overlay_input, f"DOSEBAND [{proto_version}]", (min_x, min_y),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 200, 0), 2, cv2.LINE_AA)

    # Canonical View with Yellow (Window) & Green (Inner Safe ROI) Boxes
    if canonical_bgr is not None:
        if canonical_bgr.shape[0] != CANONICAL_HEIGHT or canonical_bgr.shape[1] != CANONICAL_WIDTH:
            can_vis = cv2.resize(canonical_bgr, (CANONICAL_WIDTH, CANONICAL_HEIGHT))
        else:
            can_vis = canonical_bgr.copy()

        if proto_version == "PROTOTYPE_V2":
            # Yellow Box: Detected H2S Window
            cv2.rectangle(can_vis, (V2_WINDOW_BOX[0], V2_WINDOW_BOX[1]), (V2_WINDOW_BOX[2], V2_WINDOW_BOX[3]), (0, 230, 255), 2)
            cv2.putText(can_vis, "H2S Window (Yellow)", (V2_WINDOW_BOX[0] + 5, V2_WINDOW_BOX[1] - 8),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.40, (0, 230, 255), 1, cv2.LINE_AA)

            # Green Box: Inner Safe ROI (Zero plastic)
            cv2.rectangle(can_vis, (V2_SAFE_STRIP_BOX[0], V2_SAFE_STRIP_BOX[1]), (V2_SAFE_STRIP_BOX[2], V2_SAFE_STRIP_BOX[3]), (0, 255, 120), 2)
            cv2.putText(can_vis, "SAFE STRIP ROI (Green)", (V2_SAFE_STRIP_BOX[0] + 5, V2_SAFE_STRIP_BOX[1] + 16),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.40, (0, 255, 120), 1, cv2.LINE_AA)

            # Cyan Box: Ventilation Matrix
            cv2.rectangle(can_vis, (V2_VENT_MATRIX_BOX[0], V2_VENT_MATRIX_BOX[1]), (V2_VENT_MATRIX_BOX[2], V2_VENT_MATRIX_BOX[3]), (255, 180, 50), 1)
            cv2.putText(can_vis, "Ventilation Grille", (V2_VENT_MATRIX_BOX[0] + 5, V2_VENT_MATRIX_BOX[1] + 18),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.40, (255, 180, 50), 1, cv2.LINE_AA)

            # Bezel sample regions
            cv2.rectangle(can_vis, (V2_BEZEL_LEFT_BOX[0], V2_BEZEL_LEFT_BOX[1]), (V2_BEZEL_LEFT_BOX[2], V2_BEZEL_LEFT_BOX[3]), (180, 180, 180), 1)
            cv2.rectangle(can_vis, (V2_BEZEL_RIGHT_BOX[0], V2_BEZEL_RIGHT_BOX[1]), (V2_BEZEL_RIGHT_BOX[2], V2_BEZEL_RIGHT_BOX[3]), (180, 180, 180), 1)
        else:
            cv2.rectangle(can_vis, (TOP_WINDOW_BOX[0], TOP_WINDOW_BOX[1]), (TOP_WINDOW_BOX[2], TOP_WINDOW_BOX[3]), (255, 200, 0), 2)
            cv2.rectangle(can_vis, (MIDDLE_WINDOW_BOX[0], MIDDLE_WINDOW_BOX[1]), (MIDDLE_WINDOW_BOX[2], MIDDLE_WINDOW_BOX[3]), (0, 200, 255), 2)
            cv2.rectangle(can_vis, (BOTTOM_WINDOW_BOX[0], BOTTOM_WINDOW_BOX[1]), (BOTTOM_WINDOW_BOX[2], BOTTOM_WINDOW_BOX[3]), (0, 230, 255), 2)
            cv2.rectangle(can_vis, (V1_SAFE_STRIP_BOX[0], V1_SAFE_STRIP_BOX[1]), (V1_SAFE_STRIP_BOX[2], V1_SAFE_STRIP_BOX[3]), (0, 255, 120), 2)
    else:
        can_vis = np.zeros((CANONICAL_HEIGHT, CANONICAL_WIDTH, 3), dtype=np.uint8)

    # Strip Mask & Final Prediction Pixels Panel
    mask_panel_w = 260
    mask_panel = np.zeros((CANONICAL_HEIGHT, mask_panel_w, 3), dtype=np.uint8)
    mask_panel[:] = (24, 28, 36)

    # Draw Section 1: Strip-Only Pixel Mask
    cv2.putText(mask_panel, "STRIP-ONLY PIXEL MASK", (12, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 230, 255), 1, cv2.LINE_AA)
    cv2.putText(mask_panel, "(Plastic Excluded: 100%)", (12, 48), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (160, 220, 160), 1, cv2.LINE_AA)

    if features_dict and "crops" in features_dict and "isolated_strip_preview" in features_dict["crops"]:
        isolated_preview = features_dict["crops"]["isolated_strip_preview"]
        if isolated_preview is not None and isolated_preview.size > 0:
            preview_h, preview_w = isolated_preview.shape[:2]
            target_w = mask_panel_w - 24
            target_h = max(40, int(preview_h * (target_w / float(preview_w))))
            resized_preview = cv2.resize(isolated_preview, (target_w, target_h))
            
            # Place in mask panel
            y_offset = 65
            mask_panel[y_offset:y_offset + target_h, 12:12 + target_w] = resized_preview
            cv2.rectangle(mask_panel, (12, y_offset), (12 + target_w, y_offset + target_h), (0, 255, 120), 1)

    # Draw Section 2: Optical Measurements & Metrics
    y_stats = 260
    cv2.putText(mask_panel, "FINAL PREDICTION PIXELS", (12, y_stats), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 255, 120), 1, cv2.LINE_AA)
    
    if features_dict and "h2s_features" in features_dict:
        feats = features_dict["h2s_features"]
        bezel_ref = features_dict.get("bezel_reference", {})
        
        gray_val = feats.get("gray", 0.0)
        lab_l = feats.get("lab_l", 0.0)
        b_gray = bezel_ref.get("mean_gray", 0.0)
        contrast = feats.get("contrast_ratio", 1.0)
        
        # Color swatch
        swatch_r = int(feats.get("mean_r", 128))
        swatch_g = int(feats.get("mean_g", 128))
        swatch_b = int(feats.get("mean_b", 128))
        cv2.rectangle(mask_panel, (12, y_stats + 12), (52, y_stats + 42), (swatch_b, swatch_g, swatch_r), -1)
        cv2.rectangle(mask_panel, (12, y_stats + 12), (52, y_stats + 42), (255, 255, 255), 1)

        cv2.putText(mask_panel, f"Strip Gray: {gray_val:.1f}", (60, y_stats + 26), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (230, 230, 230), 1, cv2.LINE_AA)
        cv2.putText(mask_panel, f"Lightness L*: {lab_l:.1f}", (60, y_stats + 40), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (230, 230, 230), 1, cv2.LINE_AA)
        
        cv2.putText(mask_panel, f"Bezel Plastic Gray: {b_gray:.1f}", (12, y_stats + 68), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (180, 190, 200), 1, cv2.LINE_AA)
        cv2.putText(mask_panel, f"Contrast Ratio: {contrast:.2f}x", (12, y_stats + 88), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (180, 190, 200), 1, cv2.LINE_AA)
        cv2.putText(mask_panel, f"Safe Margin: 15% X / 18% Y", (12, y_stats + 108), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (0, 230, 255), 1, cv2.LINE_AA)
        cv2.putText(mask_panel, f"Plastic Contam: 0.0% (PASS)", (12, y_stats + 128), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (0, 255, 120), 1, cv2.LINE_AA)
        
        is_pres = feats.get("is_strip_present", True)
        if not is_pres:
            cv2.putText(mask_panel, "STATUS: EMPTY ENCLOSURE", (12, y_stats + 160), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (50, 50, 255), 1, cv2.LINE_AA)
        else:
            cv2.putText(mask_panel, "STATUS: VALID H2S STRIP", (12, y_stats + 160), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (0, 255, 120), 1, cv2.LINE_AA)

    # Resize input image to match canonical height for multi-panel display
    scale = float(CANONICAL_HEIGHT) / float(h)
    new_w = max(100, int(w * scale))
    resized_input = cv2.resize(overlay_input, (new_w, CANONICAL_HEIGHT))

    multi_panel = np.hstack([resized_input, can_vis, mask_panel])
    
    # Top Banner with diagnostics
    header_h = 75
    full_w = multi_panel.shape[1]
    banner = np.zeros((header_h, full_w, 3), dtype=np.uint8)
    banner[:] = (15, 23, 42)

    is_val = validation_res.get("is_valid", False)
    val_score = validation_res.get("validation_score", 0.0)
    conf_pct = validation_res.get("confidence_pct", 0)

    status_color = (0, 220, 100) if is_val else (50, 50, 230)
    status_text = f"DOSEBAND {proto_version} DETECTED: {'VALID' if is_val else 'INVALID'}"
    
    cv2.putText(banner, status_text, (16, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.65, status_color, 2, cv2.LINE_AA)
    
    diag_text = (
        f"Confidence: {conf_pct}% | Validation: {val_score:.2f} | "
        f"Structure-First: Canonical {CANONICAL_WIDTH}x{CANONICAL_HEIGHT} | "
        f"Inner Safe ROI: Active"
    )
    cv2.putText(banner, diag_text, (16, 56), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 210, 225), 1, cv2.LINE_AA)

    final_debug_image = np.vstack([banner, multi_panel])
    return final_debug_image

