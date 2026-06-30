import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/recurrence.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_colors.dart';
import 'package:hugeicons/hugeicons.dart';

class DatePickerResult {
  final DateTime? date;
  final TimeOfDay? time;
  final Recurrence? recurrence;
  const DatePickerResult({this.date, this.time, this.recurrence});
}

class TaskDatePickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final Recurrence? initialRecurrence;
  final bool inDialog;
  final bool showRecurrence;
  // BUG-DATE-OLD: antes, a única forma de propagar a seleção era o valor de
  // retorno de Navigator.pop() ao confirmar (_confirm()). Tap fora do sheet
  // (barrier dismiss) ou swipe-down fecham o ModalBottomSheet internamente
  // com pop() sem argumento (retorna null), descartando a seleção feita,
  // mesmo já tendo sido aplicada via setState dentro deste widget.
  // onChanged dispara a persistência no momento da seleção, antes de
  // qualquer fechamento — independente do caminho de saída usado depois.
  final void Function(DatePickerResult)? onChanged;

  const TaskDatePickerSheet({
    super.key,
    this.initialDate,
    this.initialTime,
    this.initialRecurrence,
    this.inDialog = false,
    this.showRecurrence = true,
    this.onChanged,
  });

  @override
  State<TaskDatePickerSheet> createState() => _TaskDatePickerSheetState();
}

class _TaskDatePickerSheetState extends State<TaskDatePickerSheet> {
  DateTime? _selected;
  TimeOfDay? _time;
  Recurrence? _recurrence;
  DateTime _focusedDay = DateTime.now();
  bool _timeExpanded = false;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;

