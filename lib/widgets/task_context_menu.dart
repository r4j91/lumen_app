import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/section_repository.dart'; // ADICIONADO_SECAO_PROJETO
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'popover_style.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Public entry-point ────────────────────────────────────────────────────────

Future<void> showTaskContextMenu(
  BuildContext context, {
  required Task task,
  required Offset tapPosition,
  VoidCallback? onEdit,
  VoidCallback? onComplete,
  VoidCallback? onDelete,
  VoidCallback? onRefresh,
}) async {
  HapticService().taskCreated();

  final projectsFuture = _fetchProjects();

  final result = await _showContextMenu(
    context,
    origin: tapPosition,
    items: [
      _MenuItem('edit',      Icons.edit_outlined,        'Editar'),
      _MenuItem('complete',  Icons.check_circle_outline, 'Concluir'),
      _MenuItem('duplicate', Icons.copy_outlined,        'Duplicar'),
      _MenuItem('priority',  Icons.flag_outlined,        'Prioridade',
        hasArrow: true,
        subTitle: 'Prioridade',
        subItems: [
          _MenuItem('priority:high',   Icons.flag, 'Alta',
              selected: task.priority == Priority.high,
              iconColor: AppColors.priorityHigh),
          _MenuItem('priority:medium', Icons.flag, 'Média',
              selected: task.priority == Priority.medium,
              iconColor: AppColors.priorityMedium),
          _MenuItem('priority:low',    Icons.flag, 'Baixa',
              selected: task.priority == Priority.low,
              iconColor: AppColors.priorityLow),
          _MenuItem('priority:none', Icons.flag_outlined, 'Sem prioridade',
              selected: task.priority == null),
        ],
      ),
      // SUBSTITUIDO_SECAO_PROJETO: "Mover para" agora é dois níveis
      // (Projeto -> Seção), ver bloco _MenuItem('move', ...) abaixo.
      // _MenuItem('move', Icons.folder_outlined, 'Mover para projeto',
      //   hasArrow: true,
      //   subTitle: 'Mover para',
      //   subItemsLoader: () async {
      //     final projects = await projectsFuture;
      //     return [
      //       _MenuItem('move:', Icons.inbox_outlined, 'Sem projeto'),
      //       ...projects.map((p) => _MenuItem('move:${p.id}', Icons.folder_outlined, p.name)),
      //     ];
      //   },
      // ),
      // ADICIONADO_SECAO_PROJETO: nível 1 lista projetos; ao tocar num
      // projeto, nível 2 carrega suas seções (via subItemsLoader do próprio
      // _MenuItem do projeto). Se o projeto não tiver seções, o
      // subItemsLoader retorna null e a navegação finaliza direto com o
      // valor do projeto (sem seção) — ver _navigateTo, que trata esse caso.
      _MenuItem('move', Icons.folder_outlined, 'Mover para projeto',
        hasArrow: true,
        subTitle: 'Mover para',
        subItemsLoader: () async {
          final projects = await projectsFuture;
          return [
            _MenuItem('move:|', Icons.inbox_outlined, 'Sem projeto'),
            ...projects.map((p) => _MenuItem(
                  'move:${p.id}|', Icons.folder_outlined, p.name,
                  hasArrow: true,
                  subTitle: p.name,
                  subItemsLoader: () async {
                    final sections =
                        await SectionRepository().getSectionsForProject(p.id);
                    if (sections.isEmpty) return null;
                    return [
                      _MenuItem('move:${p.id}|', Icons.subdirectory_arrow_right_outlined, 'Sem seção'),
                      ...sections.map((s) => _MenuItem(
                            'move:${p.id}|${s.id}',
                            Icons.subdirectory_arrow_right_outlined,
                            s.name,
                          )),
                    ];
                  },
                )),
          ];
        },
      ),
      _MenuItem('delete', Icons.delete_outline, 'Excluir', destructive: true),
    ],
  );

  if (result == null || !context.mounted) return;

  if (result.startsWith('priority:')) {
    final prioStr = result.substring(9);
    try {
      await supabase
          .from('tasks')
          .update({'prioridade': prioStr.isEmpty ? null : prioStr})
          .eq('id', task.id);
      onRefresh?.call();
    } catch (_) {}
  } else if (result.startsWith('move:')) {
    // SUBSTITUIDO_SECAO_PROJETO: formato antigo era 'move:<projectId>'
    // (sem seção). Mantido como referência:
    // final projectId = result.substring(5);
    // await supabase.from('tasks').update({'project_id': projectId.isEmpty ? null : projectId}).eq('id', task.id);

    // ADICIONADO_SECAO_PROJETO: novo formato 'move:<projectId>|<sectionId>',
    // qualquer um dos dois lados pode ser vazio (sem projeto / sem seção).
    final payload = result.substring(5);
    final parts = payload.split('|');
    final projectId = parts.isNotEmpty ? parts[0] : '';
    final sectionId = parts.length > 1 ? parts[1] : '';
    try {
      await supabase
          .from('tasks')
          .update({
            'project_id': projectId.isEmpty ? null : projectId,
            'section_id': sectionId.isEmpty ? null : sectionId,
          })
          .eq('id', task.id);
      onRefresh?.call();
    } catch (_) {}
  } else {
    switch (result) {
      case 'edit':     onEdit?.call();
      case 'complete': onComplete?.call();
      case 'duplicate':
        await _duplicateTask(task);
        onRefresh?.call();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Tarefa duplicada'),
            backgroundColor: AppColors.surfaceVariant,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ));
        }
      case 'delete': onDelete?.call();
    }
  }
}

