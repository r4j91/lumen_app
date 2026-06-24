import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_client.dart';
import '../../theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DesktopSidebar — expanded sidebar with projects/labels/filters sections
// Old plain-nav version is commented at the bottom of this file.
// ══════════════════════════════════════════════════════════════════════════════

class DesktopSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onSettings;
  final VoidCallback? onNewTask;
  final VoidCallback? onLogbookTap;
  // id e name da etiqueta clicada na sidebar
  final void Function(String id, String name)? onLabelTap;
  // id do projeto atualmente aberto (para highlight no sidebar)
  final String? selectedProjectId;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onSettings,
    this.onNewTask,
    this.onLogbookTap,
    this.onLabelTap,
    this.selectedProjectId,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar>
    with TickerProviderStateMixin {
  late int _localIndex;
  String? _avatarUrl;
  String _displayName = '';

  // Counters shown on nav items
  int _todayCount = 0;
  int _inboxCount = 0;

  // Dynamic lists
  List<_SBProject> _projects = [];
  List<_SBLabel> _labels = [];

  // Section expansion state + controllers
  bool _projectsExpanded = true;
  bool _labelsExpanded = false;
  bool _filtersExpanded = false;

  late final AnimationController _projectsCtrl;
  late final AnimationController _labelsCtrl;
  late final AnimationController _filtersCtrl;

  static const _kExpandDur = Duration(milliseconds: 220);
  static const _kMaxSubItems = 8;

  // Hard-coded filter items matching FiltersScreen._FilterView
  static const _filterDefs = [
    (icon: Icons.warning_amber_rounded,      label: 'Atrasadas'),
    (icon: Icons.today_rounded,               label: 'Hoje'),
    (icon: Icons.date_range_rounded,          label: 'Próximos 7 dias'),
    (icon: Icons.check_circle_outline_rounded, label: 'Concluídas'),
  ];

  bool get _accentIsLight => AppColors.accent.computeLuminance() > 0.5;

  @override
  void initState() {
    super.initState();
    _localIndex = widget.selectedIndex;
    _projectsCtrl = AnimationController(vsync: this, duration: _kExpandDur, value: 1.0);
    _labelsCtrl   = AnimationController(vsync: this, duration: _kExpandDur, value: 0.0);
    _filtersCtrl  = AnimationController(vsync: this, duration: _kExpandDur, value: 0.0);
    _loadUser();
    _loadCounts();
    _loadProjects();
    _loadLabels();
  }

  @override
  void dispose() {
    _projectsCtrl.dispose();
    _labelsCtrl.dispose();
    _filtersCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DesktopSidebar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      setState(() => _localIndex = widget.selectedIndex);
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  void _loadUser() {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final url  = meta['avatar_url'] as String?;
    final nome     = meta['nome'] as String? ?? '';
    final apelido  = meta['apelido'] as String? ?? '';
    final email    = user?.email ?? '';
    if (mounted) {
      setState(() {
        _avatarUrl    = (url != null && url.startsWith('http')) ? url : null;
        _displayName  = apelido.isNotEmpty
            ? apelido
            : nome.isNotEmpty
                ? nome.split(' ').first
                : email.split('@').first;
      });
    }
  }

  Future<void> _loadCounts() async {
    try {
      final now      = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final todayRows = await supabase
          .from('tasks')
          .select('id')
          .eq('concluida', false)
          .eq('data', todayStr) as List;

      final inboxRows = await supabase
          .from('tasks')
          .select('id')
          .eq('concluida', false)
          .isFilter('project_id', null)
          .isFilter('data', null) as List;

      if (mounted) {
        setState(() {
          _todayCount = todayRows.length;
          _inboxCount = inboxRows.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProjects() async {
    try {
      final rows = await supabase
          .from('projects')
          .select('id, nome, cor')
          .order('nome') as List;
      if (mounted) {
        setState(() {
          _projects = rows.map((r) => _SBProject(
            id:       r['id'].toString(),
            name:     r['nome'] as String? ?? '',
            colorHex: r['cor'] as String?,
          )).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLabels() async {
    try {
      final rows = await supabase
          .from('labels')
          .select('id, nome, cor')
          .order('nome') as List;
      if (mounted) {
        setState(() {
          _labels = rows.map((r) => _SBLabel(
            id:       r['id'].toString(),
            name:     r['nome'] as String? ?? '',
            colorHex: r['cor'] as String?,
          )).toList();
        });
      }
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _select(int i) {
    setState(() => _localIndex = i);
    widget.onDestinationSelected(i);
  }

  void _toggleSection({
    required bool current,
    required AnimationController ctrl,
    required void Function(bool) setter,
  }) {
    final next = !current;
    setState(() => setter(next));
    next ? ctrl.forward() : ctrl.reverse();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final al = _accentIsLight;

    return Container(
      width: 260,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo ───────────────────────────────────────────────────────────
          const _SBLogo(),

          // ── Nova tarefa ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
            child: _NewTaskButton(
              onTap: widget.onNewTask,
              accentIsLight: al,
            ),
          ),

          // ── Fixed nav: Inbox, Hoje, Em breve ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _SBNavItem(
                  icon: Icons.move_to_inbox_rounded,
                  label: 'Inbox',
                  selected: _localIndex == 1,
                  badge: _inboxCount,
                  accentIsLight: al,
                  onTap: () => _select(1),
                ),
                _SBNavItem(
                  iconBuilder: (sel) => _TodaySBIcon(selected: sel, accentIsLight: al),
                  label: 'Hoje',
                  selected: _localIndex == 2,
                  badge: _todayCount,
                  accentIsLight: al,
                  onTap: () => _select(2),
                ),
                _SBNavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Em breve',
                  selected: _localIndex == 3,
                  accentIsLight: al,
                  onTap: () => _select(3),
                ),
                _SBNavItem(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Concluídas',
                  selected: false,
                  accentIsLight: al,
                  onTap: widget.onLogbookTap,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _SBDivider(),
          ),

          // ── Expandable sections ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Projetos ──────────────────────────────────────────────
                    _SectionHeader(
                      label: 'Projetos',
                      expanded: _projectsExpanded,
                      accentIsLight: al,
                      onChevronTap: () => _toggleSection(
                        current: _projectsExpanded,
                        ctrl: _projectsCtrl,
                        setter: (v) => _projectsExpanded = v,
                      ),
                      onLabelTap: () => _select(0),
                    ),
                    ClipRect(
                      child: SizeTransition(
                        sizeFactor: CurvedAnimation(
                          parent: _projectsCtrl,
                          curve: Curves.easeInOutCubic,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_projects.isEmpty)
                              _EmptyHint('Nenhum projeto ainda'),
                            ..._projects.take(_kMaxSubItems).map((p) => _SubNavItem(
                              dot: AppColors.parseHex(p.colorHex),
                              label: p.name,
                              accentIsLight: al,
                              selected: widget.selectedProjectId == p.id,
                              onTap: () => _select(0),
                            )),
                            if (_projects.length > _kMaxSubItems)
                              _SeeAllRow(
                                label: 'Ver todos (${_projects.length})',
                                onTap: () => _select(0),
                              ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // ── Etiquetas ─────────────────────────────────────────────
                    _SectionHeader(
                      label: 'Etiquetas',
                      expanded: _labelsExpanded,
                      accentIsLight: al,
                      onChevronTap: () => _toggleSection(
                        current: _labelsExpanded,
                        ctrl: _labelsCtrl,
                        setter: (v) => _labelsExpanded = v,
                      ),
                    ),
                    ClipRect(
                      child: SizeTransition(
                        sizeFactor: CurvedAnimation(
                          parent: _labelsCtrl,
                          curve: Curves.easeInOutCubic,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_labels.isEmpty)
                              _EmptyHint('Nenhuma etiqueta ainda'),
                            ..._labels.take(_kMaxSubItems).map((l) => _SubNavItem(
                              dot: AppColors.parseHex(l.colorHex),
                              label: l.name,
                              accentIsLight: al,
                              onTap: () => widget.onLabelTap?.call(l.id, l.name),
                            )),
                            if (_labels.length > _kMaxSubItems)
                              _SeeAllRow(
                                label: 'Ver todas (${_labels.length})',
                                onTap: () => widget.onLabelTap?.call('', ''),
                              ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // ── Filtros ───────────────────────────────────────────────
                    _SectionHeader(
                      label: 'Filtros',
                      expanded: _filtersExpanded,
                      accentIsLight: al,
                      onChevronTap: () => _toggleSection(
                        current: _filtersExpanded,
                        ctrl: _filtersCtrl,
                        setter: (v) => _filtersExpanded = v,
                      ),
                      onLabelTap: () => _select(4),
                    ),
                    ClipRect(
                      child: SizeTransition(
                        sizeFactor: CurvedAnimation(
                          parent: _filtersCtrl,
                          curve: Curves.easeInOutCubic,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._filterDefs.map((f) => _SubNavItem(
                              icon: f.icon,
                              label: f.label,
                              accentIsLight: al,
                              onTap: () => _select(4),
                            )),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _SBDivider(),
          ),
          _SBUserTile(
            avatarUrl: _avatarUrl,
            displayName: _displayName,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _SBDivider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            child: _SBNavItem(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              selected: false,
              accentIsLight: al,
              onTap: widget.onSettings,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────────

class _SBProject {
  final String id;
  final String name;
  final String? colorHex;
  const _SBProject({required this.id, required this.name, this.colorHex});
}

class _SBLabel {
  final String id;
  final String name;
  final String? colorHex;
  const _SBLabel({required this.id, required this.name, this.colorHex});
}

// ── Logo ───────────────────────────────────────────────────────────────────────

class _SBLogo extends StatelessWidget {
  const _SBLogo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/lumen_fosco.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'LUMEN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nova tarefa button ─────────────────────────────────────────────────────────

class _NewTaskButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool accentIsLight;
  const _NewTaskButton({this.onTap, required this.accentIsLight});

  @override
  State<_NewTaskButton> createState() => _NewTaskButtonState();
}

class _NewTaskButtonState extends State<_NewTaskButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _bg {
    if (_pressed) return AppColors.accent.withValues(alpha: 0.85);
    if (_hovered) return AppColors.accent.withValues(alpha: 0.92);
    return AppColors.accent;
  }

  Color get _fg =>
      widget.accentIsLight ? AppColors.textPrimary.withValues(alpha: 0.9) : Colors.white;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 36,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: _fg),
              const SizedBox(width: 6),
              Text(
                'Nova tarefa',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _fg,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _fg.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Q',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _fg.withValues(alpha: 0.70),
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

// ── Section header (label + chevron) ──────────────────────────────────────────

class _SectionHeader extends StatefulWidget {
  final String label;
  final bool expanded;
  final bool accentIsLight;
  final VoidCallback onChevronTap;
  final VoidCallback? onLabelTap;

  const _SectionHeader({
    required this.label,
    required this.expanded,
    required this.accentIsLight,
    required this.onChevronTap,
    this.onLabelTap,
  });

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onChevronTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.textPrimary.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              // Label — navigates to section screen if onLabelTap provided
              Expanded(
                child: GestureDetector(
                  onTap: widget.onLabelTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              // Chevron
              AnimatedRotation(
                turns: widget.expanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-item (indented, with dot or icon) ─────────────────────────────────────

class _SubNavItem extends StatefulWidget {
  final Color? dot;
  final IconData? icon;
  final String label;
  final bool accentIsLight;
  final bool selected;
  final VoidCallback onTap;

  const _SubNavItem({
    this.dot,
    this.icon,
    required this.label,
    required this.accentIsLight,
    this.selected = false,
    required this.onTap,
  });

  @override
  State<_SubNavItem> createState() => _SubNavItemState();
}

class _SubNavItemState extends State<_SubNavItem> {
  bool _hovered = false;

  Color get _bg {
    if (widget.selected) {
      return widget.accentIsLight
          ? AppColors.surfaceVariant
          : AppColors.accent.withValues(alpha: 0.10);
    }
    if (_hovered) return AppColors.textPrimary.withValues(alpha: 0.05);
    return Colors.transparent;
  }

  Color get _textColor {
    if (widget.selected) {
      return widget.accentIsLight ? AppColors.textPrimary : AppColors.accent;
    }
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 32,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Leading: colored dot or icon
              SizedBox(
                width: 20,
                child: Center(
                  child: widget.dot != null
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.dot,
                            shape: BoxShape.circle,
                          ),
                        )
                      : Icon(
                          widget.icon,
                          size: 14,
                          color: _textColor,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
                    color: _textColor,
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

// ── Empty hint ─────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── See-all row ────────────────────────────────────────────────────────────────

class _SeeAllRow extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SeeAllRow({required this.label, required this.onTap});

  @override
  State<_SeeAllRow> createState() => _SeeAllRowState();
}

class _SeeAllRowState extends State<_SeeAllRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _hovered ? AppColors.accent : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav item (with optional badge) ────────────────────────────────────────────

class _SBNavItem extends StatefulWidget {
  final IconData? icon;
  final Widget Function(bool selected)? iconBuilder;
  final String label;
  final bool selected;
  final int badge;
  final bool accentIsLight;
  final VoidCallback? onTap;

  const _SBNavItem({
    this.icon,
    this.iconBuilder,
    required this.label,
    required this.selected,
    this.badge = 0,
    required this.accentIsLight,
    this.onTap,
  });

  @override
  State<_SBNavItem> createState() => _SBNavItemState();
}

class _SBNavItemState extends State<_SBNavItem> {
  bool _hovered = false;

  Color get _bg {
    if (widget.selected) {
      return widget.accentIsLight
          ? AppColors.surfaceVariant
          : AppColors.accent.withValues(alpha: 0.12);
    }
    if (_hovered) return AppColors.surfaceVariant;
    return Colors.transparent;
  }

  Color get _fg {
    if (widget.selected) {
      return widget.accentIsLight ? AppColors.textPrimary : AppColors.accent;
    }
    return _hovered ? AppColors.textPrimary : AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: widget.iconBuilder != null
                      ? widget.iconBuilder!(widget.selected)
                      : Icon(widget.icon, size: 18, color: _fg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color: _fg,
                  ),
                  child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              // Badge counter
              if (widget.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.badge}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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

// ── Divider ────────────────────────────────────────────────────────────────────

class _SBDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppColors.surfaceVariant);
  }
}

// ── User tile ──────────────────────────────────────────────────────────────────

class _SBUserTile extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  const _SBUserTile({required this.avatarUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final initials = displayName.isEmpty
        ? '?'
        : displayName.substring(0, math.min(2, displayName.length)).toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
              image: avatarUrl != null
                  ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: avatarUrl == null
                ? Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today icon (day number in rounded square) ──────────────────────────────────

class _TodaySBIcon extends StatelessWidget {
  final bool selected;
  final bool accentIsLight;
  const _TodaySBIcon({required this.selected, required this.accentIsLight});

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (accentIsLight ? AppColors.textPrimary : AppColors.accent)
        : AppColors.textSecondary;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Center(
        child: Text(
          '${DateTime.now().day}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OLD CODE — commented for manual reversion
// ══════════════════════════════════════════════════════════════════════════════

/*
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class DesktopSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onSettings;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onSettings,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  late int _localIndex;
  String? _avatarUrl;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _localIndex = widget.selectedIndex;
    _loadUser();
  }

  void _loadUser() {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final url = meta['avatar_url'] as String?;
    final nome = meta['nome'] as String? ?? '';
    final apelido = meta['apelido'] as String? ?? '';
    final email = user?.email ?? '';
    setState(() {
      _avatarUrl = (url != null && url.startsWith('http')) ? url : null;
      _displayName = apelido.isNotEmpty
          ? apelido
          : nome.isNotEmpty
              ? nome.split(' ').first
              : email.split('@').first;
    });
  }

  @override
  void didUpdateWidget(DesktopSidebar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _localIndex = widget.selectedIndex;
    }
  }

  void _select(int i) {
    setState(() => _localIndex = i);
    widget.onDestinationSelected(i);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarLogo(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _SidebarNavItem(
                  icon: Icons.move_to_inbox_rounded,
                  label: 'Caixa de entrada',
                  selected: _localIndex == 1,
                  onTap: () => _select(1),
                ),
                _SidebarNavItem(
                  iconBuilder: (selected) => _TodaySidebarIcon(selected: selected),
                  label: 'Hoje',
                  selected: _localIndex == 2,
                  onTap: () => _select(2),
                ),
                _SidebarNavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Em breve',
                  selected: _localIndex == 3,
                  onTap: () => _select(3),
                ),
                const SizedBox(height: 4),
                _SidebarDivider(),
                const SizedBox(height: 4),
                _SidebarNavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Projetos',
                  selected: _localIndex == 0,
                  onTap: () => _select(0),
                ),
                _SidebarNavItem(
                  icon: Icons.filter_list_rounded,
                  label: 'Filtros',
                  selected: _localIndex == 4,
                  onTap: () => _select(4),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _SidebarDivider(),
          ),
          _SidebarUserTile(
            avatarUrl: _avatarUrl,
            displayName: _displayName,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: _SidebarDivider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: _SidebarNavItem(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              selected: false,
              onTap: widget.onSettings,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/icon/lumen_fosco.png', width: 28, height: 28, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Text('LUMEN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppColors.surfaceVariant);
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData? icon;
  final Widget Function(bool selected)? iconBuilder;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _SidebarNavItem({this.icon, this.iconBuilder, required this.label, required this.selected, this.onTap});
  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;
  bool get _accentIsLight => AppColors.accent.computeLuminance() > 0.5;
  Color get _bg {
    if (widget.selected) return _accentIsLight ? AppColors.surfaceVariant : AppColors.accent.withValues(alpha: 0.12);
    if (_hovered) return AppColors.surfaceVariant;
    return Colors.transparent;
  }
  Color get _fgColor {
    if (widget.selected) return _accentIsLight ? AppColors.textPrimary : AppColors.accent;
    return _hovered ? AppColors.textPrimary : AppColors.textSecondary;
  }
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              SizedBox(width: 20, height: 20, child: Center(
                child: widget.iconBuilder != null
                    ? widget.iconBuilder!(widget.selected)
                    : Icon(widget.icon, size: 18, color: _fgColor),
              )),
              const SizedBox(width: 10),
              Expanded(child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(fontSize: 13.5, fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400, color: _fgColor),
                child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarUserTile extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  const _SidebarUserTile({required this.avatarUrl, required this.displayName});
  @override
  Widget build(BuildContext context) {
    final initials = displayName.isEmpty ? '?' : displayName.substring(0, math.min(2, displayName.length)).toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.15),
              image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover) : null),
            child: avatarUrl == null ? Center(child: Text(initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(displayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _TodaySidebarIcon extends StatelessWidget {
  final bool selected;
  const _TodaySidebarIcon({required this.selected});
  @override
  Widget build(BuildContext context) {
    final color = selected ? (AppColors.accent.computeLuminance() > 0.5 ? AppColors.textPrimary : AppColors.accent) : AppColors.textSecondary;
    return Container(
      width: 18, height: 18,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: color, width: 1.6)),
      child: Center(child: Text('${DateTime.now().day}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, height: 1))),
    );
  }
}
*/
