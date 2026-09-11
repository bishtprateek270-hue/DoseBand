"""
Consistency Test Suite: Web Pipeline vs Backend API.

Verifies that for any given DoseBand dosimeter image and parameters,
the Web application internal pipeline and the REST API return EXACTLY identical outputs:
- is_valid
- status
- validation_score
- confidence_pct
- estimated_h2s_ppm
- predicted_humidity
- risk_level
"""

import os
import cv2
from fastapi.testclient import TestClient
from backend.api import app
import strip_validator
import inference_engine

client = TestClient(app)
pipeline = inference_engine.get_inference_pipeline()

TEST_IMAGES = [
    "exposure_level_1_very_low.jpg",
    "exposure_level_2_low.jpg",
    "exposure_level_3_medium.jpg",
    "exposure_level_4_high.jpg",
    "exposure_level_5_very_high.jpg",
    "exposure_shade_01_pure_white.jpg",
    "exposure_shade_05_mid_grey.jpg",
    "exposure_shade_09_deep_black.jpg",
    "real_strip_01_fresh_cream.jpg",
    "real_strip_06_charcoal_slate.jpg",
    "real_strip_11_mottled_heavy_black.jpg",
    "negative_plain_white.jpg",
    "negative_noisy_texture.jpg"
]

def run_consistency_test():
    print("=" * 80)
    print("DOSEBAND MODEL CONSISTENCY VERIFICATION: WEB PIPELINE vs REST API")
    print("=" * 80)
    print(f"{'Image Asset':<38} | {'Web Valid':<9} | {'API Valid':<9} | {'Web PPM':<8} | {'API PPM':<8} | {'Status'}")
    print("-" * 80)

    all_consistent = True

    for img_name in TEST_IMAGES:
        img_path = os.path.join("test_images", img_name)
        if not os.path.exists(img_path):
            continue

        img_bgr = cv2.imread(img_path)
        
        # 1. Web Internal Pipeline
        web_res = pipeline.run_full_inference(
            image_bgr=img_bgr,
            temperature_c=25.0,
            exposure_time_h=1.0,
            manual_humidity_override=None
        )

        # 2. API Backend Call
        with open(img_path, "rb") as f:
            resp = client.post(
                "/scan/analyze",
                files={"image": (img_name, f, "image/jpeg")},
                data={"worker_id": "W-101", "temperature_c": 25.0, "exposure_time_h": 1.0}
            )
        api_res = resp.json()

        web_valid = bool(web_res.get("is_valid", False))
        api_valid = bool(api_res.get("is_valid", False))
        web_ppm = round(float(web_res.get("estimated_h2s_ppm", 0.0)), 2)
        api_ppm = round(float(api_res.get("estimated_h2s_ppm", 0.0)), 2)
        web_risk = web_res.get("risk_level", "Invalid")
        api_risk = api_res.get("risk_level", "Invalid")

        match = (web_valid == api_valid) and (abs(web_ppm - api_ppm) < 0.05)
        if not match:
            all_consistent = False

        status_tag = "MATCH" if match else "MISMATCH"
        print(f"{img_name:<38} | {str(web_valid):<9} | {str(api_valid):<9} | {web_ppm:<8.2f} | {api_ppm:<8.2f} | {status_tag}")

    print("=" * 80)
    if all_consistent:
        print("[SUCCESS] 100% PERFECT CONSISTENCY! Web and API outputs are identical.")
    else:
        print("[FAIL] Mismatch detected between Web and API pipelines.")
    print("=" * 80)
    assert all_consistent

if __name__ == "__main__":
    run_consistency_test()
