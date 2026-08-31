"""
DoseBand Strip Reader Module - Optical Staining Intensity Extraction.

This module extracts the H2S sensor strip region from a lighting-corrected image
and calculates a normalized chemical staining intensity score.

Why Use HSV Value (V) Channel Instead of Raw RGB? (Hackathon Judge Talking Point):
----------------------------------------------------------------------------------
1. Decoupling Luminance from Chromaticity:
   In RGB color space, red, green, and blue channels are highly correlated. Ambient light
   flashes, shadows, or color tints shift all three channels simultaneously, making it
   difficult to isolate pure chemical darkening.

2. Chemical Reaction Mechanism:
   H2S dosimeter strips rely on colorimetric chemical indicators (such as lead acetate or
   silver nitrate paper). Upon exposure to H2S gas, the indicator forms dark metal sulfides
   (e.g., PbS or Ag2S), causing a direct attenuation of surface reflectance (darkening).

3. Perception-Aligned Measurement:
   Converting to HSV (Hue, Saturation, Value) isolates the 'Value' (V) channel—which directly
   measures perceived luminance/brightness on a 0-255 scale. As H2S dose increases, the strip
   darkens, causing V to decrease monotonically. Normalizing V provides a stable, light-robust
   metric for cumulative chemical exposure.
"""

import os
from typing import Dict, Tuple, Any
import cv2
import numpy as np

# Calibration constants for unexposed vs fully exposed sensor baseline brightness (V channel)
# V_UNEXPOSED: Brightness of a fresh, unexposed sensor strip (high V)
# V_EXPOSED:   Brightness of a saturated, fully dark exposed sensor strip (low V)
BASELINE_V_UNEXPOSED: float = 240.0
BASELINE_V_EXPOSED: float = 40.0


def extract_strip_region(corrected_image: np.ndarray) -> np.ndarray:
    """
    Extracts the candidate region containing the H2S test strip from the lighting-corrected image.

    Assumes the reference scale occupies the left third of the image, while the active
    H2S sensor strip is located in the right two-thirds of the image frame.

    Args:
        corrected_image (np.ndarray): Lighting-corrected BGR image array.

    Returns:
        np.ndarray: Cropped image array corresponding to the sensor strip region.
    """
    h, w = corrected_image.shape[:2]

    # The right two-thirds contains the worker dosimeter strip
    strip_x_start = w // 3
    strip_region = corrected_image[:, strip_x_start:]

    # Focus on the central portion of this region to avoid edge artifacts
    sh, sw = strip_region.shape[:2]
    crop_margin_y = int(sh * 0.15)
    crop_margin_x = int(sw * 0.15)

    cropped_strip = strip_region[
        crop_margin_y : sh - crop_margin_y,
        crop_margin_x : sw - crop_margin_x
    ]

    return cropped_strip


def get_average_color(strip_region: np.ndarray) -> Tuple[Tuple[float, float, float], Tuple[float, float, float]]:
    """
    Converts the cropped sensor strip region from BGR to HSV and computes average channel values.

    Args:
        strip_region (np.ndarray): Cropped BGR sensor strip array.

    Returns:
        Tuple: (avg_hsv_tuple, avg_bgr_tuple)
            - avg_hsv: (Hue [0-179], Saturation [0-255], Value [0-255])
            - avg_bgr: (Blue [0-255], Green [0-255], Red [0-255])
    """
    # Convert BGR to HSV color space
    hsv_region = cv2.cvtColor(strip_region, cv2.COLOR_BGR2HSV)

    # Compute mean HSV values across all pixels in the crop
    avg_hsv_vals = cv2.mean(hsv_region)[:3]
    avg_hsv = (float(avg_hsv_vals[0]), float(avg_hsv_vals[1]), float(avg_hsv_vals[2]))

    # Compute mean BGR values for debugging/reference
    avg_bgr_vals = cv2.mean(strip_region)[:3]
    avg_bgr = (float(avg_bgr_vals[0]), float(avg_bgr_vals[1]), float(avg_bgr_vals[2]))

    return avg_hsv, avg_bgr


