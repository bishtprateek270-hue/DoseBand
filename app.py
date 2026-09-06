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
        
        # Query registered workers from SQLite database
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
            is_worker_id_valid = True

            # Display rich worker profile metadata card
            worker_info = database.get_worker_by_id(worker_id_clean)
            if worker_info:
                # Check badge expiry status
                try:
                    exp_date = datetime.strptime(worker_info["badge_expiry_date"], "%Y-%m-%d").date()
                    is_badge_date_expired = exp_date < date.today()
                    days_left = (exp_date - date.today()).days
                except Exception:
                    is_badge_date_expired = False
                    days_left = 999

                status_badge_color = "#10B981" if (worker_info["status"] == "Active" and not is_badge_date_expired) else "#EF4444"
                status_label = worker_info["status"]
                if is_badge_date_expired:
                    status_label = "Badge Expired"

                st.markdown(
                    f"""
                    <div style="background-color: #1E293B; border-left: 4px solid {status_badge_color}; padding: 0.85rem; border-radius: 0.5rem; margin-top: 0.5rem; margin-bottom: 0.5rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <strong style="color: #F8FAFC; font-size: 0.95rem;">👤 {worker_info['name']} ({worker_info['worker_id']})</strong>
                            <span style="background-color: {'rgba(16, 185, 129, 0.2)' if not is_badge_date_expired and worker_info['status'] == 'Active' else 'rgba(239, 68, 68, 0.2)'}; color: {status_badge_color}; font-size: 0.75rem; font-weight: 700; padding: 2px 8px; border-radius: 4px;">
                                {status_label.upper()}
                            </span>
                        </div>
                        <div style="font-size: 0.82rem; color: #94A3B8; margin-top: 0.4rem; line-height: 1.4;">
                            🏭 <b>Dept:</b> {worker_info['department']} &nbsp;|&nbsp; 📍 <b>Zone:</b> {worker_info['work_zone']}<br>
                            ⏰ <b>Shift:</b> {worker_info['shift']}<br>
                            🏷️ <b>Badge ID:</b> <code style="color: #F97316;">{worker_info['badge_id']}</code> &nbsp;|&nbsp; 📅 <b>Expiry:</b> {worker_info['badge_expiry_date']}
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True
                )

                if is_badge_date_expired:
                    st.warning(f"⚠️ Dosimeter Badge `{worker_info['badge_id']}` expired on {worker_info['badge_expiry_date']}. Immediate replacement recommended.")
                elif days_left <= 7:
                    st.caption(f"⏳ Badge `{worker_info['badge_id']}` expires soon ({days_left} days remaining).")
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

                dossier_c1, dossier_c2 = st.columns([1, 1], gap="large")
                with dossier_c1:
                    st.markdown(
                        f"""
                        <div style="background-color: #1E293B; border-radius: 0.75rem; padding: 1.25rem; border: 1px solid #334155;">
                            <div style="display: flex; align-items: center; gap: 1rem; margin-bottom: 0.75rem;">
                                <div style="background: #0F172A; border-radius: 50%; width: 50px; height: 50px; display: flex; align-items: center; justify-content: center; font-size: 1.6rem; border: 2px solid #F97316;">
                                    👷
                                </div>
                                <div>
                                    <h3 style="margin: 0; color: #F8FAFC; font-size: 1.25rem;">{w_profile['name']}</h3>
                                    <span style="color: #F97316; font-weight: 700; font-size: 0.85rem;">{w_profile['worker_id']}</span> &nbsp;|&nbsp; 
                                    <span style="color: #94A3B8; font-size: 0.85rem;">{w_profile['status']}</span>
                                </div>
                            </div>
                            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; font-size: 0.85rem; color: #CBD5E1; margin-top: 1rem;">
                                <div><b>Department:</b><br><span style="color: #F8FAFC;">{w_profile['department']}</span></div>
                                <div><b>Work Zone:</b><br><span style="color: #F8FAFC;">{w_profile['work_zone']}</span></div>
                                <div><b>Assigned Shift:</b><br><span style="color: #F8FAFC;">{w_profile['shift']}</span></div>
                                <div><b>Dosimeter Badge ID:</b><br><code style="color: #F97316;">{w_profile['badge_id']}</code></div>
                                <div><b>Badge Issue Date:</b><br><span style="color: #F8FAFC;">{w_profile['badge_issue_date']}</span></div>
                                <div><b>Badge Expiry Date:</b><br><span style="color: #F8FAFC;">{w_profile['badge_expiry_date']}</span></div>
                            </div>
                        </div>
                        """,
                        unsafe_allow_html=True
                    )

                with dossier_c2:
                    st.markdown("##### ⚡ Exposure & Dosimeter Health")
                    st.metric(
                        "Total Cumulative H₂S Dose",
                        f"{w_cum_dose:.2f} ppm*hr",
                        delta=f"{UNSAFE_CUMULATIVE_THRESHOLD - w_cum_dose:.2f} ppm*hr remaining" if w_cum_dose < UNSAFE_CUMULATIVE_THRESHOLD else "EXCEEDED LIMIT",
                        delta_color="normal" if w_cum_dose < UNSAFE_CUMULATIVE_THRESHOLD else "inverse"
                    )
                    
                    # Exposure threshold progress bar
                    progress_val = min(1.0, max(0.0, w_cum_dose / UNSAFE_CUMULATIVE_THRESHOLD))
                    st.progress(progress_val, text=f"OSHA/DGMS Cumulative Limit ({w_cum_dose:.1f} / {UNSAFE_CUMULATIVE_THRESHOLD:.1f} ppm*hr)")

                    st.caption(f"Total Dosimeter Scans Logged: **{len(w_readings)}** records.")

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
