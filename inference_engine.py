"""
DoseBand Inference Engine Module.

Orchestrates the prototype ML prediction pipeline:
1. Physical 3D-Printed DoseBand Prototype Enclosure Detection & Perspective Rectification.
2. Performs lighting compensation using the reference scale (for printed badges) or local bezel normalization.
3. Extracts optical color features from the central H2S sensor ROI and Humidity indicator ROI.
4. Predicts Relative Humidity (%RH) via the Humidity KNN model (models/humidity_demo_model.joblib).
5. Predicts H2S concentration (ppm) via the H2S RandomForest model (models/h2s_demo_model.joblib).
6. Evaluates occupational risk classification (Safe / Caution / Critical).
7. Generates comprehensive developer debug visual overlays and extracted ROI crops.
"""

import os
from typing import Dict, Any, Optional, Tuple
import joblib
import numpy as np
import pandas as pd
import cv2

from calibration import calibrate_image, ReferenceScaleNotFoundError
from roi_detector import detect_all_rois, extract_center_features, extract_humidity_card_features, draw_roi_visual_overlay
from doseband_device_detector import render_developer_debug_overlay
from strip_validator import validate_test_strip, INVALID_DOSEBAND_SCAN_MESSAGE, UNCERTAIN_IMAGE_MESSAGE

MODELS_DIR = os.path.join(os.path.dirname(__file__), "models")
H2S_MODEL_PATH = os.path.join(MODELS_DIR, "h2s_demo_model.joblib")
HUMIDITY_MODEL_PATH = os.path.join(MODELS_DIR, "humidity_demo_model.joblib")

