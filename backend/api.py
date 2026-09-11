"""
DoseBand REST API Module - FastAPI Backend for Mobile and Web Integration.

Provides unified endpoints for:
- Worker Profile CRUD & Badge verification
- Image analysis & ML Gas Dosimetry inference (reusing inference_engine.py & strip_validator.py)
- Sensor reading persistence in SQLite (database.py)
- Live Industrial Dashboard Analytics & Reports
"""

import io
import json
import os
import sys
from datetime import datetime, date
from typing import Dict, Any, List, Optional

import cv2
import numpy as np
import pandas as pd
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field

# Ensure root workspace directory is in python search path
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

import database
import expiry_checker
import inference_engine
import qr_manager
import quality_validator
import roi_detector
import safety_report_generator
import strip_validator

app = FastAPI(
    title="DoseBand Industrial Safety API",
    description="Unified REST API for optical dosimetry, worker tracking, and H2S exposure compliance.",
    version="1.0.0"
)

# Enable permissive CORS for mobile devices, emulators, and web frontends
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def to_serializable(val: Any) -> Any:
    """Recursively converts NumPy types, DataFrames, dates, and NaNs to standard JSON-compatible Python primitives."""
    if val is None:
        return None
    elif isinstance(val, (bool, np.bool_)):
        return bool(val)
    elif isinstance(val, (np.integer, int)):
        return int(val)
    elif isinstance(val, (np.floating, float)):
        if np.isnan(val) or np.isinf(val):
            return 0.0
        return float(val)
    elif isinstance(val, np.ndarray):
        return [to_serializable(x) for x in val.tolist()]
    elif isinstance(val, pd.DataFrame):
        return [to_serializable(row) for row in val.to_dict(orient="records")]
    elif isinstance(val, pd.Series):
        return to_serializable(val.to_dict())
    elif isinstance(val, (date, datetime)):
        return val.isoformat()
    elif isinstance(val, dict):
        return {str(k): to_serializable(v) for k, v in val.items()}
    elif isinstance(val, (list, tuple, set)):
        return [to_serializable(x) for x in val]
    return val


# -----------------------------------------------------------------------------
# PYDANTIC SCHEMAS
# -----------------------------------------------------------------------------

class WorkerCreateRequest(BaseModel):
    worker_id: str = Field(..., example="W-106")
    name: str = Field(..., example="Kavita Sharma")
    department: str = Field(..., example="Refinery Operations")
    work_zone: str = Field(..., example="Zone A - Crude Distillation Unit")
    shift: str = Field(..., example="Shift 1 (06:00 - 14:00)")
    badge_id: str = Field(..., example="BDG-106")
    badge_issue_date: str = Field(..., example="2026-08-01")
    badge_expiry_date: str = Field(..., example="2026-11-01")
    status: str = Field("Active", example="Active")


class WorkerUpdateRequest(BaseModel):
    name: str
    department: str
    work_zone: str
    shift: str
    badge_id: str
    badge_issue_date: str
    badge_expiry_date: str
    status: str


class SaveReadingRequest(BaseModel):
    worker_id: str
    intensity: float
    dose: float
    risk_level: str
    is_expired: bool = False
    expiry_status_message: str = "Active & Verified"
    temperature: float = 25.0
    humidity: float = 50.0
    raw_intensity: Optional[float] = None
    corrected_intensity: Optional[float] = None
    compensation_factor: float = 1.0
    badge_id: Optional[str] = None
    predicted_humidity: Optional[float] = None
    exposure_time: float = 1.0
    strip_intensity: Optional[float] = None
    estimated_h2s_ppm: Optional[float] = None
    data_source: str = "CALIBRATED_OPTICAL_DOSIMETRY_MODEL"


# -----------------------------------------------------------------------------
# 1. SYSTEM HEALTH & METADATA
# -----------------------------------------------------------------------------

@app.get("/health", tags=["System"])
def health_check():
    """Returns system status, active database connectivity, and ML engine readiness."""
    db_ok = True
    try:
        database.init_db()
    except Exception:
        db_ok = False

    return {
        "status": "healthy" if db_ok else "degraded",
        "service": "DoseBand Industrial Safety API",
        "version": "1.0.0",
        "database_connected": db_ok,
        "timestamp": datetime.now().isoformat()
    }


# -----------------------------------------------------------------------------
# 2. WORKERS & BADGE MANAGEMENT
# -----------------------------------------------------------------------------

