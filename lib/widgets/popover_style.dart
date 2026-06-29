import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_durations.dart';

/// Visual tokens shared by all popover and context-menu overlays in the app.
/// Import this instead of duplicating values across components.
abstract class PopoverStyle {
  static const double radius      = 20.0;
  static const double blurSigma   = 20.0;
  static const double bgAlpha     = 0.78;
  static const Duration animDuration = AppDurations.popover;
  static const double scaleBegin  = 0.90;

  /// Shared top→bottom highlight gradient for Liquid Glass borders.
  static const LinearGradient borderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x4DFFFFFF),
      Color(0x26FFFFFF),
      Color(0x1FFFFFFF),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static Shader borderGradientShader(Rect rect) =>
      borderGradient.createShader(rect);

  /// The two layered drop-shadows used under every popover card.
  static List<BoxShadow> get shadows => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.24),
      blurRadius: 24,
      spreadRadius: -2,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Background color for the popover card (Liquid Glass fill).
  static Color get bg => AppColors.navBar.withValues(alpha: bgAlpha);
}

/// Draws a single continuous RRect border stroke with a top→bottom gradient
/// so the highlight is stronger at the top (~30%) and fades toward the base
/// (~12%). A single drawRRect call guarantees continuity at every corner
/// — unlike Border() with per-side BorderSide, which produces seam artifacts.
/// Draws a gradient border around a rounded rect.
/// [bottomRadius] lets callers flatten the bottom corners (e.g. when the
/// popover is positioned above an anchor and its bottom should blend with the
/// element below rather than showing rounded corners in mid-air).
class PopoverBorderPainter extends CustomPainter {
  final double? bottomRadius;
  const PopoverBorderPainter({this.bottomRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect   = Offset.zero & size;
    final top    = const Radius.circular(PopoverStyle.radius);
    final bottom = bottomRadius != null
        ? Radius.circular(bottomRadius!)
        : top;
    final rrect  = RRect.fromRectAndCorners(
      rect,
      topLeft: top, topRight: top,
      bottomLeft: bottom, bottomRight: bottom,
    );

    final paint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader      = PopoverStyle.borderGradientShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(PopoverBorderPainter old) => old.bottomRadius != bottomRadius;
}

/// Liquid Glass background panel for large surfaces (bottom sheets, dialogs) —
/// as opposed to [PopoverStyle]/[PopoverBorderPainter] which target small
/// anchored popovers. Extracted from quick_add_task_sheet.dart's original
/// private `_LiquidPanel` so other large surfaces (e.g. TaskDetailSheet) can
/// reuse the exact same blur/fill/border treatment instead of duplicating it.
///
/// Uses a lower blur sigma (12) than [PopoverStyle.blurSigma] (20) to avoid an
/// overly heavy effect on a large area, while keeping the same visual
/// language. Graceful-without-blur note: the fill color alpha (0.82) is
/// opaque enough that the surface still reads cleanly if BackdropFilter ever
/// fails to render (e.g. unsupported renderer) — no separate fallback branch
/// is needed.
class LiquidPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const LiquidPanel({super.key, required this.child, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    // drawBottom=false when borderRadius has no bottom radius (bottom sheet):
    // omits the border line at the keyboard junction for a seamless blend.
    final hasBottomRadius = borderRadius.bottomLeft != Radius.zero;
    return CustomPaint(
      foregroundPainter: LiquidPanelBorderPainter(
        borderRadius: borderRadius,
        drawBottom: hasBottomRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          // Sigma 12 (vs 20 in popovers) — softer on a large area.
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              // Same color formula as PopoverStyle.bg but slightly more opaque
              // on a big surface so content stays readable through the blur.
              color: AppColors.navBar.withValues(alpha: 0.82),
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Draws the gradient border for a [LiquidPanel].
/// [drawBottom] = false for bottom sheets: skips the bottom edge so no
/// visible border line appears where the sheet meets the keyboard
/// (Todoist-style blend).
class LiquidPanelBorderPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool drawBottom;
  const LiquidPanelBorderPainter({required this.borderRadius, this.drawBottom = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader      = PopoverStyle.borderGradientShader(rect);

    if (drawBottom) {
      canvas.drawRRect(borderRadius.toRRect(rect), paint);
    } else {
      // Draw left side + top arc + right side; omit bottom edge entirely.
      final r  = borderRadius.topLeft.x;
      final w  = size.width;
      final h  = size.height;
      final path = Path()
        ..moveTo(0, h)              // start bottom-left (open end)
        ..lineTo(0, r)              // left side up to arc start
        ..arcToPoint(Offset(r, 0),
            radius: Radius.circular(r), clockwise: true)
        ..lineTo(w - r, 0)         // top edge
        ..arcToPoint(Offset(w, r),
            radius: Radius.circular(r), clockwise: true)
        ..lineTo(w, h);             // right side down to bottom-right (open end)
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(LiquidPanelBorderPainter old) =>
      old.borderRadius != borderRadius || old.drawBottom != drawBottom;
}
