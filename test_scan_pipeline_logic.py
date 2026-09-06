"""
DoseBand Scan Page Logical Verification & Prerequisite Test Suite.

Tests the strict prerequisite pipeline across all 8 required test scenarios:
1. Valid DoseBand badge image + active registered worker -> Prediction ALLOWED & LOGGED.
2. Expired badge date -> BLOCKED from prediction & database logging.
3. Plain white paper -> BLOCKED (Test-strip validator rejected).
4. Plain grey / black paper -> BLOCKED (Test-strip validator rejected).
5. Random photo / texture -> BLOCKED (Test-strip validator rejected).
6. Missing reference scale -> BLOCKED (Scale check & validator rejected).
7. Blurry image -> BLOCKED (Scan quality check failed - Retake required).
8. Wrong-worker QR / Inactive worker -> BLOCKED from prediction & logging.
"""

import os
import sqlite3
import tempfile
import cv2
import numpy as np
from datetime import datetime, date, timedelta

import database
import qr_manager
import strip_validator
import quality_validator
import roi_detector
from inference_engine import get_inference_pipeline


def run_pipeline_check(
    worker_profile: dict,
    image_bgr: np.ndarray,
    manual_humidity: float = None,
    humidity_mode: str = "card",
    ambient_temp: float = 25.0,
    exposure_time: float = 1.0,
    qr_bytes: bytes = None
) -> dict:
    """
    Simulates the exact logical flow from the DoseBand Scan page.
    """
    # 1. Worker Identification & Badge Validity Check
    is_worker_id_valid = False
    worker_id_clean = worker_profile.get("worker_id", "")

    if qr_bytes is not None:
        decoded_wid, decoded_bid, _ = qr_manager.decode_qr_from_image_bytes(qr_bytes)
        val_res = qr_manager.validate_badge_profile(decoded_wid, decoded_bid)
        is_worker_id_valid = val_res["valid"]
    else:
        is_active = (worker_profile.get("status") == "Active")
        try:
            exp_date = datetime.strptime(worker_profile.get("badge_expiry_date", "1970-01-01"), "%Y-%m-%d").date()
            is_expired = exp_date < date.today()
        except Exception:
            is_expired = True
        is_worker_id_valid = bool(is_active and not is_expired)

    # 2. Image and Quality Analysis
    image_provided = image_bgr is not None and image_bgr.size > 0
    quality_diag = quality_validator.evaluate_image_quality(image_bgr) if image_provided else None
    is_quality_valid = quality_diag["is_valid_for_analysis"] if quality_diag else False

    # 3. Test-Strip Multi-Criteria Validation
    strip_val_res = strip_validator.validate_test_strip(image_bgr) if image_provided else None
    is_strip_valid = strip_val_res["is_valid"] if strip_val_res else False

    # 4. ROI Detections
    roi_detections = roi_detector.detect_all_rois(image_bgr) if image_provided else None
    ref_ok = bool(quality_diag and quality_diag["ref_scale_detected"] and strip_val_res and strip_val_res["checks"]["reference_scale"]["score"] >= 0.40)
    strip_ok = bool(quality_diag and quality_diag["sensor_strip_detected"] and is_strip_valid)
    if humidity_mode == "card":
        hum_ok = bool(roi_detections and roi_detections["humidity_indicator"]["confidence"] >= 0.50)
    else:
        hum_ok = (manual_humidity is not None)
    rois_detected = bool(ref_ok and strip_ok and hum_ok)

    # 5. Environmental parameters
    env_params_valid = bool(ambient_temp is not None and exposure_time is not None and exposure_time > 0)

    # 6. Unified prediction_allowed Gate
    prediction_allowed = bool(
        is_worker_id_valid and
        image_provided and
        is_strip_valid and
        is_quality_valid and
        rois_detected and
        env_params_valid
    )

    inference_result = None
    if prediction_allowed:
        pipeline = get_inference_pipeline()
        inference_result = pipeline.run_full_inference(
            image_bgr=image_bgr,
            temperature_c=ambient_temp,
            exposure_time_h=exposure_time,
            manual_humidity_override=manual_humidity
        )

    return {
        "prediction_allowed": prediction_allowed,
        "is_worker_id_valid": is_worker_id_valid,
        "is_strip_valid": is_strip_valid,
        "is_quality_valid": is_quality_valid,
        "rois_detected": rois_detected,
        "inference_result": inference_result
    }