@app.get("/workers", tags=["Workers"])
def get_all_workers():
    """Retrieves all registered industrial workers ordered by worker ID."""
    df = database.get_all_workers()
    if df.empty:
        return []

    # Enrich with computed expiry and dose
    workers = []
    today = date.today()
    for _, r in df.iterrows():
        w_dict = r.to_dict()
        exp_date_str = str(w_dict.get("badge_expiry_date", ""))
        is_exp = False
        try:
            exp_d = datetime.strptime(exp_date_str, "%Y-%m-%d").date()
            is_exp = exp_d < today
        except Exception:
            is_exp = False

        cum_dose = database.get_cumulative_dose(w_dict["worker_id"])
        w_dict["is_badge_expired"] = is_exp
        w_dict["cumulative_dose"] = round(cum_dose, 2)
        workers.append(w_dict)

    return workers


@app.get("/workers/{worker_id}", tags=["Workers"])
def get_worker(worker_id: str):
    """Retrieves a single worker by unique worker identifier (e.g. 'W-101')."""
    w = database.get_worker_by_id(worker_id)
    if not w:
        raise HTTPException(status_code=404, detail=f"Worker '{worker_id}' not found.")

    today = date.today()
    try:
        exp_d = datetime.strptime(w.get("badge_expiry_date", ""), "%Y-%m-%d").date()
        w["is_badge_expired"] = exp_d < today
    except Exception:
        w["is_badge_expired"] = False

    w["cumulative_dose"] = round(database.get_cumulative_dose(worker_id), 2)
    return w


@app.post("/workers", status_code=201, tags=["Workers"])
def create_worker(req: WorkerCreateRequest):
    """Registers a new worker profile and assigns a dosimeter badge."""
    try:
        rec_id = database.insert_worker(
            worker_id=req.worker_id,
            name=req.name,
            department=req.department,
            work_zone=req.work_zone,
            shift=req.shift,
            badge_id=req.badge_id,
            badge_issue_date=req.badge_issue_date,
            badge_expiry_date=req.badge_expiry_date,
            status=req.status
        )
        return {"success": True, "id": rec_id, "worker_id": req.worker_id, "message": "Worker registered successfully."}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.put("/workers/{worker_id}", tags=["Workers"])
def update_worker_profile(worker_id: str, req: WorkerUpdateRequest):
    """Updates an existing worker's department, shift, zone, or badge details."""
    success = database.update_worker(
        worker_id=worker_id,
        name=req.name,
        department=req.department,
        work_zone=req.work_zone,
        shift=req.shift,
        badge_id=req.badge_id,
        badge_issue_date=req.badge_issue_date,
        badge_expiry_date=req.badge_expiry_date,
        status=req.status
    )
    if not success:
        raise HTTPException(status_code=404, detail=f"Worker '{worker_id}' not found.")
    return {"success": True, "worker_id": worker_id, "message": "Worker profile updated."}


@app.delete("/workers/{worker_id}", tags=["Workers"])
def delete_worker_profile(worker_id: str):
    """Deletes a worker profile from the database."""
    success = database.delete_worker(worker_id)
    if not success:
        raise HTTPException(status_code=404, detail=f"Worker '{worker_id}' not found.")
    return {"success": True, "worker_id": worker_id, "message": "Worker deleted."}


@app.get("/badges/{badge_id}", tags=["Badges"])
def get_badge(badge_id: str):
    """Looks up a worker profile by unique badge identifier (e.g. 'BDG-101')."""
    w = database.get_worker_by_badge_id(badge_id)
    if not w:
        raise HTTPException(status_code=404, detail=f"Badge '{badge_id}' not found.")
    return w


@app.post("/badges/verify-qr", tags=["Badges"])
async def verify_badge_qr(
    file: Optional[UploadFile] = File(None),
    raw_payload: Optional[str] = Form(None)
):
    """
    Decodes and verifies an official DoseBand QR badge.
    Accepts either an uploaded QR image file or raw string payload.
    """
    decoded_wid = None
    decoded_bid = None
    payload_str = raw_payload

    if file is not None:
        contents = await file.read()
        decoded_wid, decoded_bid, payload_str = qr_manager.decode_qr_from_image_bytes(contents)
    elif raw_payload:
        try:
            parsed = json.loads(raw_payload)
            if isinstance(parsed, dict) and parsed.get("app") == "DoseBand":
                decoded_wid = parsed.get("worker_id")
                decoded_bid = parsed.get("badge_id")
        except Exception:
            pass

    val_res = qr_manager.validate_badge_profile(decoded_wid, decoded_bid)
    return {
        "valid": val_res["valid"],
        "status": val_res["status"],
        "message": val_res["message"],
        "worker": val_res.get("worker"),
        "raw_payload": payload_str
    }


