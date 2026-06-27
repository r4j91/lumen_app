import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../services/task_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/swipeable_task_tile.dart';
import '../widgets/task_tile.dart';
import 'task_detail_sheet.dart';
import '../widgets/scroll_fade_overlay.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Calendar mode ─────────────────────────────────────────────────────────────

enum _CalMode { month, week, agenda }

// Top-level constants — avoid allocating new lists on every _dayLabel call.
const _kWk = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _kMo = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

// ─────────────────────────────────────────────────────────────────────────────

class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Task> _tasks = [];
  // Cached per-day map — rebuilt only when _tasks changes, not on every build.
  Map<DateTime, List<Task>> _tasksByDay = {};
  bool _loading = true;

  _CalMode _mode = _CalMode.month;
  late final AnimationController _modeCtrl;
  late final Animation<double> _calendarHeight;

  // Drag tracking for swipe-to-change-mode
  double _dragStart = 0;
  double _modeCtrlAtDragStart = 0;

  static const _monthHeight = 360.0;
  static const _weekHeight = 135.0;

  @override
  void initState() {
    super.initState();
    _modeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // 1.0 = month full height
    );
    _calendarHeight = Tween<double>(begin: _weekHeight, end: _monthHeight)
        .animate(CurvedAnimation(parent: _modeCtrl, curve: Curves.easeOutCubic));
    _loadTasks();
  }

  @override
  void dispose() {
    _modeCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadTasks() async {
    try {
      final rows = await supabase
          .from('tasks')
          .select('''
            id, titulo, descricao, prioridade, hora, ordem,
            data_vencimento, recorrencia,
            projects ( nome ),
            subtasks ( titulo, descricao, concluida, ordem, prioridade ),
            task_labels ( labels ( id, nome, cor ) )
          ''')
          .eq('concluida', false)
          .not('data_vencimento', 'is', null)
          .order('data_vencimento', ascending: true)
          .order('ordem', ascending: true);

      final tasks = (rows as List)
          .map((r) => TaskRepository.mapRow(r as Map<String, dynamic>))
          .toList();
      final byDay = <DateTime, List<Task>>{};
      for (final t in tasks) {
        if (t.dueDate == null) continue;
        final d = DateTime.utc(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        byDay.putIfAbsent(d, () => []).add(t);
      }
      if (mounted) setState(() { _tasks = tasks; _tasksByDay = byDay; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Mode switching ─────────────────────────────────────────────────────────

  void _setMode(_CalMode mode) {
    if (_mode == mode) return;
    HapticService().tabChanged();
    setState(() => _mode = mode);
    if (mode == _CalMode.month) {
      _modeCtrl.animateTo(1.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 300));
    } else if (mode == _CalMode.week) {
      _modeCtrl.animateTo(0.0,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 300));
    }
    // Agenda: calendar hidden, no height animation needed
  }

  void _onDragStart(DragStartDetails d) {
    _dragStart = d.globalPosition.dy;
    _modeCtrlAtDragStart = _modeCtrl.value;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_mode == _CalMode.agenda) return;
    final delta = d.globalPosition.dy - _dragStart;
    // Map drag distance to controller value change
    // Full range (_monthHeight - _weekHeight) maps to controller 0→1
    final range = _monthHeight - _weekHeight;
    final valueDelta = delta / range;
    _modeCtrl.value = (_modeCtrlAtDragStart + valueDelta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final delta = d.globalPosition.dy - _dragStart;
    final velocity = d.velocity.pixelsPerSecond.dy;

    // Swipe UP (negative dy) → collapse (week) or agenda
    // Swipe DOWN (positive dy) → expand
    if (delta < -40 || velocity < -400) {
      // swipe up
      if (_mode == _CalMode.month) { _setMode(_CalMode.week); }
      else if (_mode == _CalMode.week) { _setMode(_CalMode.agenda); }
    } else if (delta > 40 || velocity > 400) {
      // swipe down
      if (_mode == _CalMode.agenda) { _setMode(_CalMode.week); }
      else if (_mode == _CalMode.week) { _setMode(_CalMode.month); }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _agendaPeriodLabel() {
    if (_tasks.isEmpty) return 'Agenda';
    final withDates = _tasks.where((t) => t.dueDate != null).toList();
    if (withDates.isEmpty) return 'Agenda';
    withDates.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final first = withDates.first.dueDate!;
    final last = withDates.last.dueDate!;
    final firstLabel = _dayLabel(first);
    final lastLabel = _dayLabel(last);
    if (firstLabel == lastLabel) return firstLabel;
    return '$firstLabel – $lastLabel';
  }

  List<Task> get _filtered {
    if (_selectedDay == null) return _tasks;
    return _tasks
        .where((t) => t.dueDate != null && isSameDay(t.dueDate!, _selectedDay!))
        .toList();
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hoje';
    if (d == today.add(const Duration(days: 1))) return 'Amanhã';
    return '${_kWk[date.weekday - 1]}, ${date.day} ${_kMo[date.month - 1]}';
  }

  Future<void> _deleteTask(Task task) async {
    if (!mounted) return;
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = messenger.showSnackBar(SnackBar(
      content: Text('"${task.title}" excluída'),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Desfazer',
        textColor: AppColors.accent,
        onPressed: () {
          undone = true;
          if (mounted) setState(() => _tasks.add(task));
        },
      ),
    ));
    await ctrl.closed;
    if (!undone) {
      try {
        await supabase.from('tasks').delete().eq('id', task.id);
      } catch (e) {
        if (mounted) {
          setState(() => _tasks.add(task));
          messenger.showSnackBar(SnackBar(
              content: Text('Erro: $e'), behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonLoader();

    final grouped = <DateTime, List<Task>>{};
    for (final t in _filtered) {
      if (t.dueDate == null) continue;
      final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      grouped.putIfAbsent(d, () => []).add(t);
    }
    final sortedDays = grouped.keys.toList()..sort();
    final bottomInset = MediaQuery.of(context).viewPadding.bottom + 90;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _loadTasks,
      child: ScrollFadeOverlay(child: CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // ── Mode toggle bar ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Em breve',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                _ModeToggle(current: _mode, onChanged: _setMode),
              ],
            ),
          ),
        ),

        // ── Agenda period indicator (shown only in agenda mode) ──────────────
        if (_mode == _CalMode.agenda)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedListView, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    _agendaPeriodLabel(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Calendar (hidden in agenda mode) ─────────────────────────────────
        if (_mode != _CalMode.agenda)
          SliverToBoxAdapter(
            child: GestureDetector(
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: AnimatedBuilder(
                animation: _calendarHeight,
                builder: (_, child) => SizedBox(
                  height: _calendarHeight.value,
                  child: child,
                ),
                child: _buildCalendar(),
              ),
            ),
          ),

        // Drag hint bar
        if (_mode != _CalMode.agenda)
          SliverToBoxAdapter(
            child: GestureDetector(
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

        // ── Task list ────────────────────────────────────────────────────────
        if (_filtered.isEmpty)
          const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.calendar_month,
              title: 'Nenhuma tarefa',
              subtitle:
                  'Selecione outro dia ou adicione uma tarefa com data de vencimento.',
            ),
          )
        else
          for (final day in sortedDays) ...[
            SliverToBoxAdapter(
              child: AppSectionLabel(
                _dayLabel(day).toUpperCase(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final t = grouped[day]![i];
                  return RepaintBoundary(
                    key: ValueKey('rb_${t.id}'),
                    child: SwipeableTaskTile(
                    key: ValueKey(t.id),
                    task: t,
                    onCompleted: () async {
                      await supabase
                          .from('tasks')
                          .update({'concluida': true})
                          .eq('id', t.id);
                      _loadTasks();
                    },
                    onDeleteRequested: () => _deleteTask(t),
                    onEdit: () =>
                        showTaskDetailSheet(ctx, t, onSaved: _loadTasks),
                    onRefresh: _loadTasks,
                    child: TaskTile(
                      task: t,
                      onSubtaskToggled: (_) {},
                      onCompleted: () async {
                        await supabase
                            .from('tasks')
                            .update({'concluida': true})
                            .eq('id', t.id);
                        _loadTasks();
                      },
                      onTap: () =>
                          showTaskDetailSheet(ctx, t, onSaved: _loadTasks),
                    ),
                  ),
                  );
                },
                findChildIndexCallback: (key) {
                  final id = (key as ValueKey<String>).value;
                  final i = grouped[day]!.indexWhere((t) => t.id == id);
                  return i == -1 ? null : i;
                },
                childCount: grouped[day]!.length,
              ),
            ),
          ],

        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    )));
  }

  Widget _buildCalendar() {
    return TableCalendar<Task>(
      locale: 'pt_BR',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _mode == _CalMode.week
          ? CalendarFormat.week
          : CalendarFormat.month,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Mês',
        CalendarFormat.week: 'Semana',
      },
      selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
      eventLoader: (day) {
        final key = DateTime.utc(day.year, day.month, day.day);
        return _tasksByDay[key] ?? [];
      },
      onDaySelected: (selected, focused) => setState(() {
        _selectedDay = isSameDay(_selectedDay, selected) ? null : selected;
        _focusedDay = focused;
      }),
      onPageChanged: (f) => setState(() => _focusedDay = f),
      onFormatChanged: (_) {}, // controlled by _mode
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
            color: AppColors.surfaceVariant, shape: BoxShape.circle),
        selectedDecoration: BoxDecoration(
            color: AppColors.accent, shape: BoxShape.circle),
        todayTextStyle: TextStyle(color: AppColors.textPrimary),
        selectedTextStyle: TextStyle(
            color: AppColors.background, fontWeight: FontWeight.w700),
        defaultTextStyle: TextStyle(color: AppColors.textPrimary),
        weekendTextStyle: TextStyle(color: AppColors.textSecondary),
        outsideTextStyle: TextStyle(color: AppColors.textTertiary),
        markerDecoration: BoxDecoration(
            color: AppColors.accent, shape: BoxShape.circle),
        markerSize: 5,
        markerMargin: const EdgeInsets.only(top: 1),
        cellMargin: const EdgeInsets.all(4),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15),
        leftChevronIcon:
            HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.textSecondary, size: 20),
        rightChevronIcon: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
            color: AppColors.textSecondary, size: 20),
        headerPadding: EdgeInsets.symmetric(vertical: 8),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle:
            TextStyle(color: AppColors.textTertiary, fontSize: 11.5),
        weekendStyle:
            TextStyle(color: AppColors.textTertiary, fontSize: 11.5),
      ),
    );
  }
}

// ── Mode toggle segmented control ─────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _CalMode current;
  final ValueChanged<_CalMode> onChanged;

  const _ModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(label: 'Mês', mode: _CalMode.month, current: current, onTap: onChanged),
          _Seg(label: 'Semana', mode: _CalMode.week, current: current, onTap: onChanged),
          _Seg(label: 'Agenda', mode: _CalMode.agenda, current: current, onTap: onChanged),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final _CalMode mode;
  final _CalMode current;
  final ValueChanged<_CalMode> onTap;

  const _Seg({
    required this.label,
    required this.mode,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == mode;
    return Pressable(
      onTap: () => onTap(mode),
      pressedScale: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceVariant : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
