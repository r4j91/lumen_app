import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/section.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/section_repository.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../widgets/anchored_select_menu.dart';
import 'package:hugeicons/hugeicons.dart';
// CORRIGIDO_ETAPA3B_PARCELAS
import '../widgets/installment_generator_sheet.dart';
import '../widgets/popover_style.dart';
import '../widgets/task_detail/sheets/task_date_picker_sheet.dart';

// ── Public entry-point ─────────────────────────────────────────────────────────

Future<void> showQuickAddTaskSheet(BuildContext context,
    {VoidCallback? onSaved, String? initialProjectId, String? initialSectionId}) async {
  final isDesktop = MediaQuery.of(context).size.width >= 1024;
  if (isDesktop) {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Align(
        alignment: const Alignment(0, -0.15),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 480,
            child: QuickAddTaskSheet(
              onSaved: onSaved,
              asDialog: true,
              initialProjectId: initialProjectId,
              initialSectionId: initialSectionId,
            ),
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,   // allows sheet to resize above keyboard
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddTaskSheet(
        onSaved: onSaved,
        initialProjectId: initialProjectId,
        initialSectionId: initialSectionId,
      ),
    );
  }
}

// ── Lightweight local structs ──────────────────────────────────────────────────

class _QProject {
  final String id;
  final String name;
  final Color? color;
  const _QProject(this.id, this.name, {this.color});
}

class _QLabel {
  final String id;
  final String name;
  final Color color;
  const _QLabel(this.id, this.name, this.color);
}

// ── Widget ─────────────────────────────────────────────────────────────────────

class QuickAddTaskSheet extends StatefulWidget {
  final VoidCallback? onSaved;
  final bool asDialog;
  final String? initialProjectId;
  final String? initialSectionId;

  const QuickAddTaskSheet({
    super.key,
    this.onSaved,
    this.asDialog = false,
    this.initialProjectId,
    this.initialSectionId,
  });

