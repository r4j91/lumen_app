// SCROLL-FADE-V1
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Scrim gradient on the bottom edge of scrollable content so items dissolving
/// under the floating nav pill + FAB stay legible and don't bleed through
/// the glass navbar.
///
/// Uses an opaque background overlay (not alpha-mask on content) for a
/// stronger hide than [ShaderMask] alone.
class ScrollFadeOverlay extends StatelessWidget {
  const ScrollFadeOverlay({
    super.key,
    required this.child,
    this.fadeHeight,
  });

  final Widget child;

  /// Height of the bottom scrim. Defaults to nav chrome + extra buffer.
  final double? fadeHeight;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width >= 1024) return child;

    final bg = AppColors.background;
    final height = fadeHeight ?? AppLayout.totalBottomChromeHeight(context) + 28;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0),
                    bg.withValues(alpha: 0.82),
                    bg.withValues(alpha: 0.96),
                    bg,
                  ],
                  stops: const [0.0, 0.38, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
