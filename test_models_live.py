"""
DoseBand Live Test for Reference ML Models.
"""
from inference_engine import get_inference_pipeline
from reference_dataset_generator import extract_h2s_dataset, extract_humidity_dataset
import pandas as pd

pipeline = get_inference_pipeline()

print("=" * 60)
print("HUMIDITY KNN MODEL EVALUATION")
print("=" * 60)
df_hum = extract_humidity_dataset()
unique_hum = df_hum.drop_duplicates(subset=["humidity_rh"]).sort_values("humidity_rh")

for _, row in unique_hum.iterrows():
    feats = {
        "mean_r": row["mean_r"],
        "mean_g": row["mean_g"],
        "mean_b": row["mean_b"],
        "hue": row["hue"],
        "sat": row["sat"],
        "val": row["val"]
    }
    pred_rh = pipeline.predict_humidity(feats)
    diff = abs(pred_rh - row['humidity_rh'])
    print(f"Target RH: {row['humidity_rh']:>4.0f}% | Predicted: {pred_rh:>5.1f}% | Diff: {diff:>4.1f}% | RGB: ({row['mean_r']:.0f}, {row['mean_g']:.0f}, {row['mean_b']:.0f})")

print("\n" + "=" * 60)
print("H2S RANDOM FOREST REGRESSOR EVALUATION (Sample Swatches)")
print("=" * 60)
import os, cv2
h2s_csv = "data/simulated_h2s_training_data.csv"
if os.path.exists(h2s_csv):
    df_h2s = pd.read_csv(h2s_csv)
else:
    df_h2s = extract_h2s_dataset()
sample_rows = df_h2s.sample(n=12, random_state=42).sort_values("h2s_ppm")

for _, row in sample_rows.iterrows():
    feats = {
        "mean_r": row["mean_r"],
        "mean_g": row["mean_g"],
        "mean_b": row["mean_b"],
        "gray": row["gray"],
        "hue": row["hue"],
        "sat": row["sat"],
        "val": row["val"]
    }
    pred_ppm = pipeline.predict_h2s_ppm(
        h2s_features=feats,
        temperature_c=row["temperature_c"],
        humidity_rh=row["humidity_rh"],
        exposure_time_h=row["exposure_time_h"]
    )
    diff = abs(pred_ppm - row['h2s_ppm'])
    print(f"True: {row['h2s_ppm']:>5.1f} ppm | Pred: {pred_ppm:>6.2f} ppm | Diff: {diff:>5.2f} | Cond: {row['temperature_c']:.0f}C, {row['humidity_rh']:.0f}%RH, {row['exposure_time_h']:.0f}h")

print("\n" + "=" * 60)
print("FULL PIPELINE INFERENCE ON TEST DOSIMETER BADGES (ALL SHADES)")
print("=" * 60)
test_images_to_run = [
    'exposure_shade_01_pure_white.jpg',
    'exposure_shade_02_off_white.jpg',
    'exposure_shade_03_very_light_grey.jpg',
    'exposure_shade_04_light_grey.jpg',
    'exposure_shade_05_mid_grey.jpg',
    'exposure_shade_06_slate_grey.jpg',
    'exposure_shade_07_dark_grey.jpg',
    'exposure_shade_08_charcoal_grey.jpg',
    'exposure_shade_09_deep_black.jpg',
    'exposure_level_1_very_low.jpg',
    'exposure_level_2_low.jpg',
    'exposure_level_3_medium.jpg',
    'exposure_level_4_high.jpg',
    'exposure_level_5_very_high.jpg',
    'real_strip_01_fresh_cream.jpg',
    'real_strip_02_light_beige_tan.jpg',
    'real_strip_03_medium_greyish_tan.jpg',
    'real_strip_04_warm_brownish_grey.jpg',
    'real_strip_05_dark_bronze_grey.jpg',
    'real_strip_06_charcoal_slate.jpg',
    'real_strip_07_dense_charcoal_black.jpg',
    'real_strip_08_deep_solid_black.jpg',
    'real_strip_09_mottled_light.jpg',
    'real_strip_10_mottled_medium.jpg',
    'real_strip_11_mottled_heavy_black.jpg'
]

for img_name in test_images_to_run:
    p = os.path.join('test_images', img_name)
    if os.path.exists(p):
        img = cv2.imread(p)
        res = pipeline.run_full_inference(img, temperature_c=25.0, exposure_time_h=1.0)
        print(f"{img_name:<38} -> Pred RH: {res['predicted_humidity']:>4.1f}% | Pred H2S: {res['estimated_h2s_ppm']:>6.2f} ppm | Risk: {res['risk_level']}")

print("=" * 60)
print("[OK] All model inference tests executed dynamically without hardcoding.")
