import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';

/// Círculo de conclusão padronizado: verde translúcido + borda + tick verde.
class DoneCircle extends StatelessWidget {
  final bool done;
  final double size;
  final double borderWidth;
  final double tickSize;
  final Color ringColor;
  final double ringFillAlpha;

  DoneCircle({
    super.key,
    required this.done,
    this.size = 22,
    this.borderWidth = 2,
    this.tickSize = 13,
    Color? ringColor,
    this.ringFillAlpha = 0,
  }) : ringColor = ringColor ?? AppColors.textTertiary;

  static const Color doneColor = AppColors.dateDueToday;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? doneColor.withValues(alpha: 0.15)
            : (ringFillAlpha > 0
                ? ringColor.withValues(alpha: ringFillAlpha)
                : Colors.transparent),
        border: Border.all(
          color: done ? doneColor : ringColor,
          width: borderWidth,
        ),
      ),
      child: done
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedTick01,
              size: tickSize,
              color: doneColor,
            )
          : null,
    );
  }
}
