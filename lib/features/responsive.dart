import 'package:flutter/material.dart';

/// Client's explicit instruction:
/// "Make sure you use all the relative width and height for tab laptop and
///  phone ... keep it relative and adjust it according to the display size."
///
/// This helper centralizes breakpoints and gives relative (fraction-of-
/// screen) sizing helpers instead of hardcoded pixel values, so every screen
/// in features/ stays consistent across phone / tablet / laptop widths.
class Responsive {
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < phoneMaxWidth;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= phoneMaxWidth && w < tabletMaxWidth;
  }

  static bool isLaptopOrWider(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMaxWidth;

  /// Returns a width that is a fraction of the available screen width,
  /// clamped between [min] and [max] so it never becomes unusably small or
  /// absurdly large on ultrawide monitors.
  static double relativeWidth(
    BuildContext context,
    double fraction, {
    double min = 240,
    double max = 900,
  }) {
    final w = MediaQuery.of(context).size.width * fraction;
    return w.clamp(min, max);
  }

  static double relativeHeight(
    BuildContext context,
    double fraction, {
    double min = 120,
    double max = 800,
  }) {
    final h = MediaQuery.of(context).size.height * fraction;
    return h.clamp(min, max);
  }

  /// Number of grid columns for the dashboard metric cards, based on width.
  static int dashboardColumns(BuildContext context) {
    if (isPhone(context)) return 2;
    if (isTablet(context)) return 3;
    return 4;
  }

  /// Base font scale multiplier so text remains legible without being
  /// hardcoded to fixed pixel sizes.
  static double fontScale(BuildContext context) {
    if (isPhone(context)) return 0.95;
    if (isTablet(context)) return 1.0;
    return 1.1;
  }
}
