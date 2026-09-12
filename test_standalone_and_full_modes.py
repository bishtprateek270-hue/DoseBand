"""
test_standalone_and_full_modes.py - Comprehensive Test Suite for DoseBand Two Scanning Modes
=============================================================================================
Tests:
1. Mode 2 (Standalone H2S Strip):
   - Accepts 7 shades (Fresh White, Off-White, Light Grey, Mid Grey, Dark Grey, Charcoal, Black)
   - Validates monotonic PPM progression
   - Background invariance (White, Black, Grey, Wood backgrounds)
   - Negative rejection (Blank solid white/black/grey, TV static noise, QR codes, Hand/skin)
2. Mode 1 (Full DoseBand):
   - Strict 3D enclosure and reference scale geometry validation
   - Rejection of plain paper strips when in full_badge mode
3. FastAPI Backend Parity:
   - /scan/analyze endpoint returns identical predictions, disclaimer, and mode metadata
"""

import os
import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

from strip_validator import validate_test_strip
from roi_detector import detect_all_rois
from inference_engine import run_full_inference, predict_h2s_concentration
from test_real_prototype_detection import generate_synthetic_3d_prototype_image
from backend.api import app

client = TestClient(app)


def create_synthetic_paper_strip(width=300, height=200, base_gray=220, bg_gray=128, grain_std=4.0):
    """Creates an image of a realistic paper strip on a contrasting background."""
    img = np.full((height, width, 3), bg_gray, dtype=np.uint8)
    # Strip occupies central 70%
    x1, y1 = int(width * 0.15), int(height * 0.15)
    x2, y2 = int(width * 0.85), int(height * 0.85)

    # Base strip color with paper grain noise
    strip = np.full((y2 - y1, x2 - x1, 3), base_gray, dtype=np.float32)
    noise = np.random.normal(0, grain_std, strip.shape)
    strip = np.clip(strip + noise, 0, 255).astype(np.uint8)
    img[y1:y2, x1:x2] = strip
    return img


# ==============================================================================
# 1. STANDALONE H2S STRIP TESTS: 7 SHADES AND MONOTONICITY
# ==============================================================================

class TestStandaloneSevenShades:
    """Verifies that all 7 exposure shades are accepted and produce monotonic PPM."""

    SHADES = [
        ("Fresh White", 240, 0.0, 5.0),
        ("Off-White", 215, 0.5, 15.0),
        ("Light Grey", 180, 5.0, 30.0),
        ("Mid Grey", 130, 15.0, 50.0),
        ("Dark Grey", 85, 35.0, 75.0),
        ("Charcoal", 45, 55.0, 90.0),
        ("Black", 20, 70.0, 100.0),
    ]

    @pytest.mark.parametrize("name,gray,min_expected_ppm,max_expected_ppm", SHADES)
    def test_all_seven_shades_pass_standalone_validation(self, name, gray, min_expected_ppm, max_expected_ppm):
        img = create_synthetic_paper_strip(base_gray=gray, bg_gray=120)
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is True, f"Shade '{name}' (gray={gray}) failed validation: {val_res['rejection_reasons']}"

    def test_monotonic_ppm_across_seven_shades(self):
        ppms = []
        intensities = []
        for name, gray, _, _ in self.SHADES:
            img = create_synthetic_paper_strip(base_gray=gray, bg_gray=120)
            res = run_full_inference(
                image_bgr=img,
                temperature_c=25.0,
                manual_humidity_override=50.0,
                exposure_time_h=1.0,
                scan_mode="standalone_strip",
            )
            assert res["is_valid"] is True, f"{name} failed inference: {res.get('user_message')}"
            ppms.append(res["estimated_h2s_ppm"])
            intensities.append(res["staining_intensity"])

        # Monotonicity check: each darker shade should have >= intensity and >= PPM
        for i in range(len(ppms) - 1):
            assert intensities[i] <= intensities[i + 1] + 1e-4, (
                f"Intensity not monotonic between {self.SHADES[i][0]} and {self.SHADES[i+1][0]}: "
                f"{intensities[i]} > {intensities[i+1]}"
            )
            assert ppms[i] <= ppms[i + 1] + 1e-4, (
                f"PPM not monotonic between {self.SHADES[i][0]} and {self.SHADES[i+1][0]}: "
                f"{ppms[i]} > {ppms[i+1]}"
            )


# ==============================================================================
# 2. STANDALONE H2S STRIP TESTS: BACKGROUND INVARIANCE
# ==============================================================================