// ── MenuItem ──────────────────────────────────────────────────────────────────

class _MenuItem {
  final String value;
  final IconData icon;
  final String label;
  final bool hasArrow;
  final bool destructive;
  final bool selected;
  final Color? iconColor;
  // Inline submenu support
  final List<_MenuItem>? subItems;
  final String? subTitle;
  // ADICIONADO_SECAO_PROJETO: loader agora pode retornar null para indicar
  // "sem submenu" (ex: projeto sem seções) — nesse caso _navigateTo finaliza
  // direto com o value do próprio item, em vez de empurrar uma página vazia.
  final Future<List<_MenuItem>?> Function()? subItemsLoader;

  const _MenuItem(this.value, this.icon, this.label,
      {this.hasArrow = false,
       this.destructive = false,
       this.selected = false,
       this.iconColor,
       this.subItems,
       this.subTitle,
       this.subItemsLoader});

  bool get hasSubMenu => subItems != null || subItemsLoader != null;
}

// ── Core overlay engine ───────────────────────────────────────────────────────

Future<String?> _showContextMenu(
  BuildContext context, {
  required Offset origin,
  required List<_MenuItem> items,
}) {
  final completer = Completer<String?>();
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _ContextMenuOverlay(
      origin: origin,
      items: items,
      onDismiss: (value) {
        entry.remove();
        if (!completer.isCompleted) completer.complete(value);
      },
    ),
  );

  Overlay.of(context).insert(entry);
  return completer.future;
}

// ── Overlay widget ────────────────────────────────────────────────────────────

class _ContextMenuOverlay extends StatefulWidget {
  final Offset origin;
  final List<_MenuItem> items;
  final void Function(String?) onDismiss;

  const _ContextMenuOverlay({
    required this.origin,
    required this.items,
    required this.onDismiss,
  });

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  // SUBSTITUIDO_SECAO_PROJETO: estado antigo só suportava UM nível de
  // submenu (voltar ia direto pra página raiz). Mantido como referência:
  // List<_MenuItem>? _subItems;
  // String? _subTitle;
  // bool _subLoading = false;

