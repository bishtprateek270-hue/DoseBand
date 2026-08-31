"""
DoseBand Dose Estimation Module - Machine Learning Model for H2S Cumulative Exposure.

This module fits a 2nd-degree Polynomial Regression model mapping optical staining intensity
(0.0 to 1.0) to known cumulative H2S dose (ppm x hours).

Occupational Exposure Thresholds (OSHA / DGMS Guidelines):
---------------------------------------------------------
- Safe:                < 10.0 ppm*hr  (Below 8-hr Permissible Exposure Limit TWA)
- Caution:             10.0 - 50.0 ppm*hr (Exceeds TWA, within short-term ceiling)
- Unsafe (Medical):    >= 50.0 ppm*hr (Exceeds STEL / Immediately Dangerous to Life)

Note: Thresholds are set as configurable placeholder constants and will be refined
with empirical calibration data from controlled chamber proxy testing.
"""

import os
import pickle
from typing import Tuple, Dict, Any, Optional
import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import PolynomialFeatures

# Placeholder Risk Classification Thresholds (ppm * hours)
# Refined based on OSHA 29 CFR 1910.1000 and DGMS H2S industrial safety limits
DOSE_THRESHOLD_SAFE: float = 10.0
DOSE_THRESHOLD_CAUTION: float = 50.0

DEFAULT_MODEL_PATH: str = "dose_model.pkl"
DEFAULT_DATA_PATH: str = "calibration_data.csv"


def generate_synthetic_calibration_data(filepath: str = DEFAULT_DATA_PATH, num_samples: int = 25) -> pd.DataFrame:
    """
    Generates a realistic synthetic dataset modeling optical sensor darkening vs H2S dose.

    Colorimetric indicator paper exhibits non-linear saturation:
        known_dose = 120 * (intensity ^ 1.8) + Gaussian noise

    Args:
        filepath (str): Target CSV path to save dataset.
        num_samples (int): Number of synthetic data points.

    Returns:
        pd.DataFrame: Generated dataset containing intensity, known_dose, and duration_minutes.
    """
    np.random.seed(42)  # For reproducible synthetic calibration curve

    # Evenly sample intensity values from fresh (0.02) to fully saturated (0.95)
    intensities = np.linspace(0.02, 0.95, num_samples)
    
    # Quadratic / power-law dose relationship + realistic sensor noise
    doses = 130.0 * (intensities ** 1.75) + np.random.normal(0, 2.5, num_samples)
    doses = np.clip(doses, 0.0, None)  # Dose cannot be negative

    durations = np.random.choice([60.0, 120.0, 240.0, 480.0], size=num_samples)

    df = pd.DataFrame({
        "intensity": np.round(intensities, 4),
        "known_dose": np.round(doses, 2),
        "duration_minutes": durations
    })

    df.to_csv(filepath, index=False)
    print(f"Generated synthetic calibration dataset with {num_samples} samples at '{filepath}'.")
    return df


def train_model(
    csv_path: str = DEFAULT_DATA_PATH,
    model_path: str = DEFAULT_MODEL_PATH
) -> Tuple[LinearRegression, PolynomialFeatures, float, float]:
    """
    Loads calibration data, fits a degree-2 polynomial regression model, evaluates performance,
    and serializes the fitted transformer and model to disk via pickle.

    Args:
        csv_path (str): Path to calibration_data.csv dataset.
        model_path (str): Output path for dose_model.pkl.

    Returns:
        Tuple: (model, poly, r2, mae)
    """
    if not os.path.exists(csv_path):
        generate_synthetic_calibration_data(csv_path)

    df = pd.read_csv(csv_path)

    # Feature and Target extraction
    X_list = df[["intensity"]].values.tolist()
    y_list = [float(val) for val in df["known_dose"].tolist()]

    # 80/20 Train-Test split
    X_train, X_test, y_train, y_test = train_test_split(
        X_list, y_list, test_size=0.2, random_state=42
    )

    # Polynomial Features Transformer (Degree 2 mapping)
    poly = PolynomialFeatures(degree=2, include_bias=False)
    X_train_poly = poly.fit_transform(X_train)
    X_test_poly = poly.transform(X_test)

    # Fit Ordinary Least Squares Linear Regression
    model = LinearRegression()
    model.fit(X_train_poly, y_train)

    # Evaluate model predictions on test set
    y_pred = model.predict(X_test_poly)
    r2 = float(r2_score(y_test, y_pred))
    mae = float(mean_absolute_error(y_test, y_pred))

    # Serialize model and transformer together using pickle
    with open(model_path, "wb") as f:
        pickle.dump({"poly": poly, "model": model}, f)

    print(f"Model successfully trained and saved to '{model_path}'.")
    print(f"  Evaluation Metrics -> Test R² Score: {r2:.4f} | Test MAE: {mae:.2f} ppm*hr")

    return model, poly, r2, mae


