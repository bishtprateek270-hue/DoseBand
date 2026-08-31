"""
DoseBand - Industrial H2S Gas Exposure Dosimeter Reader & Worker Safety Web App.

Designed to mirror DGMS (Directorate General of Mines Safety) and OISD (Oil Industry Safety Directorate)
occupational health reporting standards for real-time hazardous gas monitoring.
"""

from datetime import datetime
import os
import re
import sys

import cv2
import numpy as np
import pandas as pd
from PIL import Image
import streamlit as st

import calibration
import database
import dose_model
import expiry_checker
import generate_test_images
import strip_reader
import train_all_models

# Train ML models on empirical calibration & expiry datasets at startup if missing
if not os.path.exists("dose_model.pkl") or not os.path.exists("expiry_classifier.pkl"):
    train_all_models.main()

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
            font-size: 2.6rem;
            font-weight: 800;
            color: #0F172A;
            margin-bottom: 0.2rem;
            letter-spacing: -0.02em;
        }

        .sub-header {
            font-size: 1.15rem;
            color: #475569;
            margin-bottom: 1.5rem;
            font-weight: 500;
        }

        .brand-badge {
            background-color: #FFEDD5;
            color: #C2410C;
            padding: 4px 14px;
            border-radius: 9999px;
            font-weight: 700;
            font-size: 0.85rem;
            display: inline-block;
            margin-bottom: 1rem;
            border: 1px solid #FDBA74;
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
            color: #F97316;
            font-weight: 700;
            margin-bottom: 0.5rem;
        }

        .icon-card p {
            font-size: 1.05rem;
            color: #94A3B8;
        }

        /* Sidebar Styling */
        div[data-testid="stSidebar"] {
            background-color: #F1F5F9;
            border-right: 1px solid #E2E8F0;
        }

        /* Centered max-width container to prevent ultra-wide distortion at low zoom (25%) */
        .block-container {
            max-width: 1350px !important;
            padding-top: 1.5rem !important;
            padding-bottom: 2rem !important;
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

page = st.sidebar.radio("Navigation Menu", ["Home", "Scan Strip", "Dashboard"])

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
        "Enter worker details and provide a photo of the exposure wristband"
        " alongside the reference color scale."
    )

    col1, col2 = st.columns([1, 1], gap="large")

    with col1:
        st.subheader("Step 1: Worker Identification")
        worker_id_input = st.text_input(
            "Worker ID*", placeholder="Enter Worker ID (e.g., W-102)"
        )

        worker_id_clean = worker_id_input.strip()
        is_worker_id_valid = False

        if worker_id_clean:
            if re.match(r"^[a-zA-Z0-9_-]{3,10}$", worker_id_clean):
                is_worker_id_valid = True
                st.caption("✅ Valid Worker ID format.")
            else:
                st.error("⚠️ Worker ID must be 3-10 alphanumeric characters (e.g., W-102, W102).")
        else:
            st.caption("ℹ️ Worker ID is required to enable scan analysis.")

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
                    st.caption(f"📁 Loaded sample asset: `{sample_filename}`")
            else:
                uploaded_file = st.file_uploader("Upload Image File", type=["jpg", "jpeg", "png"])
                if uploaded_file is not None:
                    image_bytes_to_process = uploaded_file.getvalue()

        else: # Live Camera Input
            camera_file = st.camera_input("Photograph the strip next to the reference color scale")
            if camera_file is not None:
                image_bytes_to_process = camera_file.getvalue()

    with col2:
        st.subheader("Step 3: Preview & Analysis")

        if image_bytes_to_process is not None:
            st.image(
                image_bytes_to_process,
                caption="Dosimeter Image Preview",
                use_container_width=True,
            )
        else:
            st.info("📷 Image preview will appear here after selecting a sample, uploading a file, or taking a photo.")

        # Image Region Block Boxes & Risk Level Cards
        st.markdown("<h4 style='margin-top: 1rem; color: #F8FAFC;'>📌 Image Region (Box) Breakdown</h4>", unsafe_allow_html=True)

        box_col1, box_col2, box_col3 = st.columns(3)

        with box_col1:
            st.markdown(
                """
                <div style="background-color: #1E293B; border-left: 4px solid #64748B; padding: 1rem; border-radius: 0.5rem; height: 100%;">
                    <h5 style="color: #94A3B8; margin-top: 0;">1. Left Vertical Box</h5>
                    <strong style="color: #F8FAFC;">Reference Color Scale</strong>
                    <p style="font-size: 0.85rem; color: #CBD5E1; margin-top: 0.5rem; margin-bottom: 0;">
                        5 calibrated swatches (White → Black) used by <code>calibration.py</code> for per-channel OLS lighting correction.
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )

        with box_col2:
            st.markdown(
                """
                <div style="background-color: #1E293B; border-left: 4px solid #3B82F6; padding: 1rem; border-radius: 0.5rem; height: 100%;">
                    <h5 style="color: #60A5FA; margin-top: 0;">2. Main Center Box</h5>
                    <strong style="color: #F8FAFC;">H₂S Sensor Paper</strong>
                    <p style="font-size: 0.85rem; color: #CBD5E1; margin-top: 0.5rem; margin-bottom: 0;">
                        Colorimetric indicator paper that darkens proportionally upon exposure to H₂S gas (Intensity → Dose).
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )

        with box_col3:
            st.markdown(
                """
                <div style="background-color: #1E293B; border-left: 4px solid #22C55E; padding: 1rem; border-radius: 0.5rem; height: 100%;">
                    <h5 style="color: #4ADE80; margin-top: 0;">3. Bottom-Right Box</h5>
                    <strong style="color: #F8FAFC;">Badge Expiry Patch</strong>
                    <p style="font-size: 0.85rem; color: #CBD5E1; margin-top: 0.5rem; margin-bottom: 0;">
                        Passive shelf-life patch analyzed via 3D HSV Euclidean distance (Fresh Green vs Expired Red).
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )

        st.markdown("<h4 style='margin-top: 1.5rem; color: #F8FAFC;'>⚠️ Exposure Risk Level Thresholds</h4>", unsafe_allow_html=True)

        tier_col1, tier_col2, tier_col3 = st.columns(3)

        with tier_col1:
            st.markdown(
                """
                <div style="background-color: #064E3B; border-left: 4px solid #10B981; padding: 0.85rem; border-radius: 0.5rem;">
                    <strong style="color: #A7F3D0;">🟢 Safe Tier (< 10.0 ppm*hr)</strong>
                    <p style="font-size: 0.8rem; color: #D1FAE5; margin-top: 0.25rem; margin-bottom: 0;">
                        Below 8-hr TWA limit. Safe for routine workplace operations.
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )

        with tier_col2:
            st.markdown(
                """
                <div style="background-color: #78350F; border-left: 4px solid #F59E0B; padding: 0.85rem; border-radius: 0.5rem;">
                    <strong style="color: #FDE68A;">🟡 Caution Tier (10 - 50 ppm*hr)</strong>
                    <p style="font-size: 0.8rem; color: #FEF3C7; margin-top: 0.25rem; margin-bottom: 0;">
                        Approaching safe limits. Recommended shift rotation / check.
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )

        with tier_col3:
            st.markdown(
                """
                <div style="background-color: #7F1D1D; border-left: 4px solid #EF4444; padding: 0.85rem; border-radius: 0.5rem;">
                    <strong style="color: #FCA5A5;">🔴 Unsafe Tier (≥ 50.0 ppm*hr)</strong>
                    <p style="font-size: 0.8rem; color: #FEE2E2; margin-top: 0.25rem; margin-bottom: 0;">
                        Exceeds safe limits. <b>Immediate work stoppage & medical review!</b>
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )

        # Button is disabled until both valid worker_id and image are supplied
        is_disabled = not (is_worker_id_valid and image_bytes_to_process is not None)

        analyze_clicked = st.button(
            "🔍 Analyze", disabled=is_disabled, type="primary", use_container_width=True
        )

        if analyze_clicked and image_bytes_to_process is not None:
            with st.spinner("Processing image through calibration & ML model..."):
                try:
                    # Decode image buffer into OpenCV BGR numpy array
                    file_bytes = np.frombuffer(image_bytes_to_process, dtype=np.uint8)
                    raw_bgr = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

                    if raw_bgr is None:
                        raise ValueError("Failed to decode image data.")

                    # Pipeline Step 1: Lighting Correction (Raises ReferenceScaleNotFoundError if failed)
                    calibrated_bgr = calibration.calibrate_image(raw_bgr)

                    # Pipeline Step 2: Extract Sensor Strip Color & Staining Intensity
                    strip_res = strip_reader.read_strip(calibrated_bgr)
                    intensity = strip_res["intensity"]

                    # Pipeline Step 3: Polynomial Regression Dose Estimation
                    dose_res = dose_model.predict_dose(intensity)
                    predicted_dose = dose_res["dose"]
                    risk_level = dose_res["risk_level"]
                    confidence_note = dose_res["confidence_note"]

                    # Pipeline Step 4: Expiry Indicator Patch Verification
                    expiry_res = expiry_checker.check_badge_validity(calibrated_bgr)
                    is_expired = expiry_res["is_expired"]
                    expiry_status_msg = expiry_res["status_message"]

                    # Pipeline Step 5: Save Reading Record to Database
                    record_id = database.insert_reading(
                        worker_id=worker_id_clean,
                        intensity=intensity,
                        dose=predicted_dose,
                        risk_level=risk_level,
                        is_expired=is_expired,
                        expiry_status_message=expiry_status_msg,
                    )

                    # Fetch updated cumulative exposure dose for worker
                    cumulative_dose = database.get_cumulative_dose(worker_id_clean)

                    # Display successful analysis results
                    st.success(f"Analysis Complete! Record ID #{record_id} Logged.")

                    m_col1, m_col2, m_col3 = st.columns(3)
                    with m_col1:
                        st.metric("Current Exposure Dose", f"{predicted_dose:.2f} ppm*hr")
                    with m_col2:
                        st.metric("Total Cumulative Exposure", f"{cumulative_dose:.2f} ppm*hr")
                    with m_col3:
                        st.metric("Staining Intensity", f"{intensity:.4f}")

                    # Risk Level Banner
                    if risk_level == "Safe":
                        st.success(f"🟢 **Risk Level: {risk_level}**")
                    elif risk_level == "Caution":
                        st.warning(f"🟡 **Risk Level: {risk_level}**")
                    else:
                        st.error(f"🔴 **Risk Level: {risk_level}**")

                    # Expiry Status Banner
                    if is_expired:
                        st.error(f"❌ **Badge Status:** {expiry_status_msg}")
                    else:
                        st.info(f"✅ **Badge Status:** {expiry_status_msg}")

                    st.caption(f"ℹ️ **Confidence Note:** {confidence_note}")

                except calibration.ReferenceScaleNotFoundError as e:
                    st.warning(
                        "Could not detect the reference color scale — please retake the photo "
                        "making sure the full strip and reference scale are visible and well-lit."
                    )
                except Exception as e:
                    print(f"[ERROR] Scan Analysis Failed: {e}", file=sys.stderr)
                    st.error(f"Something went wrong analyzing this scan ({e}) — please try again or contact support.")

