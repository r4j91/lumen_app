import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/subtask.dart';
import '../../../models/task.dart' show Priority; // ADICIONADO_REDESIGN_SUBTASK
import '../../../services/haptic_service.dart';
import '../../../services/subtask_repository.dart';
import '../../../theme/app_colors.dart';
import '../../anchored_select_menu.dart';
import '../../popover_style.dart';
import '../subtask_item.dart';
import '../task_detail_widgets.dart';
import '../../task_tile.dart' show TagChip;
import 'task_date_picker_sheet.dart';
import 'task_labels_picker_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

/// Opens the lightweight subtask detail sheet (título, notas, prioridade,
/// data, etiquetas) — the reduced-field replacement for SubtaskOptionsSheet.
Future<void> showSubtaskDetailSheet({
  required BuildContext context,
  required SubtaskItem item,
  required List<LabelOption> labels,
  required VoidCallback onChanged,
  // ADICIONADO_REDESIGN_SUBTASK: título da tarefa pai, usado no breadcrumb.
  // Opcional — quando nulo (ex.: aberto de dentro do próprio TaskDetailSheet,
  // onde o contexto da tarefa pai já é óbvio), o breadcrumb não é exibido.
  String? parentTaskTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SubtaskDetailSheet(item: item, labels: labels, onChanged: onChanged, parentTaskTitle: parentTaskTitle),
  );
}

class SubtaskDetailSheet extends StatefulWidget {
  final SubtaskItem item;
  final List<LabelOption> labels;
  final VoidCallback onChanged;
  // ADICIONADO_REDESIGN_SUBTASK
  final String? parentTaskTitle;

  const SubtaskDetailSheet({
    super.key,
    required this.item,
    required this.labels,
    required this.onChanged,
    this.parentTaskTitle,
  });

  @override
  State<SubtaskDetailSheet> createState() => _SubtaskDetailSheetState();
}

class _SubtaskDetailSheetState extends State<SubtaskDetailSheet> {
  static const _repo = SubtaskRepository();
  static const _debounceDuration = Duration(milliseconds: 700);

  late SubtaskPriority? _priority;
  late Set<String> _labelIds;
  late DateTime? _dueDate;
  late TimeOfDay? _dueTime;

  late final FocusNode _titleFocusNode;
  late final FocusNode _descFocusNode;
  bool _descFocused = false;

  // Campo Valor (R$) — edição inline dentro do TaskMetaRow (PASSO 2).
  late final TextEditingController _valorCtrl;
  late final FocusNode _valorFocusNode;
  bool _valorEditing = false;

  Timer? _titleDebounce;
  Timer? _descDebounce;
  Timer? _valorDebounce;

  final _priorityChipKey = GlobalKey();
  final _labelsChipKey = GlobalKey();
  final _valorChipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _priority = widget.item.priority;
    _labelIds = Set.from(widget.item.labelIds);
    _dueDate = widget.item.dueDate;
    _dueTime = widget.item.dueTime;
    _titleFocusNode = widget.item.focus;
    _descFocusNode = widget.item.descFocus;
    _valorCtrl = TextEditingController(
      text: widget.item.valor != null ? widget.item.valor!.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _valorFocusNode = FocusNode();
    widget.item.ctrl.addListener(_onTitleText);
    widget.item.descCtrl.addListener(_onDescText);
    _descFocusNode.addListener(_onDescFocusChanged);
    _valorCtrl.addListener(_onValorText);
    _valorFocusNode.addListener(_onValorFocusChanged);
    _descFocused = _descFocusNode.hasFocus;
  }

  @override
  void dispose() {
    widget.item.ctrl.removeListener(_onTitleText);
    widget.item.descCtrl.removeListener(_onDescText);
    _descFocusNode.removeListener(_onDescFocusChanged);
    _valorCtrl.removeListener(_onValorText);
    _valorFocusNode.removeListener(_onValorFocusChanged);
    _valorCtrl.dispose();
    _valorFocusNode.dispose();
    _titleDebounce?.cancel();
    _descDebounce?.cancel();
    _valorDebounce?.cancel();
    super.dispose();
  }

  void _onDescFocusChanged() {
    if (!mounted) return;
    setState(() => _descFocused = _descFocusNode.hasFocus);
  }

