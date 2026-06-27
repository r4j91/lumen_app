import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme_data.dart';
import '../theme/app_colors.dart';
import 'app_icon_screen.dart';
import 'debug_anchored_menu_screen.dart';
import 'package:hugeicons/hugeicons.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  AppThemeId _selected = ThemeProvider.instance.themeId;

  Future<void> _pick(AppThemeId id) async {
    if (_selected == id) return;
    HapticService().selectionClick();
    setState(() => _selected = id);
    await ThemeProvider.instance.setTheme(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _SectionLabel('Tema'),
          const SizedBox(height: 10),
          _buildThemeList(),
          const SizedBox(height: 28),
          _SectionLabel('Ícone do app'),
          const SizedBox(height: 10),
          _buildIconPlaceholder(),
          const SizedBox(height: 28),
          _SectionLabel('Dev / Testes'),
          const SizedBox(height: 10),
          _buildDebugRow(),
        ],
      ),
    );
  }

  Widget _buildThemeList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: AppThemeId.values.indexed.map((entry) {
          final (i, id) = entry;
          final isLast = i == AppThemeId.values.length - 1;
          final colors = AppThemeColors.forId(id);
          final isSelected = _selected == id;
          return _ThemeRow(
            id: id,
            colors: colors,
            selected: isSelected,
            showDivider: !isLast,
            onTap: () => _pick(id),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIconPlaceholder() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppIconScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(9),
              ),
              child: HugeIcon(icon: HugeIcons.strokeRoundedGrid, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ícone do app', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Escolher ícone', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DebugAnchoredMenuScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(9),
              ),
              child: HugeIcon(icon: HugeIcons.strokeRoundedTestTube01, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teste: novo menu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('AnchoredSelectMenu', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final AppThemeId id;
  final AppThemeColors colors;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  const _ThemeRow({
    required this.id,
    required this.colors,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                _ThemePreview(colors: colors),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        id.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        id.subtitle,
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: selected
                      ? HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, key: ValueKey(true), size: 20, color: AppColors.accent)
                      : HugeIcon(icon: HugeIcons.strokeRoundedCircle, key: ValueKey(false), size: 20, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 16 + 80 + 14, color: AppColors.surfaceVariant),
      ],
    );
  }
}

// Miniature theme preview: background rect + a card strip + an accent dot.
class _ThemePreview extends StatelessWidget {
  final AppThemeColors colors;
  const _ThemePreview({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 50,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: colors.surfaceVariant,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Card strip at top
          Positioned(
            top: 8, left: 7, right: 7,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          // Second card strip
          Positioned(
            top: 27, left: 7, right: 7,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          // Bottom nav indicator
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 5,
              color: colors.navBar,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 0.3,
      ),
    );
  }
}
