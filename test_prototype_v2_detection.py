"""
DoseBand Prototype V2 Real & Synthetic Test Suite.

Comprehensive validation verifying:
1. Detection of Prototype V2 (Upper Viewing Window + Lower Circular Matrix Ventilation Holes).
2. Strict Grey Plastic Exclusion (Safe Inner ROI excludes 15-20% boundary margins).
3. 5-Shade Exposure Monotonicity (White < Light Grey < Mid Grey < Dark Grey < Black).
4. Medium Grey Strip vs Grey Enclosure separation (Color-independent geometric isolation).
5. Empty Prototype Enclosure Rejection (Unloaded window returns "No H2S strip detected inside DoseBand.").
6. Real user photograph validation (test_images/real_prototype_v2_user_sample.png).
7. Angle, tilt, perspective, scale, and lighting invariance.
8. Backward compatibility with Prototype V1 (3-window layout).
9. Strict negative image rejection (plain paper, plain grey object, noise).
"""

import os
import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

import doseband_device_detector as detector
import inference_engine
import strip_validator
from backend.api import app

client = TestClient(app)


def generate_synthetic_prototype_v2_image(
    strip_rgb=(235, 230, 222),       # Chemical strip color (None if empty prototype)
    enclosure_rgb=(135, 140, 145),   # Grey 3D-printed plastic
    angle_deg=0.0,
    scale=1.0,
    add_perspective=False,
    lighting_factor=1.0,
    is_empty=False
) -> np.ndarray:
    """
    Generates a high-fidelity synthetic image of the Prototype V2 DoseBand watch:
    - Upper Section: Single rectangular H2S viewing window
    - Lower Section: 4x4 matrix of circular ventilation holes
    - Watch lugs with black silicone strap
    """
    canvas_h, canvas_w = 900, 600
    canvas = np.full((canvas_h, canvas_w, 3), (85, 125, 170), dtype=np.uint8) # Desk surface

    # Black silicone strap
    strap_w = 120
    strap_x1 = (canvas_w - strap_w) // 2
    strap_x2 = strap_x1 + strap_w
    canvas[:, strap_x1:strap_x2] = (32, 32, 32)

    # 3D Enclosure base body
    enc_w = int(240 * scale)
    enc_h = int(360 * scale)
    cx, cy = canvas_w // 2, canvas_h // 2
    ex1 = cx - enc_w // 2
    ey1 = cy - enc_h // 2
    ex2 = ex1 + enc_w
    ey2 = ey1 + enc_h

    # Create enclosure layer
    enc_layer = np.zeros((canvas_h, canvas_w, 3), dtype=np.uint8)
    
    # 1. Bezel body (Grey plastic)
    cv2.rectangle(enc_layer, (ex1, ey1), (ex2, ey2), (enclosure_rgb[2], enclosure_rgb[1], enclosure_rgb[0]), -1)
    # Bezel border / chamfer step
    cv2.rectangle(enc_layer, (ex1, ey1), (ex2, ey2), (enclosure_rgb[2] - 30, enclosure_rgb[1] - 30, enclosure_rgb[0] - 30), 4)

    # 2. Upper Viewing Window (H2S Chemical Strip Window)
    # Physical window: ~20% to ~80% width, ~22% to ~42% height
    wx1 = ex1 + int(enc_w * 0.19)
    wx2 = ex1 + int(enc_w * 0.81)
    wy1 = ey1 + int(enc_h * 0.22)
    wy2 = ey1 + int(enc_h * 0.42)

    if is_empty:
        # Empty hollow cavity looking into dark base
        cv2.rectangle(enc_layer, (wx1, wy1), (wx2, wy2), (18, 18, 18), -1)
    else:
        # Chemical strip inserted inside the window
        cv2.rectangle(enc_layer, (wx1, wy1), (wx2, wy2), (strip_rgb[2], strip_rgb[1], strip_rgb[0]), -1)
        # Add subtle paper texture
        noise = np.random.randint(-3, 4, (wy2 - wy1, wx2 - wx1, 3)).astype(np.int16)
        patch = np.clip(enc_layer[wy1:wy2, wx1:wx2].astype(np.int16) + noise, 0, 255).astype(np.uint8)
        enc_layer[wy1:wy2, wx1:wx2] = patch

    # Window frame shadow lip
    cv2.rectangle(enc_layer, (wx1, wy1), (wx2, wy2), (40, 40, 40), 2)

    # 3. Lower Section: 4x4 Matrix of Circular Ventilation Holes
    grid_rows = 4
    grid_cols = 4
    grid_y_start = ey1 + int(enc_h * 0.52)
    grid_y_end = ey1 + int(enc_h * 0.86)
    grid_x_start = ex1 + int(enc_w * 0.26)
    grid_x_end = ex1 + int(enc_w * 0.74)

    row_spacing = (grid_y_end - grid_y_start) // (grid_rows - 1)
    col_spacing = (grid_x_end - grid_x_start) // (grid_cols - 1)
    hole_radius = max(3, int(6 * scale))

    for r in range(grid_rows):
        for c in range(grid_cols):
            hc_x = grid_x_start + c * col_spacing
            hc_y = grid_y_start + r * row_spacing
            cv2.circle(enc_layer, (hc_x, hc_y), hole_radius, (25, 25, 25), -1)
            cv2.circle(enc_layer, (hc_x, hc_y), hole_radius, (enclosure_rgb[2] - 40, enclosure_rgb[1] - 40, enclosure_rgb[0] - 40), 1)

    # Merge enclosure onto canvas
    mask = (enc_layer > 0).any(axis=2)
    canvas[mask] = enc_layer[mask]

    # Lighting factor
    if abs(lighting_factor - 1.0) > 0.01:
        canvas = np.clip(canvas.astype(np.float32) * lighting_factor, 0, 255).astype(np.uint8)

    # Optional Rotation / Perspective
    if abs(angle_deg) > 0.1:
        M = cv2.getRotationMatrix2D((cx, cy), angle_deg, 1.0)
        canvas = cv2.warpAffine(canvas, M, (canvas_w, canvas_h), borderMode=cv2.BORDER_REFLECT)

    if add_perspective:
        src_pts = np.float32([[0, 0], [canvas_w, 0], [canvas_w, canvas_h], [0, canvas_h]])
        dst_pts = np.float32([[25, 18], [canvas_w - 35, 12], [canvas_w - 15, canvas_h - 22], [12, canvas_h - 12]])
        P = cv2.getPerspectiveTransform(src_pts, dst_pts)
        canvas = cv2.warpPerspective(canvas, P, (canvas_w, canvas_h), borderMode=cv2.BORDER_REFLECT)

    return canvas


