import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';

/// Shared collapsible row for project sections and the completed block.
class CollapsibleSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? trailing;

  const CollapsibleSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            trailing ?? const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}