  // COLORS-OLD: static const _kBg = Color(0xFF1A1B1E);
  static Color get _kBg => AppColors.background;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _time = widget.initialTime;
    _recurrence = widget.initialRecurrence;
    _focusedDay = widget.initialDate ?? DateTime.now();
    final t = widget.initialTime ?? TimeOfDay.now();
    _hourCtrl = FixedExtentScrollController(initialItem: t.hour);
    _minCtrl = FixedExtentScrollController(initialItem: t.minute);
    if (widget.initialTime != null) _timeExpanded = true;
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    // BUG-DATE-OLD: pop(value) era o único canal de propagação — agora
    // onChanged dispara primeiro, garantindo persistência mesmo que o
    // fechamento do sheet em si não seja observado corretamente pelo pai.
    widget.onChanged?.call(DatePickerResult(
      date: _selected,
      time: _time,
      recurrence: _recurrence,
    ));
    // BUG-DATE-OLD-V2: Navigator.pop propagava o resultado mas o
    // showModalBottomSheet agora é <void> — não espera mais valor.
    // O fechamento acontece naturalmente pelo barrier dismiss ou
    // pelo botão X (_cancel), que chama Navigator.pop() sem valor.
    // Comentado para evitar double-pop em alguns caminhos:
    // Navigator.of(context).pop(DatePickerResult(
    //   date: _selected,
    //   time: _time,
    //   recurrence: _recurrence,
    // ));
    Navigator.of(context).pop(); // fechar sem valor
  }

  void _cancel() {
    Navigator.of(context).pop(DatePickerResult(
      date: widget.initialDate,
      time: widget.initialTime,
      recurrence: widget.initialRecurrence,
    ));
  }

  void _applyShortcut(DateTime date) {
    HapticService().dateConfirmed();
    setState(() {
      _selected = date;
      _focusedDay = date;
    });
    // Auto-confirm on shortcut tap
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
  }

  DateTime _nextWeekday(int weekday) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var d = today.add(const Duration(days: 1));
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  String _weekdayAbbr(DateTime d) {
    const names = ['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'];
    return names[d.weekday - 1];
  }

  String _timeLabel() {
    if (_time == null) return 'Nenhum';
    return '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
  }

  String _recurrenceLabel() {
    if (_recurrence == null) return 'Nenhuma';
    return _recurrence!.displayLabel;
  }

  Future<void> _pickRecurrence() async {
    final options = <({String label, Recurrence? value})>[
      (label: 'Nunca', value: null),
      (label: 'Todo dia', value: Recurrence(type: RecurrenceType.daily)),
      (label: 'Toda semana', value: Recurrence(type: RecurrenceType.weekly)),
      (label: 'Todo mês', value: Recurrence(type: RecurrenceType.monthly)),
    ];

    if (widget.inDialog) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        builder: (ctx) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 220,
              // COLORS-OLD: color: const Color(0xFF2C2D33)
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Text(
                        'REPETIR',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Divider(height: 1, thickness: 0.5,
                        color: AppColors.textTertiary.withValues(alpha: 0.12)),
                    ...options.map((o) {
                      final isSelected = o.value?.type == _recurrence?.type &&
                          (o.value == null) == (_recurrence == null);
                      return InkWell(
                        onTap: () {
                          setState(() => _recurrence = o.value);
                          Navigator.of(ctx).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isSelected ? AppColors.accent : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 15, color: AppColors.accent),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Repetir'),
        actions: options.map((o) {
          final isSelected = o.value?.type == _recurrence?.type &&
              (o.value == null) == (_recurrence == null);
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _recurrence = o.value);
              Navigator.of(ctx).pop();
            },
            child: Text(
              o.label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          isDestructiveAction: true,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Widget _buildInlineTimePicker() {
    const kItemH = 40.0;
    const kPickerH = kItemH * 3;

    Widget col(FixedExtentScrollController ctrl, int count, void Function(int) onChanged) {
      return SizedBox(
        width: 64,
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
                    fontSize: selected ? 22 : 17,
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              col(_hourCtrl, 24, (i) {
                setState(() => _time = TimeOfDay(hour: i, minute: _time?.minute ?? 0));
                // HORA-ONCHANGE: notificar pai imediatamente ao mudar hora
                widget.onChanged?.call(DatePickerResult(
                  date: _selected,
                  time: _time,
                  recurrence: _recurrence,
                ));
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              col(_minCtrl, 60, (i) {
                setState(() => _time = TimeOfDay(hour: _time?.hour ?? 0, minute: i));
                // HORA-ONCHANGE: notificar pai imediatamente ao mudar minuto
                widget.onChanged?.call(DatePickerResult(
                  date: _selected,
                  time: _time,
                  recurrence: _recurrence,
                ));
              }),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () {
                  HapticService().selectionClick();
                  setState(() {
                    _time = null;
                    _timeExpanded = false;
                    final now = TimeOfDay.now();
                    _hourCtrl.jumpToItem(now.hour);
                    _minCtrl.jumpToItem(now.minute);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Limpar', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekend = _nextWeekday(DateTime.sunday);
    final nextMonday = _nextWeekday(DateTime.monday);

    final shortcuts = [
      // COLORS-OLD: Color(0xFFF5A623)/Color(0xFF4D9FEC)/Color(0xFFB18CF5) — duplicavam priorityMedium/priorityLow/tagPurple
      // 0xFF3BAA6E sem token equivalente — FIXED-COLOR: acento decorativo único deste shortcut
      (label: 'Hoje', hugeIcon: HugeIcons.strokeRoundedCalendar01, color: AppColors.dateDueToday, date: today),
      (label: 'Amanhã', hugeIcon: HugeIcons.strokeRoundedSun01, color: AppColors.priorityMedium, date: tomorrow),
      (label: 'Este fim de semana', hugeIcon: HugeIcons.strokeRoundedSofaSingle, color: AppColors.priorityLow, date: weekend),
      (label: 'Próxima semana', hugeIcon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.tagPurple, date: nextMonday),
    ];

    bool isSameDay(DateTime? a, DateTime b) =>
        a != null && a.year == b.year && a.month == b.month && a.day == b.day;

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: widget.inDialog
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.only(
            bottom: widget.inDialog ? 0 : view.padding.bottom / view.devicePixelRatio + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.inDialog)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 20),
                    color: AppColors.textSecondary,
                    // CANCEL-OLD: botão X cancelava descartando seleção
                    // onPressed: _cancel,
                    // CANCEL-FIX: botão X confirma como as opções rápidas
                    onPressed: _confirm,
                  ),
                  Expanded(
                    child: Text(
                      'Data',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  if (_selected != null)
                    GestureDetector(
                      onTap: () {
                        setState(() { _selected = null; _time = null; _timeExpanded = false; });
                        // CORRIGIDO_DATA_REMOVER: "Limpar" só fazia setState
                        // local, sem nunca chamar _confirm() — igual ao bug já
                        // corrigido em CORRIGIDO_DATA_CALENDARIO. Sem isso, ao
                        // fechar o sheet (tap fora/swipe), Navigator faz
                        // pop(null) e a remoção da data é descartada, deixando
                        // a data antiga intacta. Mesmo padrão de auto-confirm.
                        WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Limpar', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),
            ...shortcuts.map((s) {
              final active = isSameDay(_selected, s.date);
              return InkWell(
                onTap: () => _applyShortcut(s.date),
                child: Container(
                  color: active ? s.color.withValues(alpha: 0.10) : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Row(
                    children: [
                      HugeIcon(icon: s.hugeIcon, size: 20, color: s.color),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          s.label,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                              color: active ? s.color : AppColors.textPrimary),
                        ),
                      ),
                      Text(_weekdayAbbr(s.date), style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(_selected, d),
                onDaySelected: (selected, focused) {
                  HapticService().dateSelected();
                  setState(() { _selected = selected; _focusedDay = focused; });
                  // CORRIGIDO_DATA_CALENDARIO: toque no calendário só fazia
                  // setState, sem nunca chamar _confirm() — diferente das
                  // opções rápidas (_applyShortcut), que já confirmavam
                  // automaticamente. Sem isso, fechar o sheet por swipe/tap
                  // fora descartava a seleção (Navigator faz pop(null) por
                  // padrão). Mesmo padrão de auto-confirm das opções rápidas.
                  WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
                },
                onPageChanged: (focused) => setState(() => _focusedDay = focused),
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: ''},
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  leftChevronIcon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.textSecondary, size: 22),
                  rightChevronIcon: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.textSecondary, size: 22),
                  headerMargin: const EdgeInsets.only(bottom: 8),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  weekendStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  defaultTextStyle: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  weekendTextStyle: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  todayDecoration: BoxDecoration(color: AppColors.priorityHigh.withValues(alpha: 0.18), shape: BoxShape.circle),
                  todayTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.priorityHigh),
                  selectedDecoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  selectedTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimary),
                  markerDecoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  markerSize: 4,
                  markersMaxCount: 1,
                  cellMargin: const EdgeInsets.all(4),
                ),
              ),
            ),
            // COLORS-OLD: const Divider(height: 1, color: Color(0xFF2C2D33))
            Divider(height: 1, color: AppColors.surfaceVariant),
            InkWell(
              onTap: () {
                HapticService().selectionClick();
                setState(() {
                  _timeExpanded = !_timeExpanded;
                  if (_timeExpanded && _time == null) {
                    final now2 = TimeOfDay.now();
                    _time = TimeOfDay(hour: now2.hour, minute: now2.minute);
                    _hourCtrl.jumpToItem(now2.hour);
                    _minCtrl.jumpToItem(now2.minute);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 20,
                        color: _time != null ? AppColors.accent : AppColors.textSecondary),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Hora', style: TextStyle(fontSize: 15, color: AppColors.textPrimary))),
                    Text(
                      _timeLabel(),
                      style: TextStyle(fontSize: 14,
                          color: _time != null ? AppColors.accent : AppColors.textTertiary,
                          fontWeight: _time != null ? FontWeight.w600 : FontWeight.w400),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _timeExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _timeExpanded ? _buildInlineTimePicker() : const SizedBox.shrink(),
            ),
            if (widget.showRecurrence) ...[
            // COLORS-OLD: const Divider(height: 1, indent: 54, color: Color(0xFF2C2D33))
            Divider(height: 1, indent: 54, color: AppColors.surfaceVariant),
            InkWell(
              onTap: _pickRecurrence,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedRepeat, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Repetir', style: TextStyle(fontSize: 15, color: AppColors.textPrimary))),
                    Text(_recurrenceLabel(), style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
                    const SizedBox(width: 6),
                    HugeIcon(icon: HugeIcons.strokeRoundedUnfoldMore, size: 18, color: AppColors.textTertiary),
                  ],
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
