import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'collapsible_section_header.dart';

/// Standard bottom sheet container with drag handle, title row, and body.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => AppSheet(
///     title: 'Título',
///     child: ...,
///   ),
/// );
/// ```
class AppSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? leadingAction;    // left side of header (e.g. cancel button)
  final Widget? trailingAction;   // right side of header (e.g. save button)
  final bool showHandle;
  final bool scrollable;          // wraps child in SingleChildScrollView

  const AppSheet({
    super.key,
    this.title,
    required this.child,
    this.leadingAction,
    this.trailingAction,
    this.showHandle = true,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final bottomPadding = view.padding.bottom / view.devicePixelRatio + AppSpacing.lg;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.sheetTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          if (showHandle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                    top: AppSpacing.sm + 2, bottom: AppSpacing.xs),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // ── Header row (only if title or actions provided) ────────────────
          if (title != null || leadingAction != null || trailingAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  if (leadingAction != null) leadingAction!,
                  if (leadingAction != null) const SizedBox(width: AppSpacing.sm),
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailingAction != null) trailingAction!,
                ],
              ),
            ),

          // ── Body ──────────────────────────────────────────────────────────
          if (scrollable)
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: child,
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// Convenience function — shows an AppSheet as a standard modal.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  String? title,
  required Widget child,
  Widget? leadingAction,
  Widget? trailingAction,
  bool scrollable = false,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AppSheet(
        title: title,
        leadingAction: leadingAction,
        trailingAction: trailingAction,
        scrollable: scrollable,
        child: child,
      ),
    ),
  );
}

/// Section label inside a sheet or screen — small, uppercase-style.
class AppSectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const AppSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.9),
            AppColors.textTertiary,
          ],
          stops: const [0.0, 0.55],
        ).createShader(bounds),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// Collapsible header for the "Completed" section, shared across all screens.
class CompletedSectionHeader extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const CompletedSectionHeader({
    super.key,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSectionHeader(
      title: 'Concluídas',
      count: count,
      expanded: expanded,
      onTap: onTap,
    );
  }
}
