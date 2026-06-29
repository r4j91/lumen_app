import 'package:flutter/material.dart';

/// Animation duration and curve tokens.
class AppDurations {
  AppDurations._();

  static const Duration fast   = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow   = Duration(milliseconds: 320);
  static const Duration popover = Duration(milliseconds: 150);
}

class AppCurves {
  AppCurves._();

  static const Curve easeOutCubic   = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve easeOutQuart   = Curves.easeOutQuart;
}