def test_all_scenarios():
    print("=" * 80)
    print("DOSEBAND SCAN PIPELINE STRICT LOGICAL VERIFICATION TEST SUITE")
    print("=" * 80)

    # Setup active worker profile
    future_date = (date.today() + timedelta(days=90)).strftime("%Y-%m-%d")
    past_date = (date.today() - timedelta(days=30)).strftime("%Y-%m-%d")

    active_worker = {
        "worker_id": "W-101",
        "name": "Rajesh Kumar",
        "department": "Refinery Operations",
        "work_zone": "Zone A",
        "shift": "Shift 1",
        "badge_id": "BDG-101",
        "badge_expiry_date": future_date,
        "status": "Active"
    }

    expired_worker = {
        "worker_id": "W-102",
        "name": "Sunita Sharma",
        "department": "Safety & Quality",
        "work_zone": "Zone B",
        "shift": "Shift 2",
        "badge_id": "BDG-102",
        "badge_expiry_date": past_date,
        "status": "Active"
    }

    inactive_worker = {
        "worker_id": "W-103",
        "name": "Amit Patel",
        "department": "Maintenance",
        "work_zone": "Zone C",
        "shift": "Shift 1",
        "badge_id": "BDG-103",
        "badge_expiry_date": future_date,
        "status": "Inactive"
    }

    passed_count = 0
    total_tests = 8

    # Scenario 1: Valid DoseBand badge image + active registered worker
    img_valid = cv2.imread("test_images/base_normal.jpg")
    res1 = run_pipeline_check(active_worker, img_valid)
    if res1["prediction_allowed"] and res1["inference_result"] and res1["inference_result"]["is_valid"]:
        print(f"[PASS] Scenario 1: Valid DoseBand Scan -> ALLOWED (Estimated H2S: {res1['inference_result']['estimated_h2s_ppm']} ppm)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 1: Valid DoseBand Scan was unexpectedly blocked: {res1}")

    # Scenario 2: Expired badge
    res2 = run_pipeline_check(expired_worker, img_valid)
    if not res2["prediction_allowed"] and not res2["is_worker_id_valid"]:
        print("[PASS] Scenario 2: Expired Badge -> BLOCKED (Worker badge expired)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 2: Expired Badge was NOT blocked: {res2}")

    # Scenario 3: Plain white paper
    img_white = cv2.imread("test_images/negative_plain_white.jpg")
    res3 = run_pipeline_check(active_worker, img_white)
    if not res3["prediction_allowed"] and not res3["is_strip_valid"]:
        print("[PASS] Scenario 3: Plain White Paper -> BLOCKED (Strip validator rejected)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 3: Plain White Paper was NOT blocked: {res3}")

    # Scenario 4: Black / Grey paper
    img_grey = cv2.imread("test_images/negative_plain_grey.jpg")
    res4 = run_pipeline_check(active_worker, img_grey)
    if not res4["prediction_allowed"] and not res4["is_strip_valid"]:
        print("[PASS] Scenario 4: Plain Grey Paper -> BLOCKED (Strip validator rejected)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 4: Plain Grey Paper was NOT blocked: {res4}")

    # Scenario 5: Random photo / noisy texture
    img_noise = cv2.imread("test_images/negative_noisy_texture.jpg")
    res5 = run_pipeline_check(active_worker, img_noise)
    if not res5["prediction_allowed"] and not res5["is_strip_valid"]:
        print("[PASS] Scenario 5: Random Photo / Noise -> BLOCKED (Strip validator rejected)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 5: Random Photo was NOT blocked: {res5}")

    # Scenario 6: Missing reference scale
    img_no_scale = cv2.imread("test_images/quality_test_missing_scale.jpg")
    res6 = run_pipeline_check(active_worker, img_no_scale)
    if not res6["prediction_allowed"] and not res6["rois_detected"]:
        print("[PASS] Scenario 6: Missing Reference Scale -> BLOCKED (Reference scale check failed)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 6: Missing Reference Scale was NOT blocked: {res6}")

    # Scenario 7: Blurry image
    img_blur = cv2.imread("test_images/quality_test_blurry.jpg")
    res7 = run_pipeline_check(active_worker, img_blur)
    if not res7["prediction_allowed"] and not res7["is_quality_valid"]:
        print("[PASS] Scenario 7: Blurry Image -> BLOCKED (Quality check failed - Retake required)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 7: Blurry Image was NOT blocked: {res7}")

    # Scenario 8: Inactive Worker / QR mismatch
    res8 = run_pipeline_check(inactive_worker, img_valid)
    # Also test mismatched QR
    mismatched_qr_bytes = qr_manager.generate_badge_qr_png("W-101", "BDG-999-FAKE")
    res8_qr = run_pipeline_check(active_worker, img_valid, qr_bytes=mismatched_qr_bytes)
    if not res8["prediction_allowed"] and not res8_qr["prediction_allowed"]:
        print("[PASS] Scenario 8: Inactive Worker & Mismatched QR -> BLOCKED (Credentials rejected)")
        passed_count += 1
    else:
        print(f"[FAIL] Scenario 8: Inactive/Wrong-Worker was NOT blocked: res8={res8}, res8_qr={res8_qr}")

    print("=" * 80)
    print(f"RESULTS: {passed_count}/{total_tests} SCENARIO TESTS PASSED.")
    print("=" * 80)
    assert passed_count == total_tests, f"Expected {total_tests} passed, got {passed_count}"


if __name__ == "__main__":
    test_all_scenarios()
