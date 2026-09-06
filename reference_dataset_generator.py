"""
DoseBand Reference Dataset Generator.

Extracts simulated training data from the reference calibration chart images:
1. H2S calibration chart (15 rows x 9 columns = 135 swatches)
2. Humidity indicator card (8 RH levels)

IMPORTANT:
This dataset is extracted from simulated reference images for hackathon prototype/demo
purposes only, not validated real-world occupational safety calibration.
"""

import os
import io
from typing import Dict, List, Tuple, Any
import cv2
import numpy as np
import pandas as pd

# Paths
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
REF_IMG_DIR = os.path.join(DATA_DIR, "reference_images")

H2S_IMG_PATH = os.path.join(REF_IMG_DIR, "h2s_reference_raw.jpg")
HUMIDITY_IMG_PATH = os.path.join(REF_IMG_DIR, "humidity_reference_raw.png")

H2S_CSV_PATH = os.path.join(DATA_DIR, "simulated_h2s_training_data.csv")
HUMIDITY_CSV_PATH = os.path.join(DATA_DIR, "simulated_humidity_training_data.csv")


def extract_h2s_dataset(
    img_path: str = H2S_IMG_PATH,
    output_csv: str = H2S_CSV_PATH
) -> pd.DataFrame:
    """
    Extracts all 135 swatches from the H2S calibration chart image.
    
    Chart Layout:
    - 15 Rows with specific (Temperature, Humidity, Exposure Time)
    - 9 Columns with H2S Concentration: [0, 1, 3, 5, 10, 25, 50, 100, 400] ppm
    """
    if not os.path.exists(img_path):
        raise FileNotFoundError(f"H2S reference image not found at: {img_path}")

    img = cv2.imread(img_path)
    if img is None:
        raise ValueError(f"Could not read image from: {img_path}")

    # Row metadata definition for the 15 table rows
    row_metadata = [
        # (Temp °C, Humidity %RH, Exposure Time h)
        (25.0, 20.0, 1.0),
        (25.0, 50.0, 1.0),
        (25.0, 90.0, 1.0),
        (45.0, 20.0, 1.0),
        (45.0, 50.0, 1.0),
        (45.0, 90.0, 1.0),
        (60.0, 20.0, 1.0),
        (60.0, 50.0, 1.0),
        (60.0, 90.0, 1.0),
        (25.0, 50.0, 6.0),
        (45.0, 50.0, 6.0),
        (60.0, 50.0, 6.0),
        (25.0, 50.0, 24.0),
        (45.0, 50.0, 24.0),
        (60.0, 50.0, 24.0),
    ]

    # Column ppm values
    h2s_ppm_levels = [0.0, 1.0, 3.0, 5.0, 10.0, 25.0, 50.0, 100.0, 400.0]

    # Exact pixel bounds for rows in 1024x682 image
    row_y_ranges = [
        (148, 165),
        (171, 188),
        (193, 211),
        (216, 233),
        (240, 257),
        (263, 280),
        (286, 303),
        (309, 326),
        (332, 350),
        (356, 374),
        (380, 398),
        (405, 423),
        (429, 447),
        (453, 471),
        (477, 494)
    ]

    # Exact pixel bounds for columns
    col_x_ranges = [
        (265, 340),
        (346, 420),
        (427, 501),
        (508, 582),
        (589, 663),
        (670, 745),
        (751, 826),
        (832, 907),
        (913, 988)
    ]

    records = []
    
    for r_idx, (y1, y2) in enumerate(row_y_ranges):
        temp_c, rh, exp_h = row_metadata[r_idx]
        
        for c_idx, (x1, x2) in enumerate(col_x_ranges):
            ppm = h2s_ppm_levels[c_idx]
            
            # Central sub-crop to exclude borders and cell dividers
            # Inset 5px on X, 2px on Y
            swatch_bgr = img[y1 + 2 : y2 - 2, x1 + 5 : x2 - 5]
            
            if swatch_bgr.size == 0:
                continue

            # Color conversions
            swatch_rgb = cv2.cvtColor(swatch_bgr, cv2.COLOR_BGR2RGB)
            swatch_hsv = cv2.cvtColor(swatch_bgr, cv2.COLOR_BGR2HSV)
            swatch_gray = cv2.cvtColor(swatch_bgr, cv2.COLOR_BGR2GRAY)

            # Mean features
            mean_r = float(np.mean(swatch_rgb[:, :, 0]))
            mean_g = float(np.mean(swatch_rgb[:, :, 1]))
            mean_b = float(np.mean(swatch_rgb[:, :, 2]))
            
            gray_val = float(np.mean(swatch_gray))
            
            hue_val = float(np.mean(swatch_hsv[:, :, 0]))
            sat_val = float(np.mean(swatch_hsv[:, :, 1]))
            val_val = float(np.mean(swatch_hsv[:, :, 2]))

            records.append({
                "temperature_c": temp_c,
                "humidity_rh": rh,
                "exposure_time_h": exp_h,
                "h2s_ppm": ppm,
                "mean_r": round(mean_r, 3),
                "mean_g": round(mean_g, 3),
                "mean_b": round(mean_b, 3),
                "gray": round(gray_val, 3),
                "hue": round(hue_val, 3),
                "sat": round(sat_val, 3),
                "val": round(val_val, 3),
                "data_type": "SIMULATED_FROM_REFERENCE_IMAGE"
            })

    df = pd.DataFrame(records)
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    df.to_csv(output_csv, index=False)
    print(f"Extracted {len(df)} H2S training samples to: {output_csv}")
    return df


