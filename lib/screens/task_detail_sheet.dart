import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/section.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/section_repository.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../widgets/installment_generator_sheet.dart';
import '../widgets/popover_style.dart';
import '../widgets/task_detail/sheets/task_date_picker_sheet.dart';
import '../widgets/task_detail/sheets/task_labels_picker_sheet.dart';
import '../widgets/task_detail/sheets/task_priority_picker_sheet.dart';
import '../widgets/anchored_select_menu.dart';
import '../widgets/task_detail/sheets/task_project_picker_sheet.dart';
import '../widgets/task_detail/subtask_editor.dart';
import '../widgets/task_detail/subtask_item.dart';
import '../widgets/task_detail/task_detail_widgets.dart';
import 'quick_add_task_sheet.dart';
import 'package:hugeicons/hugeicons.dart';
import '../widgets/pressable.dart';

// Lightweight structs just for this sheet
class _Project {
  final String id;
  final String name;
  final Color? color;
  const _Project(this.id, this.name, {this.color});
}

class _Label {
  final String id;
  final String name;
  final Color color;
  const _Label(this.id, this.name, this.color);
}


Future<void> showTaskDetailSheet(BuildContext context, Task task,
    {VoidCallback? onSaved}) async {
  final isDesktop = MediaQuery.of(context).size.width >= 1024;
  if (isDesktop) {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _TaskDetailSheet(task: task, onSaved: onSaved, asDialog: true),
    );
  } else {
    // ADICIONADO_TAP_FORA_FECHA: GlobalKey permite que o backdrop (criado
    // em _SheetPageRoute.buildTransitions, fora da árvore do State) acione
    // o mesmo fechamento "salva e fecha" usado pelo botão X.
    final contentKey = GlobalKey<_TaskDetailSheetState>();
    await Navigator.of(context, rootNavigator: true).push(
      _SheetPageRoute(
        builder: (_) => _TaskDetailSheet(key: contentKey, task: task, onSaved: onSaved),
        contentKey: contentKey,
      ),
    );
  }
}

Future<void> showNewTaskSheet(BuildContext context,
    {VoidCallback? onSaved}) async {
  // OLD: opened full _TaskDetailSheet with task: null — commented for revert.
  // To revert: uncomment the block below and remove the showQuickAddTaskSheet call.
  //
  // final isDesktop = MediaQuery.of(context).size.width >= 1024;
  // if (isDesktop) {
  //   await showDialog<void>(
  //     context: context,
  //     barrierColor: Colors.black.withValues(alpha: 0.4),
  //     builder: (_) => _TaskDetailSheet(task: null, onSaved: onSaved, asDialog: true),
  //   );
  // } else {
  //   await Navigator.of(context, rootNavigator: true).push(
  //     _SheetPageRoute(
  //       builder: (_) => _TaskDetailSheet(task: null, onSaved: onSaved),
  //     ),
  //   );
  // }

  await showQuickAddTaskSheet(context, onSaved: onSaved);
}

/// Slide-from-bottom page route.
class _SheetPageRoute extends PageRoute<void> {
  final WidgetBuilder builder;
  // ADICIONADO_TAP_FORA_FECHA: referência ao state do conteúdo para que o
  // backdrop (abaixo) possa acionar fechamento com persistência.
  final GlobalKey<_TaskDetailSheetState>? contentKey;

  _SheetPageRoute({required this.builder, this.contentKey})
      : super(settings: const RouteSettings());

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const _SheetSpringCurve(),
      reverseCurve: Curves.easeInCubic,
    ));

    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: fade,
      builder: (_, Widget? c) => Stack(
        children: [
          // Blur barrier fades in with the sheet
          // CORRIGIDO_TAP_FORA_FECHA: este Container opaco (tem `color`)
          // intercepta o hit-test e nunca deixava o tap chegar ao
          // ModalBarrier do Navigator (que ficaria por trás, no Overlay),
          // mesmo com barrierDismissible:true — por isso tocar fora nunca
          // fechava o sheet. Adicionado GestureDetector próprio que fecha
          // e persiste (mesmo caminho do botão X / drag-to-close).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => contentKey?.currentState?.closeAndPersist(),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 8 * fade.value,
                sigmaY: 8 * fade.value,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35 * fade.value),
              ),
            ),
          ),
          c!,
        ],
      ),
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Curva spring iOS-like: desaceleração com overshoot sutil (~4%), sem bounce excessivo.
class _SheetSpringCurve extends Curve {
  const _SheetSpringCurve();

  @override
  double transformInternal(double t) {
    // Amortecimento exponencial com frequência angular ajustada para sheet
    const damping = 8.0;
    const omega = 7.0;
    return 1 - math.exp(-damping * t) * math.cos(omega * t);
  }
}