  @override
  State<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<QuickAddTaskSheet> {
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _titleFocus = FocusNode();

  Priority?  _priority;
  DateTime?  _dueDate;
  TimeOfDay? _dueTime;
  _QProject? _project;
  final Set<String> _labelIds = {};

  // Seções: estado do seletor de dois níveis (projeto › seção)
  String? _selectedSectionId;
  String? _selectedSectionName;
  List<Section> _availableSections = [];
  static const _sectionRepo = SectionRepository();

  List<_QProject> _projects = [];
  List<_QLabel>   _labels   = [];
  bool   _saving            = false;
  double _viewPaddingBottom = 0;

  // Anchor keys for popovers
  final _labelsKey   = GlobalKey();
  final _dateKey     = GlobalKey();
  final _priorityKey = GlobalKey();
  final _projectKey  = GlobalKey();

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() { if (mounted) setState(() {}); });
    _loadMeta();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final v = WidgetsBinding.instance.platformDispatcher.views.first;
      setState(() => _viewPaddingBottom = v.padding.bottom / v.devicePixelRatio);
      final delay = widget.asDialog
          ? const Duration(milliseconds: 80)
          : const Duration(milliseconds: 420);
      Future.delayed(delay, () {
        if (mounted) _titleFocus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadMeta() async {
    try {
      final pRows = await supabase.from('projects').select('id, nome, cor').order('nome');
      final lRows = await supabase.from('labels').select('id, nome, cor').order('nome');
      if (!mounted) return;
      setState(() {
        _projects = (pRows as List)
            .map((r) => _QProject(r['id'].toString(), r['nome'] as String,
                color: _parseColor(r['cor'] as String?)))
            .toList();
        _labels = (lRows as List)
            .map((r) => _QLabel(r['id'].toString(), r['nome'] as String,
                _parseColor(r['cor'] as String?)))
            .toList();
        if (widget.initialProjectId != null) {
          try {
            _project = _projects.firstWhere((p) => p.id == widget.initialProjectId);
          } catch (_) {}
        }
      });
      // Caso especial (PASSO 5): QuickAdd aberto a partir de uma seção —
      // pré-carrega as seções do projeto e pré-seleciona a seção indicada.
      if (_project != null) {
        await _loadSectionsForProject(_project!.id);
        if (widget.initialSectionId != null && mounted) {
          setState(() {
            _selectedSectionId = widget.initialSectionId;
            try {
              _selectedSectionName = _availableSections
                  .firstWhere((s) => s.id == widget.initialSectionId)
                  .name;
            } catch (_) {}
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSectionsForProject(String projectId) async {
    try {
      final sections = await _sectionRepo.getSectionsForProject(projectId);
      if (!mounted) return;
      setState(() => _availableSections = sections);
    } catch (_) {}
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.textTertiary;
    final clean = hex.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.textTertiary;
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────────

  // CORRIGIDO_ETAPA3B_PARCELAS: lógica de insert/labels/notificação extraída
  // de _save() para um método próprio (_persistTask), reaproveitado também
  // pelo botão de gerador de parcelas (_openInstallmentGenerator), que
  // precisa de um taskId real antes de abrir o InstallmentGeneratorSheet
  // mas não deve fechar o quick add nem disparar onSaved nesse momento.
  // Comportamento de _save() preservado integralmente.
  Future<String?> _persistTask() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return null;

    final prioStr = switch (_priority) {
      Priority.high   => 'high',
      Priority.medium => 'medium',
      Priority.low    => 'low',
      null            => null,
    };

    String? dueDateStr;
    if (_dueDate != null) {
      if (_dueTime != null) {
        final dt = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day,
            _dueTime!.hour, _dueTime!.minute);
        dueDateStr = dt.toIso8601String();
      } else {
        dueDateStr =
            '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';
      }
    }

    final userId = supabase.auth.currentUser?.id;
    final inserted = await supabase
        .from('tasks')
        .insert({
          'titulo': title,
          'descricao': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'prioridade': prioStr,
          'project_id': _project?.id,
          'section_id': _selectedSectionId,
          'data_vencimento': dueDateStr,
          if (userId != null) 'user_id': userId,
        })
        .select('id')
        .single();

    final taskId = inserted['id'].toString();

    if (_labelIds.isNotEmpty) {
      unawaited(supabase.from('task_labels').insert(
        _labelIds.map((lid) => {'task_id': taskId, 'label_id': lid}).toList(),
      ));
    }

    if (_dueDate != null) {
      unawaited(NotificationService()
          .scheduleTaskNotification(taskId, title, _dueDate!));
    }

    return taskId;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _saving) return;
    HapticService().taskCreated();
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final saveFuture = _persistTask();

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved?.call();

    try {
      await saveFuture;
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Erro ao salvar: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.priorityHigh,
      ));
    }
  }

  // CORRIGIDO_ETAPA3B_PARCELAS: salva a tarefa (se ainda não tiver título
  // a ação é ignorada, igual a _save) e, com o taskId real retornado,
  // abre o InstallmentGeneratorSheet. Ao concluir a geração, fecha o
  // quick add e dispara onSaved — mesmo desfecho de _save().
  Future<void> _openInstallmentGenerator() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _saving) return;
    HapticService().taskCreated();
    setState(() => _saving = true);

    try {
      final taskId = await _persistTask();
      if (taskId == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      if (!mounted) return;
      await showInstallmentGeneratorSheet(
        context,
        taskId: taskId,
        taskTitle: title,
        onGenerated: () {
          if (mounted) {
            Navigator.of(context).pop();
            widget.onSaved?.call();
          }
        },
      );
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.priorityHigh,
        ));
      }
    }
  }

  // ── Menu handlers ─────────────────────────────────────────────────────────────

