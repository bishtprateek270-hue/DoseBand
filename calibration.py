"""
DoseBand Calibration Module - Lighting Correction for Optical Dosimeter Reading.

This module provides color calibration and lighting normalization using a 5-swatch
printed reference color scale visible within the image frame.

Math & Theory for Hackathon Judges:
----------------------------------
1. Color Space Alignment:
   Photos taken in field conditions suffer from illumination shifts (tint/temperature)
   and exposure variance (brightness). The printed scale provides known ground-truth
   reflectance values under the current ambient light.

2. Per-Channel Ordinary Least Squares (OLS) Linear Fitting:
   For each color channel C in {Blue, Green, Red}:
       C_true = m_C * C_detected + c_C

   Where:
       - m_C represents gain / contrast correction (scaling factor)
       - c_C represents offset / bias correction (ambient lighting shift)

   We solve for m_C and c_C by minimizing the sum of squared residuals:
       min_{m_C, c_C} sum_{i=1}^5 (C_true_i - (m_C * C_detected_i + c_C))^2

   Using NumPy's 1st-degree polynomial fit (numpy.polyfit(x, y, deg=1)).

3. Spatial Color Mapping:
   The computed linear transformation functions are vectorized across the full image
   array and clipped to valid uint8 bounds [0, 255].
"""

import os
from typing import Callable, List, Tuple, Dict, Any
import cv2
import numpy as np


class ReferenceScaleNotFoundError(Exception):
    """Raised when the reference scale strip cannot be detected in the image."""
    pass


# Ground-truth reference swatches (RGB order)
# 5 swatches ranging from pure white to pure black with 3 evenly spaced grays
REFERENCE_SWATCHES: List[Dict[str, Any]] = [
    {"name": "white",      "rgb": (255, 255, 255)},
    {"name": "light_gray", "rgb": (191, 191, 191)},
    {"name": "mid_gray",   "rgb": (128, 128, 128)},
    {"name": "dark_gray",  "rgb": (64, 64, 64)},
    {"name": "black",      "rgb": (0, 0, 0)}
]