class _TaskDetailSheet extends StatefulWidget {
  final Task? task;
  final VoidCallback? onSaved;
  final bool asDialog;
  const _TaskDetailSheet({super.key, required this.task, this.onSaved, this.asDialog = false});

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> with WidgetsBindingObserver {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  final _commentCtrl = TextEditingController();
  // COMMENT-LOAD: lista de comentários carregados
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = false;
  late Priority? _priority;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  // ADICIONADO_BUG_DATE_FALLBACK: guarda o último resultado recebido via
  // onChanged do TaskDatePickerSheet, para servir de fallback caso o
  // Navigator.pop() do sheet (capturado pelo await) retorne null por
  // qualquer falha de timing entre o callback e o fechamento do sheet.
  DatePickerResult? _lastDateResult;
  _Project? _project;
  final Set<String> _labelIds = {};

  // ADICIONADO_SECAO_PROJETO: estado do seletor de dois níveis (projeto ›
  // seção), espelhando o padrão já existente em quick_add_task_sheet.dart.
  String? _sectionId;
  String? _sectionName;
  List<Section> _availableSections = [];
  static const _sectionRepo = SectionRepository();

  List<_Project> _projects = [];
  List<_Label> _labels = [];
  List<SubtaskItem> _subtasks = [];
  Recurrence? _recurrence;
  bool _saving = false;
  bool _subtasksExpanded = false;
  bool _popping = false;

  double _keyboardHeight = 0;
  double _viewPaddingBottom = 0;

  OverlayEntry? _activePopover;

  final _draggableCtrl = DraggableScrollableController();
  final _descFocusNode = FocusNode();
  final _titleFocusNode = FocusNode();

  // GlobalKeys for anchored desktop pickers
  final _dateChipKey      = GlobalKey();
  final _priorityChipKey  = GlobalKey();
  final _labelsChipKey    = GlobalKey();
  final _projectChipKey   = GlobalKey();
  final _recurChipKey     = GlobalKey();
  bool _descFocused = false;

  bool get _isNew => widget.task == null;
  bool get _isLightAccent => AppColors.accent.computeLuminance() > 0.5;

  // ADICIONADO_SECAO_PROJETO: label combinado "Projeto › Seção" para o
  // MetaRow mobile, espelhando _projectPillLabel de quick_add_task_sheet.dart.
  String get _projectLabel {
    if (_project == null) return 'Sem projeto';
    if (_sectionName != null) return '${_project!.name} › $_sectionName';
    return _project!.name;
  }

  // ADICIONADO_AUTOSAVE: persiste Prioridade/Data/Etiquetas imediatamente
  // após a seleção, sem esperar o _save() completo do sheet. Tarefas ainda
  // não criadas (_isNew, sem id) são ignoradas — _save() ao fechar o sheet
  // continua sendo o caminho de criação inicial.
  Future<void> _autosavePriority() async {
    if (_isNew) return;
    final prioStr = switch (_priority) {
      Priority.high => 'high',
      Priority.medium => 'medium',
      Priority.low => 'low',
      null => null,
    };
    try {
      await supabase.from('tasks').update({'prioridade': prioStr}).eq('id', widget.task!.id);
    } catch (e) {
      // ignore: avoid_print
      print('[TaskDetail] autosave prioridade falhou: $e');
    }
  }

  // HORA-SYNC-OLD: só atualizava data_vencimento
  // Future<void> _autosaveDueDate() async {
  //   if (_isNew) return;
  //   String? dueDateStr;
  //   if (_dueDate != null) {
  //     if (_dueTime != null) {
  //       dueDateStr = DateTime(
  //         _dueDate!.year, _dueDate!.month, _dueDate!.day,
  //         _dueTime!.hour, _dueTime!.minute,
  //       ).toIso8601String();
  //     } else {
  //       dueDateStr = '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';
  //     }
  //   }
  //   try {
  //     await supabase.from('tasks').update({'data_vencimento': dueDateStr}).eq('id', widget.task!.id);
  //   } catch (e) {
  //     // ignore: avoid_print
  //     print('[TaskDetail] autosave data_vencimento falhou: $e');
  //   }
  // }

  Future<void> _autosaveDueDate() async {
    if (_isNew || widget.task?.id == null) return;

    String? dueDateStr;
    String? horaStr;

    if (_dueDate != null) {
      if (_dueTime != null) {
        final full = DateTime(
          _dueDate!.year, _dueDate!.month, _dueDate!.day,
          _dueTime!.hour, _dueTime!.minute,
        );
        dueDateStr = full.toIso8601String();
        // Sincronizar hora no formato HH:mm (mesmo formato que outras partes do app esperam em Task.time)
        horaStr = '${_dueTime!.hour.toString().padLeft(2, '0')}:'
            '${_dueTime!.minute.toString().padLeft(2, '0')}';
      } else {
        dueDateStr = '${_dueDate!.year}-'
            '${_dueDate!.month.toString().padLeft(2, '0')}-'
            '${_dueDate!.day.toString().padLeft(2, '0')}';
        horaStr = null; // sem hora — limpar o campo
      }
    }

    try {
      await supabase
          .from('tasks')
          .update({
            'data_vencimento': dueDateStr,
            'hora': horaStr, // HORA-SYNC: manter em sincronia
          })
          .eq('id', widget.task!.id);
    } catch (e) {
      // ignore: avoid_print
      print('[TaskDetail] autosave falhou: $e');
    }
  }

  Future<void> _autosaveLabels() async {
    if (_isNew) return;
    final taskId = widget.task!.id;
    try {
      // Etiquetas de tasks são sincronizadas via tabela de junção
      // task_labels (não existe coluna label_ids em tasks).
      await supabase.from('task_labels').delete().eq('task_id', taskId);
      if (_labelIds.isNotEmpty) {
        await supabase.from('task_labels').insert(
          _labelIds.map((lid) => {'task_id': taskId, 'label_id': lid}).toList(),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[TaskDetail] autosave etiquetas falhou: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _priority = widget.task?.priority;

    // Load date; extract time component if stored as full datetime
    final rawDate = widget.task?.dueDate;
    if (rawDate != null) {
      if (rawDate.hour != 0 || rawDate.minute != 0) {
        _dueTime = TimeOfDay(hour: rawDate.hour, minute: rawDate.minute);
        _dueDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
      } else {
        _dueDate = rawDate;
      }
    }

    // HORA-FALLBACK: dueDate sem componente de hora — tentar campo 'hora' separado
    if (_dueDate != null && _dueTime == null && widget.task?.time != null) {
      final parts = widget.task!.time!.split(':');
      if (parts.length >= 2) {
        _dueTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }


    _subtasks = (widget.task?.subtasks ?? [])
        .map((s) => SubtaskItem(title: s.title, description: s.description, done: s.done, priority: s.priority, valor: s.valor))
        .toList();
    _recurrence = widget.task?.recurrence;
    if (!widget.asDialog) _draggableCtrl.addListener(_onDragChange);
    _titleCtrl.addListener(() { if (mounted) setState(() {}); });
    _commentCtrl.addListener(() { if (mounted) setState(() {}); });
    _descFocusNode.addListener(() {
      if (mounted) setState(() => _descFocused = _descFocusNode.hasFocus);
    });
    _loadMeta();
    // COMMENT-LOAD: carregar comentários ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadComments());
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final v = WidgetsBinding.instance.platformDispatcher.views.first;
      setState(() => _viewPaddingBottom = v.padding.bottom / v.devicePixelRatio);
    });
    if (_isNew) {
      if (widget.asDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _titleFocusNode.requestFocus();
        });
      } else {
        // Delay past the 500ms spring sheet animation to avoid keyboard jump
        Future.delayed(const Duration(milliseconds: 560), () {
          if (mounted) _titleFocusNode.requestFocus();
        });
      }
    }
  }

  @override
  void didChangeMetrics() {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final kh = v.viewInsets.bottom / v.devicePixelRatio;
    if (mounted) setState(() => _keyboardHeight = kh);
  }

  void _onDragChange() {
    if (!_draggableCtrl.isAttached || _popping) return;
    if (_draggableCtrl.size <= 0.51 && mounted) {
      _draggableCtrl.removeListener(_onDragChange);
      if (_titleCtrl.text.trim().isNotEmpty && !_saving) {
        _save();
      } else {
        _popping = true;
        Navigator.of(context).pop();
        widget.onSaved?.call(); // ADICIONADO_REFRESH_FECHAMENTO
      }
    }
  }

  // ADICIONADO_TAP_FORA_FECHA: fechamento usado pelo tap fora do sheet
  // (acionado via GlobalKey por _SheetPageRoute) e também pelo botão X.
  // CORRIGIDO_FECHAMENTO_DESTRUTIVO: a primeira versão chamava _save()
  // (caminho completo) sempre que havia título preenchido — o que é o caso
  // de toda tarefa já existente. _save() faz delete+reinsert de TODAS as
  // subtasks e etiquetas a partir do estado local atual; se _loadMeta()
  // (subtasks/projeto) ainda não tivesse terminado de carregar no momento
  // do tap fora/X, isso sobrescrevia/zerava dados ainda não sincronizados
  // (ex.: apagava subtasks, ou regravava data/projeto com valor antigo).
  // Os campos individuais (prioridade/data/etiquetas/projeto-seção) já têm
  // autosave próprio e imediato — fechar aqui só precisa popar e avisar a
  // tela anterior para recarregar (dados já estão no banco).
  void closeAndPersist() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
    widget.onSaved?.call();
  }

  void _removePopover() {
    _activePopover?.remove();
    _activePopover = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removePopover();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _commentCtrl.dispose();
    _descFocusNode.dispose();
    _titleFocusNode.dispose();
    for (final s in _subtasks) { s.dispose(); }
    if (!widget.asDialog) _draggableCtrl.removeListener(_onDragChange);
    _draggableCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleSubtaskDone(SubtaskItem s) async {
    setState(() => s.done = !s.done);
    if (widget.task == null) return;
    final idx = _subtasks.indexOf(s);
    try {
      final rows = await supabase
          .from('subtasks')
          .select('id')
          .eq('task_id', widget.task!.id)
          .order('ordem');
      if (idx >= 0 && idx < rows.length) {
        await supabase
            .from('subtasks')
            .update({'concluida': s.done})
            .eq('id', rows[idx]['id']);
      }
      widget.onSaved?.call();
    } catch (_) {}
  }

  void _addSubtask() {
    final item = SubtaskItem(title: '');
    setState(() => _subtasks.add(item));
    WidgetsBinding.instance.addPostFrameCallback((_) => item.focus.requestFocus());
  }

  Future<void> _loadMeta() async {
    final pRows = await supabase.from('projects').select('id, nome, cor').order('nome');
    final lRows = await supabase.from('labels').select('id, nome, cor').order('nome');

    if (!mounted) return;

    final projects = (pRows as List)
        .map((r) => _Project(r['id'].toString(), r['nome'] as String,
            color: _parseColor(r['cor'] as String?)))
        .toList();
    final labels = (lRows as List)
        .map((r) => _Label(r['id'].toString(), r['nome'] as String, _parseColor(r['cor'] as String?)))
        .toList();

    Set<String> currentLabelIds = {};
    _Project? currentProject;

    if (!_isNew) {
      final tlRows = await supabase
          .from('task_labels')
          .select('label_id')
          .eq('task_id', widget.task!.id);
      currentLabelIds = (tlRows as List).map((r) => r['label_id'].toString()).toSet();
      try {
        currentProject = projects.firstWhere((p) => p.name == widget.task!.project);
      } catch (_) {}

      // Reload subtasks fresh from DB so toggles made in the tile are reflected
      await _reloadSubtasksFromDb();
    }

    if (!mounted) return;
    setState(() {
      _projects = projects;
      _labels = labels;
      _labelIds.addAll(currentLabelIds);
      _project = currentProject;
      // ADICIONADO_SECAO_PROJETO: carrega a seção já persistida na tarefa.
      _sectionId = widget.task?.sectionId;
    });

    // ADICIONADO_SECAO_PROJETO: pré-carrega as seções do projeto atual para
    // resolver o nome da seção selecionada (exibido como "Projeto › Seção").
    if (_project != null) {
      await _loadSectionsForProject(_project!.id);
      if (_sectionId != null && mounted) {
        setState(() {
          try {
            _sectionName = _availableSections.firstWhere((s) => s.id == _sectionId).name;
          } catch (_) {}
        });
      }
    }
  }

  // ADICIONADO_SECAO_PROJETO: carrega as seções do projeto informado,
  // espelhando _loadSectionsForProject() de quick_add_task_sheet.dart.
  Future<void> _loadSectionsForProject(String projectId) async {
    try {
      final sections = await _sectionRepo.getSectionsForProject(projectId);
      if (!mounted) return;
      setState(() => _availableSections = sections);
    } catch (_) {}
  }

  /// Recarrega _subtasks direto do banco (extraído de dentro de _loadMeta
  /// para ser reutilizável — usado também pelo callback onGenerated do
  /// gerador de parcelas).
  Future<void> _reloadSubtasksFromDb() async {
    if (_isNew) return;
    final stRows = await supabase
        .from('subtasks')
        .select('id, titulo, descricao, concluida, ordem, prioridade, data_vencimento, label_ids, valor')
        .eq('task_id', widget.task!.id)
        .order('ordem');
    if (!mounted) return;
    final fresh = (stRows as List).map((s) {
      DateTime? stDueDate;
      TimeOfDay? stDueTime;
      final rawDt = s['data_vencimento'];
      if (rawDt != null) {
        final parsed = DateTime.tryParse(rawDt as String);
        if (parsed != null) {
          if (parsed.hour != 0 || parsed.minute != 0) {
            stDueTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
            stDueDate = DateTime(parsed.year, parsed.month, parsed.day);
          } else {
            stDueDate = DateTime(parsed.year, parsed.month, parsed.day);
          }
        }
      }
      final rawLabelIds = s['label_ids'];
      final labelIdSet = rawLabelIds is List
          ? Set<String>.from(rawLabelIds.map((e) => e.toString()))
          : <String>{};
      return SubtaskItem(
        id: s['id']?.toString(),
        title: s['titulo'] as String,
        description: s['descricao'] as String?,
        done: s['concluida'] as bool? ?? false,
        priority: switch (s['prioridade'] as String?) {
          'high' => SubtaskPriority.high,
          'medium' => SubtaskPriority.medium,
          'low' => SubtaskPriority.low,
          _ => null,
        },
        labelIds: labelIdSet,
        dueDate: stDueDate,
        dueTime: stDueTime,
        valor: (s['valor'] as num?)?.toDouble(),
      );
    }).toList();
    setState(() {
      for (final old in _subtasks) { old.dispose(); }
      _subtasks = fresh;
    });
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

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || widget.task == null) return;
    final userId = supabase.auth.currentUser?.id;
    try {
      await supabase.from('task_comments').insert({
        'task_id': widget.task!.id,
        'conteudo': text,
        if (userId != null) 'user_id': userId,
      });
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
      HapticService().selectionClick();
      widget.onSaved?.call();
      _loadComments(); // recarregar lista após enviar
    } catch (_) {}
  }