  Future<void> _showDateSheet(BuildContext ctx) async {
    final result = await showModalBottomSheet<DatePickerResult>(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDatePickerSheet(
        initialDate: _dueDate,
        initialTime: _dueTime,
        initialRecurrence: null,
        // BUG-DATE-OLD: dependia só do retorno de Navigator.pop() ao
        // fechar o sheet — tap fora (barrier dismiss) fecha com pop() sem
        // argumento (null), descartando a seleção já feita dentro do
        // picker. onChanged atualiza o estado local no momento da seleção,
        // antes de qualquer fechamento.
        onChanged: (r) {
          if (!mounted) return;
          setState(() {
            _dueDate = r.date;
            _dueTime = r.time;
          });
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _dueDate = result.date;
      _dueTime = result.time;
    });
  }

  Future<void> _showPriorityMenu(BuildContext ctx) async {
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _priorityKey,
      items: [
        // COLORS-OLD: Color(0xFFDC4C3E)/Color(0xFFEB8909)/Color(0xFF246FE0)
        AnchoredMenuItem(id: 'high',   label: 'Prioridade 1', hugeIcon: HugeIcons.strokeRoundedFlag01,
            iconColor: AppColors.subtaskPriorityHigh, selected: _priority == Priority.high),
        AnchoredMenuItem(id: 'medium', label: 'Prioridade 2', hugeIcon: HugeIcons.strokeRoundedFlag01,
            iconColor: AppColors.subtaskPriorityMedium, selected: _priority == Priority.medium),
        AnchoredMenuItem(id: 'low',    label: 'Prioridade 3', hugeIcon: HugeIcons.strokeRoundedFlag01,
            iconColor: AppColors.subtaskPriorityLow, selected: _priority == Priority.low),
        AnchoredMenuItem(id: 'none',   label: 'Sem prioridade', hugeIcon: HugeIcons.strokeRoundedFlag01,
            iconColor: AppColors.textTertiary, selected: _priority == null),
      ],
    );
    if (result == null || !mounted) return;
    setState(() {
      _priority = switch (result) {
        'high'   => Priority.high,
        'medium' => Priority.medium,
        'low'    => Priority.low,
        _        => null,
      };
    });
  }

  Future<void> _showLabelsMenu(BuildContext ctx) async {
    if (_labels.isEmpty) return;
    final result = await showAnchoredMultiSelectMenu(
      context: context,
      anchorKey: _labelsKey,
      selectedIds: Set.from(_labelIds),
      items: _labels
          .map((l) => AnchoredMultiSelectItem(id: l.id, label: l.name, dotColor: l.color))
          .toList(),
    );
    if (result == null || !mounted) return;
    setState(() { _labelIds..clear()..addAll(result); });
  }

  // PASSO 3: label do pill Projeto/Inbox conforme estado de projeto/seção.
  String get _projectPillLabel {
    if (_project == null) return 'Inbox';
    if (_selectedSectionName != null) {
      return '${_project!.name} › $_selectedSectionName';
    }
    if (_availableSections.isNotEmpty) return '${_project!.name} ›';
    return _project!.name;
  }

  Future<void> _showProjectMenu(BuildContext ctx) async {
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _projectKey,
      items: [
        AnchoredMenuItem(id: 'none', label: 'Sem projeto',
            hugeIcon: HugeIcons.strokeRoundedRecord,
            iconColor: AppColors.textTertiary.withValues(alpha: 0.5),
            selected: _project == null),
        ..._projects.map((p) => AnchoredMenuItem(
              id: p.id, label: p.name,
              hugeIcon: HugeIcons.strokeRoundedRecord,
              iconColor: p.color ?? AppColors.accent,
              selected: _project?.id == p.id)),
      ],
    );
    if (result == null || !mounted) return;

    if (result == 'none') {
      setState(() {
        _project = null;
        _availableSections = [];
        _selectedSectionId = null;
        _selectedSectionName = null;
      });
      return;
    }

    _QProject? selected;
    try {
      final p = _projects.firstWhere((p) => p.id == result);
      selected = _QProject(p.id, p.name, color: p.color);
    } catch (_) {}
    if (selected == null) return;

    setState(() {
      _project = selected;
      _availableSections = [];
      _selectedSectionId = null;
      _selectedSectionName = null;
    });

