"""
DoseBand Inference Engine Module.

Orchestrates the prototype ML prediction pipeline:
1. Performs lighting compensation using the reference scale.
2. Extracts optical color features from the central H2S sensor ROI and Humidity indicator ROI.
3. Predicts Relative Humidity (%RH) via the Humidity KNN model (models/humidity_demo_model.joblib).
4. Predicts H2S concentration (ppm) via the H2S RandomForest model (models/h2s_demo_model.joblib).
5. Evaluates occupational risk classification (Safe / Caution / Critical).

IMPORTANT:
Prototype estimate — trained using simulated reference-image calibration data.
Not a validated occupational safety measurement.
"""

import os
from typing import Dict, Any, Optional, Tuple
import joblib
import numpy as np
import pandas as pd
import cv2

from calibration import calibrate_image, ReferenceScaleNotFoundError
from roi_detector import detect_all_rois, extract_center_features, draw_roi_visual_overlay
from strip_validator import validate_test_strip, INVALID_IMAGE_MESSAGE, UNCERTAIN_IMAGE_MESSAGE

MODELS_DIR = os.path.join(os.path.dirname(__file__), "models")
H2S_MODEL_PATH = os.path.join(MODELS_DIR, "h2s_demo_model.joblib")
HUMIDITY_MODEL_PATH = os.path.join(MODELS_DIR, "humidity_demo_model.joblib")

PROTOTYPE_DISCLAIMER: str = (
    "Prototype estimate — trained using simulated reference-image calibration data. "
    "Not a validated occupational safety measurement."
)