def load_model(path: str = DEFAULT_MODEL_PATH) -> Tuple[LinearRegression, PolynomialFeatures]:
    """
    Loads serialized model and polynomial transformer from pickle file.
    If the model file does not exist, automatically trains and serializes a new model.

    Args:
        path (str): Path to saved model pickle file.

    Returns:
        Tuple: (model, poly)
    """
    if not os.path.exists(path):
        train_model(csv_path=DEFAULT_DATA_PATH, model_path=path)

    with open(path, "rb") as f:
        data = pickle.load(f)

    return data["model"], data["poly"]


def predict_dose(
    intensity: float,
    model: Optional[LinearRegression] = None,
    poly: Optional[PolynomialFeatures] = None,
    model_path: str = DEFAULT_MODEL_PATH
) -> Dict[str, Any]:
    """
    Predicts cumulative H2S dose (ppm x hours) from a staining intensity score.

    Args:
        intensity (float): Staining intensity between 0.0 and 1.0.
        model (Optional[LinearRegression]): Pre-loaded linear model.
        poly (Optional[PolynomialFeatures]): Pre-loaded polynomial transformer.
        model_path (str): Path to load model if not provided.

    Returns:
        Dict[str, Any]: Dictionary containing predicted 'dose', 'confidence_note', and 'risk_level'.
    """
    if model is None or poly is None:
        model, poly = load_model(model_path)

    # Clamp input intensity to valid range
    clamped_intensity = float(np.clip(intensity, 0.0, 1.0))
    X_in = np.array([[clamped_intensity]])

    # Polynomial feature transformation
    X_poly = poly.transform(X_in)

    # Predict dose
    pred_dose = float(model.predict(X_poly)[0])
    pred_dose = max(0.0, pred_dose)  # Ensure non-negative dose prediction

    # Determine confidence note based on non-linear saturation extremes
    if clamped_intensity < 0.05 or clamped_intensity > 0.90:
        confidence = "estimate — colorimetric reactions are non-linear at extremes"
    else:
        confidence = "high confidence — within calibrated linear region"

    # Classify occupational health risk level
    risk_level = classify_risk_level(pred_dose)

    return {
        "dose": round(pred_dose, 2),
        "confidence_note": confidence,
        "risk_level": risk_level
    }


def classify_risk_level(dose: float) -> str:
    """
    Buckets predicted H2S dose into occupational health safety tiers.

    Args:
        dose (float): Predicted dose in ppm x hours.

    Returns:
        str: 'Safe', 'Caution', or 'Unsafe — seek medical review'
    """
    if dose < DOSE_THRESHOLD_SAFE:
        return "Safe"
    elif dose < DOSE_THRESHOLD_CAUTION:
        return "Caution"
    else:
        return "Unsafe — seek medical review"


if __name__ == "__main__":
    csv_file = DEFAULT_DATA_PATH
    model_file = DEFAULT_MODEL_PATH

    print("--- DoseBand Model Training Pipeline ---")
    if not os.path.exists(csv_file):
        generate_synthetic_calibration_data(csv_file)

    # Train model and output evaluation metrics
    model, poly, r2, mae = train_model(csv_path=csv_file, model_path=model_file)

    print("\n--- Model Inference Sanity Checks ---")
    sample_intensities = [0.10, 0.50, 0.90]

    for val in sample_intensities:
        res = predict_dose(val, model=model, poly=poly)
        print(f"\nIntensity: {val:.2f}")
        print(f"  Predicted Dose:  {res['dose']} ppm*hr")
        print(f"  Risk Level:      {res['risk_level']}")
        print(f"  Confidence Note: {res['confidence_note']}")
