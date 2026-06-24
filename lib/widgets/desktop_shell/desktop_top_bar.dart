import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DesktopTopBar extends StatelessWidget {
  final VoidCallback? onSearch;
  // title: nome da seção ativa exibido no lado esquerdo da barra
  final String title;

  const DesktopTopBar({
    super.key,
    this.onSearch,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // ── Título da seção ──────────────────────────────────────────────
            if (title.isNotEmpty)
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            const Spacer(),
            _SearchButton(onTap: onSearch),
          ],
        ),
      ),
    );
  }
}

class _SearchButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _SearchButton({this.onTap});

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceVariant
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Buscar',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⌘K',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OLD CODE — comentado para reversão manual
// ══════════════════════════════════════════════════════════════════════════════

/*
class DesktopTopBar extends StatelessWidget {
  final VoidCallback? onSearch;
  final VoidCallback? onNewTask;

  const DesktopTopBar({
    super.key,
    this.onSearch,
    this.onNewTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Spacer(),
            _SearchButton(onTap: onSearch),
            const SizedBox(width: 10),
            _NewTaskButton(onTap: onNewTask),
          ],
        ),
      ),
    );
  }
}

class _NewTaskButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _NewTaskButton({this.onTap});

  @override
  State<_NewTaskButton> createState() => _NewTaskButtonState();
}

class _NewTaskButtonState extends State<_NewTaskButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accent.withValues(alpha: 0.85)
                : AppColors.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: AppColors.background),
              const SizedBox(width: 5),
              Text(
                'Nova tarefa',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.background,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Q',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.background.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