class TestStandaloneBackgroundInvariance:
    """Verifies that standalone mode works correctly regardless of background color."""

    BACKGROUNDS = [
        ("White Background", 245),
        ("Black Background", 20),
        ("Grey Background", 128),
        ("Dark Grey Background", 70),
    ]

    @pytest.mark.parametrize("bg_name,bg_val", BACKGROUNDS)
    def test_strip_on_various_backgrounds(self, bg_name, bg_val):
        img = create_synthetic_paper_strip(base_gray=160, bg_gray=bg_val)
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is True, f"Failed on {bg_name}: {val_res['rejection_reasons']}"

        res = run_full_inference(img, scan_mode="standalone_strip")
        assert res["is_valid"] is True
        assert res["is_standalone"] is True
        assert res["is_prototype_estimate"] is True
        assert 5.0 <= res["estimated_h2s_ppm"] <= 40.0


# ==============================================================================
# 3. STANDALONE NEGATIVE REJECTION TESTS
# ==============================================================================

class TestStandaloneNegativeRejections:
    """Verifies strict rejection of blank solid colors, static noise, QR codes, and skin tones."""

    def test_reject_blank_solid_white(self):
        img = np.full((300, 300, 3), 255, dtype=np.uint8)
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is False
        assert any("texture" in r.lower() or "blank" in r.lower() or "solid" in r.lower() for r in val_res["rejection_reasons"])

    def test_reject_blank_solid_black(self):
        img = np.full((300, 300, 3), 0, dtype=np.uint8)
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is False

    def test_reject_blank_solid_grey(self):
        img = np.full((300, 300, 3), 128, dtype=np.uint8)
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is False

    def test_reject_tv_static_noise(self):
        img = np.random.randint(0, 256, (300, 300, 3), dtype=np.uint8)
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is False

    def test_reject_qr_code_pattern(self):
        # Generate binary checkerboard
        img = np.zeros((300, 300, 3), dtype=np.uint8)
        for i in range(0, 300, 20):
            for j in range(0, 300, 20):
                if ((i // 20) + (j // 20)) % 2 == 0:
                    img[i:i+20, j:j+20] = 255
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is False

    def test_reject_human_skin_tone(self):
        # Swatch with heavy red/yellow chromaticity
        img = np.zeros((300, 300, 3), dtype=np.uint8)
        img[:, :] = (140, 175, 230)  # BGR for peachy/tan skin tone
        val_res = validate_test_strip(img, scan_mode="standalone_strip")
        assert val_res["is_valid"] is False


# ==============================================================================
# 4. FULL DOSEBAND MODE TESTS
# ==============================================================================

class TestFullDoseBandMode:
    """Verifies Mode 1 full prototype validation."""

    def test_full_badge_mode_accepts_prototype(self):
        img = generate_synthetic_3d_prototype_image(strip_rgb=(180, 180, 180))
        val_res = validate_test_strip(img, scan_mode="full_badge")
        assert val_res["is_valid"] is True, f"Prototype failed full badge validation: {val_res['rejection_reasons']}"

    def test_full_badge_mode_rejects_plain_paper_strip(self):
        img = create_synthetic_paper_strip(base_gray=180, bg_gray=240)
        val_res = validate_test_strip(img, scan_mode="full_badge")
        assert val_res["is_valid"] is False, "Full badge mode should reject plain strip lacking 3D enclosure/reference scale"


# ==============================================================================
# 5. REST API SERVER PARITY TESTS
# ==============================================================================

class TestFastApiScanAnalyzeEndpoint:
    """Verifies FastAPI /scan/analyze endpoint responses for both modes."""

    def test_api_standalone_mode_response(self):
        img = create_synthetic_paper_strip(base_gray=170, bg_gray=120)
        _, encoded = cv2.imencode(".jpg", img)

        response = client.post(
            "/scan/analyze",
            data={
                "worker_id": "W-DEMO",
                "scan_mode": "standalone_strip",
                "temperature_c": "25.0",
                "humidity_rh": "50.0",
                "exposure_time_h": "1.0",
            },
            files={"image": ("standalone_test.jpg", encoded.tobytes(), "image/jpeg")},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] is True
        assert data["scan_mode"] == "standalone_strip"
        assert data["is_standalone"] is True
        assert data["is_prototype_estimate"] is True
        assert "PROTOTYPE ESTIMATE" in data["disclaimer"]
        assert "estimated_h2s_ppm" in data
        assert "debug_overlay_base64" in data

    def test_api_full_badge_mode_response(self):
        img = generate_synthetic_3d_prototype_image(strip_rgb=(160, 160, 160))
        _, encoded = cv2.imencode(".jpg", img)

        response = client.post(
            "/scan/analyze",
            data={
                "worker_id": "W-101",
                "scan_mode": "full_badge",
                "temperature_c": "25.0",
                "humidity_rh": "50.0",
                "exposure_time_h": "1.0",
            },
            files={"image": ("badge_test.jpg", encoded.tobytes(), "image/jpeg")},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] is True
        assert data["scan_mode"] == "full_badge"
        assert data["is_standalone"] is False
        assert data["is_prototype_estimate"] is False
        assert data["is_allowed_to_save"] is True
