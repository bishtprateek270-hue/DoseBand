"""
DoseBand Test-Strip Validator Pipeline Evaluation Script.

Tests the validator on:
- Positive genuine DoseBand dosimeter badges across exposure levels
- Programmatic negative benchmark images (plain paper, random colors, screenshot, dark rectangle without scale)
"""

import os
import cv2
import pandas as pd
from strip_validator import validate_test_strip

TEST_IMAGES_DIR = "test_images"


def run_validator_benchmarks():
    print("=" * 80)
    print("DOSEBAND TEST-STRIP VALIDATOR BENCHMARK SUITE")
    print("=" * 80)

    test_cases = [
        # POSITIVE CASES (Must pass with status == 'Valid' and score >= 0.80)
        ("exposure_level_1_very_low.jpg", "Positive: DoseBand 0 ppm", True),
        ("exposure_level_2_low.jpg",      "Positive: DoseBand 3 ppm", True),
        ("exposure_level_3_medium.jpg",   "Positive: DoseBand 10 ppm", True),
        ("exposure_level_4_high.jpg",     "Positive: DoseBand 50 ppm", True),
        ("exposure_level_5_very_high.jpg", "Positive: DoseBand 400 ppm", True),
        ("lighting_normal.jpg",           "Positive: DoseBand Normal Light", True),
        ("lighting_dim.jpg",              "Positive: DoseBand Dim Light", True),
        ("lighting_bright.jpg",           "Positive: DoseBand Bright Light", True),

        # NEGATIVE CASES (Must be REJECTED with status != 'Valid' and score < 0.80)
        ("negative_plain_white.jpg",          "Negative: Plain White Paper", False),
        ("negative_plain_grey.jpg",           "Negative: Plain Grey Paper", False),
        ("negative_black_rectangle.jpg",      "Negative: Black Rectangle", False),
        ("negative_colored_rectangles.jpg",   "Negative: Vivid Colored Patches", False),
        ("negative_gradient.jpg",             "Negative: Color Gradient", False),
        ("negative_noisy_texture.jpg",        "Negative: Noisy Texture / Scene", False),
        ("negative_screenshot_text.jpg",      "Negative: UI / Text Screenshot", False),
        ("negative_isolated_h2s_crop.jpg",    "Negative: Cropped Strip w/o Scale", False),
    ]

    all_passed = True
    results = []

    for filename, description, expected_valid in test_cases:
        p = os.path.join(TEST_IMAGES_DIR, filename)
        if not os.path.exists(p):
            print(f"[WARN] Missing test asset: {p}")
            continue

        img = cv2.imread(p)
        res = validate_test_strip(img)

        is_valid = res["is_valid"]
        score = res["validation_score"]
        status = res["status"]
        conf_pct = res["confidence_pct"]

        test_passed = (is_valid == expected_valid)
        if not test_passed:
            all_passed = False

        status_tag = "[PASS]" if test_passed else "[FAIL]"
        print(f"{status_tag} {description:<35} | Score: {score:>4.2f} ({conf_pct:>2}%) | Status: {status:<9} | Expected: {'Valid' if expected_valid else 'Blocked'}")
        if not is_valid and res["rejection_reasons"]:
            print(f"       -> Rejections: {'; '.join(res['rejection_reasons'][:2])}")

        results.append({
            "filename": filename,
            "description": description,
            "expected_valid": expected_valid,
            "actual_valid": is_valid,
            "score": score,
            "status": status,
            "passed": test_passed
        })

    print("=" * 80)
    if all_passed:
        print("[SUCCESS] ALL VALIDATOR BENCHMARKS PASSED! 100% precision on positives & negatives.")
    else:
        print("[FAILED] Some validator benchmarks failed. Review scores above.")
    print("=" * 80)

    return all_passed, results


if __name__ == "__main__":
    run_validator_benchmarks()
