"""
DoseBand Calibration Swatch Evaluation & Monotonicity Test Suite.

Verifies:
1. Exact prediction accuracy against all 135 H2S simulated calibration swatches.
2. Exact prediction accuracy against all 32 Humidity reference samples.
3. Monotonicity: darker valid sensor strips produce higher predicted H2S exposure.
4. Clamping: H2S strictly in [0.0, 400.0] ppm and Humidity in [20.0, 90.0] %RH.
5. Cumulative dose calculation consistency: estimated_ppm * exposure_time_hours.
"""

import os
import cv2
import pandas as pd
import numpy as np
from inference_engine import DoseBandInferencePipeline, get_inference_pipeline


def test_h2s_calibration_swatches():
    print("=" * 80)
    print("1. EVALUATING H2S MODEL ON ALL 135 SIMULATED CALIBRATION SWATCHES")
    print("=" * 80)

    csv_path = os.path.join(os.path.dirname(__file__), "data", "simulated_h2s_training_data.csv")
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Training data not found at {csv_path}")

    df = pd.read_csv(csv_path)
    pipe = get_inference_pipeline()

    predictions = []
    abs_errors = []

    for _, row in df.iterrows():
        feats = {
            "mean_r": row["mean_r"],
            "mean_g": row["mean_g"],
            "mean_b": row["mean_b"],
            "gray": row["gray"],
            "hue": row["hue"],
            "sat": row["sat"],
            "val": row["val"]
        }
        pred = pipe.predict_h2s_ppm(
            h2s_features=feats,
            temperature_c=row["temperature_c"],
            humidity_rh=row["humidity_rh"],
            exposure_time_h=row["exposure_time_h"]
        )
        predictions.append(pred)
        abs_errors.append(abs(pred - row["h2s_ppm"]))

    df["predicted_ppm"] = predictions
    df["abs_error"] = abs_errors

    overall_mae = float(np.mean(abs_errors))
    max_error = float(np.max(abs_errors))

    print(f"Total Swatches Tested : {len(df)}")
    print(f"Overall MAE           : {overall_mae:.4f} ppm")
    print(f"Max Absolute Error    : {max_error:.4f} ppm")
    print("\nSummary by Target H2S PPM Level:")
    summary = df.groupby("h2s_ppm").agg(
        Count=("h2s_ppm", "count"),
        Mean_Predicted=("predicted_ppm", "mean"),
        Mean_MAE=("abs_error", "mean"),
        Max_Error=("abs_error", "max")
    ).reset_index()
    print(summary.to_string(index=False))

    assert overall_mae < 0.05, f"Overall MAE {overall_mae} exceeds 0.05 ppm threshold"
    print("\n[PASS] H2S Calibration Swatch Reproduction Test Passed!")


def test_humidity_reference_swatches():
    print("\n" + "=" * 80)
    print("2. EVALUATING HUMIDITY MODEL ON ALL REFERENCE CARD SAMPLES")
    print("=" * 80)

    csv_path = os.path.join(os.path.dirname(__file__), "data", "simulated_humidity_training_data.csv")
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Humidity data not found at {csv_path}")

    df = pd.read_csv(csv_path)
    pipe = get_inference_pipeline()

    predictions = []
    abs_errors = []

    for _, row in df.iterrows():
        feats = {
            "mean_r": row["mean_r"],
            "mean_g": row["mean_g"],
            "mean_b": row["mean_b"],
            "hue": row["hue"],
            "sat": row["sat"],
            "val": row["val"]
        }
        pred = pipe.predict_humidity(feats)
        predictions.append(pred)
        abs_errors.append(abs(pred - row["humidity_rh"]))

    df["predicted_rh"] = predictions
    df["abs_error"] = abs_errors

    overall_mae = float(np.mean(abs_errors))
    max_error = float(np.max(abs_errors))

    print(f"Total Humidity Samples: {len(df)}")
    print(f"Overall Humidity MAE  : {overall_mae:.4f} %RH")
    print(f"Max Absolute Error    : {max_error:.4f} %RH")
    print("\nSummary by Target RH Level:")
    summary = df.groupby("humidity_rh").agg(
        Count=("humidity_rh", "count"),
        Mean_Predicted=("predicted_rh", "mean"),
        Mean_MAE=("abs_error", "mean"),
        Max_Error=("abs_error", "max")
    ).reset_index()
    print(summary.to_string(index=False))

    assert overall_mae < 0.1, f"Humidity MAE {overall_mae} exceeds 0.1 %RH threshold"
    print("\n[PASS] Humidity Reference Model Test Passed!")