def compute_staining_intensity(
    hsv_average: Tuple[float, float, float],
    v_unexposed: float = BASELINE_V_UNEXPOSED,
    v_exposed: float = BASELINE_V_EXPOSED
) -> float:
    """
    Converts the average HSV Value (brightness) into a normalized staining intensity score [0.0, 1.0].

    Formula:
        intensity = (V_unexposed - V_current) / (V_unexposed - V_exposed)

    Values are clipped between 0.0 (fresh/unexposed) and 1.0 (fully darkened/exposed).

    Args:
        hsv_average (Tuple[float, float, float]): (Hue, Saturation, Value) tuple.
        v_unexposed (float): Baseline brightness of unexposed paper.
        v_exposed (float): Baseline brightness of fully exposed paper.

    Returns:
        float: Normalized staining intensity scalar in range [0.0, 1.0].
    """
    current_v = hsv_average[2]

    # Calculate darkening intensity relative to baselines
    denominator = v_unexposed - v_exposed
    if denominator <= 0:
        intensity = 0.0
    else:
        raw_intensity = (v_unexposed - current_v) / denominator
        intensity = float(np.clip(raw_intensity, 0.0, 1.0))

    return intensity


def read_strip(corrected_image: np.ndarray) -> Dict[str, Any]:
    """
    Chains strip region extraction, color averaging, and intensity computation.

    Args:
        corrected_image (np.ndarray): Lighting-corrected BGR image array.

    Returns:
        Dict[str, Any]: Dictionary containing:
            - 'intensity': float in range [0.0, 1.0]
            - 'avg_hsv': (H, S, V) tuple
            - 'avg_bgr': (B, G, R) tuple
    """
    # Step 1: Crop the active test strip region
    strip_region = extract_strip_region(corrected_image)

    # Step 2: Calculate mean HSV and BGR color values
    avg_hsv, avg_bgr = get_average_color(strip_region)

    # Step 3: Compute normalized chemical staining intensity
    intensity = compute_staining_intensity(avg_hsv)

    return {
        "intensity": round(intensity, 4),
        "avg_hsv": (round(avg_hsv[0], 2), round(avg_hsv[1], 2), round(avg_hsv[2], 2)),
        "avg_bgr": (round(avg_bgr[0], 2), round(avg_bgr[1], 2), round(avg_bgr[2], 2))
    }


if __name__ == "__main__":
    sample_path = os.path.join("test_images", "sample_corrected.jpg")

    print(f"Loading lighting-corrected test image from '{sample_path}'...")
    if not os.path.exists(sample_path):
        # Run calibration test script if sample_corrected.jpg doesn't exist
        from calibration import _generate_synthetic_test_image, calibrate_image
        os.makedirs("test_images", exist_ok=True)
        raw_path = os.path.join("test_images", "sample.jpg")
        if not os.path.exists(raw_path):
            _generate_synthetic_test_image(raw_path)
        raw = cv2.imread(raw_path)
        corr = calibrate_image(raw)
        cv2.imwrite(sample_path, corr)

    image = cv2.imread(sample_path)
    if image is None:
        raise FileNotFoundError(f"Failed to read image from '{sample_path}'.")

    # Run strip reader pipeline
    print("Executing read_strip() pipeline...")
    result = read_strip(image)

    print("\n--- Strip Reader Results ---")
    print(f"Staining Intensity: {result['intensity']} (0.0 = Fresh, 1.0 = Max Exposure)")
    print(f"Average HSV:        H={result['avg_hsv'][0]}, S={result['avg_hsv'][1]}, V={result['avg_hsv'][2]}")
    print(f"Average BGR:        B={result['avg_bgr'][0]}, G={result['avg_bgr'][1]}, R={result['avg_bgr'][2]}")