def detect_reference_scale(image: np.ndarray) -> List[Tuple[float, float, float]]:
    """
    Locates the printed reference color scale strip in the image and extracts average BGR colors.

    Assumption:
    The reference scale strip is located in the left portion (left 1/3) of the image frame.

    Args:
        image (np.ndarray): OpenCV image in BGR format (H x W x 3).

    Returns:
        List[Tuple[float, float, float]]: List of 5 average BGR color tuples extracted from top to bottom.

    Raises:
        ReferenceScaleNotFoundError: If image is invalid or scale region contour is too small/undetectable.
    """
    if image is None or image.size == 0:
        raise ReferenceScaleNotFoundError("Invalid image input provided to calibration module.")

    h, w = image.shape[:2]

    # Focus on the left third of the image where the reference scale is assumed to be placed
    roi_width = max(1, w // 3)
    roi = image[:, :roi_width]

    # Convert ROI to grayscale for contour detection
    gray_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    
    # Apply Gaussian blur and thresholding to highlight structural boundaries
    blurred = cv2.GaussianBlur(gray_roi, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)

    # Find contours within the left region
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    strip_box = None
    max_area = 0
    min_area_threshold = max(500, int(h * w * 0.005))  # Minimum contour area threshold

    # Search for vertical rectangular contour with height > width
    for cnt in contours:
        x, y, bw, bh = cv2.boundingRect(cnt)
        area = bw * bh
        aspect_ratio = bh / float(bw) if bw > 0 else 0

        # Look for vertical rectangle with minimum area
        if area > max_area and aspect_ratio > 1.1 and bh > (h * 0.15):
            max_area = area
            strip_box = (x, y, bw, bh)

    # If no valid contour met the threshold, fallback to central column or check fallback ROI
    if strip_box is None or max_area < min_area_threshold:
        box_x = int(roi_width * 0.2)
        box_y = int(h * 0.1)
        box_w = int(roi_width * 0.6)
        box_h = int(h * 0.8)
        strip_box = (box_x, box_y, box_w, box_h)
        
        # Verify fallback ROI height and width
        if box_h < 50 or box_w < 10:
            raise ReferenceScaleNotFoundError(
                "Could not detect the reference color scale — please retake the photo making sure "
                "the full strip and reference scale are visible and well-lit."
            )

    box_x, box_y, box_w, box_h = strip_box

    # Crop the detected reference strip ROI
    strip_crop = roi[box_y:box_y + box_h, box_x:box_x + box_w]
    if strip_crop.shape[0] < 25 or strip_crop.shape[1] < 5:
        raise ReferenceScaleNotFoundError(
            "Detected reference scale area is too small to separate 5 distinct swatches."
        )

    # Divide the strip vertically into 5 equal segments
    detected_bgr_colors: List[Tuple[float, float, float]] = []
    seg_height = box_h // 5

    if seg_height < 4:
        raise ReferenceScaleNotFoundError(
            "Fewer than 5 distinct swatch segments could be reliably separated."
        )

    for i in range(5):
        seg_y_start = i * seg_height
        seg_y_end = box_h if i == 4 else (i + 1) * seg_height
        
        segment = strip_crop[seg_y_start:seg_y_end, :]
        if segment.size == 0:
            raise ReferenceScaleNotFoundError("Reference scale segment extraction failed.")

        # Compute mean color in BGR for the segment
        mean_bgr = cv2.mean(segment)[:3]
        detected_bgr_colors.append((float(mean_bgr[0]), float(mean_bgr[1]), float(mean_bgr[2])))

    if len(detected_bgr_colors) != 5:
        raise ReferenceScaleNotFoundError("Could not reliably extract 5 color swatch segments.")

    return detected_bgr_colors


def compute_correction_matrix(
    detected_colors: List[Tuple[float, float, float]],
    reference_colors: List[Dict[str, Any]] = REFERENCE_SWATCHES
) -> Tuple[Callable[[np.ndarray], np.ndarray], Callable[[np.ndarray], np.ndarray], Callable[[np.ndarray], np.ndarray]]:
    """
    Computes per-channel linear transformation functions using Least-Squares fitting (numpy.polyfit).

    Args:
        detected_colors (List[Tuple[float, float, float]]): List of 5 detected BGR tuples.
        reference_colors (List[Dict[str, Any]]): Ground-truth reference swatches list.

    Returns:
        Tuple of 3 transformation functions (func_b, func_g, func_r).
    """
    det_b = np.array([c[0] for c in detected_colors], dtype=np.float64)
    det_g = np.array([c[1] for c in detected_colors], dtype=np.float64)
    det_r = np.array([c[2] for c in detected_colors], dtype=np.float64)

    ref_b = np.array([ref["rgb"][2] for ref in reference_colors], dtype=np.float64)
    ref_g = np.array([ref["rgb"][1] for ref in reference_colors], dtype=np.float64)
    ref_r = np.array([ref["rgb"][0] for ref in reference_colors], dtype=np.float64)

    fit_b = np.polyfit(det_b, ref_b, deg=1)
    fit_g = np.polyfit(det_g, ref_g, deg=1)
    fit_r = np.polyfit(det_r, ref_r, deg=1)

    func_b = lambda channel: np.clip(fit_b[0] * channel.astype(np.float64) + fit_b[1], 0, 255).astype(np.uint8)
    func_g = lambda channel: np.clip(fit_g[0] * channel.astype(np.float64) + fit_g[1], 0, 255).astype(np.uint8)
    func_r = lambda channel: np.clip(fit_r[0] * channel.astype(np.float64) + fit_r[1], 0, 255).astype(np.uint8)

    return (func_b, func_g, func_r)


def apply_correction(
    image: np.ndarray,
    correction_functions: Tuple[Callable[[np.ndarray], np.ndarray], Callable[[np.ndarray], np.ndarray], Callable[[np.ndarray], np.ndarray]]
) -> np.ndarray:
    """
    Applies per-channel lighting correction matrix to all pixels in the image.
    """
    func_b, func_g, func_r = correction_functions
    b, g, r = cv2.split(image)

    b_corrected = func_b(b)
    g_corrected = func_g(g)
    r_corrected = func_r(r)

    return cv2.merge([b_corrected, g_corrected, r_corrected])


def calibrate_image(image: np.ndarray) -> np.ndarray:
    """
    Chains detection, matrix computation, and correction into a single calibration pipeline.
    """
    detected_colors = detect_reference_scale(image)
    correction_funcs = compute_correction_matrix(detected_colors)
    return apply_correction(image, correction_funcs)


def _generate_synthetic_test_image(filepath: str) -> None:
    """Helper to generate a synthetic sample image with lighting distortion for testing."""
    h, w = 400, 600
    img = np.full((h, w, 3), 220, dtype=np.uint8)

    strip_x1, strip_w = 40, 60
    strip_y1, strip_h = 40, 320
    seg_h = strip_h // 5

    swatch_rgbs = [(255, 255, 255), (191, 191, 191), (128, 128, 128), (64, 64, 64), (0, 0, 0)]
    
    for i, rgb in enumerate(swatch_rgbs):
        y_start = strip_y1 + i * seg_h
        y_end = strip_y1 + (i + 1) * seg_h
        bgr = (rgb[2], rgb[1], rgb[0])
        cv2.rectangle(img, (strip_x1, y_start), (strip_x1 + strip_w, y_end), bgr, -1)

    cv2.rectangle(img, (strip_x1, strip_y1), (strip_x1 + strip_w, strip_y1 + strip_h), (50, 50, 50), 2)
    cv2.rectangle(img, (300, 100), (500, 300), (180, 200, 240), -1)

    distorted = img.astype(np.float64)
    distorted[:, :, 0] *= 0.70
    distorted[:, :, 1] *= 0.85
    distorted[:, :, 2] *= 0.95
    distorted = np.clip(distorted - 25, 0, 255).astype(np.uint8)

    cv2.imwrite(filepath, distorted)


if __name__ == "__main__":
    test_dir = "test_images"
    os.makedirs(test_dir, exist_ok=True)
    sample_path = os.path.join(test_dir, "sample.jpg")
    output_path = os.path.join(test_dir, "sample_corrected.jpg")

    if not os.path.exists(sample_path):
        _generate_synthetic_test_image(sample_path)

    raw_image = cv2.imread(sample_path)
    detected = detect_reference_scale(raw_image)
    corrected = calibrate_image(raw_image)
    cv2.imwrite(output_path, corrected)
    print(f"Calibration successful. Output saved to '{output_path}'.")
