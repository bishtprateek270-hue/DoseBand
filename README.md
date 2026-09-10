# 🛡️ DoseBand: Industrial H₂S Optical Dosimeter & Worker Safety Intelligence Platform

[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Streamlit](https://img.shields.io/badge/Streamlit-1.30%2B-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)](https://streamlit.io/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![OpenCV](https://img.shields.io/badge/OpenCV-4.8%2B-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white)](https://opencv.org/)
[![Scikit-Learn](https://img.shields.io/badge/Scikit--Learn-1.3%2B-F7931E?style=for-the-badge&logo=scikitlearn&logoColor=white)](https://scikit-learn.org/)
[![SQLite](https://img.shields.io/badge/SQLite-3.x-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org/)
[![Safety Compliance](https://img.shields.io/badge/Compliance-DGMS%20%7C%20OISD%20%7C%20OSHA-22C55E?style=for-the-badge)]()

---

> ## ⚠️ CRITICAL CHEMICAL & OCCUPATIONAL SAFETY WARNING
>
> ### 🛑 HAZARDOUS CHEMICALS & TOXIC GAS PROTOCOL
> **Hydrogen Sulfide ($\text{H}_2\text{S}$)** is an extremely hazardous, toxic, flammable, and rapid chemical asphyxiant. At low concentrations, it produces a characteristic rotten egg odor; however, **olfactory fatigue rapidly numbs the sense of smell at concentrations above 100 ppm, making odor completely unreliable as a warning of lethal exposure**.
>
> **Lead Acetate $[\text{Pb(CH}_3\text{COO)}_2]$** and **Lead Sulfide $[\text{PbS}]$** are toxic heavy metal compounds harmful if inhaled, ingested, or absorbed through skin.
>
> ### 🧪 MANDATORY LABORATORY EXECUTION DIRECTIVES:
> 1. **Qualified Expert Supervision Only:** Any chemical preparation, strip sensitization, lead acetate handling, or gas exposure testing must be conducted **strictly under the direct supervision of qualified industrial hygienists and certified chemical safety experts**.
> 2. **Certified Engineering Controls:** All reagent handling, acid-sulfide reactions, and test strip exposures MUST be performed inside a certified, continuously monitored **chemical fume hood** (minimum face velocity of $100\text{ fpm} / 0.5\text{ m/s}$) with active exhaust scrubbers.
> 3. **Mandatory Personal Protective Equipment (PPE):**
>    - **Eye & Face Protection:** ANSI Z87.1 certified chemical splash goggles and full-face shield.
>    - **Hand Protection:** Chemical-resistant nitrile or neoprene gloves (minimum 8 mil thickness; double gloving required for direct lead solutions).
>    - **Body Protection:** Chemical-resistant lab coat and non-permeable apron.
>    - **Respiratory Protection:** Calibrated portable continuous $\text{H}_2\text{S}$ personal electronic gas monitors with audible/visual alarms. In areas with potential gas release exceeding permissible exposure limits, use NIOSH/OSHA-certified positive-pressure Self-Contained Breathing Apparatus (SCBA) or supplied-air respirators.
> 4. **Hazardous Waste Disposal:** All spent paper test strips, rinse solutions, and chemical residues contain heavy metal lead $(\text{Pb})$ and must be collected in labeled hazardous chemical waste containers in accordance with local and national environmental protection regulations.

---

## 📌 Executive Overview

**DoseBand** is an enterprise-grade occupational health and hazardous gas monitoring platform designed for real-time optical colorimetric dosimetry in severe industrial environments (mining sites, oil & gas refineries, petrochemical processing facilities, and wastewater utilities).

Industrial personnel operating in confined spaces and hazardous zones face lethal risks from **Hydrogen Sulfide ($\text{H}_2\text{S}$)** toxicity. Traditional electronic personal gas monitors are costly, bulky, battery-constrained, and susceptible to sensor poisoning. Passive colorimetric dosimeters offer an accessible, intrinsically safe alternative; however, manual visual inspection by eye is prone to observer bias, ambient lighting distortion, and lack of verifiable compliance logging.

**DoseBand bridges this gap** by transforming passive colorimetric chemical strips and wristbands into verifiable, AI-calibrated optical dosimeters. By combining on-badge optical grayscale step wedges, multi-factor computer vision verification, physical environmental compensation algorithms, machine learning concentration regressors, and cross-platform dashboards, DoseBand delivers reliable, audit-ready worker safety intelligence.

Engineered to align directly with occupational safety mandates established by the **Directorate General of Mines Safety (DGMS)**, **Oil Industry Safety Directorate (OISD)**, and **OSHA 29 CFR 1910.1000**.

---

## 🌟 Key Features & Innovations

```
                                  DOSEBAND SYSTEM FLOW
  +--------------------+      +-----------------------+      +-----------------------+
  |  Smart QR Badge /  | ---> |   Computer Vision     | ---> |   Lighting & Spatial  |
  |  Dosimeter Strip   |      |   Pre-Flight QA (6D)  |      |   Calibration (OLS)   |
  +--------------------+      +-----------------------+      +-----------------------+
                                                                         |
                                                                         v
  +--------------------+      +-----------------------+      +-----------------------+
  |  DGMS/OISD PDF/CSV | <--- |   SQLite Database &   | <--- |   Multi-Modal AI /    |
  |   Safety Reports   |      |   Trend Forecasting   |      |   Inference Pipeline  |
  +--------------------+      +-----------------------+      +-----------------------+
```

### 1. 🔍 Strict Pre-Flight Computer Vision & QA Pipeline
* **Laplacian Variance Sharpness Engine:** Discards motion-blurred and out-of-focus captures before processing.
* **Dynamic Range & Illumination Verification:** Rejects extreme underexposure (pitch dark) and overexposure (direct flash glare).
* **Multi-Factor Test Strip Validation:** Employs a weighted 6-factor physical confidence engine (0–100%) to verify authentic chemical paper fiber texture, aspect ratio, and colorimetric profile while rejecting non-strip images, digital screenshots, and counterfeits.
* **Dual-Mode Scan Architecture:** Seamlessly supports both complete **Full DoseBand Multi-ROI Badges** (reference scale, humidity card, strip) and direct **Standalone Physical Chemical Test Strips**.

### 2. 📸 Adaptive Lighting Normalization (OLS Step Wedge)
* Integrates a printed 5-step grayscale reference wedge directly on each badge.
* Computes independent per-channel $(B, G, R)$ **Ordinary Least Squares (OLS)** linear transformation against standardized reflectance values, eliminating ambient color casts and field lighting variations.

### 3. 🧪 Multi-Modal AI Inference & Environmental Compensation
* **Relative Humidity (%RH) KNN Regressor:** Predicts ambient moisture from on-badge silica/cobalt indicator patches.
* **$\text{H}_2\text{S}$ Multi-Tree & Polynomial Concentration Regressors:** Accurately maps optical darkening ($V$-channel attenuation and chromatic shift in HSV/Lab color space) to cumulative $\text{H}_2\text{S}$ dose ($\text{ppm} \cdot \text{hr}$).
* **Continuous Shade Calibration:** Accurately quantifies the full optical spectrum from virgin chemical white through light cream, beige, tan, warm grey, bronze, dark slate, and dense lead sulfide black ($\text{PbS}$).
* **Environmental Arrhenius & Langmuir Compensation:** Applies thermodynamic reaction rate corrections for ambient temperature ($25^\circ\text{C}$ baseline) and relative humidity ($50\%\text{ RH}$ baseline).
* **Optical Shelf-Life Classifier:** Verifies chemical reagent freshness and flags expired badges.

### 4. 📈 Predictive Exposure Trend Forecasting
* Real-time regression analysis over historical worker logs.
* Computes daily accumulation rates ($\text{ppm} \cdot \text{hr} / \text{day}$) and projects **Time-to-Warning** ($10.0\ \text{ppm} \cdot \text{hr}$ 8-hr TWA) and **Time-to-Critical** ($50.0\ \text{ppm} \cdot \text{hr}$ STEL/IDLH).

### 5. 🏷️ Smart QR Badge Management
* JSON-encoded worker identification and camera scanning.
* Instant verification of worker credentials, hazardous zone assignments, shift validity, and dosimeter expiration status.

### 6. 📄 Audit-Ready Safety Reporting
* One-click generation of industrial safety audit reports in **PDF (via ReportLab)** and **CSV**.
* Granular filtering across worker directories, risk tiers, and custom shift date ranges.

### 7. 📱 Cross-Platform Mobile Application (Flutter)
* Dedicated Flutter application for field supervisors and safety officers featuring camera scanning, real-time KPI metrics, and worker exposure records.

---

## 🗂️ Complete Directory & Folder Structure Breakdown

```
doseband/
├── 📄 app.py                           # Main Streamlit web application & UI orchestrator
├── 📄 calibration.py                   # OLS per-channel lighting calibration engine
├── 📄 calibration_data.csv             # Empirical chemical colorimetric dose calibration dataset
├── 📄 database.py                      # SQLite ORM, worker directory, schema migrations & seeding
├── 📄 dose_model.py                    # Polynomial regression & dose-to-risk classifier
├── 📄 dose_model.pkl                   # Serialized polynomial dose estimation model
├── 📄 doseband.db                      # SQLite database file (worker logs & readings)
├── 📄 environmental_compensation.py    # Thermodynamic temperature & humidity correction math
├── 📄 expiry_checker.py                # KNN shelf-life patch expiration classifier
├── 📄 expiry_classifier.pkl            # Serialized KNN expiry classification model
├── 📄 expiry_training_data.csv         # Labeled HSV dataset for expiry classification
├── 📄 exposure_forecaster.py           # Statistical time-to-threshold exposure trend forecaster
├── 📄 generate_negative_test_images.py # Generator for negative QA security test cases
├── 📄 generate_test_images.py          # Generator for multi-exposure annotated chemical test strips
├── 📄 inference_engine.py              # Central ML pipeline orchestrator for H2S & Humidity
├── 📄 qr_manager.py                    # QR code generator, camera decoder, and badge validator
├── 📄 quality_validator.py             # Pre-flight sharpness, lighting & ROI quality validator
├── 📄 reference_dataset_generator.py   # Dataset builder from reference chemical strip images
├── 📄 requirements.txt                 # Project dependencies for Python backend & web app
├── 📄 roi_detector.py                  # Multi-region bounding box detector (scale, strip, humidity, expiry)
├── 📄 safety_report_generator.py       # DGMS/OISD compliant PDF & CSV safety audit generator
├── 📄 strip_reader.py                  # Optical colorimetry & HSV staining intensity extractor
├── 📄 strip_validator.py               # 6-Factor dynamic physical & optical confidence engine
├── 📄 test_calibration_swatches.py     # Verification script for step-wedge color swatches
├── 📄 test_models_live.py              # Live inference verification against trained models
├── 📄 test_scan_pipeline_logic.py      # Comprehensive 8-scenario prerequisite test suite
├── 📄 test_validator_pipeline.py       # Test script for strip validation confidence scoring
├── 📄 train_all_models.py              # CLI batch trainer for core models
├── 📄 train_reference_models.py        # Machine learning training pipeline for chemical dosimeters
├── 📄 verify_test_scenarios.py         # Automated end-to-end scenario verification harness
│
├── 📁 data/                            # Training datasets and raw reference imagery
│   ├── 📁 reference_images/            # Reference calibration scale image assets
│   ├── 📄 simulated_h2s_training_data.csv       # Multi-feature chemical optical H2S dosimeter dataset
│   └── 📄 simulated_humidity_training_data.csv  # Multi-feature optical humidity calibration dataset
│
├── 📁 models/                          # Serialized production machine learning artifacts
│   ├── 📄 h2s_demo_model.joblib        # Trained H2S chemical concentration regression model
│   └── 📄 humidity_demo_model.joblib   # Trained KNN Humidity regression model
│
├── 📁 test_images/                     # Test image suite (positive, negative & edge cases)
│   ├── 📄 base_normal.jpg              # Baseline normal exposure test strip
│   ├── 📄 expiry_expired.jpg           # Expired shelf-life test patch
│   ├── 📄 expiry_fresh.jpg             # Fresh valid shelf-life test patch
│   ├── 📄 exposure_level_1_very_low.jpg# Exposure scenario: 1-5 ppm*hr
│   ├── 📄 exposure_level_2_low.jpg     # Exposure scenario: 10 ppm*hr
│   ├── 📄 exposure_level_3_medium.jpg  # Exposure scenario: 25 ppm*hr
│   ├── 📄 exposure_level_4_high.jpg    # Exposure scenario: 45 ppm*hr
│   ├── 📄 exposure_level_5_very_high.jpg# Exposure scenario: 75+ ppm*hr
│   ├── 📄 lighting_bright.jpg          # Overexposed lighting test case
│   ├── 📄 lighting_dim.jpg             # Underexposed lighting test case
│   ├── 📄 lighting_normal.jpg          # Normal ambient lighting test case
│   ├── 📄 negative_black_rectangle.jpg # Negative QA: Plain black rectangle
│   ├── 📄 negative_colored_rectangles.jpg # Negative QA: Non-chemical color blocks
│   ├── 📄 negative_gradient.jpg        # Negative QA: Inverted/generic gradient
│   ├── 📄 negative_isolated_h2s_crop.jpg  # Strip image test case
│   ├── 📄 negative_noisy_texture.jpg   # Negative QA: Random noise / fabric texture
│   ├── 📄 negative_plain_grey.jpg      # Negative QA: Plain gray sheet
│   ├── 📄 negative_plain_white.jpg     # Negative QA: Plain white sheet
│   ├── 📄 negative_screenshot_text.jpg # Negative QA: Screenshot containing text
│   ├── 📄 quality_test_blurry.jpg      # Quality QA: Defocused / motion blurred
│   ├── 📄 quality_test_missing_scale.jpg # Quality QA: Standalone strip format
│   ├── 📄 quality_test_underexposed.jpg# Quality QA: Pitch dark scan
│   ├── 📄 real_strip_01_fresh_cream.jpg       # Physical strip: Fresh unexposed cream
│   ├── 📄 real_strip_02_light_beige_tan.jpg   # Physical strip: Light beige exposure
│   ├── 📄 real_strip_03_medium_greyish_tan.jpg# Physical strip: Medium tan exposure
│   ├── 📄 real_strip_04_warm_brownish_grey.jpg# Physical strip: Warm brownish grey
│   ├── 📄 real_strip_05_dark_bronze_grey.jpg  # Physical strip: Dark bronze exposure
│   ├── 📄 real_strip_06_charcoal_slate.jpg    # Physical strip: Charcoal slate
│   ├── 📄 real_strip_07_dense_charcoal_black.jpg # Physical strip: Dense PbS black
│   ├── 📄 real_strip_08_deep_solid_black.jpg  # Physical strip: Deep saturation black
│   ├── 📄 sample.jpg                   # Original raw sample image
│   └── 📄 sample_corrected.jpg         # Sample image after OLS lighting correction
│
└── 📁 flutter_app/                     # Cross-platform Flutter Mobile Application
    ├── 📄 pubspec.yaml                 # Flutter package definitions & dependencies
    ├── 📁 lib/
    │   ├── 📄 main.dart                # Mobile app entrypoint & navigation controller
    │   ├── 📁 models/
    │   │   └── 📄 reading.dart         # Data model for dosimeter readings
    │   ├── 📁 screens/
    │   │   ├── 📄 dashboard_screen.dart# Real-time KPIs, statistics & safety cards
    │   │   ├── 📄 history_screen.dart  # Worker scan audit trail & logs
    │   │   └── 📄 scanner_screen.dart  # Mobile camera viewfinder & scanning UI
    │   └── 📁 theme/
    │       └── 📄 app_theme.dart       # Industrial navy & safety orange styling
    └── 📁 android/ ios/ web/ windows/  # Native platform build configurations
```

---

## 🔬 Mathematical & Scientific Formulation

### 1. On-Badge Ordinary Least Squares (OLS) Lighting Calibration
Let $C \in \{\text{Blue}, \text{Green}, \text{Red}\}$ be the color channels. For 5 reference grayscale swatches with true reflectance values $C_{\text{true}, i} \in \{255, 191, 128, 64, 0\}$ and detected values $C_{\text{det}, i}$:

$$\min_{m_C, c_C} \sum_{i=1}^{5} \Big( C_{\text{true}, i} - (m_C \cdot C_{\text{det}, i} + c_C) \Big)^2$$

Where:
* $m_C$ is the **gain / contrast correction factor**.
* $c_C$ is the **ambient offset / color temperature bias**.
* Each pixel is corrected and clipped: $C_{\text{corrected}} = \text{clip}\big(m_C \cdot C + c_C, 0, 255\big)$.

---

### 2. Optical Staining Intensity ($V$-Channel Darkening)
Colorimetric lead acetate $[\text{Pb(CH}_3\text{COO)}_2]$ reacts stoichiometrically with Hydrogen Sulfide gas to form dark Lead Sulfide $[\text{PbS}]$ precipitate on the fibrous cellulose matrix:

$$\text{Pb(CH}_3\text{COO)}_2 + \text{H}_2\text{S} \longrightarrow \text{PbS} \downarrow + 2\text{CH}_3\text{COOH}$$

The optical staining intensity $I_{\text{raw}} \in [0.0, 1.0]$ is computed using the HSV Value ($V$) channel, normalized against baseline unexposed chemical paper:

$$I_{\text{raw}} = 1.0 - \left( \frac{\text{median}(V_{\text{strip}})}{255.0} \right)$$

---

### 3. Environmental Temperature & Humidity Compensation
Chemical reaction velocity and vapor diffusion follow thermodynamic temperature dependencies (Arrhenius relation) and surface moisture kinetics (Langmuir adsorption isotherm):

$$f_{\text{temp}} = 1.0 + 0.008 \cdot (T - 25.0^\circ\text{C})$$

$$f_{\text{RH}} = 1.0 + 0.003 \cdot (\text{RH} - 50.0\%)$$

$$\text{CF} = \text{clamp}\Big(f_{\text{temp}} \cdot f_{\text{RH}},\ 0.70,\ 1.40\Big)$$

$$I_{\text{corrected}} = \frac{I_{\text{raw}}}{\text{CF}}$$

---

### 4. Occupational Exposure Limits (DGMS / OISD / OSHA)

| Risk Classification | Exposure Dose ($\text{ppm} \cdot \text{hr}$) | Safety Status & Protocol |
| :--- | :--- | :--- |
| 🟢 **Safe** | $< 10.0\ \text{ppm} \cdot \text{hr}$ | Within 8-hr Permissible Exposure Limit (PEL TWA). Safe to continue shift. |
| 🟡 **Caution** | $10.0 - 50.0\ \text{ppm} \cdot \text{hr}$ | Exceeds 8-hr TWA. Mandatory ventilation check and supervisor rotation. |
| 🔴 **Unsafe / Critical** | $\ge 50.0\ \text{ppm} \cdot \text{hr}$ | Exceeds STEL / Immediately Dangerous. Immediate evacuation & medical review. |

---

## 🚀 Quick Start Guide

### Prerequisites
* **Python 3.10+**
* **Flutter SDK 3.x** (Optional, for mobile app development)
* **Git**

---

### 🐍 Backend & Web App Setup

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/bishtprateek270-hue/DoseBand.git
   cd doseband
   ```

2. **Create and Activate a Virtual Environment:**
   ```bash
   # Windows (PowerShell)
   python -m venv venv
   .\venv\Scripts\activate

   # Linux / macOS
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Launch the DoseBand Web Application:**
   ```bash
   streamlit run app.py
   ```
   The portal will open automatically at `http://localhost:8501`.

---

### 📱 Flutter Mobile App Setup

1. **Navigate to the Flutter directory:**
   ```bash
   cd flutter_app
   ```

2. **Fetch packages:**
   ```bash
   flutter pub get
   ```

3. **Run on an attached device or emulator:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing & Validation Suite

DoseBand includes comprehensive automated test harnesses to guarantee detection accuracy and security against adversarial or malformed inputs:

| Test Script | Description |
| :--- | :--- |
| `python test_scan_pipeline_logic.py` | Validates all 8 core prerequisite scenarios (expired badges, inactive workers, security checks, blurred scans). |
| `python test_validator_pipeline.py` | Tests the 6-factor dynamic confidence score on authentic chemical strips and negative test cases. |
| `python test_models_live.py` | Verifies live model inference predictions across various chemical exposure gradients. |
| `python test_calibration_swatches.py` | Validates OLS step wedge extraction and regression stability. |
| `python verify_test_scenarios.py` | Runs end-to-end automated sanity verification across the complete pipeline. |

---

## 🛡️ Industrial Safety Standards Aligned

* **DGMS (Tech) Circulars (Directorate General of Mines Safety)** — Gaseous monitoring in underground & opencast mining operations.
* **OISD-STD-114 (Oil Industry Safety Directorate)** — Hazardous gas monitoring and control in petroleum refineries & offshore installations.
* **OSHA 29 CFR 1910.1000** — Occupational Safety and Health Administration Table Z-2 Toxic and Hazardous Substances.

---

## ⚖️ License & Compliance Notice

This project is licensed under the **MIT License**.

> 🔬 **Professional Industrial Safety Notice:** This software and optical dosimetry framework are designed to assist industrial hygiene protocols. All physical testing, chemical dosimetry preparation, and exposure evaluations must strictly adhere to certified industrial occupational hygiene procedures under expert supervision with appropriate engineering controls and safety equipment.