    // PASSO 2/3: carrega seções do projeto escolhido e, se houver,
    // abre o segundo nível do mesmo popover para escolher a seção.
    await _loadSectionsForProject(selected.id);
    if (!mounted) return;
    if (_availableSections.isNotEmpty) {
      await _showSectionMenu(ctx);
    }
  }

  /// Segundo nível do seletor Projeto/Seção (PASSO 3) — reutiliza o mesmo
  /// AnchoredSelectMenu, anexado ao mesmo _projectKey. O item "‹ Voltar"
  /// funciona como back button, reabrindo a lista de projetos.
  Future<void> _showSectionMenu(BuildContext ctx) async {
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _projectKey,
      items: [
        AnchoredMenuItem(id: '__back__', label: '‹ Voltar',
            hugeIcon: HugeIcons.strokeRoundedArrowLeft01,
            iconColor: AppColors.textTertiary),
        AnchoredMenuItem(id: '__none__', label: 'Sem seção',
            selected: _selectedSectionId == null),
        ..._availableSections.map((s) => AnchoredMenuItem(
              id: s.id, label: s.name,
              selected: _selectedSectionId == s.id)),
      ],
    );
    if (result == null || !mounted) return;

    if (result == '__back__') {
      await _showProjectMenu(ctx);
      return;
    }

    setState(() {
      if (result == '__none__') {
        _selectedSectionId = null;
        _selectedSectionName = null;
      } else {
        try {
          final s = _availableSections.firstWhere((s) => s.id == result);
          _selectedSectionId = s.id;
          _selectedSectionName = s.name;
        } catch (_) {}
      }
    });
  }

  // ── Computed getters ──────────────────────────────────────────────────────────

  String get _dateLabel {
    if (_dueDate == null) return '';
    final d = _dueDate!;
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul',
        'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final base = '${d.day} ${months[d.month - 1]}';
    if (_dueTime != null) {
      return '$base ${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}';
    }
    return base;
  }

  // PRIORITY-CENTRAL-OLD: _priorityColor/_priorityLabel locais — movidos
  // pra PriorityExtension em lib/models/task.dart.
  Color get _priorityColor => _priority?.color ?? AppColors.textTertiary;

  String get _priorityLabel => _priority?.label ?? '';

  // Part 6 — date color, reusing exact same colors as TaskDatePickerSheet
  // (Hoje=green, Amanhã=orange, Fim de semana=blue, Próxima semana=purple)
  // COLORS-OLD: Color(0xFFF5A623)/Color(0xFF4D9FEC)/Color(0xFFB18CF5) — duplicavam priorityMedium/priorityLow/tagPurple
  // 0xFF3BAA6E sem token equivalente — FIXED-COLOR: mesmo acento decorativo único do TaskDatePickerSheet
  static const _dateColorToday    = Color(0xFF3BAA6E);
  static const _dateColorTomorrow = AppColors.priorityMedium;
  static const _dateColorWeekend  = AppColors.priorityLow;
  static const _dateColorNextWeek = AppColors.tagPurple;

  Color get _datePillColor {
    if (_dueDate == null) return AppColors.textSecondary;
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    if (d == today) return _dateColorToday;
    if (d == today.add(const Duration(days: 1))) return _dateColorTomorrow;
    final daysToSun  = (DateTime.sunday  - today.weekday + 7) % 7;
    final sunday     = today.add(Duration(days: daysToSun  == 0 ? 7 : daysToSun));
    if (d == sunday) return _dateColorWeekend;
    final daysToMon  = (DateTime.monday  - today.weekday + 7) % 7;
    final nextMonday = today.add(Duration(days: daysToMon  == 0 ? 7 : daysToMon));
    if (d == nextMonday) return _dateColorNextWeek;
    return AppColors.accent;
  }

  String get _datePillLabel {
    if (_dueDate == null) return '';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    if (d == today) return 'Hoje';
    if (d == today.add(const Duration(days: 1))) return 'Amanhã';
    final daysToSun  = (DateTime.sunday  - today.weekday + 7) % 7;
    final sunday     = today.add(Duration(days: daysToSun  == 0 ? 7 : daysToSun));
    if (d == sunday) return 'Fim de sem';
    final daysToMon  = (DateTime.monday  - today.weekday + 7) % 7;
    final nextMonday = today.add(Duration(days: daysToMon  == 0 ? 7 : daysToMon));
    if (d == nextMonday) return 'Próx. sem';
    return _dateLabel; // formatted date fallback
  }

  // Part 6 — label pill: color = the selected label's own color (1 label),
  // accent (2+). Falls back to accent if label data not yet loaded.
  Color get _labelPillColor {
    if (_labelIds.isEmpty) return AppColors.textSecondary;
    if (_labelIds.length == 1) {
      final id = _labelIds.first;
      try { return _labels.firstWhere((l) => l.id == id).color; } catch (_) {}
    }
    return AppColors.accent;
  }

  // Returns name of the single selected label, or null when 0 or 2+.
  String? get _labelPillName {
    if (_labelIds.length != 1) return null;
    final id = _labelIds.first;
    try { return _labels.firstWhere((l) => l.id == id).name; } catch (_) {}
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) return _buildDialog();
    return _buildSheet();
  }

  Widget _buildDialog() {
    // Desktop: full rounded corners, no drag handle.
    return _LiquidPanel(
      borderRadius: BorderRadius.circular(20),
      child: _buildContent(isDialog: true),
    );
  }

  Widget _buildSheet() {
    // isScrollControlled:true only allows the sheet to exceed 50% of screen height;
    // it does NOT automatically add keyboard padding. We make the sheet taller by
    // kbH using a SizedBox INSIDE _LiquidPanel so that:
    //   • The content position above the keyboard is identical to Padding(bottom:kbH)
    //   • The _LiquidPanel background visually extends behind the keyboard, eliminating
    //     the abrupt cut at the keyboard boundary.
    final kbH = MediaQuery.of(context).viewInsets.bottom;
    return _LiquidPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildContent(isDialog: false),
          // Background extension: invisible content, purely visual.
          // Extends the Liquid Glass surface behind the iOS keyboard so the
          // junction between sheet and keyboard blends instead of cutting abruptly.
          if (kbH > 0) SizedBox(height: kbH),
        ],
      ),
    );
  }

  Widget _buildContent({required bool isDialog}) {
    final hasTitle = _titleCtrl.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Drag handle (sheet only) ──────────────────────────────────────────
        if (!isDialog) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 20),

        // ── Title field ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CustomPaint(
            foregroundPainter: const PopoverBorderPainter(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(PopoverStyle.radius),
              ),
              child: TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              // cursorHeight set explicitly so the caret stays proportional to
              // the font size instead of stretching to fill the container height.
              cursorHeight: 20,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              cursorColor: AppColors.accent,
              cursorWidth: 1.5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Nome da tarefa',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withValues(alpha: 0.30),
                ),
                // Override theme's filled:true/fillColor:surface so the
                // InputDecorator doesn't draw its own background inside the
                // Container, which was causing the "double border" effect.
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) {
                if (hasTitle) _save();
              },
            ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Description field ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CustomPaint(
            foregroundPainter: const PopoverBorderPainter(),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(PopoverStyle.radius),
            ),
            child: TextField(
              controller: _descCtrl,
              cursorHeight: 17,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              cursorColor: AppColors.accent,
              cursorWidth: 1.5,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Descrição',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary.withValues(alpha: 0.25),
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.textTertiary.withValues(alpha: 0.15),
        ),

        // ── B.9 Problem 2: 2-line footer ─────────────────────────────────────
        // Line 1: Etiqueta + Data + Prioridade (scrollable horizontal)
        // Line 2: Projeto/Inbox (left)  +  Botão enviar (right)
        // OLD (1 row with all 4 pills + send button) — commented for revert:
        // Padding(padding: const EdgeInsets.fromLTRB(0, 9, 14, 9), child: Row(children: [
        //   Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: ...,
        //     child: Row(children: [label, date, priority, project]))),
        //   SizedBox(10), sendButton ])),

        // Line 1 — scrollable pills: Label · Date · Priority
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 14, top: 9, right: 14),
          child: Row(
            children: [
              _QuickPill(
                key: _labelsKey,
                hugeIcon: HugeIcons.strokeRoundedTag01,
                active: _labelIds.isNotEmpty,
                activeColor: _labelPillColor,
                activeLabel: _labelPillName,
                badge: _labelIds.length > 1 ? '${_labelIds.length}' : null,
                onTap: () => _showLabelsMenu(context),
              ),
              const SizedBox(width: 7),
              _QuickPill(
                key: _dateKey,
                hugeIcon: HugeIcons.strokeRoundedCalendar01,
                active: _dueDate != null,
                activeColor: _datePillColor,
                activeLabel: _dueDate != null ? _datePillLabel : null,
                onTap: () => _showDateSheet(context),
              ),
              const SizedBox(width: 7),
              _QuickPill(
                key: _priorityKey,
                hugeIcon: HugeIcons.strokeRoundedFlag01,
                active: _priority != null,
                activeColor: _priorityColor,
                activeLabel: _priority != null ? _priorityLabel : null,
                subtleBg: true,
                onTap: () => _showPriorityMenu(context),
              ),
              const SizedBox(width: 7),
              // CORRIGIDO_ETAPA3B_PARCELAS: gerador de parcelas — salva a
              // tarefa (se houver título) e abre o InstallmentGeneratorSheet
              // com o taskId real.
              _QuickPill(
                hugeIcon: HugeIcons.strokeRoundedMoney01,
                active: false,
                activeColor: AppColors.accent,
                subtleBg: true,
                onTap: hasTitle && !_saving ? _openInstallmentGenerator : () {},
              ),
            ],
          ),
        ),

        // Line 2 — Projeto (left) + Salvar (right)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 9),
          child: Row(
            children: [
              _ProjectPill(
                key: _projectKey,
                name: _projectPillLabel,
                dotColor: _project?.color ??
                    AppColors.textPrimary.withValues(alpha: 0.28),
                active: _project != null,
                onTap: () => _showProjectMenu(context),
              ),
              const Spacer(),
              GestureDetector(
                onTap: hasTitle && !_saving ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _kSendButtonWidth,
                  height: _kFooterPillHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasTitle
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(_pillRadius),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : HugeIcon(icon: HugeIcons.strokeRoundedArrowUp01,
                          size: 18,
                          color: hasTitle
                              ? AppColors.background
                              : AppColors.background.withValues(alpha: 0.45),
                        ),
                ),
              ),
            ],
          ),
        ),

        // ── Safe area bottom (sheet only) ─────────────────────────────────────
        // When the keyboard is open, the home-indicator safe area sits behind it
        // and is irrelevant — use a small fixed gap instead so the footer sits
        // close to the keyboard rather than leaving a large empty band.
        if (!isDialog)
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? 12
                : math.max(_viewPaddingBottom, 0),
          ),
        if (isDialog) const SizedBox(height: 8),
      ],
    );
  }
}

