import 'package:flutter/material.dart';
import '../widgets/bottom_nav_scope.dart';

/// Layout helpers for consistent screen insets (nav pill, FAB, home indicator).
class AppLayout {
  AppLayout._();

  static const double breakpointPhone = 600;
  static const double breakpointTabletWide = 768;
  static const double breakpointDesktop = 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointDesktop;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= breakpointPhone && w < breakpointDesktop;
  }

  static double tabletContentMaxWidth(double screenWidth) =>
      screenWidth >= breakpointTabletWide ? 720 : 640;

  static const double bottomNavPillHeight = 62;
  static const double bottomNavPillMargin = 12;
  static const double fabSize = 56;
  static const double fabGap = 10;
  static const double fabSideMargin = 14;

  /// Home header — avatar compacto e botões sino/config (mesma altura).
  static const double headerControlSize = 48;
  static const double headerAvatarSize = 40;
  static const double headerIconSize = 24;

  /// Inset inferior seguro (home indicator) — sempre [viewPadding.bottom].
  static double bottomSafeInset(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom;

  /// Total stacked height of pill + FAB (used by [ResponsiveLayout] bottom bar).
  static double totalBottomChromeHeight(BuildContext context) {
    return bottomSafeInset(context) +
        bottomNavPillMargin +
        bottomNavPillHeight +
        fabGap +
        fabSize;
  }

  /// Distance from the physical screen bottom to the top edge of the FAB.
  static double fabTopFromBottom(BuildContext context) {
    return bottomSafeInset(context) +
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
  /// Rotas sem navbar (detalhe de projeto, busca, etc.) usam só safe area.
  static double bottomListInset(BuildContext context) {
    if (!BottomNavScope.isVisible(context)) {
      return MediaQuery.paddingOf(context).bottom + 16;
    }
    return totalBottomChromeHeight(context) + 8;
  }
}