  // ADICIONADO_SECAO_PROJETO: pilha de navegação real — cada push empilha
  // uma _MenuPage; "voltar" desempilha uma página por vez, suportando N
  // níveis (ex: Mover para -> Projeto -> Seção).
  late final List<_MenuPage> _pageStack = [_MenuPage(items: widget.items)];
  int _pageVersion = 0; // changes key for AnimatedSwitcher

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: PopoverStyle.animDuration); // was: 200ms
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss(String? value) async {
    await _ctrl.animateBack(0,
        duration: const Duration(milliseconds: 100), // was: 130ms
        curve: Curves.easeInCubic);
    widget.onDismiss(value);
  }

  // ADICIONADO_SECAO_PROJETO: _navigateTo agora empilha em _pageStack (em
  // vez de sobrescrever um único nível _subItems), permitindo qualquer
  // profundidade de submenu. Quando subItemsLoader retorna null (ex:
  // projeto sem seções), a página recém-empilhada é removida e a navegação
  // finaliza direto com o value do item — sem deixar uma página vazia.
  Future<void> _navigateTo(_MenuItem item) async {
    if (item.subItems != null) {
      HapticService().selectionClick();
      setState(() {
        _pageStack.add(_MenuPage(items: item.subItems!, title: item.subTitle ?? item.label));
        _pageVersion++;
      });
      return;
    }
    if (item.subItemsLoader != null) {
      HapticService().selectionClick();
      setState(() {
        _pageStack.add(_MenuPage(
          items: const [],
          title: item.subTitle ?? item.label,
          loading: true,
        ));
        _pageVersion++;
      });
      final loaded = await item.subItemsLoader!();
      if (!mounted) return;
      if (loaded == null || loaded.isEmpty) {
        setState(() {
          _pageStack.removeLast();
          _pageVersion++;
        });
        _dismiss(item.value);
        return;
      }
      setState(() {
        _pageStack[_pageStack.length - 1] = _MenuPage(
          items: loaded,
          title: item.subTitle ?? item.label,
        );
        _pageVersion++;
      });
      return;
    }
    if (item.destructive) {
      HapticService().taskDeleted();
    } else {
      HapticService().selectionClick();
    }
    _dismiss(item.value);
  }

  void _navigateBack() {
    if (_pageStack.length <= 1) return;
    HapticService().selectionClick();
    setState(() {
      _pageStack.removeLast();
      _pageVersion++;
    });
  }

  bool get _inSubmenu => _pageStack.length > 1;
  _MenuPage get _currentPage => _pageStack.last;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const menuWidth = 230.0;

    // Estimate card height to keep menu on screen
    const itemH = 48.0;
    // ADICIONADO_SECAO_PROJETO: itemCount/loadH agora vêm da página atual
    // da pilha (_currentPage), não mais de um único nível _subItems.
    final itemCount = _currentPage.items.length;
    final extraH = _inSubmenu ? 49.0 : 0.0; // back header
    final loadH  = _currentPage.loading ? 52.0 : 0.0;
    final menuH  = (_currentPage.loading ? 0 : itemCount * itemH) + loadH + extraH + 16.0;

    final anchorLeft = widget.origin.dx < size.width / 2;
    final anchorTop  = widget.origin.dy < size.height * 0.55;

    double left = anchorLeft
        ? widget.origin.dx - 12
        : widget.origin.dx - menuWidth + 12;
    double top = anchorTop
        ? widget.origin.dy - 8
        : widget.origin.dy - menuH + 8;

    left = left.clamp(12.0, size.width  - menuWidth - 12);
    top  = top.clamp(60.0,  size.height - menuH - 80);

    final alignX = anchorLeft ? -1.0 : 1.0;
    final alignY = anchorTop  ? -1.0 : 1.0;

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _dismiss(null),
            child: FadeTransition(
              opacity: Tween(begin: 0.0, end: 1.0).animate(_fadeAnim),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withValues(alpha: 0.28)),
              ),
            ),
          ),
        ),

        // Menu card
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: ScaleTransition(
            scale: Tween(begin: PopoverStyle.scaleBegin, end: 1.0).animate(_scaleAnim), // was: 0.80
            alignment: Alignment(alignX, alignY),
            child: FadeTransition(
              opacity: Tween(begin: 0.0, end: 1.0).animate(_fadeAnim),
              child: Material(
                color: Colors.transparent,
                child: CustomPaint(
                  foregroundPainter: const PopoverBorderPainter(),
                  child: Container(
                    // Shadow drawn outside ClipRRect so it is never clipped.
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PopoverStyle.radius),
                      boxShadow: PopoverStyle.shadows,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(PopoverStyle.radius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: PopoverStyle.blurSigma,
                          sigmaY: PopoverStyle.blurSigma,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: PopoverStyle.bg,
                            borderRadius: BorderRadius.circular(PopoverStyle.radius),
                          ),
                          // OLD card style — kept for manual revert:
                          // Material(color: AppColors.surfaceVariant,
                          //   borderRadius: BorderRadius.circular(14),
                          //   elevation: 24,
                          //   shadowColor: Colors.black.withValues(alpha: 0.45))
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 170),
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                              // ADICIONADO_SECAO_PROJETO: uma única página
                              // genérica para qualquer profundidade da pilha.
                              child: _buildPage(_currentPage, key: ValueKey(_pageVersion)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // SUBSTITUIDO_SECAO_PROJETO: _buildMainPage/_buildSubPage assumiam um
  // único nível de submenu. Mantidos como referência:
  // Widget _buildMainPage({Key? key}) {
  //   return Padding(
  //     key: key,
  //     padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: List.generate(widget.items.length, (i) {
  //         final item = widget.items[i];
  //         final t0 = (i * 0.05).clamp(0.0, 0.6);
  //         final t1 = (t0 + 0.55).clamp(0.0, 1.0);
  //         final anim = CurvedAnimation(
  //           parent: _ctrl,
  //           curve: Interval(t0, t1, curve: Curves.easeOutCubic),
  //         );
  //         return FadeTransition(
  //           opacity: anim,
  //           child: SlideTransition(
  //             position: Tween<Offset>(
  //               begin: const Offset(0, -0.12),
  //               end: Offset.zero,
  //             ).animate(anim),
  //             child: _MenuRow(
  //               item: item,
  //               showDivider: i < widget.items.length - 1 &&
  //                   !item.destructive &&
  //                   !widget.items[i + 1].destructive,
  //               onTap: () => _navigateTo(item),
  //             ),
  //           ),
  //         );
  //       }),
  //     ),
  //   );
  // }
  //
  // Widget _buildSubPage({Key? key}) {
  //   final items = _subItems ?? [];
  //   return Column(
  //     key: key,
  //     mainAxisSize: MainAxisSize.min,
  //     crossAxisAlignment: CrossAxisAlignment.stretch,
  //     children: [
  //       InkWell(
  //         onTap: _navigateBack,
  //         child: Padding(
  //           padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
  //           child: Row(
  //             children: [
  //               HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 20, color: AppColors.textSecondary),
  //               const SizedBox(width: 2),
  //               Text(
  //                 _subTitle ?? '',
  //                 style: TextStyle(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.w600,
  //                   color: AppColors.textPrimary,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //       Divider(height: 1, thickness: 0.5,
  //           color: AppColors.textTertiary.withValues(alpha: 0.15)),
  //       if (_subLoading)
  //         Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 18),
  //           child: Center(
  //             child: SizedBox(
  //               width: 18, height: 18,
  //               child: CircularProgressIndicator(
  //                   strokeWidth: 2, color: AppColors.textSecondary),
  //             ),
  //           ),
  //         )
  //       else
  //         Padding(
  //           padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: List.generate(items.length, (i) {
  //               final item = items[i];
  //               return _MenuRow(
  //                 item: item,
  //                 showDivider: i < items.length - 1 && !item.destructive,
  //                 onTap: () {
  //                   HapticService().selectionClick();
  //                   _dismiss(item.value);
  //                 },
  //               );
  //             }),
  //           ),
  //         ),
  //     ],
  //   );
  // }

  // ADICIONADO_SECAO_PROJETO: página única genérica para qualquer
  // profundidade de pilha. Página raiz (stack.length == 1) preserva a
  // animação de entrada com stagger por item, igual ao _buildMainPage
  // original; páginas empilhadas (stack.length > 1) preservam o cabeçalho
  // "‹ Voltar" + spinner de loading, igual ao _buildSubPage original.
  // Em ambos os casos, o tap de cada item agora passa por _navigateTo (em
  // vez de _dismiss direto), para que qualquer item em qualquer nível possa
  // ter seu próprio subItems/subItemsLoader (necessário para Projeto -> Seção).
  Widget _buildPage(_MenuPage page, {Key? key}) {
    final isRoot = _pageStack.length == 1;

    if (isRoot) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(page.items.length, (i) {
            final item = page.items[i];
            final t0 = (i * 0.05).clamp(0.0, 0.6);
            final t1 = (t0 + 0.55).clamp(0.0, 1.0);
            final anim = CurvedAnimation(
              parent: _ctrl,
              curve: Interval(t0, t1, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.12),
                  end: Offset.zero,
                ).animate(anim),
                child: _MenuRow(
                  item: item,
                  showDivider: i < page.items.length - 1 &&
                      !item.destructive &&
                      !page.items[i + 1].destructive,
                  onTap: () => _navigateTo(item),
                ),
              ),
            );
          }),
        ),
      );
    }

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back header
        InkWell(
          onTap: _navigateBack,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  page.title ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5,
            color: AppColors.textTertiary.withValues(alpha: 0.15)),
        if (page.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(page.items.length, (i) {
                final item = page.items[i];
                return _MenuRow(
                  item: item,
                  showDivider: i < page.items.length - 1 && !item.destructive,
                  onTap: () => _navigateTo(item),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ADICIONADO_SECAO_PROJETO: uma página da pilha de navegação do menu.
class _MenuPage {
  final List<_MenuItem> items;
  final String? title;
  final bool loading;

  const _MenuPage({required this.items, this.title, this.loading = false});
}

// ── Menu row ──────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  final bool showDivider;
  final VoidCallback onTap;

  const _MenuRow(
      {required this.item, required this.showDivider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg     = item.destructive ? AppColors.priorityHigh : AppColors.textPrimary;
    final iconFg = item.iconColor ?? fg;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 13),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: iconFg),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: fg,
                      fontWeight: item.selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (item.selected)
                  HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 15, color: iconFg)
                else if (item.hasSubMenu || item.hasArrow)
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.textTertiary.withValues(alpha: 0.15),
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
          ),
      ],
    );
  }
}