// ── Liquid Glass panel ─────────────────────────────────────────────────────────
//
// Applied to the whole QuickAddTaskSheet surface. Uses a lower blur sigma (12)
// than the small popovers (20) to avoid an overly heavy effect on a large area,
// while keeping the same visual language. The PopoverBorderPainter gradient
// border is adapted via a custom BorderPainter below that handles both full-
// round (dialog) and top-only-round (bottom sheet) border shapes.

class _LiquidPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const _LiquidPanel({required this.child, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    // drawBottom=false when borderRadius has no bottom radius (bottom sheet):
    // omits the border line at the keyboard junction for a seamless blend.
    final hasBottomRadius = borderRadius.bottomLeft != Radius.zero;
    return CustomPaint(
      foregroundPainter: _PanelBorderPainter(
        borderRadius: borderRadius,
        drawBottom: hasBottomRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          // Sigma 12 (vs 20 in popovers) — softer on a large area.
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              // Same color formula as PopoverStyle.bg but slightly more opaque
              // on a big surface so content stays readable through the blur.
              color: AppColors.navBar.withValues(alpha: 0.82),
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Draws the gradient border for the sheet/dialog panel.
// [drawBottom] = false for bottom sheets: skips the bottom edge so no visible
// border line appears where the sheet meets the keyboard (Todoist-style blend).
class _PanelBorderPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool drawBottom;
  const _PanelBorderPainter({required this.borderRadius, this.drawBottom = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader      = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x4DFFFFFF), // top   ~30%
          Color(0x26FFFFFF), // mid   ~15%
          Color(0x1FFFFFFF), // base  ~12%
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);

    if (drawBottom) {
      canvas.drawRRect(borderRadius.toRRect(rect), paint);
    } else {
      // Draw left side + top arc + right side; omit bottom edge entirely.
      final r  = borderRadius.topLeft.x;
      final w  = size.width;
      final h  = size.height;
      final path = Path()
        ..moveTo(0, h)              // start bottom-left (open end)
        ..lineTo(0, r)              // left side up to arc start
        ..arcToPoint(Offset(r, 0),
            radius: Radius.circular(r), clockwise: true)
        ..lineTo(w - r, 0)         // top edge
        ..arcToPoint(Offset(w, r),
            radius: Radius.circular(r), clockwise: true)
        ..lineTo(w, h);             // right side down to bottom-right (open end)
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PanelBorderPainter old) =>
      old.borderRadius != borderRadius || old.drawBottom != drawBottom;
}

// ── Icon pill — fully rounded (pill/circle), matching the tab bar / FAB /
// Liquid Glass bottom sheet language used elsewhere in the app ─────────────

// Pill height target ~44px (icon 16 + vertical padding 14*2), matching the
// app's 44x44 minimum touch target. _pillRadius = height/2 gives a perfect
// pill shape for text variants and a perfect circle for icon-only (calendar).
// OLD squircle (radius 10, height ~32) — replaced for full-round consistency.
const double _pillRadius = 22.0;
const double _kFooterPillHeight = _pillRadius * 2; // 44.0 — shared with the send button
const double _kSendButtonWidth = 64.0; // matches the visual width of the Inbox/Project pill

class _QuickPill extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final bool active;
  final Color activeColor;
  final String? activeLabel;
  final String? badge;
  // Part 6: when true (Priority), background stays neutral even when active —
  // only icon+text take the activeColor; background is always white 5%.
  final bool subtleBg;
  final VoidCallback onTap;

  const _QuickPill({
    super.key,
    required this.hugeIcon,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.activeLabel,
    this.badge,
    this.subtleBg = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasText = activeLabel != null || badge != null;

    // Background: colored tint when active (unless subtleBg), neutral otherwise.
    final Color bg = (active && !subtleBg)
        ? activeColor.withValues(alpha: 0.12)
        : AppColors.surfaceVariant.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        // Icon-only: square 44x44 (padding 14 all → 16+14+14=44) → perfect circle.
        // With text: pill ~44 tall (16+14+14), width grows with content.
        padding: hasText
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
            : const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_pillRadius),
          border: Border.all(
            color: AppColors.textTertiary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: hugeIcon, size: 16,
                color: active ? activeColor : AppColors.textSecondary),
            if (activeLabel != null) ...[
              const SizedBox(width: 5),
              Text(activeLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    color: activeColor,
                    fontWeight: FontWeight.w500,
                  )),
            ],
            if (badge != null) ...[
              const SizedBox(width: 4),
              Text(badge!,
                  style: TextStyle(
                    fontSize: 12,
                    color: activeColor,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Project pill — same fully-rounded style as _QuickPill ────────────────────
// OLD squircle (radius 10, height ~32) — replaced for full-round consistency,
// matching the tab bar / FAB / Liquid Glass bottom sheet pill language.

class _ProjectPill extends StatelessWidget {
  final String name;
  final Color dotColor;
  final bool active;
  final VoidCallback onTap;

  const _ProjectPill({
    super.key,
    required this.name,
    required this.dotColor,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = active
        ? dotColor.withValues(alpha: 0.12)
        : AppColors.surfaceVariant.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_pillRadius),
          border: Border.all(
            color: AppColors.textTertiary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: active ? dotColor : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
