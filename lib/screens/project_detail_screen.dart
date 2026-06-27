import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/section.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../widgets/task_context_menu.dart';
import 'package:hugeicons/hugeicons.dart';
// CORRIGIDO_ETAPA3B
import '../services/label_repository.dart';
import '../services/section_repository.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../widgets/app_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/swipeable_task_tile.dart';
import '../widgets/task_detail/subtask_item.dart';
import '../widgets/task_detail/sheets/subtask_detail_sheet.dart';
import '../widgets/task_detail/sheets/task_labels_picker_sheet.dart' show LabelOption;
import '../widgets/task_tile.dart';
import 'quick_add_task_sheet.dart';
import 'task_detail_sheet.dart';
import '../widgets/scroll_fade_overlay.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailScreen({super.key, required this.projectId, required this.projectName});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  static const _sectionRepo = SectionRepository();
  // CORRIGIDO_ETAPA3B
  static const _labelRepo = LabelRepository();

  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  List<Section> _sections = [];
  // CORRIGIDO_ETAPA3B: todas as labels do projeto/workspace, usadas para
  // resolver nome/cor das etiquetas de subtarefa (em vez de só task.labels,
  // que não cobre labelIds fora do conjunto da tarefa pai).
  List<TaskLabel> _allLabels = [];
  final Set<String> _collapsedSectionIds = {};
  bool _loading = true;
  bool _showCompleted = true;
  bool _completedExpanded = false;

  // M4: modo de display — 'cards' (padrão atual) ou 'list'
  String _displayMode = 'cards';

  // M5-EXPAND: estado de expansão exclusivo do modo Lista. O modo cards
  // guarda isso dentro do State privado de TaskTile — não há nada a
  // reaproveitar aqui, então este é um conjunto novo e isolado.
  final Set<String> _expandedListIds = {};

  // ANIM-DONE: tarefas em transição de conclusão no modo lista. Modo
  // Balões anima diferente (strikethrough + colapso/remoção da row via
  // _completionCtrl em TaskTile, ver task_tile.dart) — aqui a row continua
  // visível, só dimming/strikethrough animados.
  final Set<String> _completingTaskIds = {};

  String get _prefsKey => 'proj_detail_show_completed_${widget.projectId}';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadTasks();
    _loadDisplayMode();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _showCompleted = prefs.getBool(_prefsKey) ?? true);
  }

  Future<void> _setShowCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    if (mounted) setState(() => _showCompleted = value);
  }

  Future<void> _loadDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _displayMode = prefs.getString('display_mode') ?? 'cards';
      });
    }
  }

  Future<void> _setDisplayMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_mode', mode);
    if (mounted) setState(() => _displayMode = mode);
  }

  Future<void> _loadTasks() async {
    try {
      // OLD select (sem section_id, sem sections) — substituído abaixo para
      // suportar agrupamento por seção. Mantido como referência:
      // final rows = await supabase
      //     .from('tasks')
      //     .select('id, titulo, descricao, prioridade, hora, ordem, concluida, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade), task_labels(labels(id, nome, cor))')
      //     .eq('project_id', widget.projectId)
      //     .order('concluida', ascending: true)
      //     .order('ordem');

      // ADICIONADO_ETAPA3A: subquery de subtasks ganhou data_vencimento e
      // label_ids. Mantém fallback para o caso da migration ainda não ter
      // sido aplicada no Supabase (mesmo padrão usado em subtask_repository.dart).
      // final rowsFuture = supabase
      //     .from('tasks')
      //     .select('id, titulo, descricao, prioridade, hora, ordem, concluida, section_id, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade), task_labels(labels(id, nome, cor))')
      //     .eq('project_id', widget.projectId)
      //     .order('concluida', ascending: true)
      //     .order('ordem');
      // M1-DATE-OLD: 'data_vencimento' só era pedido dentro da subquery
      // subtasks(...), nunca no nível da própria tarefa — por isso
      // row['data_vencimento'] chegava sempre null em Task.fromJson aqui,
      // mesmo com o valor correto já gravado no banco pelo autosave.
      // const tasksSelectWithSubtaskExtras = 'id, titulo, descricao, prioridade, hora, ordem, concluida, section_id, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade, data_vencimento, label_ids), task_labels(labels(id, nome, cor))';
      // const tasksSelectFallback = 'id, titulo, descricao, prioridade, hora, ordem, concluida, section_id, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade), task_labels(labels(id, nome, cor))';
      // M2-OLD: 'task_comments' não estava no SELECT, então commentCount
      // sempre caía no default 0 no construtor manual de Task abaixo.
      // const tasksSelectWithSubtaskExtras = 'id, titulo, descricao, prioridade, hora, ordem, concluida, data_vencimento, section_id, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade, data_vencimento, label_ids), task_labels(labels(id, nome, cor))';
      // const tasksSelectFallback = 'id, titulo, descricao, prioridade, hora, ordem, concluida, data_vencimento, section_id, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade), task_labels(labels(id, nome, cor))';
      const tasksSelectWithSubtaskExtras = 'id, titulo, descricao, prioridade, hora, ordem, concluida, data_vencimento, section_id, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade, data_vencimento, label_ids), task_labels(labels(id, nome, cor)), task_comments(count)';
      const tasksSelectFallback = 'id, titulo, descricao, prioridade, hora, ordem, concluida, data_vencimento, section_id, projects(nome), subtasks(titulo, descricao, concluida, ordem, prioridade), task_labels(labels(id, nome, cor)), task_comments(count)';
      List<Map<String, dynamic>> rows;
      try {
        rows = await supabase
            .from('tasks')
            .select(tasksSelectWithSubtaskExtras)
            .eq('project_id', widget.projectId)
            .order('concluida', ascending: true)
            .order('ordem')
            // ADICIONADO_ORDEM_ESTAVEL: tarefas com 'ordem' repetido/nulo
            // (comum, já que não é uma coluna garantida única) eram
            // reordenadas de forma não-determinística entre recargas —
            // ficava parecendo que as tarefas "trocavam de lugar" sozinhas
            // a cada refresh. 'id' como critério final garante ordem estável.
            .order('id');
      } catch (e) {
        final msg = e.toString();
        final isMissingColumn = msg.contains('data_vencimento') || msg.contains('label_ids');
        if (!isMissingColumn) rethrow;
        rows = await supabase
            .from('tasks')
            .select(tasksSelectFallback)
            .eq('project_id', widget.projectId)
            .order('concluida', ascending: true)
            .order('ordem')
            // ADICIONADO_ORDEM_ESTAVEL: tarefas com 'ordem' repetido/nulo
            // (comum, já que não é uma coluna garantida única) eram
            // reordenadas de forma não-determinística entre recargas —
            // ficava parecendo que as tarefas "trocavam de lugar" sozinhas
            // a cada refresh. 'id' como critério final garante ordem estável.
            .order('id');
      }
      final sections = await _sectionRepo.getSectionsForProject(widget.projectId);
      // CORRIGIDO_ETAPA3B: carrega todas as labels do workspace (mesmo
      // padrão de _sectionRepo.getSectionsForProject), para resolver
      // corretamente as etiquetas de subtarefa no TaskTile.
      final allLabels = await _labelRepo.fetchLabels();

      final tasks = rows.map((r) {
        final sub = ((r['subtasks'] as List?) ?? [])
          ..sort((a, b) => (a['ordem'] as int? ?? 0).compareTo(b['ordem'] as int? ?? 0));
        final labels = ((r['task_labels'] as List?) ?? [])
            .map((tl) {
              final l = tl['labels'] as Map?;
              if (l == null) return null;
              final nome = l['nome'] as String? ?? '';
              if (nome.isEmpty) return null;
              return TaskLabel(
                id: l['id']?.toString() ?? '',
                name: nome,
                color: AppColors.parseHex(l['cor'] as String?),
              );
            })
            .whereType<TaskLabel>()
            .toList();
        return Task(
          id: r['id'].toString(),
          title: r['titulo'] as String,
          project: (r['projects'] as Map?)?['nome'] as String? ?? widget.projectName,
          sectionId: r['section_id']?.toString(),
          // BUG5-OLD: '_ => Priority.low' transformava null ("Sem prioridade")
          // em Priority.low ao reler do banco, mascarando a gravação correta.
          // priority: switch (r['prioridade'] as String?) {
          //   'high' => Priority.high,
          //   'medium' => Priority.medium,
          //   _ => Priority.low,
          // },
          priority: switch (r['prioridade'] as String?) {
            'high' => Priority.high,
            'medium' => Priority.medium,
            'low' => Priority.low,
            _ => null,
          },
          time: r['hora'] as String?,
          description: r['descricao'] as String?,
          done: r['concluida'] as bool? ?? false,
          // M2-DATE-OLD: construtor manual de Task aqui nunca definia
          // dueDate para a tarefa em si (só para subtasks, abaixo) — mesmo
          // com 'data_vencimento' já presente no SELECT, o valor nunca era
          // lido para o campo Task.dueDate, deixando a data sempre null
          // nesta tela mesmo com o dado correto vindo do banco.
          dueDate: r['data_vencimento'] != null
              ? DateTime.tryParse(r['data_vencimento'] as String)
              : null,
          // M2-OLD: commentCount nunca era lido aqui, sempre default 0.
          commentCount: (() {
            final raw = r['task_comments'];
            if (raw == null) return 0;
            if (raw is List && raw.isNotEmpty) {
              final first = raw.first;
              if (first is Map) return (first['count'] as int?) ?? 0;
            }
            return 0;
          })(),
          labels: labels,
          subtasks: sub.map((s) => Subtask(
            title: s['titulo'] as String,
            description: s['descricao'] as String?,
            done: s['concluida'] as bool? ?? false,
            priority: switch (s['prioridade'] as String?) {
              'high' => SubtaskPriority.high,
              'medium' => SubtaskPriority.medium,
              'low' => SubtaskPriority.low,
              _ => null,
            },
            // ADICIONADO_ETAPA3A
            dueDate: s['data_vencimento'] != null ? DateTime.tryParse(s['data_vencimento'] as String) : null,
            // ADICIONADO_ETAPA3A
            labelIds: ((s['label_ids'] as List?) ?? const []).map((e) => e.toString()).toList(),
          )).toList(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _completedTasks = tasks.where((t) => t.done).toList();
          _tasks = tasks.where((t) => !t.done).toList();
          _sections = sections;
          // CORRIGIDO_ETAPA3B
          _allLabels = allLabels;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleDone(int i) {
    final task = _tasks[i];
    if (task.done) return;
    final updated = task.copyWith(done: true);
    setState(() => _tasks[i] = updated);
    supabase.from('tasks').update({'concluida': true}).eq('id', task.id).catchError((_) {
      if (mounted) setState(() => _tasks[i] = task);
    });
  }

  Future<void> _deleteTask(int i) async {
    if (!mounted) return;
    final task = _tasks[i];
    setState(() => _tasks.removeAt(i));

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
          if (mounted) setState(() => _tasks.insert(i.clamp(0, _tasks.length), task));
        },
      ),
    ));

    await ctrl.closed;
    if (!undone) {
      try {
        await supabase.from('tasks').delete().eq('id', task.id);
      } catch (e) {
        if (mounted) {
          setState(() => _tasks.insert(i.clamp(0, _tasks.length), task));
          messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  void _toggleUndone(int i) {
    final task = _completedTasks[i];
    final updated = task.copyWith(done: false);
    setState(() {
      _completedTasks.removeAt(i);
      _tasks.add(updated);
    });
    supabase.from('tasks').update({'concluida': false}).eq('id', task.id).catchError((_) {
      if (mounted) {
        setState(() {
          _tasks.removeWhere((t) => t.id == task.id);
          _completedTasks.insert(i.clamp(0, _completedTasks.length), task);
        });
      }
    });
  }

  Future<void> _deleteCompletedTask(int i) async {
    final task = _completedTasks[i];
    setState(() => _completedTasks.removeAt(i));
    try {
      await supabase.from('tasks').delete().eq('id', task.id);
    } catch (_) {
      if (mounted) setState(() => _completedTasks.insert(i.clamp(0, _completedTasks.length), task));
    }
  }

  void _showOptionsMenu(BuildContext ctx) {
    // SUBSTITUIDO_ETAPA2: RelativeRect recalculado com base no overlay para
    // ancorar o menu logo abaixo da pílula, em vez de deslocado para baixo.
    // final renderBox = ctx.findRenderObject() as RenderBox;
    // final offset = renderBox.localToGlobal(Offset.zero);
    // final size = renderBox.size;
    // SUBSTITUIDO_ETAPA2 (correção 2): RelativeRect.fromRect trocado por
    // fromLTRB com offset vertical, forçando abertura abaixo da pílula.
    // final RenderBox button = ctx.findRenderObject() as RenderBox;
    // final RenderBox overlay = Navigator.of(ctx).overlay!.context.findRenderObject() as RenderBox;
    // final RelativeRect position = RelativeRect.fromRect(
    //   Rect.fromPoints(
    //     button.localToGlobal(Offset.zero, ancestor: overlay),
    //     button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    //   ),
    //   Offset.zero & overlay.size,
    // );
    final RenderBox button = ctx.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(ctx).overlay!.context.findRenderObject() as RenderBox;
    final Offset buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset buttonBottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonTopLeft.dx,
      buttonBottomRight.dy + 4,
      overlay.size.width - buttonBottomRight.dx,
      overlay.size.height - buttonBottomRight.dy - 4,
    );
    showMenu<String>(
      context: ctx,
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: position,
      // position: RelativeRect.fromLTRB(
      //   offset.dx + size.width - 180,
      //   offset.dy + size.height + 4,
      //   16,
      //   0,
      // ),
      items: [
        // M4: seção Display (Balões/Lista) adicionada no topo do menu.
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _setDisplayMode('cards');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _displayMode == 'cards'
                            ? AppColors.accent.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedGrid, size: 18,
                              color: _displayMode == 'cards'
                                  ? AppColors.accent
                                  : Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(height: 3),
                          Text('Balões', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: _displayMode == 'cards'
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.4),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 36,
                    color: Colors.white.withValues(alpha: 0.08)),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _setDisplayMode('list');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _displayMode == 'list'
                            ? AppColors.accent.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedListView, size: 18,
                              color: _displayMode == 'list'
                                  ? AppColors.accent
                                  : Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(height: 3),
                          Text('Lista', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: _displayMode == 'list'
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.4),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: 'toggle_completed',
          child: Row(
            children: [
              Icon(
                _showCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 17,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                _showCompleted ? 'Ocultar concluídas' : 'Mostrar concluídas',
                style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        // SUBSTITUIDO_ETAPA2: nova opção "Nova Seção" adicionada ao menu.
        PopupMenuItem<String>(
          value: 'add_section',
          child: Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 10),
              const Text('Nova Seção'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'toggle_completed') _setShowCompleted(!_showCompleted);
      // SUBSTITUIDO_ETAPA2: trata a nova opção do menu.
      if (value == 'add_section') _createSection();
    });
  }

  // ── Sections — CRUD ──────────────────────────────────────────────────────────

  Future<void> _createSection() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Nova seção', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: 'Nome da seção', hintStyle: TextStyle(color: AppColors.textTertiary)),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Criar', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final section = await _sectionRepo.createSection(widget.projectId, name);
      if (mounted) setState(() => _sections = [..._sections, section]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao criar seção: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.priorityHigh,
        ));
      }
    }
  }

  Future<void> _renameSection(Section section) async {
    final ctrl = TextEditingController(text: section.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Renomear seção', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Salvar', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == section.name || !mounted) return;
    final old = section;
    setState(() {
      _sections = _sections.map((s) => s.id == section.id ? s.copyWith(name: name) : s).toList();
    });
    try {
      await _sectionRepo.updateSection(section.id, name: name);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sections = _sections.map((s) => s.id == old.id ? old : s).toList();
        });
      }
    }
  }

  Future<void> _confirmDeleteSection(Section section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Excluir seção?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'As tarefas de "${section.name}" não serão excluídas, apenas ficarão sem seção.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Excluir', style: TextStyle(color: AppColors.priorityHigh, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removed = section;
    setState(() {
      _sections = _sections.where((s) => s.id != section.id).toList();
      _tasks = _tasks.map((t) => t.sectionId == section.id ? t.copyWith(sectionId: null) : t).toList();
    });
    try {
      await _sectionRepo.deleteSection(section.id);
    } catch (_) {
      if (mounted) setState(() => _sections = [..._sections, removed]);
    }
  }

  void _showSectionMenu(BuildContext ctx, Section section) {
    final renderBox = ctx.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    showMenu<String>(
      context: ctx,
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        offset.dx + size.width,
        offset.dy + size.height,
        16,
        0,
      ),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Renomear')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Excluir', style: TextStyle(color: AppColors.priorityHigh)),
        ),
      ],
    ).then((value) {
      if (value == 'rename') _renameSection(section);
      if (value == 'delete') _confirmDeleteSection(section);
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  // M5: cores/labels de data reaproveitadas da mesma lógica usada em
  // TaskTile._buildSubtaskChips (verde=hoje, vermelho=atrasado, amarelo=futuro).
  static const _ptMonths = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  // M5: linha de tarefa para o modo Lista — aditivo, não usado no modo Balões.
  Widget _buildTaskListRow(Task task) {
    final done = task.done;
    final subtaskDone = task.subtasks.where((s) => s.done).length;
    final subtaskTotal = task.subtasks.length;

    Widget? dateChip;
    if (task.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      final diff = due.difference(today).inDays;
      final Color color;
      final String label;
      if (diff == 0) {
        color = const Color(0xFF7ECC49);
        label = 'Hoje';
      } else if (diff < 0) {
        color = const Color(0xFFDC4C3E);
        label = '${due.day} ${_ptMonths[due.month - 1]}';
      } else {
        color = const Color(0xFFF0A830);
        label = '${due.day} ${_ptMonths[due.month - 1]}';
      }
      dateChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      );
    }

    final expanded = _expandedListIds.contains(task.id);

    // PERF-REPAINT-OLD: row inteira (cabeçalho + subtarefas expandidas)
    // sem RepaintBoundary — qualquer repaint local podia se propagar.
    // return Column(
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: [
    //     _buildTaskListRowContent(task, done, subtaskDone, subtaskTotal, dateChip, expanded),
    //     if (expanded)
    //       for (var si = 0; si < task.subtasks.length; si++)
    //         _buildTaskListSubtaskRow(task.subtasks[si]),
    //   ],
    // );
    return RepaintBoundary(
      key: ValueKey('rb_list_${task.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaskListRowContent(task, done, subtaskDone, subtaskTotal, dateChip, expanded),
          if (expanded)
            for (var si = 0; si < task.subtasks.length; si++)
              _buildTaskListSubtaskRow(task, task.subtasks[si]),
        ],
      ),
    );
  }

  // M5-EXPAND
  // LONGPRESS-OLD: row sem onLongPress — sem menu de contexto no modo
  // lista. Mesmo showTaskContextMenu(context, {task, tapPosition, onEdit,
  // onComplete, onDelete, onRefresh}) usado por SwipeableTaskTile (modo
  // Balões, swipeable_task_tile.dart:100-108), via GestureDetector
  // wrapper (onLongPressStart + onSecondaryTapDown) — mesmo padrão, não
  // duplicado.
  Future<void> _openTaskListContextMenu(BuildContext context, Task task, Offset tapPosition) async {
    final i = _tasks.indexOf(task);
    await showTaskContextMenu(
      context,
      task: task,
      tapPosition: tapPosition,
      onEdit: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
      onComplete: i == -1 ? null : () => _toggleDone(i),
      onDelete: i == -1 ? null : () => _deleteTask(i),
      onRefresh: _loadTasks,
    );
  }

  Widget _buildTaskListRowContent(Task task, bool done, int subtaskDone, int subtaskTotal, Widget? dateChip, bool expanded) {
    // LONGPRESS-OLD: return Container(...) direto, sem GestureDetector.
    return GestureDetector(
      onLongPressStart: (d) => _openTaskListContextMenu(context, task, d.globalPosition),
      onSecondaryTapDown: (d) => _openTaskListContextMenu(context, task, d.globalPosition),
      child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
        ),
      ),
      child: InkWell(
        // RIPPLE-OLD: sem splashColor/highlightColor/splashFactory —
        // onLongPressStart do GestureDetector wrapper disparava o ripple
        // cinza padrão do InkWell.
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        // HAPTIC-OLD: onTap: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
        onTap: () {
          HapticService().selectionClick();
          showTaskDetailSheet(context, task, onSaved: _loadTasks);
        },
        // ANIM-DONE: opacity anima junto da conclusão (transform/opacity
        // apenas, sem animar height/top).
        child: AnimatedOpacity(
          opacity: done ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                // HAPTIC-OLD: onTap: () => done ? _toggleUndone(_tasks.indexOf(task)) : _toggleDone(_tasks.indexOf(task)),
                // ANIM-DONE-OLD: sem entrada em _completingTaskIds.
                onTap: () async {
                  HapticService().taskCompleted();
                  setState(() => _completingTaskIds.add(task.id));
                  if (done) {
                    _toggleUndone(_tasks.indexOf(task));
                  } else {
                    _toggleDone(_tasks.indexOf(task));
                  }
                  await Future.delayed(const Duration(milliseconds: 600));
                  if (mounted) setState(() => _completingTaskIds.remove(task.id));
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  // PriorityDot já é um AnimatedContainer interno (150ms,
                  // ver task_tile.dart) — preserva a cor por prioridade, não
                  // substituído pela decoration fixa verde do pedido (perderia
                  // a cor de prioridade quando não concluída).
                  child: PriorityDot(priority: task.priority, done: done),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ANIM-DONE-OLD: Text estático, sem transição de estilo.
                    // Text(
                    //   task.title,
                    //   maxLines: 1,
                    //   overflow: TextOverflow.ellipsis,
                    //   style: TextStyle(
                    //     fontSize: 15,
                    //     fontWeight: FontWeight.w500,
                    //     color: done ? Colors.white.withValues(alpha: 0.35) : AppColors.textPrimary,
                    //     decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                    //   ),
                    // ),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: done ? Colors.white.withValues(alpha: 0.35) : AppColors.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: Colors.white.withValues(alpha: 0.3),
                      ),
                      child: Text(
                        // Sem style: aqui — herda do AnimatedDefaultTextStyle
                        // acima (Text.style, se definido, sobrescreveria o
                        // ambient e quebraria a transição).
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.38)),
                        ),
                      ),
                    // BUG2-OLD: modo Lista nunca renderizava task.labels (já
                    // populado pelo construtor manual em _loadTasks).
                    if (task.labels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: task.labels
                              .take(3)
                              .map((l) => TagChip(label: l.name, color: l.color))
                              .toList(),
                        ),
                      ),
                    if (subtaskTotal > 0 || dateChip != null || task.commentCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (subtaskTotal > 0) ...[
                              HugeIcon(icon: HugeIcons.strokeRoundedTaskDone01, size: 12, color: Colors.white.withValues(alpha: 0.35)),
                              const SizedBox(width: 3),
                              Text('$subtaskDone/$subtaskTotal', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35))),
                              const SizedBox(width: 8),
                            ],
                            if (dateChip != null) ...[
                              dateChip,
                              const SizedBox(width: 8),
                            ],
                            if (task.commentCount > 0) ...[
                              HugeIcon(icon: HugeIcons.strokeRoundedComment01, size: 12, color: Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(width: 3),
                              Text('${task.commentCount}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // M5-EXPAND-OLD: chevron antigo, sem onTap nem estado.
              // if (task.hasSubtasks)
              //   Padding(
              //     padding: const EdgeInsets.only(left: 8, top: 2),
              //     child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: Colors.white.withValues(alpha: 0.3)),
              //   ),
              // EXPAND-BTN-OLD: padding (left:8, top:2) só — área de toque
              // bem menor que 44x44 (HIG mínimo).
              // if (task.hasSubtasks)
              //   GestureDetector(
              //     behavior: HitTestBehavior.opaque,
              //     onTap: () {
              //       setState(() {
              //         if (_expandedListIds.contains(task.id)) {
              //           _expandedListIds.remove(task.id);
              //         } else {
              //           _expandedListIds.add(task.id);
              //         }
              //       });
              //     },
              //     child: Padding(
              //       padding: const EdgeInsets.only(left: 8, top: 2),
              //       child: Icon(
              //         expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              //         size: 20,
              //         color: Colors.white.withValues(alpha: 0.3),
              //       ),
              //     ),
              //   ),
              // EXPAND-GESTURE-OLD: HitTestBehavior.opaque — investigado,
              // não causava conflito real com subtarefas (subtask rows são
              // irmãs fora dessa árvore), mas removido por pedido explícito.
              if (task.hasSubtasks)
                GestureDetector(
                  // behavior: HitTestBehavior.opaque,
                  // HAPTIC-OLD: onTap sem HapticService().selectionClick().
                  onTap: () {
                    HapticService().selectionClick();
                    setState(() {
                      if (_expandedListIds.contains(task.id)) {
                        _expandedListIds.remove(task.id);
                      } else {
                        _expandedListIds.add(task.id);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
      ),
    );
  }

  // SUBTASK-TAP-FIX: replicado pela 3ª vez nesta sessão (revertido
  // externamente nas 2 anteriores). Mesmo padrão otimista de
  // _toggleDone/_toggleUndone; _openSubtaskDetail reaproveita a função
  // pública showSubtaskDetailSheet (cards mode), não duplica UI.
  void _toggleSubtaskDone(Task task, Subtask sub) {
    final taskIndex = _tasks.indexOf(task);
    if (taskIndex == -1) return;
    final subIndex = task.subtasks.indexOf(sub);
    if (subIndex == -1) return;
    final newDone = !sub.done;
    final updatedSub = sub.copyWith(done: newDone);
    final updatedSubtasks = List<Subtask>.from(task.subtasks);
    updatedSubtasks[subIndex] = updatedSub;
    final updatedTask = task.copyWith(subtasks: updatedSubtasks);
    setState(() => _tasks[taskIndex] = updatedTask);
    HapticService().selectionClick();
    if (sub.id != null) {
      supabase.from('subtasks').update({'concluida': newDone}).eq('id', sub.id!).catchError((_) {
        if (mounted) setState(() => _tasks[taskIndex] = task);
      });
    } else {
      supabase
          .from('subtasks')
          .update({'concluida': newDone})
          .eq('task_id', task.id)
          .eq('ordem', sub.order)
          .catchError((_) {
        if (mounted) setState(() => _tasks[taskIndex] = task);
      });
    }
  }

  void _openSubtaskDetail(Task task, Subtask sub) {
    HapticService().lightImpact();
    final item = SubtaskItem(
      id: sub.id,
      title: sub.title,
      description: sub.description,
      done: sub.done,
      priority: sub.priority,
      labelIds: sub.labelIds.toSet(),
      dueDate: sub.dueDate,
      valor: sub.valor,
    );
    showSubtaskDetailSheet(
      context: context,
      item: item,
      labels: _allLabels.map((l) => LabelOption(l.id, l.name, l.color)).toList(),
      parentTaskTitle: task.title,
      onChanged: _loadTasks,
    );
  }

  // M5-EXPAND: linha de subtarefa indentada, exibida quando o id da
  // tarefa pai está em _expandedListIds.
  // SUBTASK-TAP-OLD: sem InkWell/GestureDetector — toque não fazia nada.
  static const _listSubtaskPtMonths = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  Widget _listSubtaskMetaChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  List<Widget> _listSubtaskChips(Subtask sub) {
    final chips = <Widget>[];

    if (sub.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(sub.dueDate!.year, sub.dueDate!.month, sub.dueDate!.day);
      final diff = due.difference(today).inDays;
      final Color dotColor;
      final String label;
      if (diff == 0) {
        dotColor = const Color(0xFF7ECC49);
        label = 'Hoje';
      } else if (diff < 0) {
        dotColor = const Color(0xFFDC4C3E);
        label = '${due.day} ${_listSubtaskPtMonths[due.month - 1]}';
      } else {
        dotColor = const Color(0xFFF0A830);
        label = '${due.day} ${_listSubtaskPtMonths[due.month - 1]}';
      }
      chips.add(_listSubtaskMetaChip(dotColor, label));
    }

    if (sub.labelIds.isNotEmpty) {
      for (final id in sub.labelIds) {
        final option = _allLabels.where((l) => l.id == id).firstOrNull;
        if (option != null) {
          chips.add(_listSubtaskMetaChip(option.color, option.name));
        } else {
          chips.add(_listSubtaskMetaChip(AppColors.textTertiary, id));
        }
      }
    }

    return chips;
  }

  Widget _buildTaskListSubtaskRow(Task task, Subtask sub) {
    final priColor = switch (sub.priority) {
      SubtaskPriority.high => const Color(0xFFDC4C3E),
      SubtaskPriority.medium => const Color(0xFFEB8909),
      SubtaskPriority.low => const Color(0xFF246FE0),
      null => AppColors.textTertiary,
    };
    final chips = _listSubtaskChips(sub);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openSubtaskDetail(task, sub),
      child: Container(
        padding: const EdgeInsets.fromLTRB(36, 8, 18, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.015),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.03), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleSubtaskDone(task, sub),
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 1, right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sub.done ? const Color(0xFF22C55E) : priColor.withValues(alpha: 0.08),
                  border: Border.all(
                    color: sub.done ? const Color(0xFF22C55E) : priColor,
                    width: 2,
                  ),
                ),
                child: sub.done
                    ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 10, color: Colors.white)
                    : null,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      decoration: sub.done ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  if (chips.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(spacing: 5, runSpacing: 4, children: chips),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRow(int i) {
    if (_displayMode == 'list') {
      return _buildTaskListRow(_tasks[i]);
    }
    return RepaintBoundary(
      key: ValueKey('rb_${_tasks[i].id}'),
      child: SwipeableTaskTile(
        key: ValueKey(_tasks[i].id),
        task: _tasks[i],
        onCompleted: () => _toggleDone(i),
        onDeleteRequested: () => _deleteTask(i),
        onEdit: () => showTaskDetailSheet(context, _tasks[i], onSaved: _loadTasks),
        onRefresh: _loadTasks,
        child: TaskTile(
          task: _tasks[i],
          showProject: false,
          // CORRIGIDO_ETAPA3B
          allLabels: _allLabels,
          onSubtaskToggled: (_) {},
          onCompleted: () => _toggleDone(i),
          onTap: () => showTaskDetailSheet(context, _tasks[i], onSaved: _loadTasks),
          onDismissed: () {
            if (!mounted) return;
            final t = _tasks[i];
            setState(() {
              _tasks.removeWhere((x) => x.id == t.id);
              if (!_completedTasks.any((x) => x.id == t.id)) {
                _completedTasks = [t.copyWith(done: true), ..._completedTasks];
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildAddTaskRow(String? sectionId) {
    // REMOVIDO_ETAPA1: botão visual "+ Adicionar tarefa" ocultado (limpeza
    // visual do ProjectDetailScreen). Lógica preservada — chamável via
    // _openAddTask(sectionId) caso precise ser reexposta no futuro.
    return const SizedBox.shrink();
    // return InkWell(
    //   onTap: () => showQuickAddTaskSheet(
    //     context,
    //     onSaved: _loadTasks,
    //     initialProjectId: widget.projectId,
    //     initialSectionId: sectionId,
    //   ),
    //   child: Opacity(
    //     opacity: 0.5,
    //     child: Padding(
    //       padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    //       child: Row(
    //         children: [
    //           HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 16, color: AppColors.textSecondary),
    //           const SizedBox(width: 8),
    //           Text('Adicionar tarefa', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }

  // REMOVIDO_ETAPA1: mantém a lógica de adicionar tarefa por seção acessível
  // por código mesmo com o botão visual oculto.
  void _openAddTask(String? sectionId) => showQuickAddTaskSheet(
        context,
        onSaved: _loadTasks,
        initialProjectId: widget.projectId,
        initialSectionId: sectionId,
      );

  Widget _buildSeparator() => Divider(
        // REMOVIDO_ETAPA1: linha visual do separador removida (thickness 0 /
        // transparent) — height mantida em 1 para preservar o espaçamento
        // vertical existente entre os cards.
        height: 1,
        thickness: 0,
        color: Colors.transparent,
        indent: 16,
        endIndent: 16,
        // OLD:
        // thickness: 1,
        // color: Colors.white.withValues(alpha: 0.10),
      );

  List<Widget> _buildSectionedRows() {
    final rows = <Widget>[];

    final grouped = <String?, List<int>>{};
    for (var i = 0; i < _tasks.length; i++) {
      grouped.putIfAbsent(_tasks[i].sectionId, () => []).add(i);
    }

    // Tasks without section — no header, sits at the top.
    final nullIndices = grouped[null] ?? [];
    for (var n = 0; n < nullIndices.length; n++) {
      rows.add(_buildTaskRow(nullIndices[n]));
      if (n < nullIndices.length - 1) rows.add(_buildSeparator());
    }

    final sorted = [..._sections]..sort((a, b) => a.order.compareTo(b.order));
    for (final section in sorted) {
      final expanded = !_collapsedSectionIds.contains(section.id);
      final indices = grouped[section.id] ?? [];
      rows.add(_SectionHeader(
        name: section.name,
        count: indices.length,
        expanded: expanded,
        onTap: () => setState(() {
          if (expanded) {
            _collapsedSectionIds.add(section.id);
          } else {
            _collapsedSectionIds.remove(section.id);
          }
        }),
        onMenu: (ctx) => _showSectionMenu(ctx, section),
      ));
      rows.add(AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: !expanded
            ? const SizedBox(width: double.infinity)
            : Column(
                children: [
                  for (var n = 0; n < indices.length; n++) ...[
                    _buildTaskRow(indices[n]),
                    _buildSeparator(),
                  ],
                  _buildAddTaskRow(section.id),
                ],
              ),
      ));
    }

    // REMOVIDO_ETAPA1: botão visual "+ Nova Seção" ocultado (limpeza visual
    // do ProjectDetailScreen). Lógica de criação preservada em _createSection,
    // ainda chamável por código (ex: a partir do menu de opções da tela).
    // rows.add(InkWell(
    //   onTap: _createSection,
    //   child: Opacity(
    //     opacity: 0.5,
    //     child: Padding(
    //       padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    //       child: Row(
    //         children: [
    //           HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 16, color: AppColors.textSecondary),
    //           const SizedBox(width: 8),
    //           Text('Nova Seção', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
    //         ],
    //       ),
    //     ),
    //   ),
    // ));

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 90;
    final isEmpty = _tasks.isEmpty && _completedTasks.isEmpty && _sections.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          widget.projectName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // SUBSTITUIDO_ETAPA2: IconButton simples trocado por pílula
          // Liquid Glass (ClipRRect + BackdropFilter), mesmo _showOptionsMenu.
          // Builder(
          //   builder: (ctx) => IconButton(
          //     icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal, color: AppColors.textSecondary),
          //     onPressed: () => _showOptionsMenu(ctx),
          //     tooltip: 'Opções',
          //   ),
          // ),
          // BUG3-OLD: pílula 'Lista' decorativa, sem onTap, estilo diferente
          // da pílula ··· (sem o mesmo Liquid Glass / blur).
          // if (_displayMode == 'list')
          //   Container(
          //     margin: const EdgeInsets.only(right: 6),
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //     decoration: BoxDecoration(
          //       color: AppColors.accent.withValues(alpha: 0.15),
          //       borderRadius: BorderRadius.circular(20),
          //       border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          //     ),
          //     child: Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         HugeIcon(icon: HugeIcons.strokeRoundedListView,
          //              size: 12, color: AppColors.accent),
          //         const SizedBox(width: 4),
          //         Text('Lista', style: TextStyle(
          //           fontSize: 11, fontWeight: FontWeight.w600,
          //           color: AppColors.accent,
          //         )),
          //       ],
          //     ),
          //   ),
          // M4/BUG3: indicador do modo 'list', mesmo estilo Liquid Glass da
          // pílula ··· (ClipRRect + BackdropFilter), e agora tocável — abre
          // o mesmo menu de opções.
          if (_displayMode == 'list')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => _showOptionsMenu(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedListView,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Lista',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // CORRIGIDO_VISUAL_A: Padding adicionado para afastar a pílula do
          // canto direito do AppBar.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Builder(
                  builder: (ctx) => GestureDetector(
                    onTap: () => _showOptionsMenu(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal,
                            size: 18,
                            color: Theme.of(ctx).colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // REMOVIDO_ETAPA1: botão "+" do AppBar ocultado (limpeza visual).
          // Não é widget compartilhado com outras telas — comentado direto.
          // Lógica preservada, chamável via _openAddTask(null) se necessário.
          // IconButton(
          //   icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: AppColors.accent),
          //   onPressed: () => showQuickAddTaskSheet(context, onSaved: _loadTasks, initialProjectId: widget.projectId),
          //   tooltip: 'Nova tarefa',
          // ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : isEmpty
              ? const Center(child: EmptyState(icon: Icons.task_alt_outlined, title: 'Nenhuma tarefa', subtitle: 'Adicione tarefas usando o botão +'))
              : _buildTaskListView(bottomInset),
    );
  }

  // PERF-LIST-OLD: ListView(children: [...]) eager — construía TODAS as
  // rows (seções + completed) de uma vez no build(), mesmo fora da
  // viewport. Substituído por CustomScrollView+SliverList com builder
  // lazy. _buildSectionedRows() não é alterado internamente (continua
  // agrupando por seção do jeito que já fazia); rows é calculado uma
  // única vez por build e cacheado em variável local — não chamado de
  // novo dentro do builder/childCount.
  // : ListView(
  //     padding: EdgeInsets.fromLTRB(0, 12, 0, bottomInset),
  //     children: [
  //       ..._buildSectionedRows(),
  //       if (_showCompleted && _completedTasks.isNotEmpty)
  //         CompletedSectionHeader(...),
  //       if (_showCompleted && _completedExpanded)
  //         for (var ci = 0; ci < _completedTasks.length; ci++)
  //           RepaintBoundary(...),
  //     ],
  //   ),
  Widget _buildTaskListView(double bottomInset) {
    final rows = <Widget>[
      ..._buildSectionedRows(),
      if (_showCompleted && _completedTasks.isNotEmpty)
        CompletedSectionHeader(
          count: _completedTasks.length,
          expanded: _completedExpanded,
          onTap: () {
            HapticService().selectionClick();
            setState(() => _completedExpanded = !_completedExpanded);
          },
        ),
      if (_showCompleted && _completedExpanded)
        for (var ci = 0; ci < _completedTasks.length; ci++)
          RepaintBoundary(
            key: ValueKey('rb_done_${_completedTasks[ci].id}'),
            child: SwipeableTaskTile(
              task: _completedTasks[ci],
              onDeleteRequested: () => _deleteCompletedTask(ci),
              onEdit: () => showTaskDetailSheet(context, _completedTasks[ci], onSaved: _loadTasks),
              onRefresh: _loadTasks,
              child: TaskTile(
                task: _completedTasks[ci],
                showProject: false,
                // CORRIGIDO_ETAPA3B
                allLabels: _allLabels,
                onSubtaskToggled: (_) {},
                onCompleted: () => _toggleUndone(ci),
                onTap: () => showTaskDetailSheet(context, _completedTasks[ci], onSaved: _loadTasks),
              ),
            ),
          ),
    ];

    return ScrollFadeOverlay(child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(0, 12, 0, bottomInset),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => rows[index],
              childCount: rows.length,
            ),
          ),
        ),
      ],
    ));
  }
}

/// Header row for a project section — chevron + name + count + "···" menu.
class _SectionHeader extends StatelessWidget {
  final String name;
  final int count;
  final bool expanded;
  final VoidCallback onTap;
  final void Function(BuildContext ctx) onMenu;

  const _SectionHeader({
    required this.name,
    required this.count,
    required this.expanded,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // SUBSTITUIDO_ETAPA2: remove o flash cinza de ripple/highlight ao tocar
      // no cabeçalho da seção; comportamento de expandir/recolher inalterado.
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text('$count', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
            Builder(
              builder: (ctx) => IconButton(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal, size: 18, color: AppColors.textTertiary),
                onPressed: () => onMenu(ctx),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
