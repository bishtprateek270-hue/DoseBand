"""
DoseBand - Industrial H2S Gas Exposure Dosimeter Reader & Worker Safety Web App.

Designed to mirror DGMS (Directorate General of Mines Safety) and OISD (Oil Industry Safety Directorate)
occupational health reporting standards for real-time hazardous gas monitoring.
"""

from datetime import datetime, date, timedelta
import os
import re
import sys

import cv2
import numpy as np
import pandas as pd
from PIL import Image
import importlib
import streamlit as st

import calibration
import database
importlib.reload(database)
import dose_model
import environmental_compensation
importlib.reload(environmental_compensation)
import exposure_forecaster
importlib.reload(exposure_forecaster)
import expiry_checker
import generate_test_images
import inference_engine
importlib.reload(inference_engine)
import qr_manager
importlib.reload(qr_manager)
import quality_validator
importlib.reload(quality_validator)
import roi_detector
importlib.reload(roi_detector)
import safety_report_generator
importlib.reload(safety_report_generator)
import strip_reader
import strip_validator
importlib.reload(strip_validator)
import train_all_models
import train_reference_models

# Train ML models on empirical calibration & expiry datasets at startup if missing
if not os.path.exists("dose_model.pkl") or not os.path.exists("expiry_classifier.pkl"):
    train_all_models.main()

if not os.path.exists("models/h2s_demo_model.joblib") or not os.path.exists("models/humidity_demo_model.joblib"):
    train_reference_models.train_all_reference_models()

# Auto-generate annotated test images with box labels & gradient line indicators
generate_test_images.generate_all_test_assets()

# -----------------------------------------------------------------------------
# CONSTANTS & CONFIGURATION
# -----------------------------------------------------------------------------
# Placeholder cumulative threshold per OSHA / DGMS / OISD H2S exposure guidelines
UNSAFE_CUMULATIVE_THRESHOLD: float = 50.0  # ppm * hours

# Directory containing sample test images
TEST_IMAGES_DIR = "test_images"

# Initialize database table at app startup
database.init_db()

