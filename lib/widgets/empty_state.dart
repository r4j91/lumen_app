import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _iconAnim;
  late final Animation<double> _titleAnim;
  late final Animation<double> _subtitleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 540),
      vsync: this,
    );

    // Stagger: ícone → título (60ms depois) → subtítulo (60ms depois)
    _iconAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.00, 0.55, curve: Curves.easeOutCubic),
    );
    _titleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.11, 0.66, curve: Curves.easeOutCubic),
    );
    _subtitleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.22, 0.78, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone com "sol de pêssego" espiando atrás
            FadeTransition(
              opacity: _iconAnim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.0).animate(_iconAnim),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Accent "sol" deslocado para cima-direita
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                      // Círculo principal
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceVariant,
                        ),
                        child: Icon(
                          widget.icon,
                          size: 34,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            FadeTransition(
              opacity: _titleAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(_titleAnim),
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),

              // Subtítulo
              FadeTransition(
                opacity: _subtitleAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(_subtitleAnim),
                  child: Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