  void _onTitleText() {
    _titleDebounce?.cancel();
    final title = widget.item.ctrl.text.trim();
    if (title.isEmpty) return;
    _titleDebounce = Timer(_debounceDuration, () => _persistField('titulo', title));
  }

  void _onDescText() {
    _descDebounce?.cancel();
    final desc = widget.item.descCtrl.text.trim();
    _descDebounce = Timer(_debounceDuration, () => _persistField('descricao', desc));
  }

  void _onValorFocusChanged() {
    if (!mounted) return;
    if (!_valorFocusNode.hasFocus) setState(() => _valorEditing = false);
  }

  void _onValorText() {
    _valorDebounce?.cancel();
    _valorDebounce = Timer(_debounceDuration, () {
      final raw = _valorCtrl.text.trim().replaceAll(',', '.');
      final parsed = raw.isEmpty ? null : double.tryParse(raw);
      widget.item.valor = parsed;
      widget.onChanged();
      _persistValor(parsed);
    });
  }

  Future<void> _persistValor(double? value) async {
    try {
      await _repo.persistSubtask(
        id: widget.item.id,
        taskId: widget.item.taskId,
        order: widget.item.order,
        fields: {'valor': value},
        onIdResolved: (resolved) => widget.item.id = resolved,
      );
    } catch (e) {
      _showSaveError();
    }
  }

  Future<void> _persistField(String column, String value) async {
    try {
      await _repo.persistSubtask(
        id: widget.item.id,
        taskId: widget.item.taskId,
        order: widget.item.order,
        fields: {column: value.isEmpty ? null : value},
        onIdResolved: (resolved) => widget.item.id = resolved,
      );
    } catch (e) {
      _showSaveError();
    }
  }

  /// Mirrors current selections back onto the shared SubtaskItem and writes
  /// priority/date/labels straight to the DB. Called whenever this sheet
  /// closes, regardless of how (X, swipe, tap outside, back).
  Future<void> _applyAndPersist() async {
    widget.item.priority = _priority;
    widget.item.labelIds = _labelIds;
    widget.item.dueDate = _dueDate;
    widget.item.dueTime = _dueTime;
    widget.onChanged();
    await _persistMeta();
  }

