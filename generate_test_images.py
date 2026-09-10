"""
DoseBand Synthetic Test Image Generator.

Generates realistic test badge images embedding:
1. Reference Grayscale 5-Step Scale (Left 1/3)
2. Gradient indicator arrow (gap)
3. H2S Lead Acetate Sensor Strip (Right top/middle 2/3)
4. Humidity Indicator Card / Circular patch (Lower middle 2/3)
5. Shelf-life Expiry Indicator Patch (Bottom right corner)
"""

import os
from typing import Tuple, Optional
import cv2
import numpy as np

OUTPUT_DIR = "test_images"


def create_base_dosimeter_image(
    strip_rgb: Tuple[int, int, int] = (237, 230, 220),       # Fresh 0 ppm default
    humidity_rgb: Tuple[int, int, int] = (146, 154, 196),     # 50% RH lavender default
    expiry_hsv: Tuple[float, float, float] = (60.0, 150.0, 200.0), # Fresh green-yellow
    image_size: Tuple[int, int] = (720, 480)
) -> np.ndarray:
    """
    Creates a synthetic BGR dosimeter badge image with complete multi-ROI features.
    """
    width, height = image_size
    canvas = np.full((height, width, 3), 245, dtype=np.uint8)
    font = cv2.FONT_HERSHEY_SIMPLEX

    # -------------------------------------------------------------------------
    # 1. DRAW 5-SWATCH REFERENCE COLOR SCALE (LEFT THIRD)
    # -------------------------------------------------------------------------
    roi_width = width // 3
    scale_x1, scale_w = int(roi_width * 0.12), int(roi_width * 0.65)
    scale_y1, scale_h = int(height * 0.12), int(height * 0.75)
    seg_h = scale_h // 5

    swatch_names = ["100% White", "75% Gray", "50% Gray", "25% Gray", "0% Black"]
    swatch_grays = [255, 191, 128, 64, 0]

    for i, (name, gray) in enumerate(zip(swatch_names, swatch_grays)):
        y_start = scale_y1 + i * seg_h
        y_end = scale_y1 + (i + 1) * seg_h if i < 4 else scale_y1 + scale_h
        canvas[y_start:y_end, scale_x1:scale_x1 + scale_w] = (gray, gray, gray)

        text_color = (0, 0, 0) if gray > 128 else (255, 255, 255)
        cv2.putText(
            canvas,
            name,
            (scale_x1 + 6, y_start + seg_h // 2 + 4),
            font,
            0.36,
            text_color,
            1,
            cv2.LINE_AA
        )

    cv2.rectangle(
        canvas,
        (scale_x1, scale_y1),
        (scale_x1 + scale_w, scale_y1 + scale_h),
        (30, 30, 30),
        2
    )
    cv2.putText(
        canvas,
        "REF SCALE (5 SWATCHES)",
        (scale_x1, scale_y1 - 10),
        font,
        0.40,
        (30, 30, 30),
        1,
        cv2.LINE_AA
    )

    # -------------------------------------------------------------------------
    # 2. DRAW REFERENCE GRADIENT LINE / ARROW IN GAP
    # -------------------------------------------------------------------------
    arrow_x = scale_x1 + scale_w + 14
    arrow_y1 = scale_y1 + 10
    arrow_y2 = scale_y1 + scale_h - 10
    line_color = (180, 50, 0)
    cv2.arrowedLine(canvas, (arrow_x, arrow_y1), (arrow_x, arrow_y2), line_color, 2, tipLength=0.06)

    # -------------------------------------------------------------------------
    # 3. DRAW CLEAN ACTIVE H2S TEST STRIP (UPPER RIGHT TWO-THIRDS)
    # -------------------------------------------------------------------------
    strip_x1 = roi_width + int((width - roi_width) * 0.10)
    strip_y1 = int(height * 0.12)
    strip_w = int((width - roi_width) * 0.78)
    strip_h = int(height * 0.52)

    strip_bgr = (strip_rgb[2], strip_rgb[1], strip_rgb[0])
    canvas[strip_y1:strip_y1 + strip_h, strip_x1:strip_x1 + strip_w] = strip_bgr

    cv2.rectangle(
        canvas,
        (strip_x1, strip_y1),
        (strip_x1 + strip_w, strip_y1 + strip_h),
        (50, 50, 50),
        2
    )

    cv2.putText(
        canvas,
        "H2S SENSOR STRIP (TBL-024)",
        (strip_x1 + 12, strip_y1 + 26),
        font,
        0.48,
        (255, 255, 255) if np.mean(strip_rgb) < 128 else (20, 20, 20),
        1,
        cv2.LINE_AA
    )

    # -------------------------------------------------------------------------
    # 4. DRAW HUMIDITY INDICATOR CARD / PATCH (LOWER CENTER)
    # -------------------------------------------------------------------------
    hum_x1 = roi_width + int((width - roi_width) * 0.10)
    hum_y1 = int(height * 0.70)
    hum_w = int((width - roi_width) * 0.40)
    hum_h = int(height * 0.24)

    # Background card
    canvas[hum_y1:hum_y1 + hum_h, hum_x1:hum_x1 + hum_w] = (238, 238, 238)
    cv2.rectangle(canvas, (hum_x1, hum_y1), (hum_x1 + hum_w, hum_y1 + hum_h), (40, 40, 40), 2)

    # Center circle for humidity indicator
    circle_cx = hum_x1 + hum_w // 2
    circle_cy = hum_y1 + hum_h // 2
    circle_rad = min(hum_w, hum_h) // 2 - 8

    # Outer black ring
    cv2.circle(canvas, (circle_cx, circle_cy), circle_rad, (20, 20, 20), 2)
    # Inner colored disc
    hum_bgr = (humidity_rgb[2], humidity_rgb[1], humidity_rgb[0])
    cv2.circle(canvas, (circle_cx, circle_cy), circle_rad - 2, hum_bgr, -1)

    cv2.putText(
        canvas,
        "HUMIDITY CARD",
        (hum_x1 + 6, hum_y1 + 14),
        font,
        0.35,
        (30, 30, 30),
        1,
        cv2.LINE_AA
    )

    # -------------------------------------------------------------------------
    # 5. DRAW EXPIRY INDICATOR PATCH (BOTTOM-RIGHT CORNER)
    # -------------------------------------------------------------------------
    patch_x1 = roi_width + int((width - roi_width) * 0.55)
    patch_y1 = int(height * 0.70)
    patch_w = int((width - roi_width) * 0.33)
    patch_h = int(height * 0.24)

    hsv_pixel = np.uint8([[[int(expiry_hsv[0]), int(expiry_hsv[1]), int(expiry_hsv[2])]]])
    bgr_pixel = cv2.cvtColor(hsv_pixel, cv2.COLOR_HSV2BGR)[0][0]
    expiry_bgr = (int(bgr_pixel[0]), int(bgr_pixel[1]), int(bgr_pixel[2]))

    canvas[patch_y1:patch_y1 + patch_h, patch_x1:patch_x1 + patch_w] = expiry_bgr
    cv2.rectangle(canvas, (patch_x1, patch_y1), (patch_x1 + patch_w, patch_y1 + patch_h), (30, 30, 30), 2)

    patch_text = "EXP: FRESH" if expiry_hsv[0] > 40 else "EXP: EXPIRED"
    cv2.putText(
        canvas,
        patch_text,
        (patch_x1 + 8, patch_y1 + patch_h // 2 + 5),
        font,
        0.42,
        (255, 255, 255) if expiry_hsv[0] <= 40 else (0, 0, 0),
        1,
        cv2.LINE_AA
    )

    return canvas


def adjust_lighting(image_bgr: np.ndarray, factor: float) -> np.ndarray:
    """Adjusts image brightness."""
    adjusted = image_bgr.astype(np.float64) * factor
    return np.clip(adjusted, 0, 255).astype(np.uint8)


def generate_all_test_assets() -> None:
    """Generates all synthetic test images."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Generating synthetic test images in '{OUTPUT_DIR}/'...\n")

    # 1. Base image & lighting variants
    base_bgr = create_base_dosimeter_image()
    cv2.imwrite(os.path.join(OUTPUT_DIR, "base_normal.jpg"), base_bgr)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "lighting_normal.jpg"), base_bgr)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "lighting_dim.jpg"), adjust_lighting(base_bgr, 0.7))
    cv2.imwrite(os.path.join(OUTPUT_DIR, "lighting_bright.jpg"), adjust_lighting(base_bgr, 1.3))

    # 2. H2S Exposure levels (Continuous spectrum of white, grey, and black shades)
    exposure_levels = [
        # Standard legacy benchmark levels (Smooth progression)
        ("exposure_level_1_very_low.jpg",        (245, 242, 238), (146, 154, 196)), # 0.0 ppm, 50% RH (Pure white)
        ("exposure_level_2_low.jpg",             (210, 205, 200), (140, 178, 213)), # ~5.5 ppm, 30% RH (Very light grey)
        ("exposure_level_3_medium.jpg",          (160, 155, 150), (146, 154, 196)), # ~23.5 ppm, 50% RH (Mid grey)
        ("exposure_level_4_high.jpg",            (105, 100, 95),  (192, 157, 183)), # ~48.0 ppm, 70% RH (Dark grey)
        ("exposure_level_5_very_high.jpg",       (50, 48, 48),    (215, 141, 159)), # ~76.5 ppm, 90% RH (Charcoal / Black)

        # Complete continuum of white, grey, and black shades for live UI testing
        ("exposure_shade_01_pure_white.jpg",     (248, 248, 245), (146, 154, 196)), # ~0.0 ppm (Pure White)
        ("exposure_shade_02_off_white.jpg",      (230, 226, 222), (146, 154, 196)), # ~2.0 ppm (Off-White)
        ("exposure_shade_03_very_light_grey.jpg",(210, 205, 200), (140, 178, 213)), # ~5.5 ppm (Very Light Grey)
        ("exposure_shade_04_light_grey.jpg",     (185, 180, 175), (146, 154, 196)), # ~12.5 ppm (Light Grey)
        ("exposure_shade_05_mid_grey.jpg",       (158, 152, 146), (146, 154, 196)), # ~24.0 ppm (Mid Grey)
        ("exposure_shade_06_slate_grey.jpg",     (128, 122, 116), (192, 157, 183)), # ~37.5 ppm (Slate Grey)
        ("exposure_shade_07_dark_grey.jpg",      (98, 93, 88),    (192, 157, 183)), # ~51.5 ppm (Dark Grey)
        ("exposure_shade_08_charcoal_grey.jpg",  (68, 65, 62),    (215, 141, 159)), # ~66.5 ppm (Charcoal Grey)
        ("exposure_shade_09_deep_black.jpg",     (42, 40, 40),    (215, 141, 159))  # ~80.5 ppm (Deep Black)
    ]

    for filename, h2s_rgb, hum_rgb in exposure_levels:
        out_path = os.path.join(OUTPUT_DIR, filename)
        img = create_base_dosimeter_image(strip_rgb=h2s_rgb, humidity_rgb=hum_rgb)
        cv2.imwrite(out_path, img)
        print(f"  [+] Saved Exposure/Humidity Variant: {out_path}")

    # 3. Expiry variants
    fresh_hsv = (60.0, 150.0, 200.0)
    expired_hsv = (15.0, 200.0, 100.0)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "expiry_fresh.jpg"), create_base_dosimeter_image(expiry_hsv=fresh_hsv))
    cv2.imwrite(os.path.join(OUTPUT_DIR, "expiry_expired.jpg"), create_base_dosimeter_image(expiry_hsv=expired_hsv))

    # 4. Quality validation test assets
    blurry_img = cv2.GaussianBlur(base_bgr, (35, 35), 10.0)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "quality_test_blurry.jpg"), blurry_img)

    dark_img = adjust_lighting(base_bgr, 0.08)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "quality_test_underexposed.jpg"), dark_img)

    no_scale_img = base_bgr.copy()
    h_ns, w_ns = no_scale_img.shape[:2]
    no_scale_img[:, :w_ns // 3] = (245, 245, 245)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "quality_test_missing_scale.jpg"), no_scale_img)

    print("\n[OK] Successfully regenerated test assets with H2S + Humidity cards.")


if __name__ == "__main__":
    generate_all_test_assets()
