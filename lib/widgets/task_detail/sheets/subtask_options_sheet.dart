import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/subtask.dart';
import '../../../services/haptic_service.dart';
import '../../../services/subtask_repository.dart';
import '../../../theme/app_colors.dart';
import '../subtask_item.dart';
import 'task_labels_picker_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

class SubtaskOptionsSheet extends StatefulWidget {
  final SubtaskItem item;
  final List<LabelOption> labels;
  final VoidCallback onChanged;

  const SubtaskOptionsSheet({
    super.key,
    required this.item,
    required this.labels,
    required this.onChanged,
  });

  @override
  State<SubtaskOptionsSheet> createState() => _SubtaskOptionsSheetState();
}

class _SubtaskOptionsSheetState extends State<SubtaskOptionsSheet> {
  late SubtaskPriority? _priority;
  late Set<String> _labelIds;
  late DateTime? _dueDate;
  late TimeOfDay? _dueTime;
  bool _timeExpanded = false;
  bool _calendarExpanded = false;
  DateTime _focusedDay = DateTime.now();
  FixedExtentScrollController? _hourCtrl;
  FixedExtentScrollController? _minCtrl;

  static const _kBg = Color(0xFF242529);

  @override
  void initState() {
    super.initState();
    _priority = widget.item.priority;
    _labelIds = Set.from(widget.item.labelIds);
    _dueDate = widget.item.dueDate;
    _dueTime = widget.item.dueTime;
    if (_dueTime != null) _timeExpanded = true;
    _focusedDay = widget.item.dueDate ?? DateTime.now();
    final t = widget.item.dueTime ?? TimeOfDay.now();
    _hourCtrl = FixedExtentScrollController(initialItem: t.hour);
    _minCtrl = FixedExtentScrollController(initialItem: t.minute);
  }

  @override
  void dispose() {
    _hourCtrl?.dispose();
    _minCtrl?.dispose();
    super.dispose();
  }

  static const _repo = SubtaskRepository();

  void _apply() {
    widget.item.priority = _priority;
    widget.item.labelIds = _labelIds;
    widget.item.dueDate = _dueDate;
    widget.item.dueTime = _dueTime;
    widget.onChanged();
    _persist();
  }