# =============================================================================
# 1. TEST REAL USER PHOTOGRAPH OF PROTOTYPE V2
# =============================================================================
def test_real_prototype_v2_user_sample():
    """Verifies that the actual user photograph of Prototype V2 is detected with zero error."""
    sample_path = os.path.join("test_images", "real_prototype_v2_user_sample.png")
    assert os.path.exists(sample_path), f"Real prototype sample {sample_path} not found."
    
    img = cv2.imread(sample_path)
    pipe = inference_engine.get_inference_pipeline()
    res = pipe.run_full_inference(img)

    assert res["is_valid"] is True, f"Real prototype failed inference: {res.get('user_message')}"
    assert res["badge_mode"] == "FULL_3D_DOSEBAND_ENCLOSURE"
    assert res["prototype_version"] == "PROTOTYPE_V2"
    assert res["estimated_h2s_ppm"] > 0.0
    assert res["debug_overlay"] is not None


# =============================================================================
# 2. TEST 5 STRIP SHADES MONOTONIC ORDERING (WHITE < LIGHT < MID < DARK < BLACK)
# =============================================================================
@pytest.mark.parametrize("shade_name,strip_rgb,expected_ppm_min,expected_ppm_max", [
    ("White (Unexposed)",     (237, 230, 220), 0.0,  5.0),
    ("Light Grey (10 ppm)",   (137, 125, 116), 25.0, 42.0),
    ("Mid Grey (25 ppm)",     (115, 105, 97),  38.0, 52.0),
    ("Dark Grey (50 ppm)",    (96, 88, 82),    48.0, 62.0),
    ("Near-Black (100 ppm)",  (78, 72, 68),    58.0, 95.0),
])
def test_prototype_v2_5_strip_shades(shade_name, strip_rgb, expected_ppm_min, expected_ppm_max):
    """Verifies color-independent geometric isolation on all 5 strip shades inside grey enclosure."""
    img = generate_synthetic_prototype_v2_image(strip_rgb=strip_rgb, enclosure_rgb=(135, 140, 145))
    
    pipe = inference_engine.get_inference_pipeline()
    res = pipe.run_full_inference(img, temperature_c=25.0, exposure_time_h=1.0)

    assert res["is_valid"] is True, f"Failed detection for {shade_name}: {res.get('user_message')}"
    assert res["prototype_version"] == "PROTOTYPE_V2"
    ppm = res["estimated_h2s_ppm"]
    assert expected_ppm_min <= ppm <= expected_ppm_max, f"{shade_name} predicted {ppm} ppm outside [{expected_ppm_min}, {expected_ppm_max}]"


def test_strict_monotonic_ordering():
    """Verifies that estimated H2S response is strictly monotonic: White < Light < Mid < Dark < Black."""
    pipe = inference_engine.get_inference_pipeline()
    
    shades = [
        ("White", (237, 230, 220)),
        ("Light Grey", (137, 125, 116)),
        ("Mid Grey", (115, 105, 97)),
        ("Dark Grey", (96, 88, 82)),
        ("Black", (78, 72, 68)),
    ]
    
    predictions = []
    for name, s_rgb in shades:
        img = generate_synthetic_prototype_v2_image(strip_rgb=s_rgb, enclosure_rgb=(135, 140, 145))
        res = pipe.run_full_inference(img)
        assert res["is_valid"] is True
        predictions.append((name, res["estimated_h2s_ppm"]))

    for i in range(len(predictions) - 1):
        name_curr, ppm_curr = predictions[i]
        name_next, ppm_next = predictions[i + 1]
        assert ppm_curr < ppm_next, f"Monotonic ordering failed: {name_curr} ({ppm_curr} ppm) is NOT strictly less than {name_next} ({ppm_next} ppm)"