def extract_humidity_dataset(
    img_path: str = HUMIDITY_IMG_PATH,
    output_csv: str = HUMIDITY_CSV_PATH
) -> pd.DataFrame:
    """
    Extracts circular indicator patches from the humidity reference card image.
    
    Excludes the black circular border and white background by sampling
    within the central region of each circle (radius ~22px from circle center).
    """
    if not os.path.exists(img_path):
        raise FileNotFoundError(f"Humidity reference image not found at: {img_path}")

    img = cv2.imread(img_path)
    if img is None:
        raise ValueError(f"Could not read image from: {img_path}")

    # Center coordinates (cx, cy) and corresponding RH %
    indicator_cards = [
        (64, 242, 20.0),
        (192, 242, 30.0),
        (318, 242, 40.0),
        (446, 242, 50.0),
        (570, 242, 60.0),
        (700, 242, 70.0),
        (830, 241, 80.0),
        (956, 242, 90.0)
    ]

    records = []
    
    # Circle mask sampling radius (safely inside outer radius 39px)
    sample_radius = 22

    for cx, cy, rh in indicator_cards:
        # Create circular mask centered at (cx, cy)
        y_min, y_max = cy - sample_radius, cy + sample_radius
        x_min, x_max = cx - sample_radius, cx + sample_radius
        
        crop_bgr = img[y_min:y_max, x_min:x_max]
        
        # Circular mask inside the bounding box
        ch, cw = crop_bgr.shape[:2]
        yy, xx = np.ogrid[:ch, :cw]
        dist_from_center = np.sqrt((xx - cw/2)**2 + (yy - ch/2)**2)
        circle_mask = dist_from_center <= (sample_radius - 2)

        crop_rgb = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2RGB)
        crop_hsv = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2HSV)

        # Extract central pixels
        r_pixels = crop_rgb[:, :, 0][circle_mask]
        g_pixels = crop_rgb[:, :, 1][circle_mask]
        b_pixels = crop_rgb[:, :, 2][circle_mask]
        
        h_pixels = crop_hsv[:, :, 0][circle_mask]
        s_pixels = crop_hsv[:, :, 1][circle_mask]
        v_pixels = crop_hsv[:, :, 2][circle_mask]

        # Primary anchor point
        mean_r = float(np.mean(r_pixels))
        mean_g = float(np.mean(g_pixels))
        mean_b = float(np.mean(b_pixels))
        hue = float(np.mean(h_pixels))
        sat = float(np.mean(s_pixels))
        val = float(np.mean(v_pixels))

        records.append({
            "mean_r": round(mean_r, 3),
            "mean_g": round(mean_g, 3),
            "mean_b": round(mean_b, 3),
            "hue": round(hue, 3),
            "sat": round(sat, 3),
            "val": round(val, 3),
            "humidity_rh": rh
        })

        # Multi-sample sub-regions within center for robust KNN training
        for sub_r in [12, 16, 20]:
            sub_mask = dist_from_center <= sub_r
            records.append({
                "mean_r": round(float(np.mean(crop_rgb[:, :, 0][sub_mask])), 3),
                "mean_g": round(float(np.mean(crop_rgb[:, :, 1][sub_mask])), 3),
                "mean_b": round(float(np.mean(crop_rgb[:, :, 2][sub_mask])), 3),
                "hue": round(float(np.mean(crop_hsv[:, :, 0][sub_mask])), 3),
                "sat": round(float(np.mean(crop_hsv[:, :, 1][sub_mask])), 3),
                "val": round(float(np.mean(crop_hsv[:, :, 2][sub_mask])), 3),
                "humidity_rh": rh
            })

    df = pd.DataFrame(records)
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    df.to_csv(output_csv, index=False)
    print(f"Extracted {len(df)} Humidity training samples to: {output_csv}")
    return df


if __name__ == "__main__":
    print("Extracting datasets from simulated reference images...")
    df_h2s = extract_h2s_dataset()
    print(f"\nH2S Dataset Shape: {df_h2s.shape}")
    print("\nH2S Dataset Summary by PPM:")
    print(df_h2s.groupby("h2s_ppm")[["mean_r", "mean_g", "mean_b", "val"]].mean())

    print("\n" + "="*50 + "\n")

    df_humidity = extract_humidity_dataset()
    print(f"Humidity Dataset Shape: {df_humidity.shape}")
    print("Humidity Dataset Unique RH Levels and Colors:")
    unique_rh = df_humidity.drop_duplicates(subset=["humidity_rh"])
    print(unique_rh[["humidity_rh", "mean_r", "mean_g", "mean_b", "hue", "sat", "val"]])