  Future<void> _persistMeta() async {
    String? dueDateStr;
    if (_dueDate != null) {
      dueDateStr = _dueTime != null
          ? DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day, _dueTime!.hour, _dueTime!.minute)
              .toIso8601String()
          : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';
    }
    try {
      await _repo.persistSubtask(
        id: widget.item.id,
        taskId: widget.item.taskId,
        order: widget.item.order,
        fields: {
          'prioridade': switch (_priority) {
            SubtaskPriority.high => 'high',
            SubtaskPriority.medium => 'medium',
            SubtaskPriority.low => 'low',
            null => null,
          },
          'data_vencimento': dueDateStr,
          'label_ids': _labelIds.isEmpty ? null : _labelIds.toList(),
        },
        onIdResolved: (resolved) => widget.item.id = resolved,
      );
    } catch (e) {
      _showSaveError();
    }
  }

  void _showSaveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Não foi possível salvar'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.priorityHigh,
    ));
  }

  // PRIORITY-CENTRAL-OLD: _priorityColor/_priorityLabel locais, não
  // referenciados (só em código comentado) — removidos. Usar
  // SubtaskPriorityExtension (lib/models/subtask.dart) se precisar: p?.color/p?.label.

  Future<void> _showPriorityMenu() async {
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _priorityChipKey,
      items: [
        AnchoredMenuItem(id: 'high', label: 'Prioridade 1', hugeIcon: HugeIcons.strokeRoundedFlag01, iconColor: AppColors.priorityHigh, selected: _priority == SubtaskPriority.high),
        AnchoredMenuItem(id: 'medium', label: 'Prioridade 2', hugeIcon: HugeIcons.strokeRoundedFlag01, iconColor: AppColors.priorityMedium, selected: _priority == SubtaskPriority.medium),
        AnchoredMenuItem(id: 'low', label: 'Prioridade 3', hugeIcon: HugeIcons.strokeRoundedFlag01, iconColor: AppColors.priorityLow, selected: _priority == SubtaskPriority.low),
        AnchoredMenuItem(id: 'none', label: 'Sem prioridade', hugeIcon: HugeIcons.strokeRoundedFlag01, iconColor: AppColors.textTertiary, selected: _priority == null),
      ],
    );
    if (result == null || !mounted) return;
    HapticService().prioritySelected();
    setState(() {
      _priority = switch (result) {
        'high' => SubtaskPriority.high,
        'medium' => SubtaskPriority.medium,
        'low' => SubtaskPriority.low,
        _ => null,
      };
    });
    _persistMeta();
  }

  String _formatDate(DateTime d, TimeOfDay? t) {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final base = '${d.day} ${months[d.month - 1]}';
    if (t == null) return base;
    return '$base ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDateSheet() async {
    DatePickerResult? lastResult;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDatePickerSheet(
        initialDate: _dueDate,
        initialTime: _dueTime,
        // BUG-DATE-SUBTASK: o picker confirma via onChanged + pop() sem valor;
        // depender do retorno do await deixava result sempre null.
        onChanged: (r) {
          lastResult = r;
          if (!mounted) return;
          setState(() {
            _dueDate = r.date;
            _dueTime = r.time;
          });
        },
      ),
    );
    if (!mounted) return;
    if (lastResult == null) return;
    setState(() {
      _dueDate = lastResult!.date;
      _dueTime = lastResult!.time;
    });
    widget.item.dueDate = _dueDate;
    widget.item.dueTime = _dueTime;
    widget.onChanged();
    await _persistMeta();
  }

  Future<void> _showLabelsMenu() async {
    if (widget.labels.isEmpty) return;
    final result = await showAnchoredMultiSelectMenu(
      context: context,
      anchorKey: _labelsChipKey,
      selectedIds: Set.from(_labelIds),
      items: widget.labels.map((l) => AnchoredMultiSelectItem(id: l.id, label: l.name, dotColor: l.color)).toList(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _labelIds = result;
    });
    _persistMeta();
  }

  Widget _buildLabelsValue() {
    final selected = widget.labels.where((l) => _labelIds.contains(l.id)).toList();
    if (selected.isEmpty) return const SizedBox.shrink();
    final extra = selected.length - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...selected.take(2).map((l) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TagChip(label: l.name, color: l.color),
            )),
        if (extra > 0)
          Text(
            '+$extra',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    );
  }

  // ADICIONADO_REDESIGN_SUBTASK: mesmo padrão de _dueDateColor do
  // TaskDetailSheet — vermelho se atrasada, verde se hoje, neutro se futura.
  Color get _dueDateColor {
    if (_dueDate == null) return AppColors.textPrimary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return AppColors.dateDueToday;
    if (diff < 0) return AppColors.dateOverdue;
    return AppColors.textPrimary;
  }

  // ADICIONADO_REDESIGN_SUBTASK: chips de etiqueta com bolinha colorida,
  // mesmo padrão de _buildLabelValue() do TaskDetailSheet.
  Widget _buildLabelChips() {
    final selected = widget.labels.where((l) => _labelIds.contains(l.id)).toList();
    if (selected.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: selected
          .map((l) => TagChip(label: l.name, color: l.color))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    return PopScope(
      // Catches every way this sheet can close — X, swipe-to-dismiss, tap
      // outside the barrier, system back — so an edit is never left
      // applied in only one of those paths.
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _applyAndPersist();
      },
      child: LiquidPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: EdgeInsets.only(bottom: view.padding.bottom / view.devicePixelRatio + 12),
          // CORRIGIDO_TECLADO_SUBTASK: Column era fixo (sem scroll), então
          // com o teclado aberto o conteúdo final (MetaRows/FieldPills)
          // ficava coberto sem nenhuma forma de rolar até ele. Envolvido em
          // SingleChildScrollView só aqui, no nível mais interno do próprio
          // sheet — nada no LiquidPanel/PopScope pai foi alterado, e o
          // showModalBottomSheet (isScrollControlled: true) continua igual.
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                        icon: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18, color: AppColors.textSecondary),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TextField(
                  controller: widget.item.ctrl,
                  focusNode: _titleFocusNode,
                  cursorColor: AppColors.accent,
                  cursorWidth: 1.5,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.3, letterSpacing: -0.3),
                  decoration: InputDecoration(
                    hintText: 'Nova subtarefa',
                    hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.textTertiary.withValues(alpha: 0.65), letterSpacing: -0.3),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              // ADICIONADO_REDESIGN_SUBTASK: breadcrumb da tarefa pai.
              if (widget.parentTaskTitle != null && widget.parentTaskTitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 8),
                  child: Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedArrowDownRight01,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        widget.parentTaskTitle!,
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _descFocused ? AppColors.accent.withValues(alpha: 0.5) : AppColors.textTertiary.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: widget.item.descCtrl,
                    focusNode: _descFocusNode,
                    cursorColor: AppColors.accent,
                    cursorWidth: 1.5,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.55),
                    decoration: InputDecoration(
                      hintText: 'Adicionar notas...',
                      hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.55), fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    maxLines: null,
                  ),
                ),
              ),
              // SUBSTITUIDO_REDESIGN_SUBTASK: bloco antigo de TaskMetaRow
              // (Prioridade/Data) substituído por MetaRow/FieldPill abaixo.
              // TaskMetaRow(
              //   key: _priorityChipKey,
              //   icon: Icons.flag_outlined,
              //   title: 'Prioridade',
              //   valueWidget: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       Text(_priorityLabel(_priority), style: TextStyle(fontSize: 14, color: _priority == null ? AppColors.textTertiary : AppColors.textPrimary, fontWeight: FontWeight.w500)),
              //       if (_priority != null) ...[
              //         const SizedBox(width: 6),
              //         Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _priorityColor(_priority))),
              //       ],
              //     ],
              //   ),
              //   active: _priority != null,
              //   onTap: _showPriorityMenu,
              // ),
              // TaskMetaRow(
              //   icon: Icons.calendar_today_outlined,
              //   title: 'Data',
              //   value: _dueDate != null ? _formatDate(_dueDate!, _dueTime) : 'Sem data',
              //   active: _dueDate != null,
              //   onTap: _showDateSheet,
              // ),
              // REMOVIDO_ETAPA3B_VALOR: campo "Valor (R$)" era específico do
              // gerador de parcelas e não deve aparecer no sheet de
              // subtarefa comum. Lógica/variáveis de valor preservadas
              // (_valorCtrl, _valorFocusNode, _valorEditing, _persistValor,
              // widget.item.valor) — apenas o widget visual foi removido.
              // TaskMetaRow(
              //   key: _valorChipKey,
              //   icon: Icons.sell_outlined,
              //   title: 'Valor (R\$)',
              //   value: _valorEditing ? null : (widget.item.valor != null ? null : 'Sem valor'),
              //   valueWidget: _valorEditing
              //       ? SizedBox(
              //           width: 110,
              //           child: TextField(
              //             controller: _valorCtrl,
              //             focusNode: _valorFocusNode,
              //             autofocus: true,
              //             textAlign: TextAlign.right,
              //             keyboardType: const TextInputType.numberWithOptions(decimal: true),
              //             style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              //             decoration: InputDecoration(
              //               isDense: true,
              //               border: InputBorder.none,
              //               hintText: '0,00',
              //               hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              //             ),
              //           ),
              //         )
              //       : (widget.item.valor != null
              //           ? Text(
              //               'R\$ ${widget.item.valor!.toStringAsFixed(2).replaceAll('.', ',')}',
              //               style: const TextStyle(fontSize: 14, color: Color(0xFF34C759), fontWeight: FontWeight.w500),
              //             )
              //           : null),
              //   active: widget.item.valor != null,
              //   onTap: () {
              //     setState(() => _valorEditing = true);
              //     WidgetsBinding.instance.addPostFrameCallback((_) => _valorFocusNode.requestFocus());
              //   },
              // ),
              // SUBSTITUIDO_REDESIGN_SUBTASK
              // TaskMetaRow(
              //   key: _labelsChipKey,
              //   icon: Icons.label_outline,
              //   title: 'Etiquetas',
              //   value: _labelIds.isEmpty ? 'Sem etiquetas' : null,
              //   valueWidget: _labelIds.isNotEmpty ? _buildLabelsValue() : null,
              //   active: _labelIds.isNotEmpty,
              //   onTap: _showLabelsMenu,
              // ),
              // ADICIONADO_REDESIGN_SUBTASK: META ROWS — só aparecem quando o
              // campo está preenchido.
              // CORRIGIDO_SUBTASK_TAP: Builder garante que o context usado
              // pelos onTap (e por showAnchoredSelectMenu/anchorKey) seja o
              // context mais próximo desta subárvore, não o context "frio"
              // capturado no build() externo.
              Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // CORRIGIDO_VISUAL_A: Divider adicionado após cada
                      // MetaRow preenchido.
                      if (_priority != null) ...[
                        MetaRow(
                          key: _priorityChipKey,
                          hugeIcon: HugeIcons.strokeRoundedFlag01,
                          onTap: () => _showPriorityMenu(),
                          child: PriorityValueWidget(
                            priority: switch (_priority!) {
                              SubtaskPriority.high => Priority.high,
                              SubtaskPriority.medium => Priority.medium,
                              SubtaskPriority.low => Priority.low,
                            },
                          ),
                        ),
                        Divider(height: 1, thickness: 1, color: AppColors.textTertiary.withValues(alpha: 0.12)),
                      ],
                      if (_dueDate != null) ...[
                        MetaRow(
                          hugeIcon: HugeIcons.strokeRoundedCalendar01,
                          onTap: () => _showDateSheet(),
                          child: Text(
                            _formatDate(_dueDate!, _dueTime),
                            style: TextStyle(fontSize: 13, color: _dueDateColor),
                          ),
                        ),
                        Divider(height: 1, thickness: 1, color: AppColors.textTertiary.withValues(alpha: 0.12)),
                      ],
                      if (_labelIds.isNotEmpty) ...[
                        MetaRow(
                          key: _labelsChipKey,
                          hugeIcon: HugeIcons.strokeRoundedTag01,
                          onTap: () => _showLabelsMenu(),
                          child: _buildLabelChips(),
                        ),
                        Divider(height: 1, thickness: 1, color: AppColors.textTertiary.withValues(alpha: 0.12)),
                      ],
                    ],
                  ),
                ),
              ),
              // CORRIGIDO_VISUAL_A: Divider único pré-grupo substituído por
              // um Divider após cada MetaRow individual (ver acima).
              // if (_priority != null || _dueDate != null || _labelIds.isNotEmpty)
              //   Divider(height: 1, thickness: 1, color: Color.fromRGBO(255, 255, 255, 0.06)),
              // ADICIONADO_REDESIGN_SUBTASK: PILLS — scroll horizontal, só
              // para os campos ainda vazios.
              if (_priority == null || _dueDate == null || _labelIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (_dueDate == null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FieldPill(
                              hugeIcon: HugeIcons.strokeRoundedCalendar01,
                              label: 'Data',
                              onTap: _showDateSheet,
                            ),
                          ),
                        if (_priority == null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FieldPill(
                              // CORRIGIDO_PILL_TAP: _priorityChipKey só era
                              // atribuída ao MetaRow (campo preenchido). Com
                              // o campo vazio, anchorKey.currentContext era
                              // null e showAnchoredSelectMenu retornava null
                              // silenciosamente (anchored_select_menu.dart:56)
                              // — o tap parecia não fazer nada.
                              key: _priorityChipKey,
                              hugeIcon: HugeIcons.strokeRoundedFlag01,
                              label: 'Prioridade',
                              onTap: _showPriorityMenu,
                            ),
                          ),
                        if (_labelIds.isEmpty)
                          FieldPill(
                            // CORRIGIDO_PILL_TAP: mesmo problema do
                            // _priorityChipKey acima, agora para
                            // _labelsChipKey/showAnchoredMultiSelectMenu.
                            key: _labelsChipKey,
                            hugeIcon: HugeIcons.strokeRoundedTag01,
                            label: 'Etiquetas',
                            onTap: _showLabelsMenu,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          ), // CORRIGIDO_TECLADO_SUBTASK: fecha o SingleChildScrollView.
        ),
      ),
    );
  }
}
