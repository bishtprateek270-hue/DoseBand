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
    Generates a continuous, dense calibration dataset modeling Lead Acetate / Lead Sulfide (PbS)
    dosimeter paper darkening across the entire continuum of grayscale shades (white -> grey -> black),
    calibrated against ambient temperature, relative humidity, and exposure duration.
    
    Calibration Characteristics:
    - Pure / Off-White (gray 242-255): 0.00 ppm (Fresh unexposed sensor)
    - Very Light Grey (gray 210-230): ~2.0 - 5.0 ppm (Safe operational zone)
    - Light Grey (gray 180-210): ~6.0 - 14.0 ppm (Permissible limit boundary)
    - Medium Grey (gray 140-180): ~15.0 - 28.0 ppm (Caution threshold)
    - Slate / Dark Grey (gray 90-140): ~30.0 - 55.0 ppm (High caution / Warning)
    - Charcoal / Deep Black (gray 25-90): ~58.0 - 85.0 ppm (Unsafe / STEL Ceiling)
    """
    records = []
    
    # Ambient environmental grids
    temperatures = [15.0, 20.0, 25.0, 30.0, 35.0, 45.0, 60.0]
    humidities = [20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]
    exposure_times = [0.5, 1.0, 2.0, 4.0, 6.0, 8.0, 12.0, 24.0]

    # Dense sampling of 120 grayscale levels across the entire spectrum (25 to 252)
    gray_levels = np.linspace(25.0, 252.0, 120)

    # Lead acetate / Lead sulfide optical variations (neutral gray, warm cream, tan, PbS bronze, charcoal)
    optical_variations = [
        (0.0, 0.0, 0.0),       # Pure neutral grayscale
        (4.0, 2.0, -12.0),     # Natural cream / ivory unexposed cellulose paper
        (8.0, 4.0, -18.0),     # Warm cream / yellowish-tan fresh paper
        (6.0, 2.0, -8.0),      # Typical warm PbS brownish-gray tint
        (10.0, 5.0, -15.0),    # Warm tan / beige exposure
        (7.0, 2.0, -6.0),      # Dark bronze / umber tint
        (-2.0, -1.0, 2.0),     # Cool slate gray
        (1.0, 1.0, 1.0)        # Diffuse white reflection
    ]

    for g in gray_levels:
        for tint_r, tint_g, tint_b in optical_variations:
            r = float(np.clip(g + tint_r, 0.0, 255.0))
            g_c = float(np.clip(g + tint_g, 0.0, 255.0))
            b = float(np.clip(g + tint_b, 0.0, 255.0))

            # Exact HSV conversion
            val = max(r, g_c, b)
            sat = 0.0 if val == 0 else ((val - min(r, g_c, b)) / val) * 255.0
            hue = 0.0 if sat == 0 else 15.0 # Warm hue anchor

            # Continuous Staining Intensity (0.0 at pure white to 1.0 at black)
            staining = float(np.clip((242.0 - g) / 205.0, 0.0, 1.0))

            # Base concentration curve (smooth power law matching colorimetric dosimetry)
            if staining <= 0.005:
                base_ppm = 0.0
            else:
                base_ppm = 85.0 * (staining ** 1.42)

            for temp_c in temperatures:
                for rh in humidities:
                    for exp_h in exposure_times:
                        # Temperature kinetics factor (+0.3% per °C above 25°C)
                        temp_factor = 1.0 + 0.003 * (temp_c - 25.0)
                        # Humidity diffusion factor (+0.2% per %RH above 50% RH)
                        rh_factor = 1.0 + 0.002 * (rh - 50.0)
                        # Exposure time accumulation factor
                        exp_factor = (1.0 / exp_h) ** 0.12

                        if base_ppm == 0.0:
                            ppm = 0.0
                        else:
                            ppm = float(np.clip(base_ppm * temp_factor * rh_factor * exp_factor, 0.0, 120.0))

                        records.append({
                            "temperature_c": temp_c,
                            "humidity_rh": rh,
                            "exposure_time_h": exp_h,
                            "h2s_ppm": round(ppm, 3),
                            "mean_r": round(r, 2),
                            "mean_g": round(g_c, 2),
                            "mean_b": round(b, 2),
                            "gray": round(float(g), 2),
                            "hue": round(hue, 2),
                            "sat": round(sat, 2),
                            "val": round(val, 2),
                            "data_type": "CONTINUOUS_COLORIMETRIC_CALIBRATION"
                        })

    df = pd.DataFrame(records)
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    df.to_csv(output_csv, index=False)
    print(f"Generated {len(df)} continuous spectrum H2S calibration samples to: {output_csv}")
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
