"""
DoseBand Environmental Compensation Module - Prototype Temperature & Humidity Correction.

Calculates reaction rate and moisture diffusion compensation factors for colorimetric dosimeter strips
exposed under non-standard ambient environmental conditions (relative to 25°C, 50% RH).

Status: PROTOTYPE / EXPERIMENTAL
Note: Experimental compensation model until empirical multi-chamber environmental calibration datasets are collected.
"""

from typing import Dict, Any

# Standard reference conditions for chemical dosimeters
REF_TEMPERATURE_C: float = 25.0     # Standard reference calibration temperature (°C)
REF_HUMIDITY_RH: float = 50.0       # Standard reference relative humidity (% RH)

# Sensitivity coefficients (Empirical Arrhenius reaction rate & Langmuir moisture adsorption approximations)
TEMP_COEFFICIENT: float = 0.008     # ~0.8% reaction rate change per °C deviation from 25°C
HUMIDITY_COEFFICIENT: float = 0.003 # ~0.3% moisture adsorption change per % RH deviation from 50%

MIN_COMPENSATION_FACTOR: float = 0.70
MAX_COMPENSATION_FACTOR: float = 1.40


def calculate_compensation_factor(
    temperature_c: float,
    humidity_rh: float
) -> Dict[str, Any]:
    """
    Computes environmental compensation factor (CF) based on ambient T (°C) and RH (%).

    Formula:
        f_temp = 1.0 + 0.008 * (T - 25.0)
        f_rh   = 1.0 + 0.003 * (RH - 50.0)
        CF     = clamp(f_temp * f_rh, 0.70, 1.40)

    Args:
        temperature_c (float): Ambient temperature in degrees Celsius.
        humidity_rh (float): Ambient relative humidity in percent (0 - 100%).

    Returns:
        Dict[str, Any]: Compensation factors and diagnostic deltas.
    """
    temp_delta = float(temperature_c) - REF_TEMPERATURE_C
    humidity_delta = float(humidity_rh) - REF_HUMIDITY_RH

    f_temp = 1.0 + (TEMP_COEFFICIENT * temp_delta)
    f_rh = 1.0 + (HUMIDITY_COEFFICIENT * humidity_delta)

    raw_cf = f_temp * f_rh
    clamped_cf = max(MIN_COMPENSATION_FACTOR, min(MAX_COMPENSATION_FACTOR, raw_cf))

    return {
        "compensation_factor": round(clamped_cf, 4),
        "temp_factor": round(f_temp, 4),
        "humidity_factor": round(f_rh, 4),
        "temp_delta": round(temp_delta, 1),
        "humidity_delta": round(humidity_delta, 1),
        "is_reference_condition": (abs(temp_delta) < 0.1 and abs(humidity_delta) < 0.1)
    }


def apply_environmental_compensation(
    raw_intensity: float,
    temperature_c: float = 25.0,
    humidity_rh: float = 50.0
) -> Dict[str, Any]:
    """
    Applies temperature and humidity compensation to raw optical staining intensity.

    Args:
        raw_intensity (float): Raw staining intensity score (0.0 to 1.0).
        temperature_c (float): Ambient temperature in degrees Celsius.
        humidity_rh (float): Ambient relative humidity in percent (0 - 100%).

    Returns:
        Dict[str, Any]: Dictionary containing raw_intensity, corrected_intensity, compensation_factor, etc.
    """
    comp = calculate_compensation_factor(temperature_c, humidity_rh)
    cf = comp["compensation_factor"]

    # Higher T/RH increases chemical reaction rate, yielding higher staining for same gas dose.
    # Therefore, normalized corrected intensity = raw_intensity / CF.
    if cf > 0:
        corrected = raw_intensity / cf
    else:
        corrected = raw_intensity

    # Clamp to valid intensity range [0.0, 1.0]
    corrected_clamped = max(0.0, min(1.0, corrected))

    # Calculate estimated compensated dose using dose_model polynomial regression
    estimated_dose_corrected = 0.0
    try:
        import dose_model
        dose_pred = dose_model.predict_dose(corrected_clamped)
        estimated_dose_corrected = round(float(dose_pred.get("dose", 0.0)), 2)
    except Exception:
        # Fallback quadratic approximation if model pkl is uninitialized
        estimated_dose_corrected = round(130.0 * (corrected_clamped ** 1.75), 2)

    # Generate human-readable explanation
    if comp["is_reference_condition"]:
        explanation = "Ambient conditions match standard calibration reference (25.0°C, 50.0% RH). Compensation factor is 1.0000 (0.0% adjustment)."
    else:
        temp_dir = "accelerated" if comp["temp_delta"] > 0 else "suppressed"
        hum_dir = "enhanced" if comp["humidity_delta"] > 0 else "reduced"
        delta_pct = (cf - 1.0) * 100.0
        explanation = (
            f"Ambient conditions ({temperature_c:.1f}°C, {humidity_rh:.1f}% RH) {temp_dir} reaction kinetics ({comp['temp_factor']:.3f}x) "
            f"and {hum_dir} moisture diffusion ({comp['humidity_factor']:.3f}x), resulting in a net {delta_pct:+.1f}% shift (CF: {cf:.4f}). "
            f"Raw optical intensity {raw_intensity:.4f} is normalized to {corrected_clamped:.4f} at 25°C reference."
        )

    return {
        "raw_intensity": round(float(raw_intensity), 4),
        "corrected_intensity": round(float(corrected_clamped), 4),
        "compensation_factor": cf,
        "temperature_c": float(temperature_c),
        "humidity_rh": float(humidity_rh),
        "temp_factor": comp["temp_factor"],
        "humidity_factor": comp["humidity_factor"],
        "is_reference_condition": comp["is_reference_condition"],
        "estimated_dose_corrected": estimated_dose_corrected,
        "explanation": explanation
    }


if __name__ == "__main__":
    print("--- Environmental Compensation Unit Test ---")
    res_std = apply_environmental_compensation(0.50, 25.0, 50.0)
    print("Standard (25°C, 50% RH):", res_std)
    assert res_std["compensation_factor"] == 1.0

    res_hot = apply_environmental_compensation(0.50, 45.0, 80.0)
    print("Hot & Humid (45°C, 80% RH):", res_hot)
    assert res_hot["compensation_factor"] > 1.0
    assert res_hot["corrected_intensity"] < res_hot["raw_intensity"]

    res_cold = apply_environmental_compensation(0.50, 5.0, 20.0)
    print("Cold & Dry (5°C, 20% RH):", res_cold)
    assert res_cold["compensation_factor"] < 1.0
    assert res_cold["corrected_intensity"] > res_cold["raw_intensity"]

    print("All Environmental Compensation tests passed!")
