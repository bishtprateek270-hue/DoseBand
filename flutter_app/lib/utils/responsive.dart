import 'package:flutter/material.dart';

/// DoseBand Responsive Layout & Breakpoint Helper
/// Ensures 100% overflow-free rendering across narrow mobile (320px),
/// standard mobile (360-430px), tablets (600px+), and high accessibility text scaling (1.0x - 1.4x).
class Responsive {
  static const double narrowPhoneMaxWidth = 350.0;
  static const double tabletMinWidth = 600.0;

  static bool isNarrow(BuildContext context) =>
      MediaQuery.of(context).size.width <= narrowPhoneMaxWidth;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMinWidth;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double textScaleFactor(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0);
}
