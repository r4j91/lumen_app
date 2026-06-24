import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shimmer animado para estado de carregamento das listas de tarefas.
class SkeletonLoader extends StatefulWidget {
  final int itemCount;
  const SkeletonLoader({super.key, this.itemCount = 5});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final base = AppColors.surfaceVariant;
            final highlight = Color.alphaBlend(
              AppColors.textPrimary.withValues(alpha: 0.12),
              base,
            );
            return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, highlight, base],
            stops: [
              (_ctrl.value - 0.35).clamp(0.0, 1.0),
              _ctrl.value.clamp(0.0, 1.0),
              (_ctrl.value + 0.35).clamp(0.0, 1.0),
            ],
          ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        itemBuilder: (_, i) => _SkeletonCard(
          titleWidth: i % 3 == 0 ? 0.55 : (i % 3 == 1 ? 0.75 : 0.65),
          hasSecondLine: i % 2 == 0,
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double titleWidth;
  final bool hasSecondLine;

  const _SkeletonCard({required this.titleWidth, required this.hasSecondLine});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 24;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot placeholder
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Container(
                  width: w * titleWidth,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Container(
                  width: w * 0.35,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                if (hasSecondLine) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: w * 0.5,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
