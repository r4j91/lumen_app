import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../screens/task_detail_sheet.dart';
import '../screens/search_screen.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/palette_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_sheet.dart';
import 'desktop_shell/desktop_app_shell.dart';
import 'pressable.dart';
import 'package:hugeicons/hugeicons.dart';

class _NavItem {
  final List<List<dynamic>>? hugeIcon;
  final String label;
  final Widget Function(bool selected)? iconBuilder;
  const _NavItem({this.hugeIcon, required this.label, this.iconBuilder});
}

final _navItems = [
  _NavItem(hugeIcon: HugeIcons.strokeRoundedHome01, label: 'Navegar'),
  _NavItem(hugeIcon: HugeIcons.strokeRoundedInbox, label: 'Inbox'),
  _NavItem(label: 'Hoje', iconBuilder: (selected) => _TodayIcon(selected: selected)),
  _NavItem(hugeIcon: HugeIcons.strokeRoundedCalendar03, label: 'Em breve'),
  _NavItem(hugeIcon: HugeIcons.strokeRoundedFilterHorizontal, label: 'Filtros'),
];

/// Ícone da aba Hoje: quadrado arredondado com o número do dia, estilo Todoist iOS.
class _TodayIcon extends StatelessWidget {
  final bool selected;
  const _TodayIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textTertiary;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color, width: 1.8),
      ),
      child: Center(
        child: Text(
          '${DateTime.now().day}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class ResponsiveLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onTaskCreated;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProjectCreated;

  const ResponsiveLayout({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.onTaskCreated,
    this.onSearchTap,
    this.onProjectCreated,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Builder(builder: (context) {
      void openNewTask() => showNewTaskSheet(context, onSaved: onTaskCreated);
      void openSearch() => showSearchScreen(context);
      void openNewProject() => unawaited(_showNewProjectSheet(context, onCreated: onProjectCreated));

      // ── Desktop ───────────────────────────────────────────────────────────
      if (screenWidth >= 1024) {
        return DesktopAppShell(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          body: body,
          onNewTask: openNewTask,
          onSearch: openSearch,
          onProjectCreated: onProjectCreated,
        );
      }

      final adaptedBody = _adaptBodyForScreenWidth(body, screenWidth);

      // ── Mobile / Tablet ─────────────────────────────────────────────────────
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      const pillHeight = 62.0;
      const fabSize = 56.0;
      const fabGap = 10.0;
      const sideMargin = 14.0;
      final pillMarginBottom = bottomPadding + 12.0;
      final totalBarHeight = pillMarginBottom + pillHeight + fabGap + fabSize;

      return Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: SafeArea(bottom: false, child: adaptedBody),
        bottomNavigationBar: Material(
          color: Colors.transparent,
          child: SizedBox(
            height: totalBarHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Liquid Glass pill ────────────────────────────────────────
                Positioned(
                  left: sideMargin,
                  right: sideMargin,
                  bottom: pillMarginBottom,
                  height: pillHeight,
                  child: _LiquidGlassPill(
                    items: _navItems,
                    selectedIndex: selectedIndex,
                    onSelected: onDestinationSelected,
                  ),
                ),
                // ── FAB — expandable menu, above pill ───────────────────────
                Positioned(
                  right: sideMargin,
                  bottom: pillMarginBottom + pillHeight + fabGap,
                  width: fabSize,
                  height: fabSize,
                  child: _ExpandableFAB(
                    onNewTask: openNewTask,
                    onNewProject: openNewProject,
                    onSearch: openSearch,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Tablet: center content with readable max width. Phone: full bleed.
Widget _adaptBodyForScreenWidth(Widget body, double screenWidth) {
  if (screenWidth < 600) return body;
  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: screenWidth >= 768 ? 720 : 640),
      child: body,
    ),
  );
}

// ── New project sheet (standalone, usable from FAB) ───────────────────────────

Future<void> _showNewProjectSheet(BuildContext context, {VoidCallback? onCreated}) {
  return showAppSheet(
    context: context,
    title: 'Novo projeto',
    scrollable: true,
    child: _NewProjectSheetForm(onCreated: onCreated),
  );
}

class _NewProjectSheetForm extends StatefulWidget {
  final VoidCallback? onCreated;

  const _NewProjectSheetForm({this.onCreated});

  @override
  State<_NewProjectSheetForm> createState() => _NewProjectSheetFormState();
}

class _NewProjectSheetFormState extends State<_NewProjectSheetForm> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    HapticService().saved();
    final userId = supabase.auth.currentUser?.id;
    if (!mounted) return;
    Navigator.pop(context);
    try {
      await supabase.from('projects').insert({
        'nome': name,
        if (userId != null) 'user_id': userId,
        'favorito': false,
        'cor': PaletteColors.defaultHex,
      });
      widget.onCreated?.call();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: const InputDecoration(hintText: 'Nome do projeto'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Criar projeto',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ── FAB action descriptor ─────────────────────────────────────────────────────

class _FabAction {
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;
  const _FabAction({required this.icon, required this.label, this.onTap});
}

// ── Expandable FAB ────────────────────────────────────────────────────────────

class _ExpandableFAB extends StatefulWidget {
  final VoidCallback onNewTask;
  final VoidCallback? onNewProject;
  final VoidCallback? onSearch;

  const _ExpandableFAB({required this.onNewTask, this.onNewProject, this.onSearch});

  @override
  State<_ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<_ExpandableFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final Animation<double> _rotation;
  OverlayEntry? _overlay;
  bool _open = false;

  static const _pillHeight = 62.0;
  static const _fabGap = 10.0;
  static const _sideMargin = 14.0;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _rotation = Tween<double>(begin: 0.0, end: 0.125)
        .animate(CurvedAnimation(parent: _rotCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _close();
    _rotCtrl.dispose();
    super.dispose();
  }

  void _toggle() => _open ? _close() : _openMenu();

  void _openMenu() {
    HapticService().fabOpened();
    final mq = MediaQuery.of(context);
    final fabBottom = mq.padding.bottom + 12 + _pillHeight + _fabGap;

    _overlay = OverlayEntry(
      builder: (_) => _FabOverlay(
        fabBottom: fabBottom,
        fabRight: _sideMargin,
        onDismiss: _close,
        actions: [
          _FabAction(
            icon: HugeIcons.strokeRoundedTaskAdd01,
            label: 'Nova tarefa',
            onTap: () { _close(); widget.onNewTask(); },
          ),
          _FabAction(
            icon: HugeIcons.strokeRoundedFolder01,
            label: 'Novo projeto',
            onTap: () { _close(); widget.onNewProject?.call(); },
          ),
          _FabAction(
            icon: HugeIcons.strokeRoundedSearch01,
            label: 'Buscar',
            onTap: () { _close(); widget.onSearch?.call(); },
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlay!);
    _rotCtrl.forward();
    setState(() => _open = true);
  }

  void _close() {
    if (!_open && _overlay == null) return;
    _overlay?.remove();
    _overlay = null;
    _rotCtrl.reverse();
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.92,
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (_, child) =>
            Transform.rotate(angle: _rotation.value * 2 * math.pi, child: child),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
            // FAB-GLOW-OLD: halo accent muito intenso (alpha 0.38, blur 16).
            // boxShadow: [
            //   BoxShadow(
            //     color: AppColors.accent.withValues(alpha: 0.38),
            //     blurRadius: 16,
            //     offset: const Offset(0, 5),
            //   ),
            //   BoxShadow(
            //     color: Colors.black.withValues(alpha: 0.18),
            //     blurRadius: 6,
            //     offset: const Offset(0, 2),
            //   ),
            // ],
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 27, color: AppColors.background),
          ),
        ),
      ),
    );
  }
}

// ── FAB overlay: backdrop + action items ──────────────────────────────────────

class _FabOverlay extends StatefulWidget {
  final double fabBottom;
  final double fabRight;
  final VoidCallback onDismiss;
  final List<_FabAction> actions;

  const _FabOverlay({
    required this.fabBottom,
    required this.fabRight,
    required this.onDismiss,
    required this.actions,
  });

  @override
  State<_FabOverlay> createState() => _FabOverlayState();
}

class _FabOverlayState extends State<_FabOverlay> with TickerProviderStateMixin {
  late final AnimationController _barrierCtrl;
  late final List<AnimationController> _itemCtrls;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();

    _barrierCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180))
      ..forward();

    _itemCtrls = List.generate(
      widget.actions.length,
      (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 200)),
    );

    _fades = _itemCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut)
            as Animation<double>)
        .toList();

    _slides = _itemCtrls
        .map((c) => Tween<Offset>(
                    begin: const Offset(0, 0.25), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    for (var i = 0; i < _itemCtrls.length; i++) {
      Future.delayed(Duration(milliseconds: i * 45), () {
        if (mounted) _itemCtrls[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _barrierCtrl.dispose();
    for (final c in _itemCtrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fabSize = 56.0;
    const itemH = 44.0;
    const itemGap = 12.0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark backdrop — tap to dismiss
          Positioned.fill(
            child: FadeTransition(
              opacity: _barrierCtrl,
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),

          // Action rows: stacked bottom→top (index 0 = closest to FAB)
          ...widget.actions.asMap().entries.map((e) {
            final i = e.key;
            final action = e.value;
            final bottomOffset =
                widget.fabBottom + fabSize + 14 + i * (itemH + itemGap);

            return Positioned(
              right: widget.fabRight,
              bottom: bottomOffset,
              child: FadeTransition(
                opacity: _fades[i],
                child: SlideTransition(
                  position: _slides[i],
                  child: _FabMenuItem(
                    icon: action.icon,
                    label: action.label,
                    onTap: action.onTap,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Single action row ──────────────────────────────────────────────────────────

class _FabMenuItem extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;
  const _FabMenuItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticService().selectionClick();
        onTap?.call();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: HugeIcon(icon: icon, size: 20, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

// ── Liquid Glass pill ─────────────────────────────────────────────────────────

class _LiquidGlassPill extends StatefulWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _LiquidGlassPill({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<_LiquidGlassPill> createState() => _LiquidGlassPillState();
}

class _LiquidGlassPillState extends State<_LiquidGlassPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _itemWidth = 0;
  bool _laid = false;

  static const _spring = SpringDescription(mass: 1, stiffness: 600, damping: 32);

  // NAVBAR-PERF-V1: feature flag pra teste A/B de performance — false por
  // padrão (blur real é o comportamento atual). Mudar pra true só pra medir
  // se o BackdropFilter é o gargalo de scroll no iPhone; revertido depois.
  static const bool _useSimulatedBlur = false;

  // Indicator color: enough contrast on both dark and light themes
  Color get _indicatorColor => AppColors.navBar.computeLuminance() > 0.5
      ? AppColors.background   // light theme: tinted background for contrast
      : AppColors.surfaceVariant; // dark theme: lighter surface

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    final sim = SpringSimulation(_spring, _ctrl.value, target, _ctrl.velocity);
    _ctrl.animateWith(sim);
  }

  @override
  void didUpdateWidget(_LiquidGlassPill old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex && _laid) {
      _springTo(widget.selectedIndex * _itemWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NAVBAR-PERF-OLD: sem RepaintBoundary, sigmaX/Y: 24
    return RepaintBoundary(
      child: ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: _useSimulatedBlur
          // NAVBAR-PERF-V1: simulação de blur sem custo de GPU — usado só
          // pra teste A/B de performance, não é o comportamento padrão.
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.navBar.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(32),
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
              child: _buildPillContent(),
            )
          : BackdropFilter(
        // NAVBAR-PERF-V1: sigma 24->16 — imperceptível em movimento, mais barato
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16, tileMode: TileMode.clamp),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navBar.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(32),
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
          child: _buildPillContent(),
        ),
      ),
      ),
    );
  }

  // NAVBAR-PERF-V1: extraído pra ser compartilhado entre o ramo com
  // BackdropFilter real e o ramo simulado (_useSimulatedBlur).
  Widget _buildPillContent() {
    return LayoutBuilder(builder: (_, constraints) {
      final itemWidth = constraints.maxWidth / widget.items.length;
      const inset = 5.0;

      // Set initial position on first layout without animation
      if (!_laid || _itemWidth != itemWidth) {
        _itemWidth = itemWidth;
        _laid = true;
        _ctrl.value = widget.selectedIndex * itemWidth;
      }

      return Stack(
        children: [
          // Spring-animated active indicator
          AnimatedBuilder(
            animation: _ctrl,
            builder: (ctx, child) => Positioned(
              left: _ctrl.value + inset,
              top: inset,
              bottom: inset,
              width: itemWidth - inset * 2,
              child: Container(
                decoration: BoxDecoration(
                  color: _indicatorColor,
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ),
          // Nav items
          Row(
            children: widget.items
                .asMap()
                .entries
                .map((e) => Expanded(
                      child: _PillItem(
                        hugeIcon: e.value.hugeIcon,
                        iconBuilder: e.value.iconBuilder,
                        label: e.value.label,
                        selected: widget.selectedIndex == e.key,
                        onTap: () {
                          HapticService().tabChanged();
                          widget.onSelected(e.key);
                        },
                      ),
                    ))
                .toList(),
          ),
        ],
      );
    });
  }
}

// ── Single pill item with bounce on selection ─────────────────────────────────

class _PillItem extends StatefulWidget {
  final List<List<dynamic>>? hugeIcon;
  final Widget Function(bool selected)? iconBuilder;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillItem({
    this.hugeIcon,
    this.iconBuilder,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PillItem> createState() => _PillItemState();
}

class _PillItemState extends State<_PillItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.12)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.12, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 60),
    ]).animate(_bounceCtrl);
  }

  @override
  void didUpdateWidget(_PillItem old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected) {
      _bounceCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _bounce,
            builder: (context, child) =>
                Transform.scale(scale: _bounce.value, child: child),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: widget.iconBuilder != null
                  ? KeyedSubtree(
                      key: ValueKey(widget.selected),
                      child: widget.iconBuilder!(widget.selected),
                    )
                  : HugeIcon(
                      icon: widget.hugeIcon!,
                      key: ValueKey(widget.selected),
                      size: 22,
                      color: widget.selected
                          ? AppColors.accent
                          : AppColors.textTertiary,
                    ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: widget.selected
                  ? AppColors.accent
                  : AppColors.textTertiary,
              letterSpacing: 0,
            ),
            child: Text(widget.label),
          ),
        ],
      ),
    );
  }
}
