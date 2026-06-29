import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Liquid Glass treatment for header pills (avatar, bell+gear).
class HeaderLiquidPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HeaderLiquidPill({super.key, required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.navBar.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
