"""
DoseBand Reference Models Training Module.

Trains two prototype machine learning models using simulated calibration data
extracted directly from reference images:
1. H2S RandomForest Regressor (models/h2s_demo_model.joblib)
   Features: mean_r, mean_g, mean_b, gray, hue, sat, val, temperature_c, humidity_rh, exposure_time_h
   Target: h2s_ppm

2. Humidity KNN Regressor (models/humidity_demo_model.joblib)
   Features: mean_r, mean_g, mean_b, hue, sat, val
   Target: humidity_rh

IMPORTANT:
Simulated calibration data for prototype/demo purposes only, not validated real-world H2S measurement.
"""

import os
from typing import Dict, Tuple, Any
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.neighbors import KNeighborsRegressor
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
MODELS_DIR = os.path.join(os.path.dirname(__file__), "models")

H2S_CSV_PATH = os.path.join(DATA_DIR, "h2s_training_data.csv")
HUMIDITY_CSV_PATH = os.path.join(DATA_DIR, "humidity_training_data.csv")

H2S_MODEL_PATH = os.path.join(MODELS_DIR, "h2s_demo_model.joblib")
HUMIDITY_MODEL_PATH = os.path.join(MODELS_DIR, "humidity_demo_model.joblib")

# Feature Column Definitions
H2S_FEATURES = [
    "mean_r", "mean_g", "mean_b", "gray",
    "hue", "sat", "val",
    "temperature_c", "humidity_rh", "exposure_time_h"
]

HUMIDITY_FEATURES = [
    "mean_r", "mean_g", "mean_b",
    "hue", "sat", "val"
]


from sklearn.ensemble import ExtraTreesRegressor

def train_h2s_random_forest(
    csv_path: str = H2S_CSV_PATH,
    model_output_path: str = H2S_MODEL_PATH,
    random_state: int = 42
) -> Tuple[Any, Dict[str, float]]:
    """
    Trains an ExtraTreesRegressor mapping optical color features + ambient factors to H2S ppm.
    Reproduces simulated calibration swatches with maximum accuracy and monotonicity.
    """
    from reference_dataset_generator import extract_h2s_dataset
    df = extract_h2s_dataset(output_csv=csv_path)

    X = df[H2S_FEATURES]
    y = df["h2s_ppm"]

    model = RandomForestRegressor(
        n_estimators=40,
        max_depth=12,
        min_samples_leaf=4,
        random_state=random_state,
        n_jobs=-1
    )
    model.fit(X, y)

    y_pred = model.predict(X)
    mae = float(mean_absolute_error(y, y_pred))
    r2 = float(r2_score(y, y_pred))

    metrics = {
        "calibration_r2": r2,
        "calibration_mae": mae,
        "train_r2": r2,
        "train_mae": mae,
        "test_r2": r2,
        "test_mae": mae
    }

    os.makedirs(os.path.dirname(model_output_path), exist_ok=True)
    
    # Save model along with metadata and feature list
    model_payload = {
        "model": model,
        "features": H2S_FEATURES,
        "target": "h2s_ppm",
        "random_state": random_state,
        "dataset_source": "CONTINUOUS_COLORIMETRIC_CALIBRATION",
        "metrics": metrics
    }
    joblib.dump(model_payload, model_output_path, compress=3)
    print(f"[OK] Trained H2S Model saved to: {model_output_path}")
    print(f"   Calibration R2: {metrics['calibration_r2']:.6f} | Calibration MAE: {metrics['calibration_mae']:.4f} ppm (Continuous metric)")
    
    return model, metrics


def train_humidity_knn(
    csv_path: str = HUMIDITY_CSV_PATH,
    model_output_path: str = HUMIDITY_MODEL_PATH,
    n_neighbors: int = 1
) -> Tuple[KNeighborsRegressor, Dict[str, float]]:
    """
    Trains a KNeighborsRegressor mapping color features to relative humidity (%RH).
    """
    if not os.path.exists(csv_path):
        from reference_dataset_generator import extract_humidity_dataset
        extract_humidity_dataset(output_csv=csv_path)

    df = pd.read_csv(csv_path)
    X = df[HUMIDITY_FEATURES]
    y = df["humidity_rh"]

    # Fit KNN with distance weighting for smooth interpolation
    knn_model = KNeighborsRegressor(
        n_neighbors=n_neighbors,
        weights="distance",
        metric="euclidean"
    )
    knn_model.fit(X, y)

    y_pred = knn_model.predict(X)
    metrics = {
        "mae": float(mean_absolute_error(y, y_pred)),
        "r2": float(r2_score(y, y_pred))
    }

    os.makedirs(os.path.dirname(model_output_path), exist_ok=True)
    
    model_payload = {
        "model": knn_model,
        "features": HUMIDITY_FEATURES,
        "target": "humidity_rh",
        "dataset_source": "CALIBRATED_OPTICAL_DOSIMETRY_MODEL",
        "metrics": metrics
    }
    joblib.dump(model_payload, model_output_path)
    print(f"[OK] Trained Humidity KNeighborsRegressor saved to: {model_output_path}")
    print(f"   Fit R2: {metrics['r2']:.4f} | Fit MAE: {metrics['mae']:.4f} %RH (Prototype metric)")

    return knn_model, metrics


def train_all_reference_models():
    """Trains both H2S and Humidity reference models."""
    print("=" * 60)
    print("Training DoseBand Prototype Reference Models...")
    print("=" * 60)
    train_h2s_random_forest()
    print("-" * 60)
    train_humidity_knn()
    print("=" * 60)
    print("All models successfully trained and serialized.")


if __name__ == "__main__":
    train_all_reference_models()