class DoseBandInferencePipeline:
    """
    Singleton-style inference pipeline loading the serialized reference models.
    """

    def __init__(
        self,
        h2s_model_path: str = H2S_MODEL_PATH,
        humidity_model_path: str = HUMIDITY_MODEL_PATH
    ):
        self.h2s_model_path = h2s_model_path
        self.humidity_model_path = humidity_model_path
        self.h2s_payload: Optional[Dict[str, Any]] = None
        self.humidity_payload: Optional[Dict[str, Any]] = None
        self._load_models()

    def _load_models(self) -> None:
        """Loads both serialized models from disk, training them if not yet generated."""
        if not os.path.exists(self.h2s_model_path) or not os.path.exists(self.humidity_model_path):
            from train_reference_models import train_all_reference_models
            train_all_reference_models()

        self.h2s_payload = joblib.load(self.h2s_model_path)
        self.humidity_payload = joblib.load(self.humidity_model_path)

    def predict_humidity(self, hum_features: Dict[str, float]) -> float:
        """
        Estimates relative humidity (%RH) from optical color features using the KNN model.
        """
        if self.humidity_payload is None:
            self._load_models()

        knn_model = self.humidity_payload["model"]
        feat_names = self.humidity_payload["features"]
        
        input_df = pd.DataFrame([{f: hum_features.get(f, 0.0) for f in feat_names}])
        pred_rh = float(knn_model.predict(input_df)[0])
        # Bound humidity between physical limits
        return float(np.clip(pred_rh, 10.0, 100.0))

    def predict_h2s_ppm(
        self,
        h2s_features: Dict[str, float],
        temperature_c: float = 25.0,
        humidity_rh: float = 50.0,
        exposure_time_h: float = 1.0
    ) -> float:
        """
        Estimates H2S gas concentration (ppm) using the RandomForestRegressor model.
        """
        if self.h2s_payload is None:
            self._load_models()

        rf_model = self.h2s_payload["model"]
        feat_names = self.h2s_payload["features"]

        feature_dict = dict(h2s_features)
        feature_dict["temperature_c"] = float(temperature_c)
        feature_dict["humidity_rh"] = float(humidity_rh)
        feature_dict["exposure_time_h"] = float(exposure_time_h)

        input_df = pd.DataFrame([{f: feature_dict.get(f, 0.0) for f in feat_names}])
        pred_ppm = float(rf_model.predict(input_df)[0])
        return float(max(0.0, pred_ppm))

    def classify_risk(self, h2s_ppm: float, exposure_time_h: float = 1.0) -> Tuple[str, str, str]:
        """
        Classifies occupational risk according to OSHA / DGMS safety standards.

        Thresholds (OSHA 8-hr TWA & STEL guidelines):
        - Safe:        < 10.0 ppm
        - Caution:     10.0 to 50.0 ppm
        - Unsafe:      >= 50.0 ppm (Immediate evacuation / medical review)

        Returns:
            Tuple[str, str, str]: (risk_level, badge_color, action_guidance)
        """
        if h2s_ppm < 10.0:
            return "Safe", "#10B981", "Normal operational zone. Below 8-hour permissible exposure limit."
        elif h2s_ppm < 50.0:
            return "Caution", "#F59E0B", "Elevated H2S exposure detected. Increase ventilation and monitor closely."
        else:
            return "Unsafe - seek medical review", "#EF4444", "CRITICAL EXPOSURE: Exceeds STEL safety ceiling. Immediate evacuation required."

    def run_full_inference(
        self,
        image_bgr: np.ndarray,
        temperature_c: float = 25.0,
        exposure_time_h: float = 1.0,
        manual_humidity_override: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Executes end-to-end multi-ROI extraction, lighting compensation, and dual model inference.
        Includes mandatory Test-Strip Validation stage.

        Args:
            image_bgr (np.ndarray): Uploaded badge photograph.
            temperature_c (float): Ambient temperature in Celsius.
            exposure_time_h (float): Shift duration / exposure time in hours.
            manual_humidity_override (Optional[float]): Manual humidity input if overriding image card.

        Returns:
            dict: Complete inference results and diagnostic metadata.
        """
        # Step 0: Mandatory Test-Strip Validation Stage
        val_res = validate_test_strip(image_bgr)
        if not val_res["is_valid"]:
            roi_detections = detect_all_rois(image_bgr)
            annotated_overlay = draw_roi_visual_overlay(image_bgr, roi_detections)
            return {
                "is_valid": False,
                "validation_status": val_res["status"],
                "validation_score": val_res["validation_score"],
                "confidence_pct": val_res["confidence_pct"],
                "user_message": val_res["user_message"],
                "rejection_reasons": val_res["rejection_reasons"],
                "roi_detections": roi_detections,
                "annotated_overlay": annotated_overlay,
                "data_source": "VALIDATION_FAILED",
                "disclaimer": PROTOTYPE_DISCLAIMER
            }

        # 1. Lighting correction via reference scale
        calib_success = True
        try:
            corrected_bgr = calibrate_image(image_bgr)
            calib_meta = {"calibrated": True, "method": "5-step OLS polynomial fit"}
        except Exception as e:
            corrected_bgr = image_bgr.copy()
            calib_success = False
            calib_meta = {"calibrated": False, "reason": str(e)}
        
        # 2. ROI Detection
        roi_detections = detect_all_rois(corrected_bgr)
        annotated_overlay = draw_roi_visual_overlay(corrected_bgr, roi_detections)

        if not roi_detections.get("is_valid", False):
            return {
                "is_valid": False,
                "validation_status": "Invalid",
                "validation_score": val_res.get("validation_score", 0.0),
                "confidence_pct": 0,
                "user_message": "Required DoseBand sensor strip or reference ROIs could not be reliably detected in the image.",
                "rejection_reasons": ["Required sensor regions (H2S strip or reference scale) missing, occluded, or out of frame."],
                "roi_detections": roi_detections,
                "annotated_overlay": annotated_overlay,
                "data_source": "ROI_DETECTION_FAILED",
                "disclaimer": PROTOTYPE_DISCLAIMER
            }

        # 3. Feature Extraction from Central ROIs
        h2s_box = roi_detections["h2s_strip"]["box"]
        hum_box = roi_detections["humidity_indicator"]["box"]

        h2s_feats = extract_center_features(corrected_bgr, h2s_box, crop_fraction=0.60)
        hum_feats = extract_center_features(corrected_bgr, hum_box, crop_fraction=0.60)

        # 4. Predict Humidity via KNN
        if manual_humidity_override is not None:
            predicted_rh = float(manual_humidity_override)
            humidity_source = "MANUAL_OVERRIDE"
        else:
            predicted_rh = self.predict_humidity(hum_feats)
            humidity_source = "OPTICAL_KNN_MODEL"

        # 5. Predict H2S ppm via Random Forest
        estimated_h2s_ppm = self.predict_h2s_ppm(
            h2s_features=h2s_feats,
            temperature_c=temperature_c,
            humidity_rh=predicted_rh,
            exposure_time_h=exposure_time_h
        )

        # 6. Cumulative dose and Risk classification (runs only on valid prediction)
        cumulative_dose = round(estimated_h2s_ppm * exposure_time_h, 2)
        risk_level, badge_color, action_msg = self.classify_risk(estimated_h2s_ppm, exposure_time_h)

        # Calculated staining intensity (0.0 to 1.0)
        raw_val = h2s_feats["val"]
        staining_intensity = round(float(np.clip((240.0 - raw_val) / 190.0, 0.0, 1.0)), 4)

        return {
            "is_valid": True,
            "overall_confidence": roi_detections["overall_confidence"],
            "roi_detections": roi_detections,
            "annotated_overlay": annotated_overlay,
            "lighting_meta": calib_meta,
            "h2s_features": h2s_feats,
            "humidity_features": hum_feats,
            "predicted_humidity": round(predicted_rh, 1),
            "humidity_source": humidity_source,
            "temperature_c": round(temperature_c, 1),
            "exposure_time_h": round(exposure_time_h, 2),
            "staining_intensity": staining_intensity,
            "estimated_h2s_ppm": round(estimated_h2s_ppm, 2),
            "cumulative_dose_ppm_h": cumulative_dose,
            "risk_level": risk_level,
            "risk_color": badge_color,
            "action_guidance": action_msg,
            "data_source": "SIMULATED_REFERENCE_IMAGE_MODEL",
            "disclaimer": PROTOTYPE_DISCLAIMER
        }


# Global inference engine instance
_pipeline_instance: Optional[DoseBandInferencePipeline] = None


def get_inference_pipeline() -> DoseBandInferencePipeline:
    """Returns the singleton instance of DoseBandInferencePipeline."""
    global _pipeline_instance
    if _pipeline_instance is None:
        _pipeline_instance = DoseBandInferencePipeline()
    return _pipeline_instance
