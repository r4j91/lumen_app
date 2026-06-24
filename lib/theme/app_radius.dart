import 'package:flutter/material.dart';

/// Border radius scale — use for all rounded corners.
class AppRadius {
  AppRadius._();

  static const double sm    = 8;
  static const double small = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 28;
  static const double pill = 999;

  static BorderRadius get cardSm   => BorderRadius.circular(sm);
  static BorderRadius get cardMd   => BorderRadius.circular(md);
  static BorderRadius get cardLg   => BorderRadius.circular(lg);
  static BorderRadius get cardXl   => BorderRadius.circular(xl);
  static BorderRadius get sheetTop => const BorderRadius.vertical(top: Radius.circular(xl));
  static BorderRadius get pillShape => BorderRadius.circular(pill);
}