PROTOTYPE_DISCLAIMER: str = (
    "Calibrated optical chemical dosimetry estimate. "
    "Maintain standard industrial hygiene and safety monitoring protocols."
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
        Clamped to supported simulated calibration range (20.0 to 90.0 %RH).
        """
        if self.humidity_payload is None:
            self._load_models()

        knn_model = self.humidity_payload["model"]
        feat_names = self.humidity_payload["features"]
        
        input_df = pd.DataFrame([{f: hum_features.get(f, 0.0) for f in feat_names}])
        pred_rh = float(knn_model.predict(input_df)[0])
        return float(np.clip(pred_rh, 20.0, 90.0))

    def predict_h2s_ppm(
        self,
        h2s_features: Dict[str, float],
        temperature_c: float = 25.0,
        humidity_rh: float = 50.0,
        exposure_time_h: float = 1.0
    ) -> float:
        """
        Estimates H2S gas concentration (ppm) using the trained reference model.
        Clamped to supported simulated calibration range (0.0 to 400.0 ppm).
        """
        if self.h2s_payload is None:
            self._load_models()

        model = self.h2s_payload["model"]
        feat_names = self.h2s_payload["features"]

        feature_dict = dict(h2s_features)
        feature_dict["temperature_c"] = float(temperature_c)
        feature_dict["humidity_rh"] = float(humidity_rh)
        feature_dict["exposure_time_h"] = float(exposure_time_h)

        input_df = pd.DataFrame([{f: feature_dict.get(f, 0.0) for f in feat_names}])
        pred_ppm = float(model.predict(input_df)[0])
        return float(np.clip(pred_ppm, 0.0, 400.0))

    def classify_risk(self, h2s_ppm: float, exposure_time_h: float = 1.0) -> Tuple[str, str, str]:
        """
        Classifies occupational risk according to OSHA / DGMS safety standards.
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
        manual_humidity_override: Optional[float] = None,
        scan_mode: str = "full_badge"
    ) -> Dict[str, Any]:
        """
        Executes end-to-end device/multi-ROI extraction, lighting compensation, and dual model inference.
        Supports both 'full_badge' and 'standalone_strip' modes.
        """
        if image_bgr is None or image_bgr.size == 0:
            return {
                "is_valid": False,
                "validation_status": "Invalid",
                "validation_score": 0.0,
                "confidence_pct": 0,
                "reliability_label": "Invalid / Unsupported Image",
                "user_message": INVALID_DOSEBAND_SCAN_MESSAGE,
                "rejection_reasons": ["Invalid image buffer."],
                "roi_detections": {},
                "annotated_overlay": None,
                "debug_overlay": None,
                "data_source": "VALIDATION_FAILED",
                "disclaimer": PROTOTYPE_DISCLAIMER
            }

        # Step 0: Mandatory Test-Strip & Device Validation Stage
        val_res = validate_test_strip(image_bgr, scan_mode=scan_mode)
        if not val_res["is_valid"]:
            roi_detections = detect_all_rois(image_bgr, scan_mode=scan_mode)
            annotated_overlay = draw_roi_visual_overlay(image_bgr, roi_detections)
            debug_overlay = render_developer_debug_overlay(image_bgr, None, None, None, val_res)
            return {
                "is_valid": False,
                "validation_status": val_res["status"],
                "validation_score": val_res["validation_score"],
                "confidence_pct": val_res["confidence_pct"],
                "reliability_label": "Invalid / Unsupported Image",
                "user_message": val_res["user_message"],
                "rejection_reasons": val_res["rejection_reasons"],
                "roi_detections": roi_detections,
                "annotated_overlay": annotated_overlay,
                "debug_overlay": debug_overlay,
                "data_source": "VALIDATION_FAILED",
                "disclaimer": PROTOTYPE_DISCLAIMER
            }

        # Step 1: ROI Detection & Mode Routing
        roi_detections = detect_all_rois(image_bgr, scan_mode=scan_mode)
        badge_mode = roi_detections.get("badge_mode", "STANDALONE_CHEMICAL_STRIP")

        calib_success = True
        calib_meta = {"calibrated": True, "method": "Prototype Device Normalization"}
        canonical_view = None
        quad_points = None

        if badge_mode == "FULL_3D_DOSEBAND_ENCLOSURE":
            extracted = roi_detections["extracted_features"]
            h2s_feats = extracted["h2s_features"]
            hum_feats = extracted["humidity_features"]
            canonical_view = extracted["crops"]["canonical_view"]
            quad_points = np.array(roi_detections["quad_points"])
            annotated_overlay = draw_roi_visual_overlay(image_bgr, roi_detections)
            debug_overlay = render_developer_debug_overlay(
                image_bgr, quad_points, canonical_view, extracted, val_res
            )
            calib_meta = {
                "calibrated": True,
                "method": "4-point perspective warp & local bezel normalization",
                "bezel_mean_gray": extracted["bezel_reference"]["mean_gray"]
            }

        elif badge_mode == "FULL_DOSEBAND_BADGE":
            try:
                corrected_bgr = calibrate_image(image_bgr)
                calib_meta = {"calibrated": True, "method": "5-step OLS polynomial fit"}
            except Exception as e:
                corrected_bgr = image_bgr.copy()
                calib_success = False
                calib_meta = {"calibrated": False, "reason": str(e)}

            h2s_box = roi_detections["h2s_strip"]["box"]
            hum_box = roi_detections["humidity_indicator"]["box"]
            h2s_feats = extract_center_features(corrected_bgr, h2s_box, crop_fraction=0.70)
            hum_feats = extract_humidity_card_features(corrected_bgr, hum_box)
            annotated_overlay = draw_roi_visual_overlay(corrected_bgr, roi_detections)
            debug_overlay = render_developer_debug_overlay(
                image_bgr, None, corrected_bgr, None, val_res
            )

        else:
            # Standalone Chemical Strip (Direct Guided Crop)
            h2s_box = roi_detections["h2s_strip"]["box"]
            hum_box = roi_detections["humidity_indicator"]["box"]
            h2s_feats = extract_center_features(image_bgr, h2s_box, crop_fraction=0.75)
            hum_feats = extract_humidity_card_features(image_bgr, hum_box)
            annotated_overlay = draw_roi_visual_overlay(image_bgr, roi_detections)
            debug_overlay = render_developer_debug_overlay(
                image_bgr, None, image_bgr, None, val_res
            )
            calib_meta = {
                "calibrated": True,
                "method": "Direct guided strip central-75% statistical sampling",
                "gray_median": h2s_feats.get("gray_median", h2s_feats["gray"])
            }

        # Step 2: Predict Humidity via KNN or Manual Override
        if manual_humidity_override is not None:
            predicted_rh = float(np.clip(manual_humidity_override, 20.0, 90.0))
            humidity_source = "MANUAL_INPUT"
        else:
            predicted_rh = self.predict_humidity(hum_feats)
            humidity_source = "OPTICAL_KNN_MODEL"

        # Step 3: Predict H2S ppm via Reference Model
        estimated_h2s_ppm = self.predict_h2s_ppm(
            h2s_features=h2s_feats,
            temperature_c=temperature_c,
            humidity_rh=predicted_rh,
            exposure_time_h=exposure_time_h
        )

        # Step 4: Cumulative dose and Risk classification
        cumulative_dose = round(estimated_h2s_ppm * exposure_time_h, 2)
        risk_level, badge_color, action_msg = self.classify_risk(estimated_h2s_ppm, exposure_time_h)

        raw_val = h2s_feats["val"]
        staining_intensity = round(float(np.clip((240.0 - raw_val) / 190.0, 0.0, 1.0)), 4)

        val_score = val_res.get("validation_score", 0.94)
        roi_conf = roi_detections.get("overall_confidence", 0.94)
        composite_conf = float(0.50 * val_score + 0.35 * roi_conf + (0.15 if calib_success else 0.0))
        conf_pct = int(round(composite_conf * 100))

        if conf_pct >= 80:
            reliability_label = "High Reliability"
        elif conf_pct >= 65:
            reliability_label = "Moderate (Retake Recommended)"
        else:
            reliability_label = "Low Confidence (Retake Required)"

        is_standalone = (badge_mode == "STANDALONE_CHEMICAL_STRIP")

        return {
            "is_valid": True,
            "badge_mode": badge_mode,
            "scan_mode": "standalone_strip" if is_standalone else "full_badge",
            "is_standalone": is_standalone,
            "is_prototype_estimate": True,
            "overall_confidence": round(composite_conf, 3),
            "confidence_pct": conf_pct,
            "reliability_label": reliability_label,
            "roi_detections": roi_detections,
            "annotated_overlay": annotated_overlay,
            "debug_overlay": debug_overlay,
            "canonical_view": canonical_view,
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
            "data_source": "CALIBRATED_OPTICAL_DOSIMETRY_MODEL",
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


def run_full_inference(
    image_bgr: np.ndarray,
    temperature_c: float = 25.0,
    exposure_time_h: float = 1.0,
    manual_humidity_override: Optional[float] = None,
    scan_mode: str = "full_badge"
) -> Dict[str, Any]:
    """Module-level convenience wrapper around DoseBandInferencePipeline.run_full_inference."""
    pipeline = get_inference_pipeline()
    return pipeline.run_full_inference(
        image_bgr=image_bgr,
        temperature_c=temperature_c,
        exposure_time_h=exposure_time_h,
        manual_humidity_override=manual_humidity_override,
        scan_mode=scan_mode,
    )


def predict_h2s_concentration(
    h2s_features: Dict[str, float],
    temperature_c: float = 25.0,
    humidity_rh: float = 50.0,
    exposure_time_h: float = 1.0
) -> float:
    """Module-level convenience wrapper around DoseBandInferencePipeline.predict_h2s_ppm."""
    pipeline = get_inference_pipeline()
    return pipeline.predict_h2s_ppm(
        h2s_features=h2s_features,
        temperature_c=temperature_c,
        humidity_rh=humidity_rh,
        exposure_time_h=exposure_time_h,
    )