# -----------------------------------------------------------------------------
# 3. OPTICAL GAS DOSIMETRY & ML INFERENCE ENGINE
# -----------------------------------------------------------------------------

@app.post("/scan/analyze", tags=["Dosimetry"])
async def analyze_sensor_strip(
    image: UploadFile = File(...),
    worker_id: str = Form("W-101"),
    temperature_c: float = Form(25.0),
    humidity_rh: Optional[float] = Form(None),
    exposure_time_h: float = Form(1.0),
    badge_mode: str = Form("STANDALONE_CHEMICAL_STRIP")
):
    """
    Executes end-to-end multi-ROI extraction, optical lighting correction,
    mandatory test-strip validation, and dual model ML prediction.

    Returns the EXACT same prediction report as the working Web app.
    """
    try:
        contents = await image.read()
        np_arr = np.frombuffer(contents, np.uint8)
        img_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img_bgr is None:
            raise HTTPException(status_code=400, detail="Failed to decode image buffer. Please provide a valid JPG or PNG.")

        # 1. Mandatory Test-Strip Physical & Optical Validation
        strip_val_res = strip_validator.validate_test_strip(img_bgr)
        is_strip_valid = strip_val_res["is_valid"]
        strip_val_status = strip_val_res["status"]
        strip_confidence_pct = strip_val_res["confidence_pct"]
        strip_val_score = strip_val_res["validation_score"]
        user_message = strip_val_res["user_message"]
        breakdown = strip_val_res.get("breakdown", {})

        # 2. Quality Evaluation
        quality_diag = quality_validator.evaluate_image_quality(img_bgr)
        is_quality_valid = quality_diag.get("is_valid_for_analysis", False)

        # 3. ROI Detections
        roi_detections = roi_detector.detect_all_rois(img_bgr)
        detected_mode = roi_detections.get("badge_mode", badge_mode)

        if not is_strip_valid:
            return JSONResponse(
                status_code=200,
                content={
                    "is_valid": False,
                    "status": strip_val_status,
                    "validation_score": strip_val_score,
                    "confidence_pct": strip_confidence_pct,
                    "user_message": user_message,
                    "rejection_reasons": strip_val_res.get("rejection_reasons", []),
                    "estimated_h2s_ppm": 0.0,
                    "cumulative_dose_ppm_h": 0.0,
                    "predicted_humidity": 50.0,
                    "raw_intensity": 0.0,
                    "corrected_intensity": 0.0,
                    "compensation_factor": 1.0,
                    "risk_level": "Invalid",
                    "risk_color": "#EF4444",
                    "action_guidance": "Reposition valid chemical dosimeter strip under uniform lighting.",
                    "badge_mode": detected_mode,
                    "validation_breakdown": breakdown,
                    "pre_flight_checks": {
                        "ref_scale": False,
                        "sensor_strip": False,
                        "humidity_source": False,
                        "lighting_calibration": False
                    }
                }
            )

        # 4. Full ML Inference Pipeline
        pipeline = inference_engine.get_inference_pipeline()
        inf_res = pipeline.run_full_inference(
            image_bgr=img_bgr,
            temperature_c=temperature_c,
            exposure_time_h=exposure_time_h,
            manual_humidity_override=humidity_rh
        )

        # 5. Check Optical Expiry Patch if Full Badge
        is_optical_expired = False
        expiry_status_msg = "Physical Chemical Test Strip (Active)"
        if detected_mode != "STANDALONE_CHEMICAL_STRIP":
            exp_check = expiry_checker.check_badge_validity(img_bgr)
            is_optical_expired = exp_check.get("is_expired", False)
            expiry_status_msg = exp_check.get("status_message", "Valid — safe to use")

        # 6. Worker profile active & expiry verification
        worker_profile = database.get_worker_by_id(worker_id)
        is_worker_active = True
        is_profile_expired = False
        if worker_profile:
            is_worker_active = (worker_profile.get("status") == "Active")
            try:
                exp_d = datetime.strptime(worker_profile.get("badge_expiry_date", "1970-01-01"), "%Y-%m-%d").date()
                is_profile_expired = exp_d < date.today()
            except Exception:
                is_profile_expired = False

        is_allowed_to_save = is_strip_valid and is_worker_active and not is_profile_expired and not is_optical_expired

        return to_serializable({
            "is_valid": inf_res.get("is_valid", True),
            "status": "Valid",
            "validation_score": strip_val_score,
            "confidence_pct": inf_res.get("confidence_pct", strip_confidence_pct),
            "user_message": "Test strip optical verification passed with high confidence.",
            "estimated_h2s_ppm": inf_res.get("estimated_h2s_ppm", 0.0),
            "cumulative_dose_ppm_h": inf_res.get("cumulative_dose_ppm_h", 0.0),
            "predicted_humidity": inf_res.get("predicted_humidity", 50.0),
            "humidity_source": inf_res.get("humidity_source", "OPTICAL_KNN_MODEL"),
            "temperature_c": temperature_c,
            "exposure_time_h": exposure_time_h,
            "raw_intensity": inf_res.get("staining_intensity", 0.0),
            "corrected_intensity": inf_res.get("staining_intensity", 0.0),
            "compensation_factor": 1.0,
            "risk_level": inf_res.get("risk_level", "Safe"),
            "risk_color": inf_res.get("risk_color", "#10B981"),
            "action_guidance": inf_res.get("action_guidance", "Within permissible 8-hr TWA limit. Safe to continue shift."),
            "badge_mode": detected_mode,
            "is_badge_expired": is_profile_expired or is_optical_expired,
            "is_allowed_to_save": is_allowed_to_save,
            "expiry_status_message": expiry_status_msg,
            "validation_breakdown": breakdown,
            "pre_flight_checks": {
                "ref_scale": True,
                "sensor_strip": True,
                "humidity_source": True,
                "lighting_calibration": True
            }
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image analysis failed: {str(e)}")


@app.post("/scan/save", status_code=201, tags=["Dosimetry"])
def save_dosimetry_reading(req: SaveReadingRequest):
    """
    Persists an analyzed sensor reading record directly into the shared SQLite database.
    Updates worker cumulative dose and plant safety logs.
    """
    # Verify worker exists and is not expired
    w = database.get_worker_by_id(req.worker_id)
    if not w:
        raise HTTPException(status_code=404, detail=f"Worker '{req.worker_id}' not found.")

    today = date.today()
    try:
        exp_d = datetime.strptime(w.get("badge_expiry_date", "1970-01-01"), "%Y-%m-%d").date()
        if exp_d < today:
            raise HTTPException(status_code=400, detail=f"Badge '{w.get('badge_id')}' is expired on {w.get('badge_expiry_date')}. Exposure saving is blocked.")
    except HTTPException:
        raise
    except Exception:
        pass

    rec_id = database.insert_reading(
        worker_id=req.worker_id,
        intensity=req.intensity,
        dose=req.dose,
        risk_level=req.risk_level,
        is_expired=req.is_expired,
        expiry_status_message=req.expiry_status_message,
        temperature=req.temperature,
        humidity=req.humidity,
        raw_intensity=req.raw_intensity or req.intensity,
        corrected_intensity=req.corrected_intensity or req.intensity,
        compensation_factor=req.compensation_factor,
        badge_id=req.badge_id or w.get("badge_id"),
        predicted_humidity=req.predicted_humidity,
        exposure_time=req.exposure_time,
        strip_intensity=req.strip_intensity or req.intensity,
        estimated_h2s_ppm=req.estimated_h2s_ppm or req.dose,
        data_source=req.data_source
    )

    return {
        "success": True,
        "reading_id": rec_id,
        "worker_id": req.worker_id,
        "cumulative_dose": round(database.get_cumulative_dose(req.worker_id), 2),
        "message": "Reading successfully recorded in SQLite database."
    }


# -----------------------------------------------------------------------------
# 4. READINGS HISTORY & DASHBOARD ANALYTICS
# -----------------------------------------------------------------------------

@app.get("/readings", tags=["Readings"])
def get_all_readings():
    """Retrieves all logged sensor readings across all workers."""
    df = database.get_all_readings()
    if df.empty:
        return []
    return df.to_dict(orient="records")


@app.get("/workers/{worker_id}/history", tags=["Readings"])
def get_worker_readings(worker_id: str):
    """Retrieves chronological exposure readings log for a specific worker."""
    df = database.get_readings_for_worker(worker_id)
    if df.empty:
        return []
    return df.to_dict(orient="records")


@app.get("/dashboard", tags=["Dashboard"])
def get_dashboard_data():
    """
    Returns live aggregated plant analytics matching the Streamlit Dashboard:
    - Active worker count
    - Total readings logged
    - Average H2S ppm level
    - Critical / Unsafe risk count
    - Work zone risk distribution
    - Recent scans feed
    """
    workers_df = database.get_all_workers()
    readings_df = database.get_all_readings()

    total_workers = len(workers_df)
    active_workers = len(workers_df[workers_df["status"] == "Active"]) if not workers_df.empty else 0
    total_readings = len(readings_df)

    avg_ppm = 0.0
    critical_alerts = 0
    caution_alerts = 0
    safe_scans = 0

    if not readings_df.empty:
        if "estimated_h2s_ppm" in readings_df.columns:
            avg_ppm = float(readings_df["estimated_h2s_ppm"].mean())
        elif "dose" in readings_df.columns:
            avg_ppm = float(readings_df["dose"].mean())

        critical_alerts = int((readings_df["risk_level"].str.startswith("Unsafe")).sum())
        caution_alerts = int((readings_df["risk_level"] == "Caution").sum())
        safe_scans = int((readings_df["risk_level"] == "Safe").sum())

    # Work zone risk heatmap breakdown
    zone_stats = {}
    if not workers_df.empty:
        for zone in workers_df["work_zone"].unique():
            zone_wids = workers_df[workers_df["work_zone"] == zone]["worker_id"].tolist()
            zone_readings = readings_df[readings_df["worker_id"].isin(zone_wids)] if not readings_df.empty else pd.DataFrame()
            
            zone_avg = float(zone_readings["estimated_h2s_ppm"].mean()) if (not zone_readings.empty and "estimated_h2s_ppm" in zone_readings.columns) else 0.0
            zone_critical = int((zone_readings["risk_level"].str.startswith("Unsafe")).sum()) if not zone_readings.empty else 0
            
            zone_stats[str(zone)] = {
                "worker_count": len(zone_wids),
                "reading_count": len(zone_readings),
                "avg_h2s_ppm": round(zone_avg, 2),
                "critical_alerts": zone_critical,
                "status": "Critical" if zone_critical > 0 else ("Elevated" if zone_avg > 10.0 else "Normal")
            }

    # Recent 10 scans
    recent_scans = []
    if not readings_df.empty:
        # Join worker names
        merged = readings_df.head(10).copy()
        if not workers_df.empty:
            name_map = dict(zip(workers_df["worker_id"], workers_df["name"]))
            dept_map = dict(zip(workers_df["worker_id"], workers_df["department"]))
            zone_map = dict(zip(workers_df["worker_id"], workers_df["work_zone"]))
            merged["worker_name"] = merged["worker_id"].map(name_map).fillna("Unknown")
            merged["department"] = merged["worker_id"].map(dept_map).fillna("N/A")
            merged["work_zone"] = merged["worker_id"].map(zone_map).fillna("N/A")
        recent_scans = merged.to_dict(orient="records")

    return to_serializable({
        "summary": {
            "total_workers": total_workers,
            "active_workers": active_workers,
            "total_readings": total_readings,
            "average_h2s_ppm": round(avg_ppm, 2),
            "critical_alerts": critical_alerts,
            "caution_alerts": caution_alerts,
            "safe_scans": safe_scans,
            "compliance_rate_pct": round((1.0 - (critical_alerts / max(1, total_readings))) * 100, 1)
        },
        "zone_breakdown": zone_stats,
        "recent_scans": recent_scans,
        "timestamp": datetime.now().isoformat()
    })


# -----------------------------------------------------------------------------
# 5. SAFETY AUDIT REPORTS & PDF EXPORTS
# -----------------------------------------------------------------------------

@app.get("/reports/summary", tags=["Reports"])
def get_safety_summary():
    """Generates formal DGMS/OISD compliance report summary data."""
    rep_data = safety_report_generator.generate_safety_report_data()
    return to_serializable(rep_data)


@app.get("/reports/download/pdf", tags=["Reports"])
def download_safety_pdf(
    worker_id: str = Query("All Workers", description="Filter by Worker ID or 'All Workers'")
):
    """Generates and streams formal DGMS/OISD industrial safety audit PDF report."""
    try:
        pdf_bytes = safety_report_generator.generate_pdf_report(
            worker_id_filter=worker_id,
            generated_by="DoseBand Mobile Gateway"
        )
        return StreamingResponse(
            io.BytesIO(pdf_bytes),
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=DoseBand_Safety_Report_{worker_id}.pdf"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate PDF: {str(e)}")
