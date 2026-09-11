# 📱 DoseBand Mobile Companion App (Flutter)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-lightgrey?style=for-the-badge)]()

---

> ## ⚠️ CRITICAL CHEMICAL & OCCUPATIONAL SAFETY DIRECTIVE
> **Hydrogen Sulfide ($\text{H}_2\text{S}$)** is an acute, toxic, flammable chemical asphyxiant. Olfactory fatigue occurs rapidly above $100\text{ ppm}$, rendering human smell completely ineffective as a warning.
>
> All preparation, chemical handling of Lead Acetate $[\text{Pb(CH}_3\text{COO)}_2]$, and gas testing MUST only be performed by qualified personnel inside certified **chemical fume hoods** with continuous gas monitoring, ANSI Z87.1 splash goggles, chemical-resistant nitrile gloves, and NIOSH/OSHA-approved respiratory protection.

---

## 📖 Overview

The **DoseBand Mobile App** is a companion mobile application built with Flutter that provides field safety supervisors and industrial hygienists with on-the-go optical dosimeter badge & chemical strip scanning, real-time exposure readings, and cumulative dose audit histories.

---

## 🏗️ Architecture & Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App initialization & Bottom Navigation controller
│   ├── models/
│   │   ├── reading.dart          # Reading data model (H2S ppm, cumulative dose, risk level, temperature, humidity)
│   │   └── worker.dart           # Worker profile model (department, shift, cumulative exposure)
│   ├── screens/
│   │   ├── dashboard_screen.dart # KPI statistics, status cards & shift exposure analytics
│   │   ├── scanner_screen.dart   # Optical dosimeter capture & 6-criteria physical validation UI
│   │   ├── history_screen.dart   # Chronological worker scan logs & audit trail
│   │   ├── worker_directory_screen.dart # Registered worker roster & shift statuses
│   │   └── worker_detail_screen.dart    # Individual worker dosimeter history & emergency contacts
│   ├── services/
│   │   ├── dosimetry_service.dart # Pure Dart optical colorimetry & 6-criteria validation engine
│   │   └── worker_service.dart    # Worker registry, reading logs & compliance state manager
│   └── theme/
│       └── app_theme.dart        # Industrial Navy (#0F172A) & Safety Orange (#EA580C)
├── pubspec.yaml                  # Flutter package metadata & dependencies
└── test/                         # Unit & widget test suites
```

---

## 🌟 Mobile Features

1. **Dual-Mode Optical Scanning:**
   - Supports both complete **Full DoseBand Badges** and direct **Standalone Physical Chemical Test Strips** (plain and textured paper).
2. **On-Device Optical Densitometry & Colorimetry:**
   - Real-time optical staining intensity extraction ($I = 1.0 - V/255$).
   - Multi-point chromatic neutrality and paper texture verification.
3. **Environmental Compensation:**
   - Real-time Arrhenius temperature ($f_{\text{temp}}$) and Langmuir humidity ($f_{\text{RH}}$) thermodynamic adjustments.
4. **Continuous Exposure Regression:**
   - Smooth concentration mapping across all shades of white, cream, tan, grey, bronze, slate, and dense Lead Sulfide black ($\text{PbS}$).
5. **Safety Risk Protocol:**
   - Automatic classification (🟢 Safe, 🟡 Caution, 🔴 Unsafe / Critical) aligned with DGMS, OISD, and OSHA 29 CFR 1910.1000.

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK (3.x or later)](https://docs.flutter.dev/get-started/install)
- Android Studio / Xcode / VS Code with Flutter extension
- Connected physical mobile device or emulator

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the Application
```bash
flutter run
```

---

## 🎨 Design System
The app implements an **Industrial Safety Engineering** design theme:
* **Primary Navy:** `#0F172A`
* **Surface Slate:** `#1E293B`
* **Safety Orange Accent:** `#EA580C`
* **Alert Statuses:** Safe (Green `#10B981`), Caution (Amber `#F59E0B`), Critical (Red `#EF4444`)