  // COMMENT-LOAD: carrega os comentários existentes da tarefa.
  Future<void> _loadComments() async {
    if (_isNew || widget.task?.id == null) return;
    setState(() => _loadingComments = true);
    try {
      final rows = await supabase
          .from('task_comments')
          .select('id, conteudo, created_at, user_id')
          .eq('task_id', widget.task!.id)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(rows);
          _loadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingComments = false);
      // ignore: avoid_print
      print('[COMMENT] erro ao carregar: $e');
    }
  }

  String _formatCommentDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    if (_isNew) {
      HapticService().taskCreated();
    } else {
      HapticService().saved();
    }
    setState(() => _saving = true);

    try {
      final prioStr = switch (_priority) {
        Priority.high => 'high',
        Priority.medium => 'medium',
        Priority.low => 'low',
        null => null,
      };

      String? dueDateStr;
      if (_dueDate != null) {
        if (_dueTime != null) {
          final dt = DateTime(
            _dueDate!.year, _dueDate!.month, _dueDate!.day,
            _dueTime!.hour, _dueTime!.minute,
          );
          dueDateStr = dt.toIso8601String();
        } else {
          dueDateStr = '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';
        }
      }

      final payload = {
        'titulo': _titleCtrl.text.trim(),
        'descricao': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'prioridade': prioStr,
        'project_id': _project?.id,
        // ADICIONADO_SECAO_PROJETO: persistido junto com project_id.
        'section_id': _sectionId,
        'data_vencimento': dueDateStr,
        // HORA-SYNC: manter em sincronia com data_vencimento
        'hora': _dueTime != null
            ? '${_dueTime!.hour.toString().padLeft(2, '0')}:'
                '${_dueTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'recorrencia': _recurrence?.toJsonString(),
      };

      String taskId;

      if (_isNew) {
        final userId = supabase.auth.currentUser?.id;
        // ignore: avoid_print
        print('[TaskDetail] inserting new task — user=$userId');
        final inserted = await supabase
            .from('tasks')
            .insert({...payload, if (userId != null) 'user_id': userId})
            .select('id')
            .single();
        taskId = inserted['id'].toString();
      } else {
        taskId = widget.task!.id;
        // ignore: avoid_print
        print('[TaskDetail] updating task $taskId');
        await supabase.from('tasks').update(payload).eq('id', taskId);
      }

      // Sync labels
      await supabase.from('task_labels').delete().eq('task_id', taskId);
      if (_labelIds.isNotEmpty) {
        await supabase.from('task_labels').insert(
          _labelIds.map((lid) => {'task_id': taskId, 'label_id': lid}).toList(),
        );
      }

      // Sync subtasks — delete all then re-insert in current order
      await supabase.from('subtasks').delete().eq('task_id', taskId);
      final subtaskRows = <Map<String, dynamic>>[];
      for (int i = 0; i < _subtasks.length; i++) {
        final st = _subtasks[i];
        final title = st.ctrl.text.trim();
        if (title.isEmpty) continue;
        final desc = st.descCtrl.text.trim();
        String? stDueDateStr;
        if (st.dueDate != null) {
          if (st.dueTime != null) {
            stDueDateStr = DateTime(
              st.dueDate!.year, st.dueDate!.month, st.dueDate!.day,
              st.dueTime!.hour, st.dueTime!.minute,
            ).toIso8601String();
          } else {
            stDueDateStr = '${st.dueDate!.year}-${st.dueDate!.month.toString().padLeft(2, '0')}-${st.dueDate!.day.toString().padLeft(2, '0')}';
          }
        }
        subtaskRows.add({
          'task_id': taskId,
          'titulo': title,
          'descricao': desc.isEmpty ? null : desc,
          'concluida': st.done,
          'ordem': i,
          'prioridade': switch (st.priority) {
            SubtaskPriority.high => 'high',
            SubtaskPriority.medium => 'medium',
            SubtaskPriority.low => 'low',
            null => null,
          },
          // Requires migrations: ALTER TABLE subtasks ADD COLUMN IF NOT EXISTS data_vencimento timestamptz;
          // ALTER TABLE subtasks ADD COLUMN IF NOT EXISTS label_ids text[];
          'data_vencimento': stDueDateStr,
          'label_ids': st.labelIds.isEmpty ? null : st.labelIds.toList(),
        });
      }
      if (subtaskRows.isNotEmpty) {
        try {
          await supabase.from('subtasks').insert(subtaskRows);
        } catch (_) {
          // Fallback: retry without extended fields if columns don't exist yet
          final baseRows = subtaskRows.map((r) {
            final m = Map<String, dynamic>.from(r);
            m.remove('data_vencimento');
            m.remove('label_ids');
            return m;
          }).toList();
          await supabase.from('subtasks').insert(baseRows);
        }
      }

      if (_dueDate != null) {
        final title = _titleCtrl.text.trim();
        NotificationService().cancelTaskNotification(taskId);
        NotificationService().scheduleTaskNotification(taskId, title, _dueDate!);
      } else {
        NotificationService().cancelTaskNotification(taskId);
      }

      if (mounted) {
        _popping = true;
        Navigator.of(context).pop();
        widget.onSaved?.call();
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[TaskDetail] save error: $e\n$st');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    }
  }

  /// Mostra a primeira etiqueta como chip (ícone + nome colorido) + "+N" se mais.
  Widget _buildLabelValue() {
    final active = _labels.where((l) => _labelIds.contains(l.id)).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final extra = active.length - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...active.take(2).map((l) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: l.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9.5),
              border: Border.all(color: l.color.withValues(alpha: 0.30), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SUBSTITUIDO_REDESIGN_DETAIL
                // HugeIcon(icon: HugeIcons.strokeRoundedTag01, size: 11, color: l.color),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: l.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l.name,
                  style: TextStyle(fontSize: 12, color: l.color, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        )),
        if (extra > 1) ...[
          const SizedBox(width: 4),
          Text(
            '+${extra - 1}',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }

  // ADICIONADO_REDESIGN_DETAIL: cor da MetaRow de Data — vermelho se
  // atrasada, verde se hoje, neutro se futura. Mesmo padrão já usado nos
  // chips de subtarefa em task_tile.dart (_buildSubtaskChips).
  Color get _dueDateColor {
    if (_dueDate == null) return Colors.white.withValues(alpha: 0.85);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    final diff = due.difference(today).inDays;
    // COLORS-OLD: Color(0xFF7ECC49)/Color(0xFFDC4C3E)
    if (diff == 0) return AppColors.dateDueToday;
    if (diff < 0) return AppColors.dateOverdue;
    return Colors.white.withValues(alpha: 0.85);
  }

  String get _recurrenceLabel => _recurrence?.displayLabel ?? 'Repetir';

  String get _dateLabel {
    if (_dueDate == null) return 'Vencimento';
    final d = _dueDate!;
     final months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final base = '${d.day} ${months[d.month - 1]}';
    if (_dueTime != null) return '$base · ${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}';
    return base;
  }

  // ── Theme-aware card decorations ──────────────────────────────────────────────

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: _isLightAccent
        ? AppColors.surfaceVariant
        : AppColors.surfaceVariant.withValues(alpha: 0.5),
    borderRadius: const BorderRadius.all(Radius.circular(14)),
  );

  Divider get _cardDivider => Divider(
    height: 1,
    thickness: 0.5,
    indent: 16,
    endIndent: 16,
    color: AppColors.textTertiary.withValues(alpha: _isLightAccent ? 0.2 : 0.1),
  );

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) return _buildDesktopDialogV2(context);
    return Padding(
      padding: EdgeInsets.only(bottom: _keyboardHeight),
      child: DraggableScrollableSheet(
        controller: _draggableCtrl,
        initialChildSize: _isNew ? 0.92 : 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: _isNew ? const [0.92] : const [0.55, 0.92],
        builder: (ctx, scrollCtrl) {
          // OLD: solid Material background — replaced with Liquid Glass to match
          // the QuickAddTaskSheet treatment (_LiquidPanel / PopoverBorderPainter
          // tokens). Geometry (top-only rounded corners) is unchanged.
          // return Material(
          //   color: AppColors.surface,
          //   borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          //   child: Column(
          //     children: [
          //       _buildSheetHeader(),
          //       Expanded(child: _buildBody(scrollCtrl)),
          //       _buildFooter(keyboardHeight: _keyboardHeight),
          //     ],
          //   ),
          // );
          return LiquidPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            // Material(transparency) restores the Material ancestor that the
            // OLD solid Material(color: surface) used to provide — required by
            // TextField/InkWell descendants (header title field, notes field,
            // comment field). Fully transparent so it doesn't cover the blur.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  _buildSheetHeader(),
                  Expanded(child: _buildBody(scrollCtrl)),
                  _buildFooter(keyboardHeight: _keyboardHeight),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Desktop dialog ────────────────────────────────────────────────────────────

  // ── Desktop dialog V2: layout 2 colunas ─────────────────────────────────────
  // Esquerda (flex): título + notas  |  Direita (220px): painel de atributos
  Widget _buildDesktopDialogV2(BuildContext context) {
    final hasTitle = _titleCtrl.text.trim().isNotEmpty;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: CallbackShortcuts(
          bindings: {
            // ⌘⏎ / Ctrl+⏎ → salva a tarefa sem tirar o foco do campo de texto
            SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
              if (hasTitle && !_saving) _save();
            },
            SingleActivator(LogicalKeyboardKey.enter, control: true): () {
              if (hasTitle && !_saving) _save();
            },
          },
          child: Focus(
            // OLD: solid Container + heavy BoxShadow — replaced with Liquid Glass
            // (LiquidPanel) for the fill/blur/border, keeping a PopoverStyle-token
            // shadow on the outer sizing Container so it still floats off the page.
            // child: Container(
            //   width: 720,
            //   constraints: const BoxConstraints(maxHeight: 600),
            //   margin: const EdgeInsets.all(24),
            //   decoration: BoxDecoration(
            //     color: AppColors.surface,
            //     borderRadius: BorderRadius.circular(16),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withValues(alpha: 0.40),
            //         blurRadius: 40,
            //         offset: const Offset(0, 16),
            //       ),
            //     ],
            //   ),
            //   child: ClipRRect(
            //     borderRadius: BorderRadius.circular(16),
            //     child: Column( ... ),
            //   ),
            // ),
            child: Container(
              width: 720,
              constraints: const BoxConstraints(maxHeight: 600),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: PopoverStyle.shadows,
              ),
              child: LiquidPanel(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Área principal ──────────────────────────────────
                    Flexible(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Esquerda: título + notas ─────────────────
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _titleCtrl,
                                    focusNode: _titleFocusNode,
                                    cursorColor: AppColors.accent,
                                    cursorWidth: 1.5,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                      letterSpacing: -0.3,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'O que precisa ser feito?',
                                      hintStyle: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textTertiary.withValues(alpha: 0.65),
                                        letterSpacing: -0.3,
                                      ),
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
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _descCtrl,
                                    focusNode: _descFocusNode,
                                    cursorColor: AppColors.accent,
                                    cursorWidth: 1.5,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      height: 1.55,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Adicionar notas...',
                                      hintStyle: TextStyle(
                                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    maxLines: null,
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),
                            ),
                          ),
                          // ── Divisor vertical ─────────────────────────
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: AppColors.surfaceVariant,
                          ),
                          // ── Direita: atributos ────────────────────────
                          SizedBox(
                            width: 220,
                            child: _buildDesktopAttrPanel(context),
                          ),
                        ],
                      ),
                    ),
                    // ── Footer ──────────────────────────────────────────
                    _buildDesktopFooterBarV2(context, hasTitle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Painel de atributos (coluna direita do dialog V2) ─────────────────────
  Widget _buildDesktopAttrPanel(BuildContext context) {
    final dateActive = _dueDate != null;
    final prioActive = _priority != null;
    final labelActive = _labelIds.isNotEmpty;
    final recurActive = _recurrence != null;

    Color? prioColor() => switch (_priority) {
      Priority.high   => AppColors.priorityHigh,
      Priority.medium => AppColors.priorityMedium,
      Priority.low    => AppColors.priorityLow,
      null            => null,
    };

    String prioLabel() => switch (_priority) {
      Priority.high   => 'Alta',
      Priority.medium => 'Média',
      Priority.low    => 'Baixa',
      null            => 'Nenhuma',
    };

    String labelValue() {
      if (!labelActive) return 'Nenhuma';
      if (_labelIds.length == 1) {
        final lbl = _labels.where((l) => _labelIds.contains(l.id)).firstOrNull;
        return lbl?.name ?? '1 etiqueta';
      }
      return '${_labelIds.length} etiquetas';
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _AttrPanelRow(
            key: _projectChipKey,
            icon: Icons.grid_view_rounded,
            label: 'Projeto',
            value: _project?.name ?? 'Sem projeto',
            active: _project != null,
            onTap: () => _showProjectMenu(context),
          ),
          _AttrPanelDivider(),
          _AttrPanelRow(
            key: _dateChipKey,
            icon: Icons.calendar_today_outlined,
            label: 'Data',
            value: dateActive ? _dateLabel : 'Nenhuma',
            active: dateActive,
            onTap: () => _showDateSheet(context),
          ),
          _AttrPanelDivider(),
          _AttrPanelRow(
            key: _priorityChipKey,
            icon: Icons.flag_outlined,
            label: 'Prioridade',
            value: prioLabel(),
            active: prioActive,
            valueColor: prioColor(),
            onTap: () => _showPriorityMenu(context),
          ),
          _AttrPanelDivider(),
          _AttrPanelRow(
            key: _labelsChipKey,
            icon: Icons.label_outline,
            label: 'Etiquetas',
            value: labelValue(),
            active: labelActive,
            onTap: () => _showLabelsMenu(context),
          ),
          _AttrPanelDivider(),
          _AttrPanelRow(
            key: _recurChipKey,
            icon: Icons.repeat,
            label: 'Repetir',
            value: recurActive ? _recurrenceLabel : 'Nunca',
            active: recurActive,
            onTap: () => _showDateSheet(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Footer V2: apenas Cancel + Salvar com hint ⌘⏎ ─────────────────────────
  Widget _buildDesktopFooterBarV2(BuildContext context, bool hasTitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: () {
              if (_popping) return;
              _popping = true;
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Cancelar',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            opacity: hasTitle ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 150),
            child: FilledButton(
              onPressed: hasTitle && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                minimumSize: Size.zero,
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                disabledBackgroundColor: AppColors.accent,
                disabledForegroundColor: AppColors.background,
              ),
              child: _saving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.background),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_isNew ? 'Adicionar tarefa' : 'Salvar'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⌘⏎',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.background
                                  .withValues(alpha: 0.70),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── OLD: _buildDesktopDialog (single column) — comentado para reversão ──────
  /*
  Widget _buildDesktopDialog(BuildContext context) {
    final hasTitle = _titleCtrl.text.trim().isNotEmpty;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 580),
          ... (veja git history)
        ),
      ),
    );
  }
  */

  // ── OLD: chips horizontais do dialog v1 — comentado; agora no painel lateral ──
  // ignore: unused_element
  Widget _buildDesktopAttrChips(BuildContext context) {
    final dateActive = _dueDate != null;
    final prioActive = _priority != null;
    final labelActive = _labelIds.isNotEmpty;
    final recurActive = _recurrence != null;

    Color prioColor() {
      return switch (_priority) {
        Priority.high   => AppColors.priorityHigh,
        Priority.medium => AppColors.priorityMedium,
        Priority.low    => AppColors.priorityLow,
        null            => AppColors.accent,
      };
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AppColors.textTertiary.withValues(alpha: 0.10),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _DesktopChip(
              key: _dateChipKey,
              icon: Icons.calendar_today_outlined,
              label: dateActive ? _dateLabel : 'Data',
              active: dateActive,
              onTap: () => _showDateSheet(context),
            ),
            const SizedBox(width: 8),
            _DesktopChip(
              key: _priorityChipKey,
              icon: Icons.flag_outlined,
              label: prioActive
                  ? switch (_priority!) {
                      Priority.high   => 'Alta',
                      Priority.medium => 'Média',
                      Priority.low    => 'Baixa',
                    }
                  : 'Prioridade',
              active: prioActive,
              color: prioActive ? prioColor() : null,
              onTap: () => _showPriorityMenu(context),
            ),
            const SizedBox(width: 8),
            _DesktopChip(
              key: _labelsChipKey,
              icon: Icons.label_outline,
              label: labelActive
                  ? '${_labelIds.length} etiqueta${_labelIds.length != 1 ? 's' : ''}'
                  : 'Etiquetas',
              active: labelActive,
              onTap: () => _showLabelsMenu(context),
            ),
            const SizedBox(width: 8),
            _DesktopChip(
              key: _recurChipKey,
              icon: Icons.repeat,
              label: recurActive ? _recurrenceLabel : 'Repetir',
              active: recurActive,
              onTap: () => _showDateSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── OLD: footer v1 com project selector — comentado; substituído por FooterBarV2 ──
  // ignore: unused_element
  Widget _buildDesktopFooterBar(BuildContext context, bool hasTitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          // Project selector
          // GESTURE-OLD: GestureDetector sem feedback visual
          Pressable(
            key: _projectChipKey,
            onTap: () => _showProjectMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedGrid, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _project?.name ?? 'Sem projeto',
                    style: TextStyle(
                      fontSize: 13,
                      color: _project != null ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: _project != null ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, size: 14, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Cancel
          TextButton(
            onPressed: () {
              if (_popping) return;
              _popping = true;
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Cancelar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          // Save
          AnimatedOpacity(
            opacity: hasTitle ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 150),
            child: FilledButton(
              onPressed: hasTitle && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                minimumSize: Size.zero,
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                disabledBackgroundColor: AppColors.accent,
                disabledForegroundColor: AppColors.background,
              ),
              child: _saving
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                    )
                  : Text(_isNew ? 'Adicionar tarefa' : 'Salvar'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildSheetHeader() {
    // REMOVIDO_REDESIGN_DETAIL: só era usada pelo botão "Salvar" do header,
    // removido acima — preservada comentada, não deletada.
    // final hasTitle = _titleCtrl.text.trim().isNotEmpty;
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Drag handle — centrado
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: _isLightAccent ? 0.5 : 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // X — fechar (e persistir / atualizar lista pai)
          // CORRIGIDO_REFRESH_FECHAMENTO: antes só fazia pop() sem chamar
          // widget.onSaved, então alterações já autosalvas (etiquetas,
          // prioridade, data, projeto/seção) ficavam com a tela anterior
          // mostrando dado desatualizado até um refresh manual. Agora usa
          // closeAndPersist(), que sempre aciona onSaved ao fechar.
          Positioned(
            left: 8,
            top: 8,
            child: IconButton(
              onPressed: closeAndPersist,
              icon: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18,
                    color: AppColors.textSecondary),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
          // REMOVIDO_REDESIGN_DETAIL: botão "Salvar" do header — as edições
          // já persistem automaticamente via debounce (campos de
          // título/descrição/metadados), não há necessidade de um botão
          // explícito de salvar aqui. Lógica de persistência (_save,
          // debounce) preservada, apenas o botão visual foi removido.
          // Salvar — à direita, menor e discreto
          // Positioned(
          //   right: 12,
          //   top: 10,
          //   child: GestureDetector(
          //     onTap: hasTitle && !_saving ? _save : null,
          //     child: AnimatedContainer(
          //       duration: const Duration(milliseconds: 150),
          //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          //       decoration: BoxDecoration(
          //         color: hasTitle
          //             ? AppColors.accent
          //             : _isLightAccent
          //                 ? AppColors.surfaceVariant
          //                 : AppColors.accent.withValues(alpha: 0.3),
          //         borderRadius: BorderRadius.circular(16),
          //       ),
          //       child: _saving
          //           ? SizedBox(
          //               width: 12, height: 12,
          //               child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
          //             )
          //           : Text(
          //               'Salvar',
          //               style: TextStyle(
          //                 fontSize: 13,
          //                 fontWeight: FontWeight.w700,
          //                 color: AppColors.background,
          //                 letterSpacing: -0.1,
          //               ),
          //             ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }



  // ── Scrollable body ───────────────────────────────────────────────────────────

  Widget _buildBody(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Título ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaskPriorityCircle(priority: _priority),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  focusNode: _titleFocusNode,
                  cursorColor: AppColors.accent,
                  cursorWidth: 1.5,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'O que precisa ser feito?',
                    hintStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary.withValues(alpha: 0.65),
                      letterSpacing: -0.3,
                    ),
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
            ],
          ),
        ),

        // ── Notas ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(52, 4, 20, 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _descFocused
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.textTertiary.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _descCtrl,
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

        // ── Card de metadados ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: _cardDecoration,
            // SUBSTITUIDO_REDESIGN_DETAIL: bloco antigo (5 TaskMetaRow fixos,
            // sempre visíveis com "Sem data"/"Sem prioridade"/etc quando
            // vazios) substituído pelo padrão Todoist: Projeto e Repetição
            // continuam fixos; Data/Prioridade/Etiquetas migram para MetaRow
            // quando preenchidos, ou aparecem como FieldPill em scroll
            // horizontal quando vazios. Gerador de parcelas saiu de
            // _buildSubtasksSection e entrou aqui como FieldPill (Passo 4).
            // child: Column(
            //   mainAxisSize: MainAxisSize.min,
            //   children: [
            //     TaskMetaRow(
            //       key: _projectChipKey,
            //       icon: Icons.grid_view_rounded,
            //       title: 'Projeto',
            //       value: _project?.name ?? 'Sem projeto',
            //       active: _project != null,
            //       onTap: () => _showProjectMenu(context),
            //     ),
            //     _cardDivider,
            //     TaskMetaRow(
            //       icon: Icons.calendar_today_outlined,
            //       title: 'Data',
            //       value: _dueDate != null ? _dateLabel : 'Sem data',
            //       active: _dueDate != null,
            //       onTap: () => _showDateSheet(context),
            //     ),
            //     _cardDivider,
            //     TaskMetaRow(
            //       key: _priorityChipKey,
            //       icon: Icons.flag_outlined,
            //       title: 'Prioridade',
            //       value: _priority == null ? 'Sem prioridade' : null,
            //       valueWidget: _priority != null ? PriorityValueWidget(priority: _priority!) : null,
            //       active: _priority != null,
            //       onTap: () => _showPriorityMenu(context),
            //     ),
            //     _cardDivider,
            //     TaskMetaRow(
            //       key: _labelsChipKey,
            //       icon: Icons.label_outline,
            //       title: 'Etiquetas',
            //       value: _labelIds.isEmpty ? 'Sem etiquetas' : null,
            //       valueWidget: _labelIds.isNotEmpty ? _buildLabelValue() : null,
            //       active: _labelIds.isNotEmpty,
            //       onTap: () => _showLabelsMenu(context),
            //     ),
            //     if (_recurrence != null) ...[
            //       _cardDivider,
            //       TaskMetaRow(
            //         icon: Icons.repeat,
            //         title: 'Repetição',
            //         value: _recurrenceLabel,
            //         active: true,
            //         onTap: () => _showDateSheet(context),
            //       ),
            //     ],
            //   ],
            // ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ADICIONADO_REDESIGN_DETAIL: Projeto — sempre fixo como MetaRow.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MetaRow(
                    key: _projectChipKey,
                    // CORRIGIDO_REDESIGN_ICONE_PROJETO: padronizado com o
                    // ícone já usado para "projeto" em projects_screen.dart
                    // (cards de projeto listados).
                    // icon: Icons.view_sidebar_outlined,
                    icon: Icons.folder_rounded,
                    onTap: () => _showProjectMenu(context),
                    child: Text(
                      // ADICIONADO_SECAO_PROJETO: agora mostra "Projeto › Seção".
                      _projectLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: _project != null
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),

                // ADICIONADO_REDESIGN_DETAIL: Repetição — fixa quando houver
                // recorrência (decisão do usuário: não entra no grupo
                // dinâmico de pílulas, pois não tem um estado "vazio" útil
                // nesse fluxo).
                if (_recurrence != null) ...[
                  const Divider(height: 1, thickness: 1, color: Color.fromRGBO(255, 255, 255, 0.06)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MetaRow(
                      icon: Icons.repeat,
                      onTap: () => _showDateSheet(context),
                      child: Text(
                        _recurrenceLabel,
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ),
                ],

                if (_dueDate != null || _priority != null || _labelIds.isNotEmpty)
                  const Divider(height: 1, thickness: 1, color: Color.fromRGBO(255, 255, 255, 0.06)),

                // ADICIONADO_REDESIGN_DETAIL: MetaRows — só aparecem quando
                // o campo correspondente está preenchido.
                // CORRIGIDO_VISUAL_A: Divider adicionado após cada MetaRow
                // preenchido (Data/Prioridade/Etiquetas), não só entre os
                // blocos fixos e o grupo dinâmico.
                if (_dueDate != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MetaRow(
                      icon: Icons.calendar_today_outlined,
                      onTap: () => _showDateSheet(context),
                      child: Text(
                        _dateLabel,
                        style: TextStyle(fontSize: 13, color: _dueDateColor),
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color.fromRGBO(255, 255, 255, 0.06)),
                ],
                if (_priority != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MetaRow(
                      key: _priorityChipKey,
                      icon: Icons.flag_outlined,
                      onTap: () => _showPriorityMenu(context),
                      child: PriorityValueWidget(priority: _priority!),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color.fromRGBO(255, 255, 255, 0.06)),
                ],
                if (_labelIds.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MetaRow(
                      key: _labelsChipKey,
                      icon: Icons.label_outline,
                      onTap: () => _showLabelsMenu(context),
                      child: _buildLabelValue(),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color.fromRGBO(255, 255, 255, 0.06)),
                ],

                if (_dueDate == null || _priority == null || _labelIds.isEmpty || !_isNew)
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
                                icon: Icons.calendar_today_outlined,
                                label: 'Data',
                                onTap: () => _showDateSheet(context),
                              ),
                            ),
                          if (_priority == null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FieldPill(
                                // CORRIGIDO_PILL_TAP_DETAIL: o MetaRow de
                                // Prioridade usa _priorityChipKey para o menu
                                // ancorado (showAnchoredSelectMenu). Quando o
                                // campo fica vazio o MetaRow desaparece e a
                                // key não chegava a este FieldPill — o menu
                                // ancorado falhava silenciosamente
                                // (anchorKey.currentContext == null) e o
                                // toque parecia não responder.
                                key: _priorityChipKey,
                                icon: Icons.flag_outlined,
                                label: 'Prioridade',
                                onTap: () => _showPriorityMenu(context),
                              ),
                            ),
                          if (_labelIds.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FieldPill(
                                // CORRIGIDO_PILL_TAP_DETAIL: mesma causa do
                                // FieldPill de Prioridade acima, para o
                                // MetaRow de Etiquetas (_labelsChipKey).
                                key: _labelsChipKey,
                                icon: Icons.label_outline,
                                label: 'Etiquetas',
                                onTap: () => _showLabelsMenu(context),
                              ),
                            ),
                          // ADICIONADO_REDESIGN_DETAIL: Parcelas sai de
                          // _buildSubtasksSection e vira pílula aqui.
                          if (!_isNew)
                            FieldPill(
                              icon: Icons.receipt_long,
                              label: 'Parcelas',
                              onTap: () => showInstallmentGeneratorSheet(
                                context,
                                taskId: widget.task!.id,
                                taskTitle: widget.task!.title,
                                onGenerated: _reloadSubtasksFromDb,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Card de subtarefas ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CustomPaint(
            foregroundPainter: const _SubtleCardBorderPainter(radius: 17),
            child: Container(
              decoration: BoxDecoration(
                color: _isLightAccent
                    ? AppColors.surfaceVariant
                    : AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(17)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header com chevron
                  // GESTURE-OLD: GestureDetector sem feedback visual
                  Pressable(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _subtasksExpanded = !_subtasksExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                      child: Row(
                        children: [
                          // CORRIGIDO_REDESIGN_ICONE_SUBTAREFAS
                          // HugeIcon(icon: HugeIcons.strokeRoundedSquare, size: 17, color: AppColors.textSecondary),
                          HugeIcon(icon: HugeIcons.strokeRoundedTaskDone01, size: 17, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Subtarefas',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ),
                          if (_subtasks.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_subtasks.where((s) => s.done).length}/${_subtasks.length}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _subtasksExpanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // CORRIGIDO_SHEET_ALTURA: lista expandível agora dentro de
                  // AnimatedSize — o colapso instantâneo (if simples) mudava
                  // o maxScrollExtent do ListView de _buildBody de uma vez,
                  // e o DraggableScrollableSheet (que reusa esse mesmo
                  // scrollCtrl para acoplar scroll+resize) interpretava a
                  // correção de offset resultante como um drag para baixo,
                  // encolhendo o sheet para o snapSize menor e escondendo o
                  // próprio botão de Subtarefas. Só o conteúdo expansível é
                  // envolvido — não o card inteiro, não o header/botão.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _subtasksExpanded ? [
                        if (_subtasks.isNotEmpty)
                          Divider(height: 1, thickness: 0.5, color: AppColors.textTertiary.withValues(alpha: 0.1)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: _buildSubtasksSection(),
                        ),
                      ] : const [],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // COMMENT-LOAD: lista de comentários existentes, dentro da área
        // rolável (o campo de input em _buildFooter é fixo e fora do scroll;
        // colocar a lista lá causaria overflow com muitos comentários).
        if (_loadingComments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (_comments.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (_, i) {
              final c = _comments[i];
              final texto = c['conteudo'] as String? ?? '';
              final createdAt = c['created_at'] != null
                  ? DateTime.tryParse(c['created_at'] as String)
                  : null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(icon: HugeIcons.strokeRoundedUser,
                          size: 16, color: AppColors.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Text(
                              texto,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _formatCommentDate(createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── Fixed footer ─────────────────────────────────────────────────────────────

  Widget _buildFooter({double keyboardHeight = 0}) {
    if (_isNew) return const SizedBox.shrink();
    final bottomPad = keyboardHeight > 0 ? 8.0 : _viewPaddingBottom + 8.0;
    final borderTop = Border(
        top: BorderSide(
            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
            width: 0.5));
    final hasComment = _commentCtrl.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, border: borderTop),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 12, bottomPad),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: AppColors.textTertiary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              HugeIcon(icon: HugeIcons.strokeRoundedAttachment01,
                  size: 17, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  cursorColor: AppColors.accent,
                  cursorWidth: 1.5,
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Comentário...',
                    hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Send button — activates when there's text
              // GESTURE-OLD: GestureDetector sem feedback visual
              Pressable(
                onTap: hasComment ? _sendComment : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasComment
                        ? AppColors.accent
                        : AppColors.textTertiary.withValues(alpha: 0.2),
                  ),
                  child: HugeIcon(icon: HugeIcons.strokeRoundedArrowUp01,
                    size: 16,
                    color: hasComment
                        ? AppColors.background
                        : AppColors.textTertiary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Priority popover (anchored to chip, Todoist-style) ─────────────────────

  Future<void> _showDateSheet(BuildContext ctx) async {
    if (widget.asDialog) {
      final result = await _showAnchoredPicker<DatePickerResult>(
        anchorKey: _dateChipKey,
        pickerWidth: 360,
        picker: SizedBox(
          width: 360,
          child: TaskDatePickerSheet(
            initialDate: _dueDate,
            initialTime: _dueTime,
            initialRecurrence: _recurrence,
            inDialog: true,
            // BUG-DATE-OLD: dependia só do valor de retorno de
            // Navigator.pop() ao fechar o popover (perdido se o fechamento
            // não passar por _confirm()). onChanged persiste no momento da
            // seleção, antes de qualquer fechamento.
            onChanged: (r) {
              if (!mounted) return;
              setState(() {
                _dueDate = r.date;
                _dueTime = r.time;
                _recurrence = r.recurrence;
              });
              _autosaveDueDate(); // ADICIONADO_AUTOSAVE
            },
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() {
        _dueDate = result.date;
        _dueTime = result.time;
        _recurrence = result.recurrence;
      });
      return;
    }
    // BUG-DATE-OLD: bloco anterior confiava apenas no valor de retorno do
    // showModalBottomSheet (capturado em `result`); se o pop() do sheet
    // ocorresse antes do onChanged ser observado pelo await (timing),
    // `result` podia vir null mesmo com o onChanged já tendo disparado.
    // Mantido comentado abaixo, substituído pela versão com fallback:
    //
    // final result = await showModalBottomSheet<DatePickerResult>(
    //   context: ctx,
    //   isScrollControlled: true,
    //   isDismissible: true,
    //   enableDrag: true,
    //   backgroundColor: Colors.transparent,
    //   builder: (_) => TaskDatePickerSheet(
    //     initialDate: _dueDate,
    //     initialTime: _dueTime,
    //     initialRecurrence: _recurrence,
    //     onChanged: (r) {
    //       if (!mounted) return;
    //       setState(() {
    //         _dueDate = r.date;
    //         _dueTime = r.time;
    //         _recurrence = r.recurrence;
    //       });
    //       _autosaveDueDate(); // ADICIONADO_AUTOSAVE
    //     },
    //   ),
    // );
    // if (result == null || !mounted) return;
    // setState(() {
    //   _dueDate = result.date;
    //   _dueTime = result.time;
    //   _recurrence = result.recurrence;
    // });
    // _autosaveDueDate(); // ADICIONADO_AUTOSAVE

    // BUG-DATE-OLD-V2: bloco anterior usava showModalBottomSheet<DatePickerResult>
    // e dependia de `result` (capturado pelo await) OU do fallback _lastDateResult
    // logo após o await. Risco residual: se o onChanged só atualiza _lastDateResult
    // dentro do builder filho, e esse contexto filho for desmontado por barrier
    // dismiss antes do addPostFrameCallback do _confirm() rodar, o onChanged nunca
    // chega a disparar. Mantido comentado abaixo, substituído pela versão <void>:
    //
    // _lastDateResult = null; // BUG-DATE-FIX: resetar antes de abrir
    // final result = await showModalBottomSheet<DatePickerResult>(
    //   context: ctx,
    //   isScrollControlled: true,
    //   isDismissible: true,
    //   enableDrag: true,
    //   backgroundColor: Colors.transparent,
    //   builder: (_) => TaskDatePickerSheet(
    //     initialDate: _dueDate,
    //     initialTime: _dueTime,
    //     initialRecurrence: _recurrence,
    //     onChanged: (r) {
    //       _lastDateResult = r; // BUG-DATE-FIX: guardar sempre que vier
    //       if (!mounted) return;
    //       setState(() {
    //         _dueDate = r.date;
    //         _dueTime = r.time;
    //         _recurrence = r.recurrence;
    //       });
    //       _autosaveDueDate(); // ADICIONADO_AUTOSAVE
    //     },
    //   ),
    // );
    // // BUG-DATE-FIX: usa result se vier; senão cai no último onChanged
    // // recebido, garantindo que o fechamento por qualquer caminho aplique
    // // a seleção mais recente.
    // final effective = result ?? _lastDateResult;
    // if (effective == null || !mounted) return;
    // setState(() {
    //   _dueDate = effective.date;
    //   _dueTime = effective.time;
    //   _recurrence = effective.recurrence;
    // });
    // _autosaveDueDate(); // BUG-DATE-FIX garantia final

    _lastDateResult = null; // BUG-DATE-OLD-V2
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDatePickerSheet(
        initialDate: _dueDate,
        initialTime: _dueTime,
        initialRecurrence: _recurrence,
        onChanged: (r) {
          // BUG-DATE-OLD-V2: salvar na variável do estado pai, não depender
          // de mounted para persistir — só o setState depende disso.
          _lastDateResult = r;
          if (mounted) {
            setState(() {
              _dueDate = r.date;
              _dueTime = r.time;
              _recurrence = r.recurrence;
            });
          }
        },
      ),
    );

    // BUG-DATE-OLD-V2: após o sheet fechar (qualquer caminho), aplicar o resultado.
    if (!mounted) return;
    final effective = _lastDateResult;
    if (effective != null) {
      setState(() {
        _dueDate = effective.date;
        _dueTime = effective.time;
        _recurrence = effective.recurrence;
      });
      await _autosaveDueDate(); // BUG-DATE-OLD-V2: persistir aqui, após sheet fechado
    }
  }

  // ignore: unused_element
  void _showPriorityMenu_OLD(BuildContext btnCtx) {
    // BOTTOM SHEET ANTIGO — manter comentado, reverter se necessário.
    // Para reverter: renomear de volta para _showPriorityMenu e comentar
    // o método _showPriorityMenu novo abaixo.
    // COLORS-OLD: método morto (_showPriorityMenu_OLD, não chamado em
    // lugar nenhum, mantido só pra revert) — cores não migradas, sem risco.
    if (widget.asDialog) {
      const opts = [
        (value: Priority.high,   label: 'Alta',    color: Color(0xFFDC4C3E), icon: Icons.flag),
        (value: Priority.medium, label: 'Média',   color: Color(0xFFEB8909), icon: Icons.flag),
        (value: Priority.low,    label: 'Baixa',   color: Color(0xFF246FE0), icon: Icons.flag),
      ];
      _showAnchoredPicker<void>(
        anchorKey: _priorityChipKey,
        pickerWidth: 220,
        picker: _DesktopPickerCard(
          title: 'Prioridade',
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...opts.map((o) => _DesktopPickerRow(
                leading: Icon(o.icon, size: 16, color: o.color),
                label: o.label,
                selected: _priority == o.value,
                checkColor: o.color,
                onTap: () {
                  setState(() => _priority = o.value);
                  Navigator.of(context).pop();
                },
              )),
              _DesktopPickerRow(
                leading: HugeIcon(icon: HugeIcons.strokeRoundedFlag01, size: 16, color: AppColors.textTertiary),
                label: 'Sem prioridade',
                selected: _priority == null,
                onTap: () {
                  setState(() => _priority = null);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskPriorityPickerSheet(
        current: _priority,
        onSelected: (p) => setState(() => _priority = p),
      ),
    );
  }

  Future<void> _showPriorityMenu(BuildContext btnCtx) async {
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _priorityChipKey,
      items: [
        // COLORS-OLD: Color(0xFFDC4C3E)/Color(0xFFEB8909)/Color(0xFF246FE0)
        // — mesma paleta de ícone-flag usada em SubtaskPriority, reaproveitada
        AnchoredMenuItem(
          id: 'high',
          label: 'Prioridade 1',
          icon: Icons.flag,
          iconColor: AppColors.subtaskPriorityHigh,
          selected: _priority == Priority.high,
        ),
        AnchoredMenuItem(
          id: 'medium',
          label: 'Prioridade 2',
          icon: Icons.flag,
          iconColor: AppColors.subtaskPriorityMedium,
          selected: _priority == Priority.medium,
        ),
        AnchoredMenuItem(
          id: 'low',
          label: 'Prioridade 3',
          icon: Icons.flag,
          iconColor: AppColors.subtaskPriorityLow,
          selected: _priority == Priority.low,
        ),
        AnchoredMenuItem(
          id: 'none',
          label: 'Sem prioridade',
          icon: Icons.flag_outlined,
          iconColor: AppColors.textTertiary,
          selected: _priority == null,
        ),
      ],
    );
    if (result == null) return;
    setState(() {
      _priority = switch (result) {
        'high'   => Priority.high,
        'medium' => Priority.medium,
        'low'    => Priority.low,
        _        => null,
      };
    });
    _autosavePriority(); // ADICIONADO_AUTOSAVE
  }

  // ignore: unused_element
  void _showLabelsMenu_OLD(BuildContext btnCtx) {
    // BOTTOM SHEET ANTIGO — manter comentado, reverter se necessário.
    if (_labels.isEmpty) return;
    if (widget.asDialog) {
      final tempIds = Set<String>.from(_labelIds);
      _showAnchoredPicker<bool>(
        anchorKey: _labelsChipKey,
        pickerWidth: 280,
        picker: Builder(builder: (dCtx) {
          final searchCtrl = TextEditingController();
          return _DesktopPickerCard(
            title: 'Etiquetas',
            width: 280,
            child: StatefulBuilder(
              builder: (_, setInner) {
                final query = searchCtrl.text.toLowerCase();
                final filtered = _labels.where((l) =>
                    l.name.toLowerCase().contains(query)).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                        cursorColor: AppColors.accent,
                        cursorWidth: 1.5,
                        decoration: InputDecoration(
                          hintText: 'Buscar etiqueta...',
                          hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textTertiary.withValues(alpha: 0.6)),
                          prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 16,
                              color: AppColors.textTertiary),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 34, minHeight: 34),
                          filled: true,
                          fillColor: AppColors.background.withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: AppColors.textTertiary.withValues(alpha: 0.15)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: AppColors.textTertiary.withValues(alpha: 0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                          ),
                          isDense: true,
                        ),
                        onChanged: (_) => setInner(() {}),
                      ),
                    ),
                    Divider(height: 1, thickness: 0.5,
                        color: AppColors.textTertiary.withValues(alpha: 0.12)),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('Nenhuma etiqueta encontrada',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13,
                                color: AppColors.textTertiary)),
                      )
                    else
                      ...filtered.map((l) {
                        final selected = tempIds.contains(l.id);
                        return _DesktopPickerRow(
                          leading: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                                color: l.color, shape: BoxShape.circle),
                          ),
                          label: l.name,
                          selected: selected,
                          checkColor: l.color,
                          onTap: () {
                            setInner(() {
                              if (selected) {
                                tempIds.remove(l.id);
                              } else {
                                tempIds.add(l.id);
                              }
                            });
                          },
                        );
                      }),
                  ],
                );
              },
            ),
            onDone: () => Navigator.of(context).pop(true),
          );
        }),
      ).then((confirmed) {
        if (confirmed == true && mounted) {
          setState(() { _labelIds..clear()..addAll(tempIds); });
        }
      });
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskLabelsPickerSheet(
        labels: _labels.map((l) => LabelOption(l.id, l.name, l.color)).toList(),
        selectedIds: Set.from(_labelIds),
        onChanged: (ids) => setState(() { _labelIds..clear()..addAll(ids); }),
      ),
    );
  }

  Future<void> _showLabelsMenu(BuildContext btnCtx) async {
    if (_labels.isEmpty) return;
    final result = await showAnchoredMultiSelectMenu(
      context: context,
      anchorKey: _labelsChipKey,
      selectedIds: Set.from(_labelIds),
      items: _labels
          .map((l) => AnchoredMultiSelectItem(
                id: l.id,
                label: l.name,
                dotColor: l.color,
              ))
          .toList(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _labelIds
        ..clear()
        ..addAll(result);
    });
    _autosaveLabels(); // ADICIONADO_AUTOSAVE
  }

  // ignore: unused_element
  void _showProjectMenu_OLD(BuildContext btnCtx) {
    // BOTTOM SHEET ANTIGO — manter comentado, reverter se necessário.
    if (widget.asDialog) {
      _showAnchoredPicker<void>(
        anchorKey: _projectChipKey,
        pickerWidth: 280,
        picker: _DesktopPickerCard(
          title: 'Projeto',
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DesktopPickerRow(
                leading: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                  ),
                ),
                label: 'Sem projeto',
                selected: _project == null,
                onTap: () {
                  setState(() => _project = null);
                  Navigator.of(context).pop();
                },
              ),
              ..._projects.map((p) => _DesktopPickerRow(
                leading: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.color ?? AppColors.accent,
                  ),
                ),
                label: p.name,
                selected: _project?.id == p.id,
                checkColor: p.color ?? AppColors.accent,
                onTap: () {
                  setState(() => _project = _Project(p.id, p.name, color: p.color));
                  Navigator.of(context).pop();
                },
              )),
            ],
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskProjectPickerSheet(
        projects: _projects.map((p) => ProjectOption(p.id, p.name)).toList(),
        current: _project != null ? ProjectOption(_project!.id, _project!.name) : null,
        onSelected: (opt) => setState(() => _project = opt != null ? _Project(opt.id, opt.name) : null),
      ),
    );
  }

  Future<void> _showProjectMenu(BuildContext btnCtx) async {
    final items = [
      AnchoredMenuItem(
        id: 'none',
        label: 'Sem projeto',
        icon: Icons.radio_button_unchecked,
        iconColor: AppColors.textTertiary.withValues(alpha: 0.5),
        selected: _project == null,
      ),
      ..._projects.map((p) => AnchoredMenuItem(
            id: p.id,
            label: p.name,
            icon: Icons.circle,
            iconColor: p.color ?? AppColors.accent,
            selected: _project?.id == p.id,
          )),
    ];
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _projectChipKey,
      items: items,
    );
    if (result == null || !mounted) return;

    // ADICIONADO_SECAO_PROJETO: "Sem projeto" também limpa a seção, já que
    // uma seção sempre pertence a um projeto.
    if (result == 'none') {
      setState(() {
        _project = null;
        _availableSections = [];
        _sectionId = null;
        _sectionName = null;
      });
      return;
    }

    final p = _projects.firstWhere((p) => p.id == result,
        orElse: () => _projects.first);
    setState(() {
      _project = _Project(p.id, p.name, color: p.color);
      _availableSections = [];
      _sectionId = null;
      _sectionName = null;
    });

    // ADICIONADO_SECAO_PROJETO: carrega as seções do projeto recém-escolhido
    // e, se houver, abre automaticamente o segundo nível do mesmo popover
    // para escolha de seção — mesmo padrão do quick_add_task_sheet.dart.
    await _loadSectionsForProject(p.id);
    if (!mounted) return;
    if (_availableSections.isNotEmpty) {
      await _showSectionMenu(btnCtx);
    }
  }

  /// ADICIONADO_SECAO_PROJETO: segundo nível do seletor Projeto/Seção,
  /// reutiliza o mesmo _projectChipKey do primeiro nível. O item "‹ Projeto"
  /// funciona como back button, reabrindo a lista de projetos.
  Future<void> _showSectionMenu(BuildContext btnCtx) async {
    final items = [
      AnchoredMenuItem(
        id: '__back__',
        label: '‹ Projeto',
        icon: Icons.arrow_back_ios_new,
        iconColor: AppColors.textTertiary,
      ),
      AnchoredMenuItem(
        id: '__none__',
        label: 'Sem seção',
        selected: _sectionId == null,
      ),
      ..._availableSections.map((s) => AnchoredMenuItem(
            id: s.id,
            label: s.name,
            selected: _sectionId == s.id,
          )),
    ];
    final result = await showAnchoredSelectMenu(
      context: context,
      anchorKey: _projectChipKey,
      items: items,
    );
    if (result == null || !mounted) return;

    if (result == '__back__') {
      await _showProjectMenu(btnCtx);
      return;
    }

    setState(() {
      if (result == '__none__') {
        _sectionId = null;
        _sectionName = null;
      } else {
        try {
          final s = _availableSections.firstWhere((s) => s.id == result);
          _sectionId = s.id;
          _sectionName = s.name;
        } catch (_) {}
      }
    });
  }

  // ── Anchored picker helper (desktop) ─────────────────────────────────────────

  Future<T?> _showAnchoredPicker<T>({
    required GlobalKey anchorKey,
    required Widget picker,
    double pickerWidth = 260,
  }) {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return showDialog<T>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        builder: (_) => Center(child: picker),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final pos  = box.localToGlobal(Offset.zero);
    final size = box.size;

    // Preferred: appear below chip
    double top  = pos.dy + size.height + 6;
    double left = pos.dx;

    // Clamp horizontally
    if (left + pickerWidth > screenSize.width - 8) {
      left = screenSize.width - pickerWidth - 8;
    }
    if (left < 8) left = 8;

    // If below goes off screen, flip above (estimate 340px height)
    if (top + 340 > screenSize.height - 8) {
      top = pos.dy - 340 - 6;
    }
    if (top < 8) top = 8;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black.withValues(alpha: 0.15),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, anim, _) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: pickerWidth,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                alignment: Alignment.topLeft,
                child: FadeTransition(opacity: anim, child: Material(
                  color: Colors.transparent,
                  child: picker,
                )),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubtasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_subtasks.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(top: 4),
            itemCount: _subtasks.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _subtasks.removeAt(oldIndex);
                _subtasks.insert(newIndex, item);
              });
            },
            itemBuilder: (context, i) {
              final s = _subtasks[i];
              return SubtaskEditorRow(
                key: ValueKey(s.uid),
                item: s,
                index: i,
                labels: _labels.map((l) => LabelOption(l.id, l.name, l.color)).toList(),
                onToggle: () => _toggleSubtaskDone(s),
                onRemove: () {
                  s.dispose();
                  setState(() => _subtasks.removeAt(i));
                },
                onChanged: () => setState(() {}),
              );
            },
          ),
        // Botão de adição
        // GESTURE-OLD: GestureDetector sem feedback visual
        Pressable(
          onTap: _addSubtask,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 13, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Text(
                  'Adicionar subtarefa',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.accent.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // REMOVIDO_REDESIGN_DETAIL: gerador de parcelas saiu de
        // _buildSubtasksSection e agora é uma FieldPill junto dos outros
        // campos (Data/Prioridade/Etiquetas), ver bloco de metadados acima.
        // if (!_isNew)
        //   GestureDetector(
        //     onTap: () => showInstallmentGeneratorSheet(
        //       context,
        //       taskId: widget.task!.id,
        //       taskTitle: widget.task!.title,
        //       onGenerated: _reloadSubtasksFromDb,
        //     ),
        //     behavior: HitTestBehavior.opaque,
        //     child: Padding(
        //       padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        //       child: Row(
        //         children: [
        //           Container(
        //             width: 20,
        //             height: 20,
        //             decoration: BoxDecoration(
        //               color: AppColors.accent.withValues(alpha: 0.12),
        //               shape: BoxShape.circle,
        //             ),
        //             child: HugeIcon(icon: HugeIcons.strokeRoundedGrid, size: 12, color: AppColors.accent),
        //           ),
        //           const SizedBox(width: 10),
        //           Text(
        //             'Gerar parcelas',
        //             style: TextStyle(
        //               fontSize: 14,
        //               color: AppColors.accent.withValues(alpha: 0.75),
        //               fontWeight: FontWeight.w500,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
      ],
    );
  }

}

// ── Desktop picker dialogs ────────────────────────────────────────────────────

class _DesktopPickerCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;
  final VoidCallback? onDone;

  const _DesktopPickerCard({
    required this.title,
    required this.child,
    this.width = 260,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    title,
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
                Flexible(child: SingleChildScrollView(child: child)),
                if (onDone != null) ...[
                  Divider(height: 1, thickness: 0.5,
                      color: AppColors.textTertiary.withValues(alpha: 0.12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onDone,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Concluído'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPickerRow extends StatefulWidget {
  final Widget leading;
  final String label;
  final bool selected;
  final Color? checkColor;
  final VoidCallback onTap;

  const _DesktopPickerRow({
    required this.leading,
    required this.label,
    required this.selected,
    this.checkColor,
    required this.onTap,
  });

  @override
  State<_DesktopPickerRow> createState() => _DesktopPickerRowState();
}

class _DesktopPickerRowState extends State<_DesktopPickerRow> {
  bool _hovered = false;

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
          color: _hovered
              ? AppColors.textTertiary.withValues(alpha: 0.08)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: widget.selected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.selected)
                HugeIcon(icon: HugeIcons.strokeRoundedTick01,
                    size: 15,
                    color: widget.checkColor ?? AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Desktop chip button ───────────────────────────────────────────────────────

class _DesktopChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _DesktopChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  State<_DesktopChip> createState() => _DesktopChipState();
}

class _DesktopChipState extends State<_DesktopChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppColors.accent;
    final bgColor = widget.active
        ? activeColor.withValues(alpha: _hovered ? 0.18 : 0.12)
        : _hovered
            ? AppColors.surfaceVariant
            : AppColors.surfaceVariant;
    final fgColor = widget.active ? activeColor : AppColors.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.active
                  ? activeColor.withValues(alpha: 0.30)
                  : AppColors.textTertiary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: fgColor),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  color: fgColor,
                  fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Desktop attribute panel widgets (dialog V2 — coluna direita) ──────────────

class _AttrPanelRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final Color? valueColor;
  final VoidCallback onTap;

  const _AttrPanelRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.active = false,
    this.valueColor,
    required this.onTap,
  });

  @override
  State<_AttrPanelRow> createState() => _AttrPanelRowState();
}

class _AttrPanelRowState extends State<_AttrPanelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.active
        ? (widget.valueColor ?? AppColors.accent)
        : AppColors.textTertiary;
    final valueColor = widget.active
        ? (widget.valueColor ?? AppColors.textPrimary)
        : AppColors.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: _hovered
              ? AppColors.textPrimary.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, size: 15, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            widget.active ? FontWeight.w500 : FontWeight.w400,
                        color: valueColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                size: 13,
                color: AppColors.textTertiary.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttrPanelDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.surfaceVariant.withValues(alpha: 0.7),
    );
  }
}

/// Borda gradiente quase imperceptível para cards internos (ex: card de
/// Subtarefas) — mesma linguagem do PopoverBorderPainter/LiquidPanel
/// (mais forte no topo, mais discreta nas laterais/base), mas com
/// intensidade bem mais sutil já que é um card interno, não o "vidro"
/// externo do sheet.
class _SubtleCardBorderPainter extends CustomPainter {
  final double radius;
  const _SubtleCardBorderPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x14FFFFFF), // topo ~8%
          Color(0x0AFFFFFF), // meio ~4%
          Color(0x08FFFFFF), // base ~3%
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_SubtleCardBorderPainter old) => old.radius != radius;
}