# Configure Streamlit page layout - MUST be the first Streamlit command
st.set_page_config(
    page_title="DoseBand - Industrial H2S Dosimeter Reader",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for Industrial Safety Theme (Navy Blues & Safety Orange Accents)
st.markdown(
    """
    <style>
        /* Primary theme variables */
        :root {
            --primary-navy: #0F172A;
            --secondary-slate: #1E293B;
            --safety-orange: #EA580C;
            --light-bg: #F8FAFC;
            --border-color: #E2E8F0;
        }

        .main-header {
            font-size: 2.3rem;
            font-weight: 800;
            color: var(--text-color, #0F172A) !important;
            margin-top: 0.2rem;
            margin-bottom: 0.2rem;
            letter-spacing: -0.02em;
        }

        .sub-header {
            font-size: 1.05rem;
            color: var(--text-color, #334155) !important;
            opacity: 0.95;
            margin-bottom: 1.2rem;
            font-weight: 500;
        }

        .brand-badge {
            background-color: rgba(234, 88, 12, 0.15) !important;
            color: #EA580C !important;
            padding: 5px 14px !important;
            border-radius: 9999px !important;
            font-weight: 800 !important;
            font-size: 0.82rem !important;
            display: inline-block !important;
            margin-top: 0.25rem !important;
            margin-bottom: 0.6rem !important;
            border: 1.5px solid rgba(234, 88, 12, 0.45) !important;
            letter-spacing: 0.04em !important;
        }

        .section-header {
            color: var(--text-color, inherit) !important;
            font-size: 1.35rem;
            font-weight: 700;
            margin-top: 1.2rem;
            margin-bottom: 0.5rem;
        }

        .icon-card {
            background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%);
            color: #F8FAFC;
            padding: 3rem 2rem;
            border-radius: 1.2rem;
            text-align: center;
            box-shadow: 0 10px 25px -5px rgba(15, 23, 42, 0.25);
            border: 1px solid #334155;
        }

        .icon-card h2 {
            font-size: 4.5rem;
            margin-bottom: 0.5rem;
        }

        .icon-card h3 {
            color: #FB923C;
            font-weight: 800;
            margin-bottom: 0.5rem;
        }

        .icon-card p {
            font-size: 1.05rem;
            color: #E2E8F0;
        }

        /* Streamlit Metric card readability and anti-truncation */
        [data-testid="stMetricValue"] {
            font-size: 1.6rem !important;
            font-weight: 800 !important;
            white-space: normal !important;
            word-break: break-word !important;
            line-height: 1.2 !important;
        }

        [data-testid="stMetricLabel"] {
            font-size: 0.90rem !important;
            font-weight: 700 !important;
            white-space: normal !important;
            word-break: break-word !important;
            color: var(--text-color, #1E293B) !important;
        }

        [data-testid="stMetricDelta"] {
            font-weight: 700 !important;
            white-space: normal !important;
            font-size: 0.82rem !important;
        }

        /* High-contrast captions & subtitle texts */
        [data-testid="stCaptionContainer"], .stCaption {
            font-size: 0.86rem !important;
            font-weight: 500 !important;
            color: var(--text-color, #334155) !important;
            opacity: 0.95 !important;
        }

        /* High-contrast code tags */
        code {
            font-weight: 700 !important;
            padding: 2px 6px !important;
            border-radius: 4px !important;
        }

        /* Centered max-width container with generous top padding to clear Streamlit header bar */
        .block-container {
            max-width: 1350px !important;
            padding-top: 4.5rem !important;
            padding-bottom: 2.5rem !important;
            margin: 0 auto !important;
        }

        /* Responsive image preview constraints */
        [data-testid="stImage"] {
            display: flex !important;
            justify-content: center !important;
            align-items: center !important;
        }

        [data-testid="stImage"] img {
            max-height: 400px !important;
            max-width: 100% !important;
            object-fit: contain !important;
            margin: 0 auto !important;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
        }

        /* Chart height and zoom responsiveness constraints */
        [data-testid="stVegaLiteChart"], .stChart {
            max-height: 380px !important;
            max-width: 100% !important;
        }
    </style>
""",
    unsafe_allow_html=True,
)

# Sidebar Navigation with branding
st.sidebar.markdown("## 🛡️ **DoseBand**")
st.sidebar.caption("Industrial Safety Engineering Platform")
st.sidebar.divider()

page = st.sidebar.radio("Navigation Menu", ["Home", "Scan Strip", "Workers", "Dashboard"])

st.sidebar.divider()
st.sidebar.markdown(
    "<div style='font-size: 0.8rem; color: #64748B;'>"
    "<b>Team DoseBand</b><br>"
    "DGMS / OISD H₂S Safety Compliance<br>"
    "Version 1.0.0 (Hackathon Build)"
    "</div>",
    unsafe_allow_html=True
)

# -----------------------------------------------------------------------------
# PAGE 1: HOME
# -----------------------------------------------------------------------------
if page == "Home":
    st.markdown("<span class='brand-badge'>SAFETY FIRST • INDUSTRIAL DOSIMETRY</span>", unsafe_allow_html=True)
    st.markdown("<h1 class='main-header'>🛡️ DoseBand</h1>", unsafe_allow_html=True)
    st.markdown(
        "<p class='sub-header'>Scan your exposure wristband to track cumulative H2S dose</p>",
        unsafe_allow_html=True,
    )

    st.divider()

    col1, col2 = st.columns([3, 2], gap="large")

    with col1:
        st.subheader("Industrial H₂S Safety Monitoring Platform")
        st.write(
            """
            Welcome to **DoseBand**, an intelligent optical dosimeter platform designed for real-time analysis
            of Hydrogen Sulfide (H₂S) wristband sensors in hazardous industrial environments.
            
            - 🏷️ **Worker Tracking:** Automated identification and cumulative exposure dose logging.
            - 📸 **Camera & File Calibration:** Per-channel Ordinary Least Squares (OLS) lighting correction.
            - 🧪 **Colorimetric Analytics:** Perception-aligned HSV Value ($V$) channel staining intensity score.
            - 🚨 **DGMS/OISD Reporting:** Automated cumulative limit alerts and SQLite safety database logging.
            """
        )
        
        st.info("👈 Select **Scan Strip** from the sidebar menu to process a worker's sensor strip.")

        # Offline-friendly note for hackathon judges
        st.caption(
            "📌 **Note:** Production version supports offline scanning with delayed sync — "
            "this hackathon build assumes local connectivity for the SQLite demo."
        )

    with col2:
        st.markdown(
            """
            <div class="icon-card">
                <h2>⌚️☣️</h2>
                <h3>DoseBand Optical Dosimeter</h3>
                <p>Real-time optical colorimetric dosimetry for field worker safety</p>
                <div style="margin-top: 1.5rem; font-size: 0.85rem; color: #EA580C; font-weight: 600;">
                    DEVELOPED BY TEAM DOSEBAND
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

# -----------------------------------------------------------------------------
# PAGE 2: SCAN STRIP
# -----------------------------------------------------------------------------
elif page == "Scan Strip":
    st.title("📸 Scan Sensor Strip")
    st.caption(
        "Select a registered worker and provide a photo of the exposure wristband"
        " alongside the reference color scale."
    )

    col1, col2 = st.columns([1, 1], gap="large")

    with col1:
        st.subheader("Step 1: Worker Identification")
        
        id_method = st.radio(
            "Worker Identification Method",
            ["📷 Scan / Upload QR Badge (Automated)", "📋 Manual Directory Selection (Fallback)"],
            horizontal=True
        )

        worker_id_clean = ""
        is_worker_id_valid = False

        if id_method == "📷 Scan / Upload QR Badge (Automated)":
            qr_source_type = st.radio(
                "QR Code Input Source",
                ["Upload QR Badge Image", "Live Camera QR Scan", "Quick Test with Sample Badge QR"],
                horizontal=True
            )

            qr_bytes_input = None

            if qr_source_type == "Upload QR Badge Image":
                uploaded_qr_file = st.file_uploader(
                    "Upload Worker Dosimeter Badge QR",
                    type=["png", "jpg", "jpeg"],
                    key="qr_badge_file_uploader"
                )
                if uploaded_qr_file is not None:
                    qr_bytes_input = uploaded_qr_file.getvalue()

            elif qr_source_type == "Live Camera QR Scan":
                cam_qr_file = st.camera_input(
                    "Photograph Worker Dosimeter Badge QR Code",
                    key="qr_badge_cam_input"
                )
                if cam_qr_file is not None:
                    qr_bytes_input = cam_qr_file.getvalue()

            else:  # Quick Test with Sample Badge QR
                df_workers_avail = database.get_all_workers()
                if not df_workers_avail.empty:
                    sample_qr_opts = [
                        f"{r['worker_id']} — {r['name']} (Badge: {r['badge_id'] if 'badge_id' in r and pd.notna(r['badge_id']) and r['badge_id'] else 'BDG-' + str(r['worker_id']).replace('W-', '')})"
                        for _, r in df_workers_avail.iterrows()
                    ]
                    selected_sample_worker = st.selectbox("Select Worker Badge to Test:", sample_qr_opts)
                    sel_wid = selected_sample_worker.split(" — ")[0].strip()
                    sample_w_profile = database.get_worker_by_id(sel_wid)
                    if sample_w_profile:
                        badge_val = sample_w_profile.get("badge_id") or f"BDG-{sample_w_profile['worker_id'].replace('W-', '')}"
                        qr_bytes_input = qr_manager.generate_badge_qr_png(
                            sample_w_profile["worker_id"],
                            badge_val
                        )
                        st.image(qr_bytes_input, caption=f"Simulated QR for {sample_w_profile['name']}", width=160)
                else:
                    st.warning("No workers in database to generate test badge.")

            if qr_bytes_input is not None:
                decoded_wid, decoded_bid, raw_payload = qr_manager.decode_qr_from_image_bytes(qr_bytes_input)

                if not decoded_wid and not decoded_bid:
                    if raw_payload:
                        st.error(
                            "❌ **Foreign / Invalid QR Code:** The scanned QR code is NOT an official DoseBand badge generated by this platform. "
                            "External URLs, personal QR codes, and third-party barcodes are strictly blocked."
                        )
                    else:
                        st.error(
                            "❌ **QR Detection Failed:** Could not detect or decode a QR code in the provided image. "
                            "Please ensure the official DoseBand badge QR is clear, well-lit, and in focus."
                        )
                else:
                    val_result = qr_manager.validate_badge_profile(decoded_wid, decoded_bid)

                    if val_result["valid"]:
                        w_info = val_result["worker"]
                        worker_id_clean = w_info["worker_id"]
                        is_worker_id_valid = True

                        st.success(f"✅ **QR Badge Verified:** `{w_info['badge_id']}` linked to **{w_info['name']}** ({w_info['worker_id']})")

                        # Rich Verified Profile Badge Card
                        st.markdown(
                            f"""
                            <div style="background-color: #1E293B; border-left: 4px solid #10B981; padding: 0.85rem 1rem; border-radius: 0.5rem; margin-top: 0.5rem; margin-bottom: 0.5rem; border: 1px solid #334155;">
                                <div style="display: flex; justify-content: space-between; align-items: center;">
                                    <strong style="color: #FFFFFF; font-size: 1rem;">👤 {w_info['name']} ({w_info['worker_id']})</strong>
                                    <span style="background-color: #10B981; color: #FFFFFF; font-size: 0.75rem; font-weight: 800; padding: 3px 10px; border-radius: 9999px; letter-spacing: 0.03em;">
                                        QR VERIFIED • ACTIVE
                                    </span>
                                </div>
                                <div style="font-size: 0.86rem; color: #E2E8F0; margin-top: 0.45rem; line-height: 1.5;">
                                    🏭 <b style="color: #FFFFFF;">Dept:</b> {w_info['department']} &nbsp;|&nbsp; 📍 <b style="color: #FFFFFF;">Zone:</b> {w_info['work_zone']}<br>
                                    ⏰ <b style="color: #FFFFFF;">Shift:</b> {w_info['shift']}<br>
                                    🏷️ <b style="color: #FFFFFF;">Badge ID:</b> <code style="color: #FB923C; background-color: #0F172A; padding: 2px 6px; border-radius: 4px; font-weight: 700;">{w_info['badge_id']}</code> &nbsp;|&nbsp; 📅 <b style="color: #FFFFFF;">Expiry:</b> {w_info['badge_expiry_date']}
                                </div>
                            </div>
                            """,
                            unsafe_allow_html=True
                        )
                    else:
                        st.error(f"🚨 **Safety & Badge Verification Alert:** {val_result['message']}")
                        if val_result.get("worker"):
                            w_err = val_result["worker"]
                            st.warning(
                                f"Worker Found: **{w_err['name']}** ({w_err['worker_id']}) | "
                                f"Status: `{w_err['status']}` | Badge Expiry: `{w_err['badge_expiry_date']}`"
                            )
            else:
                st.info("📷 Please upload, capture, or select a Worker QR Badge above to identify the worker.")

        else:  # Manual Directory Selection (Fallback)
            df_registered_workers = database.get_all_workers()

            if not df_registered_workers.empty:
                worker_options = [
                    f"{row['worker_id']} — {row['name']} ({row['department']} | {row['work_zone']})"
                    for _, row in df_registered_workers.iterrows()
                ]
                selected_worker_str = st.selectbox(
                    "Select Registered Worker*",
                    options=worker_options,
                    help="Select worker by ID, Name, Department, or Work Zone"
                )
                worker_id_clean = selected_worker_str.split(" — ")[0].strip()

                # Display rich worker profile metadata card
                worker_info = database.get_worker_by_id(worker_id_clean)
                if worker_info:
                    # Check badge expiry status and active status
                    try:
                        exp_date = datetime.strptime(worker_info["badge_expiry_date"], "%Y-%m-%d").date()
                        is_badge_date_expired = exp_date < date.today()
                        days_left = (exp_date - date.today()).days
                    except Exception:
                        is_badge_date_expired = False
                        days_left = 999

                    is_worker_active = (worker_info.get("status") == "Active")
                    is_worker_id_valid = bool(is_worker_active and not is_badge_date_expired)

                    status_badge_color = "#10B981" if (is_worker_active and not is_badge_date_expired) else "#EF4444"
                    status_label = worker_info["status"]
                    if is_badge_date_expired:
                        status_label = "Badge Expired"

                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border-left: 4px solid {status_badge_color}; padding: 0.85rem 1rem; border-radius: 0.5rem; margin-top: 0.5rem; margin-bottom: 0.5rem; border: 1px solid #334155;">
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <strong style="color: #FFFFFF; font-size: 1rem;">👤 {worker_info['name']} ({worker_info['worker_id']})</strong>
                                <span style="background-color: {status_badge_color}; color: #FFFFFF; font-size: 0.75rem; font-weight: 800; padding: 3px 10px; border-radius: 9999px; letter-spacing: 0.03em;">
                                    {status_label.upper()}
                                </span>
                            </div>
                            <div style="font-size: 0.86rem; color: #E2E8F0; margin-top: 0.45rem; line-height: 1.5;">
                                🏭 <b style="color: #FFFFFF;">Dept:</b> {worker_info['department']} &nbsp;|&nbsp; 📍 <b style="color: #FFFFFF;">Zone:</b> {worker_info['work_zone']}<br>
                                ⏰ <b style="color: #FFFFFF;">Shift:</b> {worker_info['shift']}<br>
                                🏷️ <b style="color: #FFFFFF;">Badge ID:</b> <code style="color: #FB923C; background-color: #0F172A; padding: 2px 6px; border-radius: 4px; font-weight: 700;">{worker_info['badge_id']}</code> &nbsp;|&nbsp; 📅 <b style="color: #FFFFFF;">Expiry:</b> {worker_info['badge_expiry_date']}
                            </div>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                    if is_badge_date_expired:
                        st.error(f"🚨 **Badge Expired:** Dosimeter Badge `{worker_info['badge_id']}` expired on {worker_info['badge_expiry_date']}. Analysis and exposure recording are strictly blocked.")
                    elif not is_worker_active:
                        st.error(f"🚨 **Worker Inactive:** Worker status is '{worker_info['status']}'. Analysis and exposure recording are strictly blocked.")
                    elif days_left <= 7:
                        st.caption(f"⏳ Badge `{worker_info['badge_id']}` expires soon ({days_left} days remaining).")
                else:
                    is_worker_id_valid = False
            else:
                st.warning("⚠️ No registered workers found in database. Please register workers on the **Workers** page.")
                worker_id_clean = ""
                is_worker_id_valid = False

        st.subheader("Step 2: Provide Image")

        input_mode = st.radio(
            "Select Image Source Mode",
            ["Sample Test Images / File Upload", "Live Camera Input"],
            horizontal=True
        )

        image_bytes_to_process = None

        if input_mode == "Sample Test Images / File Upload":
            # List all sample images from test_images/ folder if available
            available_samples = []
            if os.path.exists(TEST_IMAGES_DIR):
                available_samples = sorted(
                    [f for f in os.listdir(TEST_IMAGES_DIR) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
                )

            sample_options = ["Upload Custom Image"] + [f"Sample: {f}" for f in available_samples]
            selected_sample = st.selectbox("Select Sample Test Image or Upload", options=sample_options)

            if selected_sample.startswith("Sample: "):
                sample_filename = selected_sample.replace("Sample: ", "")
                sample_filepath = os.path.join(TEST_IMAGES_DIR, sample_filename)
                if os.path.exists(sample_filepath):
                    with open(sample_filepath, "rb") as f:
                        image_bytes_to_process = f.read()
            else:
                uploaded_file = st.file_uploader("Upload Image File", type=["jpg", "jpeg", "png"])
                if uploaded_file is not None:
                    image_bytes_to_process = uploaded_file.getvalue()

        else: # Live Camera Input
            camera_file = st.camera_input("Photograph the strip next to the reference color scale")
            if camera_file is not None:
                image_bytes_to_process = camera_file.getvalue()

        # Operational parameters (Automated optical humidity extraction via KNN model)
        ambient_temp = 25.0
        exposure_time = 1.0
        humidity_input_mode = "🤖 Optical Humidity Card (KNN)"
        manual_humidity = None

    with col2:
        st.subheader("Step 3: Badge Preview & Verification")
        is_quality_valid = False
        is_strip_valid = False
        rois_detected = False
        quality_diag = None
        strip_val_res = None
        roi_detections = None
        preview_bgr = None

        if image_bytes_to_process is not None:
            # Decode image buffer for pre-flight quality validation, strip validation, and ROI extraction
            file_bytes = np.frombuffer(image_bytes_to_process, dtype=np.uint8)
            preview_bgr = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

            if preview_bgr is not None:
                # 1. Image Quality Evaluation (Focus, Sharpness, Exposure)
                quality_diag = quality_validator.evaluate_image_quality(preview_bgr)
                is_quality_valid = quality_diag["is_valid_for_analysis"]

                # 2. Mandatory Test-Strip Multi-Criteria Validation
                strip_val_res = strip_validator.validate_test_strip(preview_bgr)
                is_strip_valid = strip_val_res["is_valid"]
                strip_val_score = strip_val_res["validation_score"]
                strip_val_pct = strip_val_res["confidence_pct"]
                strip_val_status = strip_val_res["status"]

                roi_detections = roi_detector.detect_all_rois(preview_bgr)
                is_standalone_strip = (roi_detections.get("badge_mode") == "STANDALONE_CHEMICAL_STRIP")

                if is_standalone_strip:
                    ref_ok = True
                    strip_ok = is_strip_valid
                    hum_ok = True
                    calib_ok = True
                    rois_detected = is_strip_valid
                    is_quality_valid = is_strip_valid
                else:
                    # Check required ROIs for Full DoseBand Badge
                    ref_ok = quality_diag["ref_scale_detected"] and (strip_val_res["checks"]["reference_scale"]["score"] >= 0.40)
                    strip_ok = quality_diag["sensor_strip_detected"] and is_strip_valid
                    if humidity_input_mode == "🤖 Optical Humidity Card (KNN)":
                        hum_ok = (roi_detections["humidity_indicator"]["confidence"] >= 0.50)
                    else:
                        hum_ok = (manual_humidity is not None)
                    calib_ok = quality_diag["calibration_successful"] and is_strip_valid
                    rois_detected = bool(ref_ok and strip_ok and hum_ok)

                # Show preview tabs: Annotated Multi-ROI Visual Overlay vs Raw Image
                tab_preview_roi, tab_preview_raw = st.tabs(["🎯 Detected ROIs Overlay", "📷 Original Photo"])
                
                with tab_preview_roi:
                    annotated_img = roi_detector.draw_roi_visual_overlay(preview_bgr, roi_detections)
                    annotated_rgb = cv2.cvtColor(annotated_img, cv2.COLOR_BGR2RGB)
                    st.image(annotated_rgb, caption="Detected Sensor Regions & Central Sampling Zones", use_container_width=True)

                with tab_preview_raw:
                    st.image(image_bytes_to_process, caption="Original Dosimeter Photo", use_container_width=True)

                # -------------------------------------------------------------
                # MANDATORY TEST-STRIP VALIDATION DASHBOARD
                # -------------------------------------------------------------
                st.markdown("<h4 class='section-header'>🛡️ Mandatory Test-Strip Validation</h4>", unsafe_allow_html=True)

                if strip_val_status == "Valid":
                    badge_label = "VERIFIED STRIP" if is_standalone_strip else "VERIFIED BADGE"
                    badge_desc = "Physical chemical test strip (textured/plain paper) verified." if is_standalone_strip else "DoseBand H₂S badge structure & 5-step reference scale verified."
                    strip_badge_html = f"""
                    <div style="background-color: #1E293B; border: 1px solid #10B981; border-left: 4px solid #10B981; border-radius: 0.5rem; padding: 0.75rem 1rem; margin-bottom: 0.75rem; display: flex; align-items: center; justify-content: space-between;">
                        <div>
                            <strong style="color: #34D399; font-size: 1rem;">🟢 Test Strip: VALID ({strip_val_pct}%)</strong>
                            <div style="color: #F1F5F9; font-size: 0.84rem; margin-top: 2px;">{badge_desc}</div>
                        </div>
                        <span style="background-color: #10B981; color: #FFFFFF; font-size: 0.75rem; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.03em;">
                            {badge_label}
                        </span>
                    </div>
                    """
                elif strip_val_status == "Uncertain":
                    strip_badge_html = f"""
                    <div style="background-color: #1E293B; border: 1px solid #F59E0B; border-left: 4px solid #F59E0B; border-radius: 0.5rem; padding: 0.75rem 1rem; margin-bottom: 0.75rem;">
                        <div style="display: flex; align-items: center; justify-content: space-between;">
                            <strong style="color: #FBBF24; font-size: 1rem;">🟡 Test Strip: UNCERTAIN ({strip_val_pct}%)</strong>
                            <span style="background-color: #F59E0B; color: #FFFFFF; font-size: 0.75rem; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.03em;">
                                RETAKE RECOMMENDED
                            </span>
                        </div>
                        <div style="color: #FEF3C7; font-size: 0.84rem; margin-top: 4px;">{strip_val_res['user_message']}</div>
                    </div>
                    """
                else:
                    strip_badge_html = f"""
                    <div style="background-color: #1E293B; border: 1px solid #EF4444; border-left: 4px solid #EF4444; border-radius: 0.5rem; padding: 0.75rem 1rem; margin-bottom: 0.75rem;">
                        <div style="display: flex; align-items: center; justify-content: space-between;">
                            <strong style="color: #F87171; font-size: 1rem;">🔴 Test Strip: INVALID ({strip_val_pct}%)</strong>
                            <span style="background-color: #EF4444; color: #FFFFFF; font-size: 0.75rem; font-weight: 800; padding: 4px 12px; border-radius: 9999px; letter-spacing: 0.03em;">
                                UNSUPPORTED IMAGE
                            </span>
                        </div>
                        <div style="color: #FEE2E2; font-size: 0.84rem; margin-top: 4px;">{strip_val_res['user_message']}</div>
                    </div>
                    """
                st.markdown(strip_badge_html, unsafe_allow_html=True)

                # Validation Score Criteria Breakdown for Diagnostics
                with st.expander("🔬 Validation Score Breakdown (6-Criteria Analysis)", expanded=False):
                    bd = strip_val_res.get("breakdown", {})
                    bd_c1, bd_c2, bd_c3 = st.columns(3)
                    check_keys = list(bd.keys())
                    for i, k in enumerate(check_keys):
                        item = bd[k]
                        target_col = bd_c1 if i % 3 == 0 else (bd_c2 if i % 3 == 1 else bd_c3)
                        item_score = item['score_pct']
                        score_color = "#34D399" if item_score >= 75 else ("#FBBF24" if item_score >= 50 else "#F87171")
                        with target_col:
                            st.markdown(
                                f"""
                                <div style="background-color: #0F172A; border: 1px solid #334155; padding: 0.5rem 0.75rem; border-radius: 0.35rem; margin-bottom: 0.4rem;">
                                    <div style="font-size: 0.76rem; color: #CBD5E1; font-weight: 600;">{item['name']} ({item['weight_pct']}%)</div>
                                    <strong style="color: {score_color}; font-size: 0.95rem;">
                                        {item_score:.1f}%
                                    </strong>
                                    <span style="font-size: 0.75rem; color: #94A3B8;"> (+{item['weighted_points']:.1f} pts)</span>
                                </div>
                                """,
                                unsafe_allow_html=True
                            )

                if not is_strip_valid:
                    st.error(
                        "⚠️ **Optical Alignment Error:** Unable to detect a valid DoseBand H₂S dosimeter strip/badge in the camera frame. "
                        "Please align the strip flat within the frame under steady, uniform lighting."
                    )

                # -------------------------------------------------------------
                # PRE-FLIGHT SCAN QUALITY & REGION VERIFICATION
                # -------------------------------------------------------------
                st.markdown("<h4 class='section-header'>🔬 Pre-Flight Scan Quality & Regions</h4>", unsafe_allow_html=True)

                # 4 Core Indicator Cards
                ind_col1, ind_col2, ind_col3, ind_col4 = st.columns(4)

                with ind_col1:
                    ref_text = '✅ Direct Optical Strip' if is_standalone_strip else ('✅ Monotonic (5-Step)' if ref_ok else '❌ Missing / Invalid')
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border: 1px solid #334155; border-left: 3px solid {'#10B981' if ref_ok else '#EF4444'}; padding: 0.65rem 0.8rem; border-radius: 0.4rem;">
                            <div style="font-size: 0.76rem; color: #CBD5E1; font-weight: 600;">📌 Reference Scale</div>
                            <strong style="color: {'#4ADE80' if ref_ok else '#F87171'}; font-size: 0.85rem;">
                                {ref_text}
                            </strong>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                with ind_col2:
                    strip_text = '✅ Verified Paper Strip' if is_standalone_strip else ('✅ Verified Paper' if strip_ok else '❌ Rejected')
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border: 1px solid #334155; border-left: 3px solid {'#10B981' if strip_ok else '#EF4444'}; padding: 0.65rem 0.8rem; border-radius: 0.4rem;">
                            <div style="font-size: 0.76rem; color: #CBD5E1; font-weight: 600;">🧪 H2S Sensor Strip</div>
                            <strong style="color: {'#4ADE80' if strip_ok else '#F87171'}; font-size: 0.85rem;">
                                {strip_text}
                            </strong>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                with ind_col3:
                    hum_text = '✅ Auto 50% Standard' if is_standalone_strip else ('✅ Card Detected' if (humidity_input_mode.startswith('🤖') and hum_ok) else ('✅ Manual Set' if hum_ok else '❌ Not Available'))
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border: 1px solid #334155; border-left: 3px solid {'#10B981' if hum_ok else '#EF4444'}; padding: 0.65rem 0.8rem; border-radius: 0.4rem;">
                            <div style="font-size: 0.76rem; color: #CBD5E1; font-weight: 600;">💧 Humidity Source</div>
                            <strong style="color: {'#4ADE80' if hum_ok else '#F87171'}; font-size: 0.85rem;">
                                {hum_text}
                            </strong>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                with ind_col4:
                    calib_text = '✅ Feasible (Direct Pixel)' if is_standalone_strip else ('✅ Feasible (OLS)' if calib_ok else '❌ Infeasible')
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border: 1px solid #334155; border-left: 3px solid {'#10B981' if calib_ok else '#EF4444'}; padding: 0.65rem 0.8rem; border-radius: 0.4rem;">
                            <div style="font-size: 0.76rem; color: #CBD5E1; font-weight: 600;">💡 Lighting Calibration</div>
                            <strong style="color: {'#4ADE80' if calib_ok else '#F87171'}; font-size: 0.85rem;">
                                {calib_text}
                            </strong>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )
        else:
            st.info("📷 Image preview will appear here after selecting a sample, uploading a file, or taking a photo.")

        # Unified prerequisite verification gate
        env_params_valid = bool(ambient_temp is not None and exposure_time is not None and exposure_time > 0)
        prediction_allowed = bool(
            is_worker_id_valid and
            (image_bytes_to_process is not None) and
            (preview_bgr is not None) and
            is_strip_valid and
            is_quality_valid and
            rois_detected and
            env_params_valid
        )

        analyze_clicked = st.button(
            "🔍 Analyze Dosimeter Badge", disabled=not prediction_allowed, type="primary", use_container_width=True
        )

        if not prediction_allowed and image_bytes_to_process is not None:
            if not is_worker_id_valid:
                st.caption("🔒 *Analysis blocked: Worker badge is expired, inactive, or unverified. Please resolve worker credentials above.*")
            elif not is_strip_valid:
                st.caption("🔒 *Analysis disabled: Please position a valid DoseBand H₂S dosimeter strip with clear chemical paper in view.*")
            elif not is_quality_valid:
                st.caption("🔒 *Analysis disabled: Please resolve image blur/lighting quality issues indicated above (Retake Required).*")
            elif not rois_detected:
                st.caption("🔒 *Analysis disabled: Required chemical test strip region could not be detected.*")
            elif not env_params_valid:
                st.caption("🔒 *Analysis disabled: Please provide valid shift duration and environmental parameters.*")

    # -------------------------------------------------------------------------
    # FULL-WIDTH ANALYSIS & DOSIMETRY RESULTS SECTION
    # -------------------------------------------------------------------------
    if analyze_clicked and prediction_allowed and image_bytes_to_process is not None and preview_bgr is not None:
        st.divider()
        st.markdown("<h3 class='section-header'>📊 Gas Dosimetry & Worker Exposure Results</h3>", unsafe_allow_html=True)

        with st.spinner("Executing multi-ROI lighting compensation, Humidity KNN & H2S inference..."):
            try:
                pipeline = inference_engine.get_inference_pipeline()
                inf_res = pipeline.run_full_inference(
                    image_bgr=preview_bgr,
                    temperature_c=ambient_temp,
                    exposure_time_h=exposure_time,
                    manual_humidity_override=manual_humidity
                )

                if not inf_res.get("is_valid", False):
                    st.error(f"🚨 **Analysis Blocked:** {inf_res.get('user_message', 'Validation failed.')}")
                    st.stop()

                # Optical expiry patch check (only for full badges that contain the expiry patch)
                if is_standalone_strip:
                    is_optical_expired = False
                    expiry_status_msg = "Physical Chemical Test Strip (Active)"
                else:
                    expiry_res = expiry_checker.check_badge_validity(preview_bgr)
                    is_optical_expired = expiry_res.get("is_expired", False)
                    expiry_status_msg = expiry_res.get("status_message", "")

                # Unified Badge Validity Gate (Profile Active/Unexpired AND Optical Patch Unexpired)
                is_badge_fully_valid = is_worker_id_valid and not is_optical_expired

                if not is_badge_fully_valid:
                    # Expired or invalid badge -> Strictly BLOCK saving and classification
                    st.error("🚨 **Badge Invalid / Expired:** Badge invalid/expired — replace badge before recording exposure.")
                    st.warning("⚠️ **DIAGNOSTIC PREVIEW ONLY — EXPOSURE NOT SAVED TO DATABASE.** "
                               "This badge is expired or inactive. Cumulative exposure, worker history, and compliance records have NOT been updated.")

                    # Expiry Status Banner
                    st.error(f"❌ **Badge Expiry Status:** {expiry_status_msg}")

                    # Diagnostic-only metrics grid
                    m_col1, m_col2, m_col3, m_col4 = st.columns(4)
                    with m_col1:
                        st.metric(
                            "Estimated H₂S Gas (Preview)",
                            f"{inf_res['estimated_h2s_ppm']:.2f} ppm",
                            help="Diagnostic preview only. Not recorded to worker history."
                        )
                    with m_col2:
                        st.metric(
                            "Relative Humidity",
                            f"{inf_res['predicted_humidity']:.1f}% RH",
                            help=f"Source: {inf_res['humidity_source']}"
                        )
                    with m_col3:
                        st.metric(
                            "Cumulative Exposure",
                            "Not Recorded",
                            delta="BLOCKED (EXPIRED)",
                            delta_color="inverse",
                            help="Exposure logging is strictly blocked for expired badges."
                        )
                    with m_col4:
                        st.metric(
                            "Badge Status",
                            "EXPIRED / BLOCKED",
                            delta="Replace Badge",
                            delta_color="inverse",
                            help="Replace badge with active dosimeter."
                        )

                else:
                    # VALID BADGE -> Save to SQLite database with session-state deduplication
                    import hashlib
                    raw_img_sha = hashlib.sha256(image_bytes_to_process).hexdigest()
                    current_scan_hash = hashlib.sha256(
                        f"{worker_id_clean}_{raw_img_sha}_{ambient_temp:.1f}_{exposure_time:.2f}_{manual_humidity}_{inf_res['estimated_h2s_ppm']:.2f}".encode()
                    ).hexdigest()

                    if st.session_state.get("last_saved_scan_hash") != current_scan_hash:
                        record_id = database.insert_reading(
                            worker_id=worker_id_clean,
                            intensity=inf_res["staining_intensity"],
                            dose=inf_res["cumulative_dose_ppm_h"],
                            risk_level=inf_res["risk_level"],
                            is_expired=False,
                            expiry_status_message=expiry_status_msg,
                            temperature=ambient_temp,
                            humidity=inf_res["predicted_humidity"],
                            raw_intensity=inf_res["staining_intensity"],
                            corrected_intensity=inf_res["staining_intensity"],
                            compensation_factor=1.0,
                            predicted_humidity=inf_res["predicted_humidity"],
                            exposure_time=exposure_time,
                            strip_intensity=inf_res["staining_intensity"],
                            estimated_h2s_ppm=inf_res["estimated_h2s_ppm"],
                            data_source="CALIBRATED_OPTICAL_DOSIMETRY_MODEL"
                        )
                        st.session_state["last_saved_scan_hash"] = current_scan_hash
                        st.session_state["last_saved_record_id"] = record_id
                    else:
                        record_id = st.session_state.get("last_saved_record_id", "Logged")

                    cumulative_dose = database.get_cumulative_dose(worker_id_clean)

                    st.success(f"✅ **Analysis Complete & Logged!** Record ID `#{record_id}` saved against Worker `{worker_id_clean}`.")

                    # Primary Metrics Grid - Full Width 4 Columns
                    m_col1, m_col2, m_col3, m_col4 = st.columns(4)
                    with m_col1:
                        st.metric(
                            "Estimated H₂S Gas",
                            f"{inf_res['estimated_h2s_ppm']:.2f} ppm",
                            help="Predicted by trained reference model using corrected strip RGB/HSV/intensity"
                        )
                    with m_col2:
                        st.metric(
                            "Relative Humidity",
                            f"{inf_res['predicted_humidity']:.1f}% RH",
                            help=f"Source: {inf_res['humidity_source']} (Clamped: 20–90% RH)"
                        )
                    with m_col3:
                        st.metric(
                            "Shift Cumulative Exposure",
                            f"{inf_res['cumulative_dose_ppm_h']:.2f} ppm·h",
                            delta=f"Total: {cumulative_dose:.2f} ppm·h",
                            help="Shift dose (estimated ppm × hours) and total worker cumulative exposure"
                        )
                    with m_col4:
                        rel_label = inf_res.get("reliability_label", "High Reliability")
                        conf_val = inf_res.get("confidence_pct", 95)
                        st.metric(
                            "Prediction Reliability",
                            f"{conf_val}%",
                            delta=rel_label,
                            delta_color="normal" if conf_val >= 80 else "inverse",
                            help="Composite score: Test-strip validation + multi-ROI detection + lighting calibration"
                        )

                    # Environmental & Reliability Context Line - Full Width
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; color: #F1F5F9; border: 1px solid #334155; border-left: 3px solid #38BDF8; padding: 0.65rem 1rem; border-radius: 0.4rem; font-size: 0.86rem; margin-top: 0.75rem; margin-bottom: 0.75rem;">
                            👤 <b style="color: #FFFFFF;">Worker:</b> <code style="color: #38BDF8; background-color: #0F172A; padding: 2px 6px; border-radius: 4px;">{worker_id_clean}</code> &nbsp;|&nbsp; 
                            🌡️ <b style="color: #FFFFFF;">Ambient Temp:</b> <code style="color: #38BDF8; background-color: #0F172A; padding: 2px 6px; border-radius: 4px;">{ambient_temp:.1f} °C</code> &nbsp;|&nbsp; 
                            ⏱️ <b style="color: #FFFFFF;">Shift Duration:</b> <code style="color: #FBBF24; background-color: #0F172A; padding: 2px 6px; border-radius: 4px;">{exposure_time:.1f} hrs</code> &nbsp;|&nbsp; 
                            💧 <b style="color: #FFFFFF;">Humidity Source:</b> <code style="color: #34D399; background-color: #0F172A; padding: 2px 6px; border-radius: 4px;">{inf_res['humidity_source']}</code> &nbsp;|&nbsp; 
                            🛡️ <b style="color: #FFFFFF;">Scan Confidence:</b> <code style="color: #C084FC; background-color: #0F172A; padding: 2px 6px; border-radius: 4px;">{inf_res.get('reliability_label', 'High Reliability')} ({inf_res.get('confidence_pct', 95)}%)</code>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                    # Risk Level Banner - Full Width
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border: 1px solid #334155; border-left: 4px solid {inf_res['risk_color']}; padding: 0.9rem 1.1rem; border-radius: 0.5rem; margin-top: 0.75rem; margin-bottom: 0.75rem;">
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <strong style="color: #FFFFFF; font-size: 1.05rem;">🛡️ Risk Classification: <span style="color: {inf_res['risk_color']}; font-weight: 800;">{inf_res['risk_level']}</span></strong>
                                <span style="background-color: {inf_res['risk_color']}; color: #FFFFFF; font-size: 0.78rem; font-weight: 800; padding: 4px 14px; border-radius: 4px; letter-spacing: 0.05em;">
                                    {inf_res['risk_level'].upper()}
                                </span>
                            </div>
                            <p style="font-size: 0.88rem; color: #F1F5F9; margin-top: 0.45rem; margin-bottom: 0; line-height: 1.45;">
                                📋 <b style="color: #FFFFFF;">Action Guidance:</b> {inf_res['action_guidance']}
                            </p>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                    # Expiry Status Banner
                    st.info(f"✅ **Badge Expiry Status:** {expiry_status_msg}")

                # Extracted Sensor ROIs & Features in Full-Width Expander
                with st.expander("🔬 View Extracted Sensor ROIs & Optical Color Features", expanded=False):
                    roi_v_col1, roi_v_col2 = st.columns(2)
                    
                    with roi_v_col1:
                        h2s_b = inf_res["roi_detections"]["h2s_strip"]["box"]
                        h2s_crop = preview_bgr[h2s_b[1]:h2s_b[3], h2s_b[0]:h2s_b[2]]
                        if h2s_crop.size > 0:
                            st.image(cv2.cvtColor(h2s_crop, cv2.COLOR_BGR2RGB), caption="Detected H2S Sensor Strip ROI (Center Sampled)", use_container_width=True)
                        h_feat = inf_res["h2s_features"]
                        st.markdown(
                            f"""
                            <div style="background-color: #0F172A; color: #E2E8F0; padding: 0.6rem 0.85rem; border-radius: 0.4rem; font-size: 0.82rem; margin-top: 0.35rem; border: 1px solid #334155;">
                                🎨 <b style="color: #FFFFFF;">H2S Optical Features:</b> RGB: <code style="color: #38BDF8; background-color: #1E293B; padding: 1px 5px; border-radius: 3px;">({h_feat['mean_r']:.1f}, {h_feat['mean_g']:.1f}, {h_feat['mean_b']:.1f})</code> &nbsp;|&nbsp; 
                                HSV: <code style="color: #F472B6; background-color: #1E293B; padding: 1px 5px; border-radius: 3px;">(H={h_feat['hue']:.1f}, S={h_feat['sat']:.1f}, V={h_feat['val']:.1f})</code> &nbsp;|&nbsp; 
                                Grayscale: <code style="color: #FBBF24; background-color: #1E293B; padding: 1px 5px; border-radius: 3px;">{h_feat['gray']:.1f}</code>
                            </div>
                            """,
                            unsafe_allow_html=True
                        )

                    with roi_v_col2:
                        hum_b = inf_res["roi_detections"]["humidity_indicator"]["box"]
                        hum_crop = preview_bgr[hum_b[1]:hum_b[3], hum_b[0]:hum_b[2]]
                        if hum_crop.size > 0:
                            st.image(cv2.cvtColor(hum_crop, cv2.COLOR_BGR2RGB), caption="Detected Humidity Card ROI (Central Disc)", use_container_width=True)
                        u_feat = inf_res["humidity_features"]
                        st.markdown(
                            f"""
                            <div style="background-color: #0F172A; color: #E2E8F0; padding: 0.6rem 0.85rem; border-radius: 0.4rem; font-size: 0.82rem; margin-top: 0.35rem; border: 1px solid #334155;">
                                💧 <b style="color: #FFFFFF;">Humidity Optical Features:</b> RGB: <code style="color: #38BDF8; background-color: #1E293B; padding: 1px 5px; border-radius: 3px;">({u_feat['mean_r']:.1f}, {u_feat['mean_g']:.1f}, {u_feat['mean_b']:.1f})</code> &nbsp;|&nbsp; 
                                HSV: <code style="color: #F472B6; background-color: #1E293B; padding: 1px 5px; border-radius: 3px;">(H={u_feat['hue']:.1f}, S={u_feat['sat']:.1f}, V={u_feat['val']:.1f})</code>
                            </div>
                            """,
                            unsafe_allow_html=True
                        )

# -----------------------------------------------------------------------------
# PAGE 3: WORKERS
# -----------------------------------------------------------------------------
elif page == "Workers":
    st.markdown("<span class='brand-badge'>PERSONNEL & DOSIMETRY LOGISTICS</span>", unsafe_allow_html=True)
    st.markdown("<h1 class='main-header'>👷 Worker & Badge Management</h1>", unsafe_allow_html=True)
    st.markdown(
        "<p class='sub-header'>Safety Officer Console — Register, track, update, and manage plant personnel, work zones, shifts, and optical dosimeter badges.</p>",
        unsafe_allow_html=True,
    )

    df_workers = database.get_all_workers()

    # Calculate real-time KPI metrics
    total_workers = len(df_workers)
    active_workers = len(df_workers[df_workers["status"] == "Active"]) if not df_workers.empty else 0
    
    # Calculate badges expired or expiring in <= 7 days
    expired_badges_count = 0
    expiring_soon_count = 0
    today_date = date.today()
    if not df_workers.empty:
        for _, w in df_workers.iterrows():
            try:
                exp_d = datetime.strptime(w["badge_expiry_date"], "%Y-%m-%d").date()
                if exp_d < today_date or w["status"] != "Active":
                    expired_badges_count += 1
                elif (exp_d - today_date).days <= 7:
                    expiring_soon_count += 1
            except Exception:
                pass

    total_zones = df_workers["work_zone"].nunique() if not df_workers.empty else 0

    # Metric Cards row
    kpi_col1, kpi_col2, kpi_col3, kpi_col4 = st.columns(4)
    with kpi_col1:
        st.metric("Total Registered Workers", total_workers)
    with kpi_col2:
        st.metric("Active Personnel", active_workers)
    with kpi_col3:
        st.metric("Expired / Expiring Badges", f"{expired_badges_count + expiring_soon_count}")
    with kpi_col4:
        st.metric("Monitored Work Zones", total_zones)

    st.divider()

    # Worker Management Tabs
    tab_dir, tab_add, tab_edit, tab_del = st.tabs([
        "📋 Worker Directory",
        "➕ Register Worker",
        "✏️ Edit Worker",
        "🗑️ Delete Worker"
    ])

    # -------------------------------------------------------------------------
    # TAB 1: WORKER DIRECTORY
    # -------------------------------------------------------------------------
    with tab_dir:
        if df_workers.empty:
            st.info("ℹ️ No workers currently registered. Use the **'Register Worker'** tab to add personnel.")
        else:
            # Filter bar
            f_col1, f_col2, f_col3, f_col4 = st.columns([2, 1, 1, 1])
            with f_col1:
                search_query = st.text_input("🔍 Search Personnel", placeholder="Filter by Name, Worker ID, or Badge ID...").strip().lower()
            with f_col2:
                dept_options = ["All Departments"] + sorted(df_workers["department"].unique().tolist())
                selected_dept = st.selectbox("Department", options=dept_options)
            with f_col3:
                zone_options = ["All Work Zones"] + sorted(df_workers["work_zone"].unique().tolist())
                selected_zone = st.selectbox("Work Zone", options=zone_options)
            with f_col4:
                status_options = ["All Statuses"] + sorted(df_workers["status"].unique().tolist())
                selected_status = st.selectbox("Status", options=status_options)

            # Apply filters
            df_filtered = df_workers.copy()
            if search_query:
                df_filtered = df_filtered[
                    df_filtered["worker_id"].str.lower().str.contains(search_query, na=False) |
                    df_filtered["name"].str.lower().str.contains(search_query, na=False) |
                    df_filtered["badge_id"].str.lower().str.contains(search_query, na=False)
                ]
            if selected_dept != "All Departments":
                df_filtered = df_filtered[df_filtered["department"] == selected_dept]
            if selected_zone != "All Work Zones":
                df_filtered = df_filtered[df_filtered["work_zone"] == selected_zone]
            if selected_status != "All Statuses":
                df_filtered = df_filtered[df_filtered["status"] == selected_status]

            # Add Badge Validity Flag & Cumulative Dose column
            def compute_badge_status(row):
                try:
                    exp_d = datetime.strptime(row["badge_expiry_date"], "%Y-%m-%d").date()
                    if row["status"] != "Active":
                        return "⏸️ Inactive"
                    if exp_d < today_date:
                        return "❌ EXPIRED"
                    if (exp_d - today_date).days <= 7:
                        return f"⏳ Expiring ({(exp_d - today_date).days}d)"
                    return "✅ Active"
                except Exception:
                    return row["status"]

            df_filtered["Badge Health"] = df_filtered.apply(compute_badge_status, axis=1)
            df_filtered["Cumulative H₂S (ppm*hr)"] = df_filtered["worker_id"].apply(
                lambda wid: f"{database.get_cumulative_dose(wid):.2f}"
            )

            st.caption(f"Showing **{len(df_filtered)}** of **{len(df_workers)}** registered workers.")

            display_cols = [
                "worker_id",
                "name",
                "department",
                "work_zone",
                "shift",
                "badge_id",
                "badge_issue_date",
                "badge_expiry_date",
                "Badge Health",
                "Cumulative H₂S (ppm*hr)"
            ]
            
            st.dataframe(
                df_filtered[display_cols].rename(
                    columns={
                        "worker_id": "Worker ID",
                        "name": "Full Name",
                        "department": "Department",
                        "work_zone": "Work Zone",
                        "shift": "Shift",
                        "badge_id": "Badge ID",
                        "badge_issue_date": "Issue Date",
                        "badge_expiry_date": "Expiry Date",
                    }
                ),
                use_container_width=True,
                hide_index=True
            )

            # Worker Detail Dossier Card
            st.markdown("#### 🔍 Worker Safety Dossier")
            worker_ids_list = df_filtered["worker_id"].tolist()
            if worker_ids_list:
                sel_inspect_id = st.selectbox(
                    "Inspect Worker Details",
                    options=worker_ids_list,
                    format_func=lambda wid: f"{wid} — {df_workers[df_workers['worker_id'] == wid]['name'].values[0]}"
                )
                w_profile = database.get_worker_by_id(sel_inspect_id)
                w_cum_dose = database.get_cumulative_dose(sel_inspect_id)
                w_readings = database.get_readings_for_worker(sel_inspect_id)

                dossier_c1, dossier_c2, dossier_c3 = st.columns([1.1, 0.9, 1.0], gap="medium")
                with dossier_c1:
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border-radius: 0.75rem; padding: 1.15rem; border: 1px solid #334155; height: 100%;">
                            <div style="display: flex; align-items: center; gap: 1rem; margin-bottom: 0.75rem;">
                                <div style="background: #0F172A; border-radius: 50%; width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; border: 2px solid #F97316;">
                                    👷
                                </div>
                                <div>
                                    <h3 style="margin: 0; color: #F8FAFC; font-size: 1.15rem;">{w_profile['name']}</h3>
                                    <span style="color: #F97316; font-weight: 700; font-size: 0.85rem;">{w_profile['worker_id']}</span> &nbsp;|&nbsp; 
                                    <span style="color: #94A3B8; font-size: 0.85rem;">{w_profile['status']}</span>
                                </div>
                            </div>
                            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.4rem; font-size: 0.82rem; color: #CBD5E1; margin-top: 0.75rem;">
                                <div><b>Department:</b><br><span style="color: #F8FAFC;">{w_profile['department']}</span></div>
                                <div><b>Work Zone:</b><br><span style="color: #F8FAFC;">{w_profile['work_zone']}</span></div>
                                <div><b>Shift:</b><br><span style="color: #F8FAFC;">{w_profile['shift']}</span></div>
                                <div><b>Badge ID:</b><br><code style="color: #F97316;">{w_profile['badge_id']}</code></div>
                                <div><b>Issue Date:</b><br><span style="color: #F8FAFC;">{w_profile['badge_issue_date']}</span></div>
                                <div><b>Expiry Date:</b><br><span style="color: #F8FAFC;">{w_profile['badge_expiry_date']}</span></div>
                            </div>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                with dossier_c2:
                    st.markdown("##### ⚡ Exposure & Health")
                    st.metric(
                        "Cumulative H₂S Dose",
                        f"{w_cum_dose:.2f} ppm*hr",
                        delta=f"{UNSAFE_CUMULATIVE_THRESHOLD - w_cum_dose:.2f} ppm*hr remaining" if w_cum_dose < UNSAFE_CUMULATIVE_THRESHOLD else "EXCEEDED LIMIT",
                        delta_color="normal" if w_cum_dose < UNSAFE_CUMULATIVE_THRESHOLD else "inverse"
                    )
                    
                    # Exposure threshold progress bar
                    progress_val = min(1.0, max(0.0, w_cum_dose / UNSAFE_CUMULATIVE_THRESHOLD))
                    st.progress(progress_val, text=f"Limit ({w_cum_dose:.1f} / {UNSAFE_CUMULATIVE_THRESHOLD:.1f} ppm*hr)")
                    st.caption(f"Total Scans Logged: **{len(w_readings)}** records.")

                with dossier_c3:
                    st.markdown("##### 📱 Smart QR Badge")
                    badge_card_png = qr_manager.generate_styled_badge_card(w_profile)
                    raw_qr_png = qr_manager.generate_badge_qr_png(w_profile["worker_id"], w_profile["badge_id"])
                    
                    st.image(badge_card_png, caption="Printable Safety Badge Card", use_container_width=True)
                    
                    btn_c1, btn_c2 = st.columns(2)
                    with btn_c1:
                        st.download_button(
                            label="🖨️ Badge Card",
                            data=badge_card_png,
                            file_name=f"doseband_badge_{w_profile['badge_id']}.png",
                            mime="image/png",
                            use_container_width=True
                        )
                    with btn_c2:
                        st.download_button(
                            label="📱 Raw QR",
                            data=raw_qr_png,
                            file_name=f"doseband_qr_{w_profile['badge_id']}.png",
                            mime="image/png",
                            use_container_width=True
                        )

            # CSV Download
            csv_workers = df_filtered.to_csv(index=False)
            st.download_button(
                label="📥 Download Worker Registry CSV",
                data=csv_workers,
                file_name=f"doseband_workers_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                mime="text/csv",
                type="primary"
            )

    # -------------------------------------------------------------------------
    # TAB 2: REGISTER NEW WORKER
    # -------------------------------------------------------------------------
    with tab_add:
        st.subheader("➕ Register New Plant Personnel & Assign Dosimeter Badge")
        st.caption("All fields are mandatory. Worker ID and Badge ID must be globally unique.")

        with st.form("register_worker_form", clear_on_submit=False):
            form_c1, form_c2 = st.columns(2, gap="medium")
            
            with form_c1:
                new_worker_id = st.text_input("Worker ID*", placeholder="e.g., W-106").strip()
                new_name = st.text_input("Full Name*", placeholder="e.g., Kavita Sharma").strip()
                
                dept_choices = [
                    "Refinery Operations",
                    "Pipeline Maintenance",
                    "Safety & Inspection",
                    "Chemical Laboratory",
                    "Drilling & Extraction",
                    "Storage & Flare Area",
                    "Utilities & Power Plant",
                    "Quality Assurance & Control"
                ]
                new_dept = st.selectbox("Department*", options=dept_choices)
                
                zone_choices = [
                    "Zone A - Crude Distillation Unit",
                    "Zone B - Desulfurization Plant",
                    "Zone C - Storage & Flare Area",
                    "Zone D - Quality Control Lab",
                    "Zone E - Wellhead Platform",
                    "Zone F - Effluent Treatment Unit",
                    "Zone G - Gas Compressor Station"
                ]
                new_zone = st.selectbox("Work Zone / Unit*", options=zone_choices)

            with form_c2:
                shift_choices = [
                    "Shift 1 (06:00 - 14:00)",
                    "Shift 2 (14:00 - 22:00)",
                    "Shift 3 (22:00 - 06:00)",
                    "General Shift (09:00 - 17:00)"
                ]
                new_shift = st.selectbox("Shift Assignment*", options=shift_choices)
                new_status = st.selectbox("Worker Status*", options=["Active", "Inactive", "On Leave"])
                
                new_badge_id = st.text_input("Dosimeter Badge ID*", placeholder="e.g., BDG-106").strip()
                
                date_c1, date_c2 = st.columns(2)
                with date_c1:
                    new_issue_date = st.date_input("Badge Issue Date*", value=date.today())
                with date_c2:
                    new_expiry_date = st.date_input("Badge Expiry Date*", value=date.today() + timedelta(days=60))

            submit_reg = st.form_submit_button("🛡️ Register Worker & Issue Badge", type="primary", use_container_width=True)

            if submit_reg:
                # Validation checks
                if not new_worker_id or not new_name or not new_badge_id:
                    st.error("⚠️ Worker ID, Full Name, and Badge ID are mandatory fields.")
                elif not re.match(r"^[a-zA-Z0-9_-]{3,15}$", new_worker_id):
                    st.error("⚠️ Worker ID must be 3-15 alphanumeric characters (e.g., W-106).")
                elif not re.match(r"^[a-zA-Z0-9_-]{3,15}$", new_badge_id):
                    st.error("⚠️ Badge ID must be 3-15 alphanumeric characters (e.g., BDG-106).")
                elif new_expiry_date < new_issue_date:
                    st.error("⚠️ Badge Expiry Date cannot be earlier than Badge Issue Date.")
                else:
                    # Check if worker_id already exists
                    existing_worker = database.get_worker_by_id(new_worker_id)
                    existing_badge = database.get_worker_by_badge_id(new_badge_id)

                    if existing_worker:
                        st.error(f"❌ Worker ID `{new_worker_id}` is already registered for worker **{existing_worker['name']}**.")
                    elif existing_badge:
                        st.error(f"❌ Badge ID `{new_badge_id}` is already assigned to worker **{existing_badge['name']}** (`{existing_badge['worker_id']}`).")
                    else:
                        try:
                            database.insert_worker(
                                worker_id=new_worker_id,
                                name=new_name,
                                department=new_dept,
                                work_zone=new_zone,
                                shift=new_shift,
                                badge_id=new_badge_id,
                                badge_issue_date=new_issue_date.isoformat(),
                                badge_expiry_date=new_expiry_date.isoformat(),
                                status=new_status
                            )
                            st.success(f"✅ Worker **{new_name}** (`{new_worker_id}`) registered successfully with Badge `{new_badge_id}`!")
                            st.rerun()
                        except Exception as e:
                            st.error(f"❌ Failed to register worker: {e}")

    # -------------------------------------------------------------------------
    # TAB 3: EDIT WORKER
    # -------------------------------------------------------------------------
    with tab_edit:
        st.subheader("✏️ Edit Registered Worker Profile")
        if df_workers.empty:
            st.info("ℹ️ No registered workers available to edit.")
        else:
            worker_edit_list = df_workers["worker_id"].tolist()
            edit_worker_id = st.selectbox(
                "Select Worker to Edit",
                options=worker_edit_list,
                format_func=lambda wid: f"{wid} — {df_workers[df_workers['worker_id'] == wid]['name'].values[0]} ({df_workers[df_workers['worker_id'] == wid]['department'].values[0]})"
            )

            curr_worker = database.get_worker_by_id(edit_worker_id)
            if curr_worker:
                with st.form("edit_worker_form"):
                    e_col1, e_col2 = st.columns(2, gap="medium")
                    
                    with e_col1:
                        st.text_input("Worker ID (Immutable)", value=curr_worker["worker_id"], disabled=True)
                        edit_name = st.text_input("Full Name*", value=curr_worker["name"]).strip()
                        
                        dept_options = [
                            "Refinery Operations",
                            "Pipeline Maintenance",
                            "Safety & Inspection",
                            "Chemical Laboratory",
                            "Drilling & Extraction",
                            "Storage & Flare Area",
                            "Utilities & Power Plant",
                            "Quality Assurance & Control"
                        ]
                        curr_dept = curr_worker["department"]
                        dept_idx = dept_options.index(curr_dept) if curr_dept in dept_options else 0
                        edit_dept = st.selectbox("Department*", options=dept_options, index=dept_idx)
                        
                        zone_options = [
                            "Zone A - Crude Distillation Unit",
                            "Zone B - Desulfurization Plant",
                            "Zone C - Storage & Flare Area",
                            "Zone D - Quality Control Lab",
                            "Zone E - Wellhead Platform",
                            "Zone F - Effluent Treatment Unit",
                            "Zone G - Gas Compressor Station"
                        ]
                        curr_zone = curr_worker["work_zone"]
                        zone_idx = zone_options.index(curr_zone) if curr_zone in zone_options else 0
                        edit_zone = st.selectbox("Work Zone*", options=zone_options, index=zone_idx)

                    with e_col2:
                        shift_options = [
                            "Shift 1 (06:00 - 14:00)",
                            "Shift 2 (14:00 - 22:00)",
                            "Shift 3 (22:00 - 06:00)",
                            "General Shift (09:00 - 17:00)"
                        ]
                        curr_shift = curr_worker["shift"]
                        shift_idx = shift_options.index(curr_shift) if curr_shift in shift_options else 0
                        edit_shift = st.selectbox("Shift Assignment*", options=shift_options, index=shift_idx)
                        
                        status_options = ["Active", "Inactive", "On Leave"]
                        curr_status = curr_worker["status"]
                        status_idx = status_options.index(curr_status) if curr_status in status_options else 0
                        edit_status = st.selectbox("Status*", options=status_options, index=status_idx)
                        
                        edit_badge_id = st.text_input("Badge ID*", value=curr_worker["badge_id"]).strip()
                        
                        try:
                            init_issue = datetime.strptime(curr_worker["badge_issue_date"], "%Y-%m-%d").date()
                        except Exception:
                            init_issue = date.today()
                            
                        try:
                            init_expiry = datetime.strptime(curr_worker["badge_expiry_date"], "%Y-%m-%d").date()
                        except Exception:
                            init_expiry = date.today() + timedelta(days=60)

                        e_date1, e_date2 = st.columns(2)
                        with e_date1:
                            edit_issue_date = st.date_input("Badge Issue Date*", value=init_issue)
                        with e_date2:
                            edit_expiry_date = st.date_input("Badge Expiry Date*", value=init_expiry)

                    submit_edit = st.form_submit_button("💾 Save Changes", type="primary", use_container_width=True)

                    if submit_edit:
                        if not edit_name or not edit_badge_id:
                            st.error("⚠️ Full Name and Badge ID cannot be empty.")
                        elif edit_expiry_date < edit_issue_date:
                            st.error("⚠️ Badge Expiry Date cannot be earlier than Badge Issue Date.")
                        else:
                            # Check if badge_id belongs to another worker
                            badge_owner = database.get_worker_by_badge_id(edit_badge_id)
                            if badge_owner and badge_owner["worker_id"] != edit_worker_id:
                                st.error(f"❌ Badge ID `{edit_badge_id}` is already assigned to worker **{badge_owner['name']}** (`{badge_owner['worker_id']}`).")
                            else:
                                try:
                                    database.update_worker(
                                        worker_id=edit_worker_id,
                                        name=edit_name,
                                        department=edit_dept,
                                        work_zone=edit_zone,
                                        shift=edit_shift,
                                        badge_id=edit_badge_id,
                                        badge_issue_date=edit_issue_date.isoformat(),
                                        badge_expiry_date=edit_expiry_date.isoformat(),
                                        status=edit_status
                                    )
                                    st.success(f"✅ Worker profile for **{edit_name}** (`{edit_worker_id}`) updated successfully!")
                                    st.rerun()
                                except Exception as e:
                                    st.error(f"❌ Failed to update worker: {e}")

    # -------------------------------------------------------------------------
    # TAB 4: DELETE WORKER
    # -------------------------------------------------------------------------
    with tab_del:
        st.subheader("🗑️ Remove Registered Worker")
        if df_workers.empty:
            st.info("ℹ️ No registered workers available to delete.")
        else:
            del_worker_list = df_workers["worker_id"].tolist()
            del_worker_id = st.selectbox(
                "Select Worker to Delete",
                options=del_worker_list,
                format_func=lambda wid: f"{wid} — {df_workers[df_workers['worker_id'] == wid]['name'].values[0]} ({df_workers[df_workers['worker_id'] == wid]['department'].values[0]})"
            )

            worker_to_del = database.get_worker_by_id(del_worker_id)
            if worker_to_del:
                readings_count = len(database.get_readings_for_worker(del_worker_id))
                cum_exposure = database.get_cumulative_dose(del_worker_id)

                st.warning(
                    f"⚠️ You are about to remove **{worker_to_del['name']}** (`{worker_to_del['worker_id']}`). "
                    f"This worker currently has **{readings_count}** logged exposure reading(s) (Cumulative Dose: {cum_exposure:.2f} ppm*hr)."
                )

                confirm_del = st.checkbox(
                    f"I confirm that I want to delete worker **{worker_to_del['worker_id']}** ({worker_to_del['name']}) from the registry."
                )

                btn_delete = st.button("🚨 Delete Worker Permanently", disabled=not confirm_del, type="primary")

                if btn_delete and confirm_del:
                    success = database.delete_worker(del_worker_id)
                    if success:
                        st.success(f"✅ Worker **{worker_to_del['name']}** (`{del_worker_id}`) has been deleted.")
                        st.rerun()
                    else:
                        st.error("❌ Failed to delete worker.")

# -----------------------------------------------------------------------------
# PAGE 4: DASHBOARD
# -----------------------------------------------------------------------------
elif page == "Dashboard":
    # Designed to mirror DGMS/OISD occupational health reporting standards for real-time hazardous gas monitoring.
    st.markdown("<span class='brand-badge'>PLANT OCCUPATIONAL SAFETY CONSOLE</span>", unsafe_allow_html=True)
    st.markdown("<h1 class='main-header'>📊 Industrial Health & Safety Dashboard</h1>", unsafe_allow_html=True)
    st.markdown(
        "<p class='sub-header'>Real-time H₂S occupational dosimetry monitoring, cumulative exposure limits (DGMS / OISD), "
        "and proactive badge shelf-life tracking across plant zones.</p>",
        unsafe_allow_html=True,
    )

    # Fetch live data directly from SQLite database
    df_workers = database.get_all_workers()
    df_readings = database.get_all_readings()
    today_date = date.today()

    # Collect all unique registered / scanned worker IDs
    worker_ids = set()
    if not df_workers.empty:
        worker_ids.update(df_workers["worker_id"].tolist())
    if not df_readings.empty:
        worker_ids.update(df_readings["worker_id"].tolist())

    worker_attention_list = []
    expiry_alerts_list = []
    safe_count = 0
    warning_count = 0
    critical_count = 0
    near_expiry_count = 0

    for wid in sorted(list(worker_ids)):
        w_profile = database.get_worker_by_id(wid) if not df_workers.empty else None
        w_name = w_profile["name"] if w_profile else f"Worker {wid}"
        w_zone = w_profile["work_zone"] if w_profile else "Unassigned Unit"
        w_dept = w_profile["department"] if w_profile else "Operations"
        w_badge = w_profile["badge_id"] if w_profile else "N/A"
        w_status = w_profile["status"] if w_profile else "Active"
        exp_date_str = w_profile["badge_expiry_date"] if w_profile else None

        cum_dose = database.get_cumulative_dose(wid)

        is_badge_expired = False
        is_near_expiry = False
        days_left = 999
        badge_status_text = "✅ Active"

        if exp_date_str:
            try:
                exp_date_val = datetime.strptime(exp_date_str, "%Y-%m-%d").date()
                days_left = (exp_date_val - today_date).days
                if exp_date_val < today_date or w_status != "Active":
                    is_badge_expired = True
                    badge_status_text = f"❌ EXPIRED ({abs(days_left)}d ago)" if exp_date_val < today_date else f"⏸️ {w_status}"
                    expiry_alerts_list.append({
                        "worker_id": wid,
                        "name": w_name,
                        "badge_id": w_badge,
                        "dept": w_dept,
                        "zone": w_zone,
                        "expiry_date": exp_date_str,
                        "days_left": days_left,
                        "severity": "EXPIRED"
                    })
                elif days_left <= 7:
                    is_near_expiry = True
                    badge_status_text = f"⏳ Expiring ({days_left}d left)"
                    expiry_alerts_list.append({
                        "worker_id": wid,
                        "name": w_name,
                        "badge_id": w_badge,
                        "dept": w_dept,
                        "zone": w_zone,
                        "expiry_date": exp_date_str,
                        "days_left": days_left,
                        "severity": "EXPIRING_SOON"
                    })
            except Exception:
                pass

        if is_badge_expired or is_near_expiry:
            near_expiry_count += 1

        latest_risk = "None"
        if not df_readings.empty:
            w_reads = df_readings[df_readings["worker_id"] == wid]
            if not w_reads.empty:
                latest_risk = w_reads.iloc[0]["risk_level"]

        # Risk Classification Logic
        if cum_dose >= UNSAFE_CUMULATIVE_THRESHOLD or latest_risk.startswith("Unsafe"):
            risk_status = "🔴 CRITICAL"
            action_needed = "🚨 Medical review & work stoppage"
            critical_count += 1
            requires_attention = True
            priority_rank = 1
        elif is_badge_expired:
            risk_status = "🔴 BADGE EXPIRED"
            action_needed = "🛑 Prohibit entry; replace dosimeter badge"
            critical_count += 1
            requires_attention = True
            priority_rank = 2
        elif cum_dose >= 10.0 or is_near_expiry or latest_risk.startswith("Caution"):
            risk_status = "🟡 WARNING"
            action_needed = "⚠️ Shift rotation / swap badge"
            warning_count += 1
            requires_attention = True
            priority_rank = 3
        else:
            risk_status = "🟢 SAFE"
            action_needed = "Routine monitoring"
            safe_count += 1
            requires_attention = False
            priority_rank = 4

        if requires_attention:
            worker_attention_list.append({
                "Priority": priority_rank,
                "Worker ID": wid,
                "Name": w_name,
                "Work Zone": w_zone,
                "Cumulative Dose": f"{cum_dose:.2f} ppm*hr",
                "Risk Status": risk_status,
                "Badge Status": badge_status_text,
                "Action Needed": action_needed,
                "raw_cum_dose": cum_dose
            })

    total_workers_count = len(worker_ids)

    # -------------------------------------------------------------------------
    # SECTION 1: INDUSTRIAL SUMMARY KPI CARDS
    # -------------------------------------------------------------------------
    kpi_c1, kpi_c2, kpi_c3, kpi_c4, kpi_c5 = st.columns(5)
    with kpi_c1:
        st.metric(
            label="👥 Total Workers",
            value=total_workers_count,
            help="Total registered workforce tracked in safety database"
        )
    with kpi_c2:
        st.metric(
            label="🟢 Safe Personnel",
            value=safe_count,
            help="Workers within permissible 8-hr TWA limit (< 10.0 ppm*hr) with active badges"
        )
    with kpi_c3:
        st.metric(
            label="🟡 Warning Status",
            value=warning_count,
            help="Workers in caution tier (10 - 50 ppm*hr) or badge expiring in <= 7 days"
        )
    with kpi_c4:
        st.metric(
            label="🔴 Critical Alert",
            value=critical_count,
            help="Workers exceeding safe threshold (≥ 50.0 ppm*hr) or holding expired badges"
        )
    with kpi_c5:
        st.metric(
            label="⏳ Badges Near Expiry",
            value=near_expiry_count,
            help="Dosimeter badges expired or expiring within 7 days"
        )

    st.divider()

    # -------------------------------------------------------------------------
    # SECTION 2: WORKERS REQUIRING ATTENTION
    # -------------------------------------------------------------------------
    st.markdown("<h3 class='section-header'>🚨 Workers Requiring Attention</h3>", unsafe_allow_html=True)
    st.caption("Proactive supervisory action list prioritized by cumulative exposure severity and badge expiry condition.")

    if worker_attention_list:
        # Sort by Priority rank ascending (Critical first), then by cumulative dose descending
        worker_attention_list.sort(key=lambda x: (x["Priority"], -x["raw_cum_dose"]))
        df_attention = pd.DataFrame(worker_attention_list)
        attention_cols = ["Worker ID", "Name", "Work Zone", "Cumulative Dose", "Risk Status", "Badge Status", "Action Needed"]
        st.dataframe(df_attention[attention_cols], use_container_width=True, hide_index=True)
    else:
        st.markdown(
            f"""
            <div style="background-color: rgba(16, 185, 129, 0.15); border: 1px solid #10B981; border-radius: 0.5rem; padding: 1rem; margin-bottom: 1rem; display: flex; align-items: center; justify-content: space-between;">
                <span style="color: #34D399; font-weight: 700; font-size: 1rem;">✅ All Monitored Personnel in Safe Clearance</span>
                <span style="color: #A7F3D0; font-size: 0.85rem;">All {total_workers_count} registered workers are operating below PEL exposure limits with active badges.</span>
            </div>
            """,
            unsafe_allow_html=True
        )

    st.divider()

    # -------------------------------------------------------------------------
    # SECTION 3: EXPOSURE TREND FORECASTING & WORKERS AT RISK
    # -------------------------------------------------------------------------
    st.markdown("<h3 class='section-header'>📈 Exposure Trend Forecasting & Workers At Risk</h3>", unsafe_allow_html=True)
    st.caption("Predictive trend analysis estimating recent exposure accumulation rates and projected time until personnel reach Warning (10.0 ppm*hr) or Critical (50.0 ppm*hr) exposure thresholds.")

    # Disclaimer / Estimation Note
    st.markdown(
        """
        <div style="background-color: #1E293B; border: 1px solid #334155; border-left: 4px solid #3B82F6; padding: 0.75rem 1rem; border-radius: 0.4rem; margin-bottom: 0.85rem;">
            <strong style="color: #60A5FA; font-weight: 800; font-size: 0.88rem;">ℹ️ STATISTICAL PROJECTION NOTICE:</strong>
            <span style="font-size: 0.84rem; color: #F1F5F9; margin-left: 0.35rem; line-height: 1.4;">
                Exposure forecasts are mathematical estimations calculated strictly from real chronological SQLite scan intervals.
                Predictions require a minimum of 2 historical readings per worker to establish a valid accumulation slope.
            </span>
        </div>
        """,
        unsafe_allow_html=True
    )

    all_forecasts = exposure_forecaster.get_all_workers_forecast_summary()

    # Filter into Active Projections vs Insufficient Data
    active_projections = [f for f in all_forecasts if f["status"] in ("active_forecast", "exceeded_critical", "stable")]
    insufficient_workers = [f for f in all_forecasts if f["status"] == "insufficient_data"]

    # Table of Workers At Risk / Forecasting Summary
    if active_projections:
        forecast_table_rows = []
        for f in active_projections:
            rate_str = f"+{f['daily_rate']:.2f} ppm*hr/day" if f['daily_rate'] is not None else "—"
            
            if f["status"] == "exceeded_critical":
                warn_proj = "Exceeded (Critical)"
                crit_proj = "🚨 EXCEEDED (≥50 ppm*hr)"
            elif f["days_to_warning"] is None:
                warn_proj = "In Warning Tier"
                crit_proj = f"~{f['days_to_critical']} days" if f['days_to_critical'] is not None else "—"
            else:
                warn_proj = f"~{f['days_to_warning']} days"
                crit_proj = f"~{f['days_to_critical']} days" if f['days_to_critical'] is not None else "—"

            forecast_table_rows.append({
                "Worker ID": f["worker_id"],
                "Name": f["name"],
                "Work Zone": f["work_zone"],
                "Cumulative Dose": f"{f['cumulative_dose']:.2f} ppm*hr",
                "Daily Rate": rate_str,
                "Proj. to Warning (10 ppm*hr)": warn_proj,
                "Proj. to Critical (50 ppm*hr)": crit_proj,
                "Trend Status": f["trend_badge"],
                "Forecast Projection Message": f["forecast_message"]
            })

        df_fc_table = pd.DataFrame(forecast_table_rows)
        st.dataframe(
            df_fc_table[[
                "Worker ID", "Name", "Work Zone", "Cumulative Dose",
                "Daily Rate", "Proj. to Warning (10 ppm*hr)", "Proj. to Critical (50 ppm*hr)",
                "Trend Status", "Forecast Projection Message"
            ]],
            use_container_width=True,
            hide_index=True
        )

        # Highlight top urgency forecast cards
        top_urgent = [f for f in active_projections if f["status"] in ("active_forecast", "exceeded_critical")]
        if top_urgent:
            st.markdown("##### 🚨 Active Trajectories Requiring Supervisory Attention:")
            for u in top_urgent[:3]:
                if u["status"] == "exceeded_critical":
                    card_bg = "#7F1D1D"
                    card_border = "#EF4444"
                    card_text_color = "#FEE2E2"
                elif u["days_to_warning"] is not None and u["days_to_warning"] <= 7:
                    card_bg = "#78350F"
                    card_border = "#F59E0B"
                    card_text_color = "#FEF3C7"
                else:
                    card_bg = "#1E293B"
                    card_border = "#3B82F6"
                    card_text_color = "#E2E8F0"

                st.markdown(
                    f"""
                    <div style="background-color: {card_bg}; border-left: 4px solid {card_border}; padding: 0.75rem 1rem; border-radius: 0.4rem; margin-bottom: 0.5rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <strong style="color: {card_text_color}; font-size: 0.92rem;">👤 {u['name']} (<code>{u['worker_id']}</code>) — {u['work_zone']}</strong>
                            <span style="background-color: rgba(0,0,0,0.25); color: {card_border}; font-size: 0.75rem; font-weight: 700; padding: 2px 8px; border-radius: 4px;">
                                {u['trend_badge']}
                            </span>
                        </div>
                        <p style="font-size: 0.82rem; color: {card_text_color}; margin-top: 0.35rem; margin-bottom: 0;">
                            {u['forecast_message']}
                        </p>
                    </div>
                    """,
                    unsafe_allow_html=True
                )

    if insufficient_workers:
        insuf_names = ", ".join([f"<b>{w['name']}</b> (<code>{w['worker_id']}</code>)" for w in insufficient_workers])
        st.caption(f"ℹ️ *Insufficient chronological scan history for rate projection (< 2 scans logged):* {insuf_names}. Forecasts will automatically generate as additional shift scans are logged.")

    st.divider()

    # -------------------------------------------------------------------------
    # SECTION 4: BADGE EXPIRY ALERTS
    # -------------------------------------------------------------------------
    st.markdown("<h3 class='section-header'>🛡️ Dosimeter Badge Expiry Alerts</h3>", unsafe_allow_html=True)

    if expiry_alerts_list:
        for alert in expiry_alerts_list:
            if alert["severity"] == "EXPIRED":
                st.markdown(
                    f"""
                    <div style="background-color: #7F1D1D; border-left: 4px solid #EF4444; padding: 0.85rem 1.2rem; border-radius: 0.5rem; margin-bottom: 0.6rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <strong style="color: #FEE2E2; font-size: 0.95rem;">❌ BADGE EXPIRED: {alert['badge_id']}</strong>
                            <span style="background-color: rgba(239, 68, 68, 0.3); color: #FCA5A5; font-size: 0.75rem; font-weight: 700; padding: 2px 8px; border-radius: 4px;">
                                EXPIRED {abs(alert['days_left'])} DAYS AGO ({alert['expiry_date']})
                            </span>
                        </div>
                        <div style="font-size: 0.82rem; color: #FECACA; margin-top: 0.35rem;">
                            Assigned to: <b>{alert['name']}</b> (<code>{alert['worker_id']}</code>) &nbsp;|&nbsp; 
                            Dept: {alert['dept']} &nbsp;|&nbsp; Zone: {alert['zone']}<br>
                            <b>Action:</b> Dosimeter shelf-life exceeded. Confiscate badge and issue new calibrated strip immediately on the Workers page.
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True
                )
            else:
                st.markdown(
                    f"""
                    <div style="background-color: #78350F; border-left: 4px solid #F59E0B; padding: 0.85rem 1.2rem; border-radius: 0.5rem; margin-bottom: 0.6rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <strong style="color: #FEF3C7; font-size: 0.95rem;">⏳ BADGE EXPIRING SOON: {alert['badge_id']}</strong>
                            <span style="background-color: rgba(245, 158, 11, 0.3); color: #FDE68A; font-size: 0.75rem; font-weight: 700; padding: 2px 8px; border-radius: 4px;">
                                {alert['days_left']} DAYS REMAINING ({alert['expiry_date']})
                            </span>
                        </div>
                        <div style="font-size: 0.82rem; color: #FDE68A; margin-top: 0.35rem;">
                            Assigned to: <b>{alert['name']}</b> (<code>{alert['worker_id']}</code>) &nbsp;|&nbsp; 
                            Dept: {alert['dept']} &nbsp;|&nbsp; Zone: {alert['zone']}<br>
                            <b>Action:</b> Schedule replacement before {alert['expiry_date']} to prevent shift disruption.
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True
                )
    else:
        st.markdown(
            """
            <div style="background-color: rgba(16, 185, 129, 0.15); border: 1px solid #10B981; border-radius: 0.5rem; padding: 0.85rem 1rem; margin-bottom: 1rem;">
                <span style="color: #34D399; font-weight: 600; font-size: 0.9rem;">✅ All registered dosimeter badges are within valid operating date ranges.</span>
            </div>
            """,
            unsafe_allow_html=True
        )

    st.divider()

    # -------------------------------------------------------------------------
    # SECTION 4: EXPOSURE ANALYTICS & TIMELINE CHARTS
    # -------------------------------------------------------------------------
    st.markdown("<h3 class='section-header'>📈 Exposure Trends & Worker Comparisons</h3>", unsafe_allow_html=True)

    if df_readings.empty:
        st.info("ℹ️ No scan readings logged yet. Scan sensor strips to generate exposure charts.")
    else:
        unique_workers = sorted(df_readings["worker_id"].unique().tolist())
        view_options = ["All Workers"] + unique_workers
        selected_view = st.selectbox("🔍 Filter View by Worker", options=view_options)

        # Risk Alerts (Cumulative Thresholds)
        if selected_view == "All Workers":
            workers_exceeded = []
            workers_warning = []

            for wid in unique_workers:
                cum_dose = database.get_cumulative_dose(wid)
                if cum_dose >= UNSAFE_CUMULATIVE_THRESHOLD:
                    workers_exceeded.append((wid, cum_dose))
                elif cum_dose >= (UNSAFE_CUMULATIVE_THRESHOLD * 0.70):
                    workers_warning.append((wid, cum_dose))

            for wid, cum_dose in workers_exceeded:
                st.error(
                    f"🚨 **UNSAFE EXPOSURE ALERT:** Worker ID **{wid}** has exceeded safe cumulative H₂S exposure "
                    f"({cum_dose:.2f} ppm*hr / threshold: {UNSAFE_CUMULATIVE_THRESHOLD:.1f} ppm*hr) — immediate medical review required!"
                )

            for wid, cum_dose in workers_warning:
                st.warning(
                    f"⚡ **EXPOSURE WARNING:** Worker ID **{wid}** is approaching safe cumulative limits "
                    f"({cum_dose:.2f} ppm*hr / {int((cum_dose/UNSAFE_CUMULATIVE_THRESHOLD)*100)}% of threshold)."
                )
        else:
            cum_dose = database.get_cumulative_dose(selected_view)
            if cum_dose >= UNSAFE_CUMULATIVE_THRESHOLD:
                st.error(
                    f"🚨 **UNSAFE EXPOSURE ALERT:** Worker ID **{selected_view}** has exceeded safe cumulative H₂S exposure "
                    f"({cum_dose:.2f} ppm*hr) — immediate medical review required!"
                )
            elif cum_dose >= (UNSAFE_CUMULATIVE_THRESHOLD * 0.70):
                st.warning(
                    f"⚡ **EXPOSURE WARNING:** Worker ID **{selected_view}** is approaching safe cumulative limits "
                    f"({cum_dose:.2f} ppm*hr)."
                )

        # Visual Analytics Charts
        chart_c1, chart_c2 = st.columns(2)
        with chart_c1:
            st.subheader("📊 Cumulative Dose per Worker (ppm*hr)")
            worker_totals = df_readings.groupby("worker_id")["dose"].sum()
            st.bar_chart(worker_totals)

        with chart_c2:
            st.subheader(f"📈 Exposure Timeline ({selected_view})")
            if selected_view == "All Workers":
                df_timeline = df_readings.copy()
            else:
                df_timeline = database.get_readings_for_worker(selected_view)
            
            if not df_timeline.empty:
                df_timeline["timestamp_dt"] = pd.to_datetime(df_timeline["timestamp"])
                df_timeline = df_timeline.sort_values("timestamp_dt")
                df_timeline["cumulative_dose"] = df_timeline["dose"].cumsum()
                st.line_chart(df_timeline.set_index("timestamp_dt")["cumulative_dose"])
            else:
                st.caption("No timeline readings available for selected view.")

    st.divider()

    # -------------------------------------------------------------------------
    # SECTION 5: SAFETY AUDIT REPORT GENERATOR (DGMS / OISD)
    # -------------------------------------------------------------------------
    st.markdown("<h3 class='section-header'>📑 Safety Audit Report Generator</h3>", unsafe_allow_html=True)
    st.caption("Generate and export formal DGMS / OISD compliant occupational health audit reports in PDF and CSV formats based on live database records.")

    rc_col1, rc_col2, rc_col3 = st.columns([2, 1, 1])

    with rc_col1:
        rep_worker_options = ["All Workers"] + [
            f"{w['worker_id']} — {w['name']} ({w['department']})"
            for _, w in df_workers.iterrows()
        ] if not df_workers.empty else ["All Workers"]
        selected_rep_worker = st.selectbox("Select Worker Scope for Report:", rep_worker_options)
        rep_wid = "All Workers" if selected_rep_worker == "All Workers" else selected_rep_worker.split(" — ")[0].strip()

    with rc_col2:
        default_start = date.today() - timedelta(days=30)
        rep_start_date = st.date_input("Report Start Date:", value=default_start)

    with rc_col3:
        rep_end_date = st.date_input("Report End Date:", value=date.today())

    if rep_start_date > rep_end_date:
        st.error("⚠️ Start Date cannot be later than End Date.")
    else:
        report_data = safety_report_generator.generate_safety_report_data(
            worker_id_filter=rep_wid,
            start_date=rep_start_date,
            end_date=rep_end_date
        )

        # Executive Report Summary Box
        st.markdown(
            f"""
            <div style="background-color: #1E293B; border: 1px solid #334155; border-left: 4px solid {report_data['compliance_color']}; padding: 1rem 1.25rem; border-radius: 0.5rem; margin-top: 0.5rem; margin-bottom: 0.85rem;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <strong style="color: #FFFFFF; font-size: 1.05rem;">🛡️ {report_data['report_id']}</strong>
                    <span style="background-color: {report_data['compliance_color']}; color: #FFFFFF; font-weight: 800; font-size: 0.80rem; padding: 4px 12px; border-radius: 4px; letter-spacing: 0.03em;">
                        {report_data['overall_compliance']}
                    </span>
                </div>
                <div style="font-size: 0.86rem; color: #E2E8F0; margin-top: 0.45rem; line-height: 1.5;">
                    📌 <b style="color: #FFFFFF;">Scope:</b> {report_data['worker_filter']} &nbsp;|&nbsp; 
                    📅 <b style="color: #FFFFFF;">Period:</b> {report_data['start_date']} to {report_data['end_date']} &nbsp;|&nbsp; 
                    ⏰ <b style="color: #FFFFFF;">Generated:</b> {report_data['generated_at']}
                </div>
            </div>
            """,
            unsafe_allow_html=True
        )

        # Key Report Metrics Row
        rep_m1, rep_m2, rep_m3, rep_m4, rep_m5 = st.columns(5)
        with rep_m1:
            st.metric("Total Scans in Period", report_data["total_scans"])
        with rep_m2:
            st.metric("Cumulative Period Dose", f"{report_data['total_dose']:.2f} ppm*hr")
        with rep_m3:
            st.metric("Mean Scan Dose", f"{report_data['avg_dose']:.2f} ppm*hr")
        with rep_m4:
            st.metric("Peak Single Dose", f"{report_data['max_dose']:.2f} ppm*hr")
        with rep_m5:
            st.metric("Ambient Conditions", f"{report_data['avg_temp']:.1f}°C / {report_data['avg_humidity']:.0f}% RH")

        # Prototype Disclaimer
        st.caption(
            "⚠️ **Prototype Notice:** Ambient temperature and humidity compensation factors reflect an experimental "
            "kinetic prototype model. Official regulatory reporting references uncompensated optical calibration."
        )

        # Download Action Buttons
        pdf_bytes = safety_report_generator.generate_pdf_report(report_data)
        csv_report_data = safety_report_generator.generate_csv_report(report_data)

        dl_col1, dl_col2 = st.columns([1, 1], gap="medium")
        clean_tag = "ALL" if rep_wid == "All Workers" else rep_wid.replace("-", "_")
        
        with dl_col1:
            st.download_button(
                label="📄 Download Official Safety Report (PDF)",
                data=pdf_bytes,
                file_name=f"DoseBand_Safety_Report_{clean_tag}_{datetime.now().strftime('%Y%m%d')}.pdf",
                mime="application/pdf",
                type="primary",
                use_container_width=True
            )
        with dl_col2:
            st.download_button(
                label="📊 Download Safety Audit Logs (CSV)",
                data=csv_report_data,
                file_name=f"DoseBand_Audit_Data_{clean_tag}_{datetime.now().strftime('%Y%m%d')}.csv",
                mime="text/csv",
                use_container_width=True
            )

    st.divider()

    # -------------------------------------------------------------------------
    # SECTION 6: LOGGED READINGS TABLE & CSV EXPORT
    # -------------------------------------------------------------------------
    st.markdown("<h3 class='section-header'>📋 Logged Dosimeter Readings & Environmental Data</h3>", unsafe_allow_html=True)

    if not df_readings.empty:
        if selected_view == "All Workers":
            df_display = df_readings.copy()
        else:
            df_display = database.get_readings_for_worker(selected_view)

        df_display["Badge Validity"] = df_display["is_expired"].apply(
            lambda x: "❌ EXPIRED" if x == 1 else "✅ Valid"
        )

        if "temperature" not in df_display.columns:
            df_display["temperature"] = 25.0
        if "humidity" not in df_display.columns:
            df_display["humidity"] = 50.0
        if "compensation_factor" not in df_display.columns:
            df_display["compensation_factor"] = 1.0
        if "corrected_intensity" not in df_display.columns:
            df_display["corrected_intensity"] = df_display["intensity"]
        if "raw_intensity" not in df_display.columns:
            df_display["raw_intensity"] = df_display["intensity"]

        display_cols = [
            "id",
            "worker_id",
            "timestamp",
            "dose",
            "intensity",
            "temperature",
            "humidity",
            "compensation_factor",
            "corrected_intensity",
            "risk_level",
            "Badge Validity",
            "expiry_status_message",
        ]
        df_table = df_display[display_cols].rename(
            columns={
                "id": "ID",
                "worker_id": "Worker ID",
                "timestamp": "Timestamp",
                "dose": "Dose (ppm*hr)",
                "intensity": "Raw Intensity",
                "temperature": "Temp (°C)",
                "humidity": "RH (%)",
                "compensation_factor": "Comp Factor",
                "corrected_intensity": "Corrected Intensity",
                "risk_level": "Risk Level",
                "expiry_status_message": "Expiry Message",
            }
        )

        st.dataframe(df_table, use_container_width=True, hide_index=True)

        col_export, col_reset = st.columns([2, 2], gap="large")
        with col_export:
            csv_data = df_table.to_csv(index=False)
            st.download_button(
                label="📥 Download readings as CSV",
                data=csv_data,
                file_name=f"doseband_readings_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                mime="text/csv",
                type="primary",
            )

        with col_reset:
            st.markdown("##### 🗑️ Reset Demo Data")
            confirm_reset = st.checkbox("Confirm clearing all logged database readings")
            reset_btn = st.button("Clear Demo Data", disabled=not confirm_reset)

            if reset_btn and confirm_reset:
                database.reset_db()
                st.success("Demo database reset successfully! All readings cleared.")
                st.rerun()
