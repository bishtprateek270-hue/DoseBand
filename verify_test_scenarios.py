"""
Verification script for DoseBand Test-Strip Validation Score.
Evaluates the 5 requested scenarios to confirm distinct, dynamic scoring.
"""

import os
import cv2
from strip_validator import validate_test_strip

test_scenarios = [
    ("exposure_level_1_very_low.jpg", "1. Valid DoseBand (0 ppm)"),
    ("exposure_level_4_high.jpg",     "2. Another Valid DoseBand (50 ppm)"),
    ("negative_isolated_h2s_crop.jpg","3. Cropped H2S Strip Only"),
    ("negative_plain_white.jpg",      "4. White Paper"),
    ("negative_noisy_texture.jpg",     "5. Random Photo / Scene Noise")
]

print("=" * 80)
print("DOSEBAND VALIDATION SCORE DYNAMIC RECALCULATION VERIFICATION")
print("=" * 80)

scores = []
for fname, desc in test_scenarios:
    p = os.path.join("test_images", fname)
    img = cv2.imread(p)
    res = validate_test_strip(img)
    pct = res["confidence_pct"]
    status = res["status"]
    scores.append((desc, pct, status))
    
    print(f"\n{desc}")
    print(f"  -> Total Weighted Confidence Score : {pct}% ({status})")
    print(f"  -> Breakdown (6-Criteria):")
    for key, val in res["breakdown"].items():
        print(f"     • {val['name']:<28} ({val['weight_pct']}% wt): {val['score_pct']:>5.1f}% (+{val['weighted_points']:.1f} pts)")

print("\n" + "=" * 80)
print("SCORE SUMMARY:")
for desc, pct, st in scores:
    print(f"  {desc:<36} -> {pct}% [{st}]")

unique_scores = set(s[1] for s in scores)
print(f"\nDistinct Score Values: {len(unique_scores)} out of {len(scores)} scenarios.")
if len(unique_scores) == len(scores):
    print("[SUCCESS] Every scenario produced a unique, differentiated confidence score!")
print("=" * 80)