  /// Writes priority/date/labels straight to the DB if this subtask is
  /// already persisted (has a real id). New, not-yet-saved subtasks keep
  /// the previous in-memory-only behavior — they only get an id once the
  /// parent task is saved for the first time.
  Future<void> _persist() async {
    final id = widget.item.id;
    if (id == null) return;
    String? dueDateStr;
    if (_dueDate != null) {
      dueDateStr = _dueTime != null
          ? DateTime(
              _dueDate!.year,
              _dueDate!.month,
              _dueDate!.day,
              _dueTime!.hour,
              _dueTime!.minute,
            ).toIso8601String()
          : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';
    }
    try {
      await _repo.updateSubtaskFields(id, {
        'prioridade': switch (_priority) {
          SubtaskPriority.high => 'high',
          SubtaskPriority.medium => 'medium',
          SubtaskPriority.low => 'low',
          null => null,
        },
        'data_vencimento': dueDateStr,
        'label_ids': _labelIds.isEmpty ? null : _labelIds.toList(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível salvar'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.priorityHigh,
        ),
      );
    }
  }

  Color _prioColor(SubtaskPriority? p) => switch (p) {
    SubtaskPriority.high => const Color(0xFFDC4C3E),
    SubtaskPriority.medium => const Color(0xFFEB8909),
    SubtaskPriority.low => const Color(0xFF246FE0),
    null => const Color(0xFF6B6E76),
  };

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final prioOpts = [
      (SubtaskPriority.high, 'P1'),
      (SubtaskPriority.medium, 'P2'),
      (SubtaskPriority.low, 'P3'),
      (null as SubtaskPriority?, '–'),
    ];

    final dateOpts = [
      (label: 'Hoje', date: today),
      (label: 'Amanhã', date: tomorrow),
    ];

    return PopScope(
      // Catches every way this sheet can close — X button, swipe-to-dismiss,
      // tap outside the barrier, system back — so a field edit can never be
      // applied/persisted by only one of those paths.
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _apply();
      },
      child: Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: view.padding.bottom / view.devicePixelRatio + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.ctrl.text.isEmpty
                            ? 'Opções da subtarefa'
                            : widget.item.ctrl.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                  ],
                ),
              ),

              // ── Prioridade ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Prioridade',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: prioOpts.map((opt) {
                    final (val, label) = opt;
                    final active = _priority == val;
                    final color = _prioColor(val);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticService().prioritySelected();
                          setState(() => _priority = val);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active
                                ? color.withValues(alpha: 0.18)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? color.withValues(alpha: 0.6)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                val != null ? Icons.flag : Icons.flag_outlined,
                                size: 18,
                                color: active ? color : AppColors.textTertiary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? color
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              Divider(
                height: 1,
                color: AppColors.textTertiary.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 12),

              // ── Data ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Data',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        _dueDate = null;
                        _dueTime = null;
                        _timeExpanded = false;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _dueDate == null
                              ? AppColors.textTertiary.withValues(alpha: 0.18)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Sem data',
                          style: TextStyle(
                            fontSize: 13,
                            color: _dueDate == null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...dateOpts.map((opt) {
                      final active =
                          _dueDate != null &&
                          _dueDate!.year == opt.date.year &&
                          _dueDate!.month == opt.date.month &&
                          _dueDate!.day == opt.date.day;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticService().dateConfirmed();
                            setState(() {
                              _dueDate = opt.date;
                              _focusedDay = opt.date;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(
                                      0xFF4D9FEC,
                                    ).withValues(alpha: 0.18)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active
                                    ? const Color(
                                        0xFF4D9FEC,
                                      ).withValues(alpha: 0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: active
                                    ? const Color(0xFF4D9FEC)
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: () => setState(
                        () => _calendarExpanded = !_calendarExpanded,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _calendarExpanded
                              ? AppColors.accent.withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _calendarExpanded
                                ? AppColors.accent.withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: HugeIcon(icon: HugeIcons.strokeRoundedCalendar03,
                          size: 16,
                          color: _calendarExpanded
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _calendarExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2030),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (d) =>
                              _dueDate != null &&
                              d.year == _dueDate!.year &&
                              d.month == _dueDate!.month &&
                              d.day == _dueDate!.day,
                          onDaySelected: (sel, foc) {
                            HapticService().dateSelected();
                            setState(() {
                              _dueDate = DateTime(sel.year, sel.month, sel.day);
                              _focusedDay = foc;
                              _calendarExpanded = false;
                            });
                          },
                          onPageChanged: (f) => setState(() => _focusedDay = f),
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: const {
                            CalendarFormat.month: '',
                          },
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            leftChevronIcon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            rightChevronIcon: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            headerMargin: const EdgeInsets.only(bottom: 4),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                            weekendStyle: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            defaultTextStyle: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            weekendTextStyle: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            todayDecoration: BoxDecoration(
                              color: AppColors.priorityHigh.withValues(
                                alpha: 0.18,
                              ),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.priorityHigh,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            cellMargin: const EdgeInsets.all(3),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              if (_dueDate != null) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    HapticService().selectionClick();
                    setState(() {
                      _timeExpanded = !_timeExpanded;
                      if (_timeExpanded && _dueTime == null) {
                        final t = TimeOfDay.now();
                        _dueTime = t;
                        _hourCtrl?.jumpToItem(t.hour);
                        _minCtrl?.jumpToItem(t.minute);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Row(
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedClock01,
                          size: 17,
                          color: _dueTime != null
                              ? const Color(0xFF4D9FEC)
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Hora',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          _dueTime != null
                              ? '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}'
                              : 'Nenhum',
                          style: TextStyle(
                            fontSize: 13,
                            color: _dueTime != null
                                ? const Color(0xFF4D9FEC)
                                : AppColors.textTertiary,
                            fontWeight: _dueTime != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _timeExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                            size: 17,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _timeExpanded
                      ? _buildTimePicker()
                      : const SizedBox.shrink(),
                ),
              ],

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: AppColors.textTertiary.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 12),

              // ── Etiquetas ────────────────────────────────────────────────
              if (widget.labels.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Etiquetas',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...widget.labels.map((l) {
                  final sel = _labelIds.contains(l.id);
                  return InkWell(
                    onTap: () {
                      HapticService().selectionClick();
                      setState(() {
                        if (sel) {
                          _labelIds.remove(l.id);
                        } else {
                          _labelIds.add(l.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: l.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.name,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (sel) HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 16, color: l.color),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    const kItemH = 38.0;
    const kPickerH = kItemH * 3;

    Widget col(
      FixedExtentScrollController ctrl,
      int count,
      void Function(int) onChanged,
    ) {
      return SizedBox(
        width: 58,
        height: kPickerH,
        child: ListWheelScrollView.useDelegate(
          controller: ctrl,
          itemExtent: kItemH,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 1.8,
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (ctx, i) {
              final selected = ctrl.hasClients && ctrl.selectedItem == i;
              return Center(
                child: Text(
                  i.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: selected ? 20 : 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? AppColors.accent : AppColors.textTertiary,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          col(
            _hourCtrl!,
            24,
            (i) => setState(
              () =>
                  _dueTime = TimeOfDay(hour: i, minute: _dueTime?.minute ?? 0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              ':',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          col(
            _minCtrl!,
            60,
            (i) => setState(
              () => _dueTime = TimeOfDay(hour: _dueTime?.hour ?? 0, minute: i),
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () => setState(() {
              _dueTime = null;
              _timeExpanded = false;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Limpar',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
