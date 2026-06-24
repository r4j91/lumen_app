import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/supabase_client.dart';
import '../services/task_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/task_tile.dart';
import 'task_detail_sheet.dart';

Future<void> showSearchScreen(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, a, b) => const SearchScreen(),
      transitionsBuilder: (ctx, anim, b, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    ),
  );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  List<Task> _allTasks = [];
  List<Task> _results = [];
  bool _loadingAll = true;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final rows = await supabase
          .from('tasks')
          .select('''
            id, titulo, descricao, prioridade, hora, ordem, concluida, data_vencimento,
            projects ( nome ),
            subtasks ( titulo, concluida, ordem ),
            task_labels ( labels ( id, nome, cor ) )
          ''')
          .eq('concluida', false)
          .order('ordem');

      final tasks = (rows as List)
          .map((r) => TaskRepository.mapRow(r as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() { _allTasks = tasks; _loadingAll = false; });
        _focus.requestFocus();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim().toLowerCase();
        _results = _query.isEmpty ? [] : _filter(_query);
      });
    });
  }

  List<Task> _filter(String q) {
    return _allTasks.where((t) {
      if (t.title.toLowerCase().contains(q)) return true;
      if (t.description != null && t.description!.toLowerCase().contains(q)) return true;
      if (t.project.toLowerCase().contains(q)) return true;
      if (t.labels.any((l) => l.name.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }

  // ── Grouping ────────────────────────────────────────────────────────────────

  Map<String, List<Task>> get _grouped {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Map<String, List<Task>> groups = {
      'Hoje': [],
      'Em breve': [],
      'Sem data': [],
    };

    for (final task in _results) {
      if (task.dueDate == null) {
        groups['Sem data']!.add(task);
      } else {
        final d = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        if (d.isAtSameMomentAs(today) || d.isBefore(today)) {
          groups['Hoje']!.add(task);
        } else {
          groups['Em breve']!.add(task);
        }
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final groups = _grouped;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
              padding: EdgeInsets.fromLTRB(16, mq.padding.top + 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search, size: 18, color: AppColors.textTertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              onChanged: _onQueryChanged,
                              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                              cursorColor: AppColors.accent,
                              cursorHeight: 18,
                              cursorWidth: 1.5,
                              decoration: InputDecoration(
                                hintText: 'Buscar tarefas...',
                                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 15),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                fillColor: Colors.transparent,
                                filled: true,
                              ),
                              textInputAction: TextInputAction.search,
                              autofocus: true,
                            ),
                          ),
                          if (_ctrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                _onQueryChanged('');
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(Icons.cancel, size: 17, color: AppColors.textTertiary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    // ignore: deprecated_member_use
                    minSize: 0,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
          ),

          const SizedBox(height: 4),

          // ── Results ─────────────────────────────────────────────────────────
          Expanded(
            child: _loadingAll
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  )
                : _query.isEmpty
                    ? _EmptyPrompt()
                    : _results.isEmpty
                        ? _NoResults(query: _query)
                        : _AnimatedResults(
                            key: ValueKey(_query),
                            groups: groups,
                            query: _query,
                            bottomPadding: mq.padding.bottom + 90,
                            onTap: (task) => showTaskDetailSheet(context, task),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Animated results list ─────────────────────────────────────────────────────

class _AnimatedResults extends StatefulWidget {
  final Map<String, List<Task>> groups;
  final String query;
  final double bottomPadding;
  final void Function(Task) onTap;

  const _AnimatedResults({
    super.key,
    required this.groups,
    required this.query,
    required this.bottomPadding,
    required this.onTap,
  });

  @override
  State<_AnimatedResults> createState() => _AnimatedResultsState();
}

class _AnimatedResultsState extends State<_AnimatedResults>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    var idx = 0;

    for (final groupName in ['Hoje', 'Em breve', 'Sem data']) {
      final tasks = widget.groups[groupName] ?? [];
      if (tasks.isEmpty) continue;
      items.add(_GroupHeader(label: groupName));
      for (final task in tasks) {
        final delay = (idx * 0.06).clamp(0.0, 0.5);
        final anim = CurvedAnimation(
          parent: _ctrl,
          curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        );
        items.add(FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(anim),
            child: _SearchResultTile(
              task: task,
              query: widget.query,
              onTap: () => widget.onTap(task),
            ),
          ),
        ));
        idx++;
      }
    }

    return ListView(
      padding: EdgeInsets.only(top: AppSpacing.sm, bottom: widget.bottomPadding),
      children: items,
    );
  }
}

// ── Group header ──────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return AppSectionLabel(
      label.toUpperCase(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
    );
  }
}

// ── Search result tile ────────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final Task task;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({required this.task, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg - 2, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: PriorityDot(priority: task.priority, done: false),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(text: task.title, query: query, style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
                  if (task.project.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.folder_outlined, size: 11, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          task.project,
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                        if (task.time != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time, size: 11, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(task.time!, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ],
                    ),
                  ],
                  if (task.labels.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      children: task.labels.take(3).map((l) => TagChip(label: l.name, color: l.color)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Highlighted text with query match ────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightText({required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx == -1) return Text(text, style: style);

    return Text.rich(
      TextSpan(children: [
        if (idx > 0) TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: style.copyWith(
            color: AppColors.accent,
            backgroundColor: AppColors.accent.withValues(alpha: 0.15),
          ),
        ),
        if (idx + query.length < text.length)
          TextSpan(text: text.substring(idx + query.length), style: style),
      ]),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search, size: 30, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),
          Text('Digite para buscar', style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Título, descrição, projeto ou etiqueta', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('Nenhum resultado para "$query"', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