// ── Data helpers ──────────────────────────────────────────────────────────────

Future<List<({String id, String name})>> _fetchProjects() async {
  try {
    final rows = await supabase
        .from('projects')
        .select('id, nome')
        .order('nome')
        .timeout(const Duration(seconds: 4));
    return (rows as List)
        .map((r) => (id: r['id'].toString(), name: r['nome'] as String))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _duplicateTask(Task task) async {
  final userId = supabase.auth.currentUser?.id;
  final pad = (int n) => n.toString().padLeft(2, '0');
  final prioStr = switch (task.priority) {
    Priority.high   => 'high',
    Priority.medium => 'medium',
    Priority.low    => 'low',
    null            => null,
  };
  try {
    final inserted = await supabase
        .from('tasks')
        .insert({
          'titulo': '${task.title} (cópia)',
          'descricao': task.description,
          'prioridade': prioStr,
          'hora': task.time,
          'concluida': false,
          if (task.dueDate != null)
            'data_vencimento':
                '${task.dueDate!.year}-${pad(task.dueDate!.month)}-${pad(task.dueDate!.day)}',
          if (userId != null) 'user_id': userId,
        })
        .select('id')
        .single();
    final newId = inserted['id'].toString();
    if (task.labels.isNotEmpty) {
      await supabase.from('task_labels').insert(
        task.labels.map((l) => {'task_id': newId, 'label_id': l.id}).toList(),
      );
    }
  } catch (_) {}
}