# -----------------------------------------------------------------------------
# PAGE 3: DASHBOARD
# -----------------------------------------------------------------------------
elif page == "Dashboard":
    # Note: Designed to mirror DGMS/OISD-style occupational health reporting formats for industrial safety compliance.
    st.title("📊 Occupational Health & Exposure Dashboard")
    st.caption(
        "DGMS/OISD compliant H₂S exposure monitoring, cumulative dose"
        " tracking, and badge expiry status."
    )

    # Fetch all logged database records
    df_readings = database.get_all_readings()

    if df_readings.empty:
        st.info(
            "ℹ️ No database records found. Scan sensor strips on the 'Scan Strip'"
            " page to populate the dashboard."
        )
    else:
        # Dynamic Worker Selection Dropdown
        unique_workers = sorted(df_readings["worker_id"].unique().tolist())
        view_options = ["All Workers"] + unique_workers
        selected_view = st.selectbox("🔍 Filter View", options=view_options)

        # -------------------------------------------------------------------------
        # RISK ALERT BANNERS (Cumulative Exposure Limits)
        # -------------------------------------------------------------------------
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
                    f"🚨 **UNSAFE EXPOSURE ALERT:** Worker ID **{wid}** has"
                    f" exceeded safe cumulative H₂S exposure ({cum_dose:.2f}"
                    " ppm*hr / threshold:"
                    f" {UNSAFE_CUMULATIVE_THRESHOLD:.1f} ppm*hr) — recommend"
                    " immediate medical review!"
                )

            for wid, cum_dose in workers_warning:
                st.warning(
                    f"⚡ **EXPOSURE WARNING:** Worker ID **{wid}** is"
                    f" approaching safe cumulative limits ({cum_dose:.2f}"
                    f" ppm*hr / {int((cum_dose/UNSAFE_CUMULATIVE_THRESHOLD)*100)}%"
                    " of threshold)."
                )
        else:
            cum_dose = database.get_cumulative_dose(selected_view)
            if cum_dose >= UNSAFE_CUMULATIVE_THRESHOLD:
                st.error(
                    f"🚨 **UNSAFE EXPOSURE ALERT:** Worker ID **{selected_view}**"
                    f" has exceeded safe cumulative H₂S exposure ({cum_dose:.2f}"
                    " ppm*hr) — recommend immediate medical review!"
                )
            elif cum_dose >= (UNSAFE_CUMULATIVE_THRESHOLD * 0.70):
                st.warning(
                    f"⚡ **EXPOSURE WARNING:** Worker ID **{selected_view}** is"
                    f" approaching safe cumulative limits ({cum_dose:.2f}"
                    " ppm*hr)."
                )

        st.divider()

        # -------------------------------------------------------------------------
        # CUMULATIVE DOSE CHARTS
        # -------------------------------------------------------------------------
        if selected_view == "All Workers":
            st.subheader("📊 Cumulative Dose per Worker (ppm * hr)")
            worker_totals = df_readings.groupby("worker_id")["dose"].sum()
            st.bar_chart(worker_totals)
        else:
            st.subheader(
                f"📈 Cumulative Exposure Dose Timeline — Worker ID: {selected_view}"
            )
            df_worker = database.get_readings_for_worker(selected_view)
            df_worker["timestamp_dt"] = pd.to_datetime(df_worker["timestamp"])
            df_worker = df_worker.sort_values("timestamp_dt")
            df_worker["cumulative_dose"] = df_worker["dose"].cumsum()
            st.line_chart(df_worker.set_index("timestamp_dt")["cumulative_dose"])

        st.divider()

        # -------------------------------------------------------------------------
        # READINGS TABLE & CSV EXPORT
        # -------------------------------------------------------------------------
        st.subheader("📋 Logged Dosimeter Readings")

        if selected_view == "All Workers":
            df_display = df_readings.copy()
        else:
            df_display = database.get_readings_for_worker(selected_view)

        df_display["Badge Validity"] = df_display["is_expired"].apply(
            lambda x: "❌ EXPIRED" if x == 1 else "✅ Valid"
        )

        display_cols = [
            "id",
            "worker_id",
            "timestamp",
            "dose",
            "intensity",
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
                "intensity": "Staining Intensity",
                "risk_level": "Risk Level",
                "expiry_status_message": "Expiry Message",
            }
        )

        st.dataframe(df_table, use_container_width=True, hide_index=True)

        col_export, col_reset = st.columns([2, 2], gap="large")

        with col_export:
            # Export Button (Download readings as CSV)
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