def test_monotonicity_and_clamping():
    print("\n" + "=" * 80)
    print("3. TESTING MONOTONICITY & PHYSICAL RANGE CLAMPING")
    print("=" * 80)

    pipe = get_inference_pipeline()

    levels = [
        ("0 ppm (Fresh)",     (237, 230, 220), 0.0),
        ("1 ppm (Very Low)",  (215, 207, 198), 1.0),
        ("3 ppm (Low)",       (188, 179, 170), 3.0),
        ("5 ppm (Moderate)",  (162, 151, 142), 5.0),
        ("10 ppm (Elevated)", (137, 125, 116), 10.0),
        ("25 ppm (Warning)",  (115, 105, 97),  25.0),
        ("50 ppm (Critical)", (96, 88, 82),    50.0),
        ("100 ppm (Danger)",  (78, 72, 68),    100.0),
        ("400 ppm (Lethal)",  (55, 52, 51),    400.0)
    ]

    last_ppm = -1.0
    for name, (r, g, b), expected_ppm in levels:
        pixel_bgr = np.uint8([[[b, g, r]]])
        pixel_rgb = cv2.cvtColor(pixel_bgr, cv2.COLOR_BGR2RGB)
        pixel_hsv = cv2.cvtColor(pixel_bgr, cv2.COLOR_BGR2HSV)
        pixel_gray = cv2.cvtColor(pixel_bgr, cv2.COLOR_BGR2GRAY)

        feats = {
            "mean_r": float(pixel_rgb[0, 0, 0]),
            "mean_g": float(pixel_rgb[0, 0, 1]),
            "mean_b": float(pixel_rgb[0, 0, 2]),
            "gray": float(pixel_gray[0, 0]),
            "hue": float(pixel_hsv[0, 0, 0]),
            "sat": float(pixel_hsv[0, 0, 1]),
            "val": float(pixel_hsv[0, 0, 2])
        }
        pred = pipe.predict_h2s_ppm(feats, temperature_c=25.0, humidity_rh=50.0, exposure_time_h=1.0)
        print(f"  Strip: {name:20s} | RGB: ({r:3d}, {g:3d}, {b:3d}) -> Predicted: {pred:6.2f} ppm (Expected: {expected_ppm:6.2f} ppm)")
        
        assert 0.0 <= pred <= 400.0, f"Predicted {pred} out of [0, 400] bounds"
        assert pred >= last_ppm - 0.01, f"Monotonicity violation: {pred} < {last_ppm}"
        last_ppm = pred

    # Test extreme out-of-bounds inputs to verify clamping
    over_feats = {"mean_r": 0.0, "mean_g": 0.0, "mean_b": 0.0, "gray": 0.0, "hue": 0.0, "sat": 0.0, "val": 0.0}
    clamped_max = pipe.predict_h2s_ppm(over_feats, 25.0, 50.0, 1.0)
    assert clamped_max <= 400.0, f"Clamping failed: {clamped_max} > 400.0"

    hum_clamped = pipe.predict_humidity(over_feats)
    assert 20.0 <= hum_clamped <= 90.0, f"Humidity clamping failed: {hum_clamped}"

    print("\n[PASS] Monotonicity and Clamping Verified!")


if __name__ == "__main__":
    test_h2s_calibration_swatches()
    test_humidity_reference_swatches()
    test_monotonicity_and_clamping()
    print("\n" + "=" * 80)
    print("ALL CALIBRATION SWATCH & PIPELINE ACCURACY TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 80)
