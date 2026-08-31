"""
DoseBand Synthetic Test Image Generator.

Generates realistic test images with annotated reference color scale strips, exposure gradient indicators,
and badge expiry states for pipeline testing and verification.
"""

import os
from typing import Tuple
import cv2
import numpy as np

# Output directory for test assets
OUTPUT_DIR = "test_images"


def create_base_dosimeter_image(
    strip_rgb: Tuple[int, int, int] = (230, 230, 230),
    expiry_hsv: Tuple[float, float, float] = (60.0, 150.0, 200.0),
    image_size: Tuple[int, int] = (720, 480)
) -> np.ndarray:
    """
    Creates a synthetic BGR dosimeter image with overlay text annotations.

    Layout Structure:
      - Left 1/3:  Printed reference color scale (5 swatches: White to Black) with swatch labels.
      - Middle Gap: Vertical reference gradient arrow indicator (White -> Black calibration line).
      - Right 2/3: Clean active H2S exposure sensor strip.
      - Bottom-Right: Passive shelf-life expiry indicator patch.
    """
    width, height = image_size
    # Light gray background canvas
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

        # Draw text label inside swatch
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

    # Border around reference scale
    cv2.rectangle(
        canvas,
        (scale_x1, scale_y1),
        (scale_x1 + scale_w, scale_y1 + scale_h),
        (30, 30, 30),
        2
    )
    # Header label for Reference Scale
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
    # 2. DRAW REFERENCE GRADIENT LINE / ARROW IN GAP BETWEEN SCALE & SENSOR STRIP
    # -------------------------------------------------------------------------
    # Position line in the neutral space to the right of the reference scale
    arrow_x = scale_x1 + scale_w + 14
    arrow_y1 = scale_y1 + 10
    arrow_y2 = scale_y1 + scale_h - 10

    line_color = (180, 50, 0)  # Blue/Navy indicator color
    cv2.arrowedLine(canvas, (arrow_x, arrow_y1), (arrow_x, arrow_y2), line_color, 2, tipLength=0.06)

    # Text annotations on gradient arrow alongside reference scale
    cv2.putText(canvas, "Light", (arrow_x + 6, arrow_y1 + 12), font, 0.35, line_color, 1, cv2.LINE_AA)
    cv2.putText(canvas, "Gradient", (arrow_x + 6, (arrow_y1 + arrow_y2) // 2), font, 0.33, line_color, 1, cv2.LINE_AA)
    cv2.putText(canvas, "Dark", (arrow_x + 6, arrow_y2 - 2), font, 0.35, line_color, 1, cv2.LINE_AA)

    # -------------------------------------------------------------------------
    # 3. DRAW CLEAN ACTIVE H2S TEST STRIP (RIGHT TWO-THIRDS)
    # -------------------------------------------------------------------------
    strip_x1 = roi_width + int((width - roi_width) * 0.15)
    strip_y1 = int(height * 0.12)
    strip_w = int((width - roi_width) * 0.70)
    strip_h = int(height * 0.65)

    # Convert sensor strip RGB to BGR for OpenCV (Keep strip clean without overlay lines)
    strip_bgr = (strip_rgb[2], strip_rgb[1], strip_rgb[0])
    canvas[strip_y1:strip_y1 + strip_h, strip_x1:strip_x1 + strip_w] = strip_bgr

    # Draw sensor strip border
    cv2.rectangle(
        canvas,
        (strip_x1, strip_y1),
        (strip_x1 + strip_w, strip_y1 + strip_h),
        (50, 50, 50),
        2
    )

    # Clean Header label for Sensor Strip
    cv2.putText(
        canvas,
        "H2S SENSOR STRIP",
        (strip_x1 + 12, strip_y1 + 28),
        font,
        0.55,
        (255, 255, 255) if np.mean(strip_rgb) < 128 else (20, 20, 20),
        2,
        cv2.LINE_AA
    )

    # -------------------------------------------------------------------------
    # 4. DRAW EXPIRY INDICATOR PATCH (BOTTOM-RIGHT CORNER)
    # -------------------------------------------------------------------------
    patch_y1 = int(height * 0.72)
    patch_x1 = int(width * 0.72)

    # Convert OpenCV HSV tuple to BGR
    hsv_pixel = np.uint8([[[int(expiry_hsv[0]), int(expiry_hsv[1]), int(expiry_hsv[2])]]])
    bgr_pixel = cv2.cvtColor(hsv_pixel, cv2.COLOR_HSV2BGR)[0][0]
    expiry_bgr = (int(bgr_pixel[0]), int(bgr_pixel[1]), int(bgr_pixel[2]))

    canvas[patch_y1:height, patch_x1:width] = expiry_bgr
    cv2.rectangle(canvas, (patch_x1, patch_y1), (width - 1, height - 1), (30, 30, 30), 2)

    # Label on Expiry Patch
    patch_text = "EXPIRY: FRESH" if expiry_hsv[0] > 40 else "EXPIRY: EXPIRED"
    cv2.putText(
        canvas,
        patch_text,
        (patch_x1 + 10, patch_y1 + 30),
        font,
        0.45,
        (255, 255, 255) if expiry_hsv[0] <= 40 else (0, 0, 0),
        2,
        cv2.LINE_AA
    )

    return canvas


def adjust_lighting(image_bgr: np.ndarray, factor: float) -> np.ndarray:
    """
    Adjusts image brightness by multiplying pixel values by factor and clipping [0, 255].
    """
    adjusted = image_bgr.astype(np.float64) * factor
    return np.clip(adjusted, 0, 255).astype(np.uint8)


def generate_all_test_assets() -> None:
    """
    Generates all required synthetic test images with visual annotations.
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Generating annotated synthetic test images in '{OUTPUT_DIR}/'...\n")

    # 1. BASE IMAGE & LIGHTING VARIANTS
    base_bgr = create_base_dosimeter_image()

    lighting_variants = {
        "lighting_dim.jpg": 0.7,
        "lighting_normal.jpg": 1.0,
        "lighting_bright.jpg": 1.3
    }

    for filename, factor in lighting_variants.items():
        out_path = os.path.join(OUTPUT_DIR, filename)
        img_variant = adjust_lighting(base_bgr, factor)
        cv2.imwrite(out_path, img_variant)
        print(f"  [+] Saved Annotated Image: {out_path}")

    cv2.imwrite(os.path.join(OUTPUT_DIR, "base_normal.jpg"), base_bgr)

    # 2. FIVE H2S EXPOSURE LEVEL VARIANTS
    exposure_levels = [
        ("exposure_level_1_very_low.jpg", (240, 240, 240)),
        ("exposure_level_2_low.jpg",      (190, 190, 190)),
        ("exposure_level_3_medium.jpg",   (140, 140, 140)),
        ("exposure_level_4_high.jpg",     (90, 90, 90)),
        ("exposure_level_5_very_high.jpg", (40, 40, 40))
    ]

    for filename, rgb_color in exposure_levels:
        out_path = os.path.join(OUTPUT_DIR, filename)
        img_exposure = create_base_dosimeter_image(strip_rgb=rgb_color)
        cv2.imwrite(out_path, img_exposure)
        print(f"  [+] Saved Exposure Variant: {out_path}")

    # 3. TWO EXPIRY PATCH VARIANTS
    fresh_hsv = (60.0, 150.0, 200.0)
    expired_hsv = (15.0, 200.0, 100.0)

    fresh_img = create_base_dosimeter_image(expiry_hsv=fresh_hsv)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "expiry_fresh.jpg"), fresh_img)

    expired_img = create_base_dosimeter_image(expiry_hsv=expired_hsv)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "expiry_expired.jpg"), expired_img)

    print("\nSuccessfully updated all annotated test images!")


if __name__ == "__main__":
    generate_all_test_assets()
