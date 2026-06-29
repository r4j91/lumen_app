import 'package:flutter/material.dart';

/// Layout helpers for consistent screen insets (nav pill, FAB, home indicator).
class AppLayout {
  AppLayout._();

  static const double bottomNavPillHeight = 62;
  static const double bottomNavPillMargin = 12;
  static const double fabSize = 56;
  static const double fabGap = 10;
  static const double fabSideMargin = 14;

  /// Total stacked height of pill + FAB (used by [ResponsiveLayout] bottom bar).
  static double totalBottomChromeHeight(BuildContext context) {
    return MediaQuery.of(context).viewPadding.bottom +
        bottomNavPillMargin +
        bottomNavPillHeight +
        fabGap +
        fabSize;
  }

  /// Distance from the physical screen bottom to the top edge of the FAB.
  static double fabTopFromBottom(BuildContext context) {
    return MediaQuery.of(context).padding.bottom +
        bottomNavPillMargin +
        bottomNavPillHeight +
        fabGap +
        fabSize;
  }

  /// Home: scroll tail so the projects card docks just above the FAB.
  static double homeDockBottomInset(BuildContext context) {
    return fabTopFromBottom(context) + 8;
  }

  /// Bottom padding for scroll views — keeps last items above pill + FAB hit area.
  static double bottomListInset(BuildContext context) {
    return totalBottomChromeHeight(context) + 8;
  }
}
