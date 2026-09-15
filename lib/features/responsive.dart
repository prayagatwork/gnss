import 'package:flutter/material.dart';

/// Centralized Responsive Logic per Client Instruction:
/// "Make sure you use all the relative width and height... keep it relative
/// and adjust it according to the display size."
class Responsive {
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth =
      1100; // Increased for modern wide tablets

  // --- Device Detection ---
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < phoneMaxWidth;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= phoneMaxWidth && w < tabletMaxWidth;
  }

  static bool isLaptopOrWider(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMaxWidth;

  // --- Relative Sizing Helpers ---

  /// Returns a width as a fraction of screen width, with strict clamping.
  static double relativeWidth(BuildContext context, double fraction,
      {double min = 0, double max = double.infinity}) {
    return (MediaQuery.of(context).size.width * fraction).clamp(min, max);
  }

  /// Returns a height as a fraction of screen height, with strict clamping.
  static double relativeHeight(BuildContext context, double fraction,
      {double min = 0, double max = double.infinity}) {
    return (MediaQuery.of(context).size.height * fraction).clamp(min, max);
  }

  // --- UI Layout Adjustments (To fix "Bad UI" issues) ---

  /// Adjusts the number of columns for the Dashboard grid.
  static int dashboardColumns(BuildContext context) {
    if (isPhone(context)) return 2;
    if (isTablet(context)) return 3;
    return 4; // Laptop/Desktop
  }

  /// CRUCIAL: Fixes the 8-card grid look.
  /// On wide screens, cards should be wider. On phones, they should be taller.
  static double cardAspectRatio(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width < 400) return 1.1; // Small phone
    if (width < 600) return 1.4; // Large phone
    if (width < 1100) return 1.6; // Tablet
    return 1.8; // Laptop/Desktop
  }

  /// Dynamic padding for the whole app.
  /// Instruction: "Relative width and height for tab laptop and phone"
  static EdgeInsets screenPadding(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    if (isPhone(context)) return EdgeInsets.all(w * 0.03); // 3% padding
    if (isTablet(context)) return EdgeInsets.all(w * 0.04); // 4% padding
    return EdgeInsets.symmetric(
        horizontal: w * 0.05, vertical: 20); // 5% side padding
  }

  /// Space between cards/widgets
  static double elementSpacing(BuildContext context) {
    return relativeWidth(context, 0.02, min: 8, max: 20);
  }

  // --- Typography ---

  /// Base font scale so text doesn't look tiny on 4K monitors or huge on phones.
  static double fontScale(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    if (w < 400) return 0.85;
    if (w < 600) return 1.0;
    if (w < 1200) return 1.1;
    return 1.25; // Large screens
  }
}
