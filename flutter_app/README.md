# 📱 DoseBand Mobile Companion App (Flutter)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-lightgrey?style=for-the-badge)]()

---

## 📖 Overview

The **DoseBand Mobile App** is a companion application built with Flutter that provides field safety supervisors and industrial workers with on-the-go dosimeter badge scanning, real-time exposure readings, and cumulative dose audit histories.

---

## 🏗️ Architecture & Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App initialization & Bottom Navigation bar
│   ├── models/
│   │   └── reading.dart          # Reading data model (dose, risk level, timestamp)
│   ├── screens/
│   │   ├── dashboard_screen.dart # KPI statistics, status cards & shift summaries
│   │   ├── scanner_screen.dart   # Viewfinder UI for badge and strip capture
│   │   └── history_screen.dart   # Chronological worker scan logs & audit trail
│   └── theme/
│       └── app_theme.dart        # Industrial Navy (#0F172A) & Safety Orange (#EA580C)
├── pubspec.yaml                  # Flutter package metadata & dependencies
└── test/                         # Unit & widget test suites
```

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK (3.x or later)](https://docs.flutter.dev/get-started/install)
- Android Studio / Xcode / VS Code with Flutter extension
- Connected physical device or emulator

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
* **Alert Statuses:** Safe (Green `#16A34A`), Caution (Amber `#D97706`), Critical (Red `#DC2626`)
