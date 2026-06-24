import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'pressable.dart';

/// Standard surface card — surface color, radius 12, optional press feedback.
///
/// Use this as the base for any card that contains content:
///   - Task cards (via TaskTile which wraps this internally)
///   - Project cards
///   - Quick-action cards
///   - Stat dashboard cards
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final double radius;
  final Border? border;
  final List<BoxShadow>? shadows;
  final bool pressable;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.only(bottom: AppSpacing.sm),
    this.color,
    this.radius = AppRadius.small,
    this.border,
    this.shadows,
    this.pressable = true,
  });

  /// Variant with no press effect — for purely informational cards.
  const AppCard.static({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.only(bottom: AppSpacing.sm),
    this.color,
    this.radius = AppRadius.small,
    this.border,
    this.shadows,
  })  : onTap = null,
        onLongPress = null,
        onLongPressStart = null,
        pressable = false;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadows,
      ),
      child: child,
    );

    if (!pressable || onTap == null) return card;

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      child: card,
    );
  }
}

/// A row inside a card with consistent icon + label + optional trailing layout.
class AppCardRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppCardRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: labelColor ??
                    Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Pressable(onTap: onTap, child: content);
  }
}