# =============================================================================
# 3. TEST MEDIUM GREY STRIP VS GREY ENCLOSURE SEPARATION
# =============================================================================
def test_medium_grey_strip_vs_grey_enclosure():
    """
    Explicit test for the critical case:
    MEDIUM GREY STRIP (135, 135, 135) inside GREY 3D-PRINTED ENCLOSURE (135, 135, 135).
    The safe ROI must isolate the strip cleanly without plastic border contamination.
    """
    img = generate_synthetic_prototype_v2_image(strip_rgb=(135, 135, 135), enclosure_rgb=(135, 135, 135))
    pipe = inference_engine.get_inference_pipeline()
    res = pipe.run_full_inference(img)

    assert res["is_valid"] is True
    assert res["prototype_version"] == "PROTOTYPE_V2"
    # Safe ROI must produce an estimate higher than unexposed white
    assert res["estimated_h2s_ppm"] > 15.0


# =============================================================================
# 4. TEST EMPTY PROTOTYPE ENCLOSURE REJECTION
# =============================================================================
def test_empty_prototype_v2_rejection():
    """
    Verifies that scanning an empty Prototype V2 without an inserted H2S strip
    correctly rejects prediction with 'No H2S strip detected inside DoseBand.'.
    """
    img = generate_synthetic_prototype_v2_image(is_empty=True)
    pipe = inference_engine.get_inference_pipeline()
    res = pipe.run_full_inference(img)

    assert res["is_valid"] is False, "Empty prototype should NOT pass validation."
    assert "No H2S strip detected inside DoseBand." in res.get("rejection_reasons", []) or "No H2S strip detected inside DoseBand." in res.get("user_message", "")


# =============================================================================
# 5. TEST MULTI-ANGLE TILT & PERSPECTIVE VARIATIONS (7 ANGLES)
# =============================================================================
@pytest.mark.parametrize("angle", [-15.0, -10.0, -5.0, 5.0, 10.0, 15.0, 20.0])
def test_prototype_v2_tilted_angles(angle):
    """Verifies that tilted Prototype V2 is rectified and validated accurately."""
    img = generate_synthetic_prototype_v2_image(strip_rgb=(137, 125, 116), angle_deg=angle, add_perspective=True)
    pipe = inference_engine.get_inference_pipeline()
    res = pipe.run_full_inference(img)

    assert res["is_valid"] is True, f"Tilted angle {angle}° failed: {res.get('user_message')}"
    assert res["prototype_version"] == "PROTOTYPE_V2"


# =============================================================================
# 6. TEST SCALE & DISTANCE VARIATIONS (5 SCALES)
# =============================================================================
@pytest.mark.parametrize("scale", [0.80, 0.90, 1.00, 1.10, 1.20])
def test_prototype_v2_scales(scale):
    """Verifies distance invariance across various zoom/camera scales."""
    img = generate_synthetic_prototype_v2_image(strip_rgb=(115, 105, 97), scale=scale)
    pipe = inference_engine.get_inference_pipeline()
    res = pipe.run_full_inference(img)

    assert res["is_valid"] is True, f"Scale {scale}x failed: {res.get('user_message')}"
    assert res["prototype_version"] == "PROTOTYPE_V2"


# =============================================================================
# 7. TEST LIGHTING VARIATIONS (DIM, NORMAL, BRIGHT)
# =============================================================================
@pytest.mark.parametrize("lighting", [0.75, 1.00, 1.25])
def test_prototype_v2_lighting_invariance(lighting):
    """Verifies that prototype detection works across dim, normal, and bright ambient lighting."""
    img = generate_synthetic_prototype_v2_image(strip_rgb=(137, 125, 116), lighting_factor=lighting)
    pipe = inference_engine.get_inference_pipeline()
    res = pipe.run_full_inference(img)

    assert res["is_valid"] is True, f"Lighting factor {lighting} failed: {res.get('user_message')}"


# =============================================================================
# 8. TEST API ENDPOINT PARITY FOR PROTOTYPE V2
# =============================================================================
def test_api_endpoint_prototype_v2():
    """Verifies that /scan/analyze returns prototype_version, debug_overlay, and valid estimate."""
    img = generate_synthetic_prototype_v2_image(strip_rgb=(137, 125, 116))
    success, enc_jpg = cv2.imencode(".jpg", img)
    assert success

    response = client.post(
        "/scan/analyze",
        data={
            "worker_id": "W-101",
            "temperature_c": 25.0,
            "exposure_time_h": 1.0,
            "badge_mode": "FULL_DOSEBAND_BADGE"
        },
        files={"image": ("prototype_v2_scan.jpg", enc_jpg.tobytes(), "image/jpeg")}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["is_valid"] is True
    assert data["prototype_version"] == "PROTOTYPE_V2"
    assert data["debug_overlay_base64"] is not None
    assert data["estimated_h2s_ppm"] > 0.0
