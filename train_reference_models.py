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

H2S_CSV_PATH = os.path.join(DATA_DIR, "simulated_h2s_training_data.csv")
HUMIDITY_CSV_PATH = os.path.join(DATA_DIR, "simulated_humidity_training_data.csv")

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


def train_h2s_random_forest(
    csv_path: str = H2S_CSV_PATH,
    model_output_path: str = H2S_MODEL_PATH,
    random_state: int = 42
) -> Tuple[RandomForestRegressor, Dict[str, float]]:
    """
    Trains a RandomForestRegressor mapping optical color features + ambient factors to H2S ppm.
    """
    if not os.path.exists(csv_path):
        from reference_dataset_generator import extract_h2s_dataset
        extract_h2s_dataset(output_csv=csv_path)

    df = pd.read_csv(csv_path)
    X = df[H2S_FEATURES]
    y = df["h2s_ppm"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=random_state
    )

    rf_model = RandomForestRegressor(
        n_estimators=100,
        max_depth=12,
        min_samples_split=2,
        random_state=random_state
    )
    rf_model.fit(X_train, y_train)

    y_pred_train = rf_model.predict(X_train)
    y_pred_test = rf_model.predict(X_test)

    metrics = {
        "train_r2": float(r2_score(y_train, y_pred_train)),
        "train_mae": float(mean_absolute_error(y_train, y_pred_train)),
        "test_r2": float(r2_score(y_test, y_pred_test)),
        "test_mae": float(mean_absolute_error(y_test, y_pred_test))
    }

    os.makedirs(os.path.dirname(model_output_path), exist_ok=True)
    
    # Save model along with metadata and feature list
    model_payload = {
        "model": rf_model,
        "features": H2S_FEATURES,
        "target": "h2s_ppm",
        "random_state": random_state,
        "dataset_source": "SIMULATED_FROM_REFERENCE_IMAGE",
        "metrics": metrics
    }
    joblib.dump(model_payload, model_output_path)
    print(f"[OK] Trained H2S RandomForestRegressor saved to: {model_output_path}")
    print(f"   Test R2: {metrics['test_r2']:.4f} | Test MAE: {metrics['test_mae']:.4f} ppm (Prototype metric)")
    
    return rf_model, metrics


def train_humidity_knn(
    csv_path: str = HUMIDITY_CSV_PATH,
    model_output_path: str = HUMIDITY_MODEL_PATH,
    n_neighbors: int = 3
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
        "dataset_source": "SIMULATED_FROM_REFERENCE_IMAGE",
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
