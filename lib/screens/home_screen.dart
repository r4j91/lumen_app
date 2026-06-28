import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../widgets/modal_media_query.dart' show ModalSheetRoute;
import '../widgets/project_options_sheet.dart';
import '../widgets/task_tile.dart' show TagChip;
import 'browse_screen.dart' show UserPill, HeaderLiquidPill, SettingsSheet, NotificationsSheet;
import 'productivity_screen.dart' show showProductivitySheet;
import 'project_detail_screen.dart';
import 'task_detail_sheet.dart';
import '../widgets/scroll_fade_overlay.dart';
import '../widgets/pressable.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/task_sync.dart';
import '../utils/project_icons.dart';

class _HomeProject {
  final String id;
  final String name;
  final int taskCount;
  final Color color;
  // ICON-OLD: sem campo de ícone.
  final String? iconName;
  const _HomeProject({
    required this.id,
    required this.name,
    required this.taskCount,
    required this.color,
    this.iconName,
  });
}

// PROJECT-ICONS-OLD: _iconFromName(name) -> IconData Material, switch local
// — movido pra ProjectIcons.resolve(name) (lib/utils/project_icons.dart),
// mesmas chaves, agora resolvendo pra Hugeicons.

class HomeScreen extends StatefulWidget {
  // Callback pra trocar de tab no RootScreen (main.dart) — mesmo padrão
  // já usado por onTaskCreated. Índices: 1=Inbox, 2=Today, 3=Upcoming,
  // 4=Filters (ver main.dart:125-131).
  final void Function(int)? onNavigateToTab;
  const HomeScreen({super.key, this.onNavigateToTab});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // Estado inicial — será expandido nas próximas etapas
  String _userName = '';
  bool _loading = true;

  // Próxima tarefa prioritária do dia + agregados do card "Hoje". Não há
  // método de TaskRepository que sirva direto aqui: fetchTodayTasks()
  // filtra concluida=false e usa .lte (hoje+atrasadas), e o card precisa
  // do total (feitas+pendentes) restrito a exatamente hoje.
  Task? _overdueTask;
  int _todayTotal = 0;
  int _todayDone = 0;
  bool _loadingTasks = true;

  // Contadores dos atalhos. _filterCount fica sempre 0: não existe tabela
  // 'filters' no Supabase — FiltersScreen é um dashboard de categorias
  // fixas (atrasadas/hoje/semana/completas), não linhas de uma tabela.
  // Consultar uma tabela inexistente lançaria exceção e abortaria o resto
  // de _loadProjects() (projetos/inbox/upcoming também ficariam sem
  // carregar), então esse fetch foi omitido.
  int _inboxCount = 0;
  int _upcomingCount = 0;
  final int _filterCount = 0;

  List<_HomeProject> _projects = [];
  bool _loadingProjects = true;
  bool _projectsExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadTasks();
    _loadProjects();
    TaskSync.instance.addListener(reload);
  }

  @override
  void dispose() {
    TaskSync.instance.removeListener(reload);
    super.dispose();
  }

  // HOME-REFRESH: chamado pelo RootScreen (main.dart, via GlobalKey) ao
  // selecionar de novo a tab Home — mesmo padrão já usado por
  // TodayScreenState/InboxScreenState. RouteObserver/AppLifecycleState
  // não servem aqui: HomeScreen é irmã de Inbox/Today/Upcoming/Filters
  // dentro de um IndexedStack (main.dart), trocar de tab é só
  // setState(_index), nunca um Navigator.push/pop — didPopNext jamais
  // dispararia. AppLifecycleState.resumed só cobre foreground do app, não
  // troca de aba.
  void reload() {
    _loadTasks();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loadingProjects = false);
        return;
      }
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // ICON-OLD: select sem 'icone' — coluna não existe ainda no banco
      // (confirmado via grep, ver PASSO 0). Tenta com 'icone'; se a coluna
      // não existir, cai no fallback sem ela (mesmo padrão de
      // tasksSelectWithSubtaskExtras/Fallback em project_detail_screen.dart).
      List projRows;
      try {
        projRows = await supabase.from('projects').select('id, nome, cor, icone').eq('user_id', userId).order('nome');
      } catch (e) {
        if (!e.toString().contains('icone')) rethrow;
        projRows = await supabase.from('projects').select('id, nome, cor').eq('user_id', userId).order('nome');
      }

      final results = await Future.wait([
        supabase.from('tasks').select('project_id').eq('user_id', userId).eq('concluida', false),
        supabase
            .from('tasks')
            .select('id')
            .eq('user_id', userId)
            .eq('concluida', false)
            .gt('data_vencimento', todayStr),
      ]);

      final taskRows = results[0] as List;
      final upcomingRows = results[1] as List;

      final countMap = <String, int>{};
      var inboxCount = 0;
      for (final t in taskRows) {
        final pid = t['project_id'] as String?;
        if (pid == null) {
          inboxCount++;
        } else {
          countMap[pid] = (countMap[pid] ?? 0) + 1;
        }
      }

      final projects = projRows.map((r) {
        final id = r['id'].toString();
        final name = r['nome'] as String? ?? '';
        return _HomeProject(
          id: id,
          name: name,
          taskCount: countMap[id] ?? 0,
          // AppColors.parseHex já existe e é o mesmo usado em
          // browse_screen.dart — reaproveitado em vez de parse manual.
          color: r['cor'] != null ? AppColors.parseHex(r['cor'] as String?) : _folderColorFromName(name),
          iconName: r['icone'] as String?,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _projects = projects;
          _inboxCount = inboxCount;
          _upcomingCount = upcomingRows.length;
          _loadingProjects = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  // Mesmo algoritmo de _folderColorFromName em browse_screen.dart.
  Color _folderColorFromName(String name) {
    final palette = [
      AppColors.accent,
      AppColors.priorityHigh,
      AppColors.priorityMedium,
      AppColors.priorityLow,
      AppColors.tagPurple,
      AppColors.tagGreen,
    ];
    return palette[name.codeUnits.fold(0, (a, b) => a + b) % palette.length];
  }

  // TASK-NEXT-OLD: _nextTask buscava a pendente mais prioritária de
  // qualquer data. Trocado por _overdueTask: tarefa atrasada (data <
  // hoje, não concluída), mais antiga primeiro. Duas queries: agregado
  // "Hoje" (exatamente hoje, feitas+pendentes) + atrasada mais antiga.
  static const _taskSelect =
      'id, titulo, descricao, prioridade, concluida, data_vencimento, hora, task_labels(labels(id, nome, cor)), projects(nome)';

  Future<void> _loadTasks() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loadingTasks = false);
        return;
      }
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        supabase.from('tasks').select(_taskSelect).eq('user_id', userId).eq('data_vencimento', todayStr),
        supabase
            .from('tasks')
            .select(_taskSelect)
            .eq('user_id', userId)
            .eq('concluida', false)
            .lt('data_vencimento', todayStr)
            .order('data_vencimento', ascending: true)
            .limit(1),
      ]);

      final todayRows = results[0] as List;
      final overdueRows = results[1] as List;

      final todayTasks = todayRows.map((r) => Task.fromJson(r)).toList();
      final done = todayTasks.where((t) => t.done).length;
      final overdueTask = overdueRows.isNotEmpty ? Task.fromJson(overdueRows.first) : null;

      if (mounted) {
        setState(() {
          _todayTotal = todayTasks.length;
          _todayDone = done;
          _overdueTask = overdueTask;
          _loadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  // Mesmo padrão usado em browse_screen.dart/productivity_screen.dart:
  // apelido > primeiro nome > parte local do email — lido direto de
  // userMetadata (síncrono, sem fetch a tabela profiles).
  Future<void> _loadUserName() async {
    final meta = supabase.auth.currentUser?.userMetadata ?? {};
    final apelido = (meta['apelido'] as String? ?? '').trim();
    final nome = (meta['nome'] as String? ?? '').trim();
    final userName = apelido.isNotEmpty
        ? apelido
        : nome.isNotEmpty
            ? nome.split(' ').first
            : supabase.auth.currentUser?.email?.split('@').first ?? '';
    if (mounted) {
      setState(() {
        _userName = userName;
        _loading = false;
      });
    }
  }

  // ── SAUDAÇÃO DINÂMICA ───────────────────────────────
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  BoxDecoration _overdueDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: AppColors.overdue.withValues(alpha: isDark ? 0.14 : 0.10),
      border: Border.all(color: AppColors.overdue.withValues(alpha: 0.32)),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    );
  }

  BoxDecoration _liquidGlassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : AppColors.surfaceVariant.withValues(alpha: 0.6),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : AppColors.textTertiary.withValues(alpha: 0.15),
      ),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    );
  }

  BoxDecoration _emptyStateDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : AppColors.surfaceVariant.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.textTertiary.withValues(alpha: 0.12),
      ),
    );
  }

  // SCROLL-PATTERN-OLD: Scaffold + SafeArea + um único SliverToBoxAdapter
  // com Column (SizedBox de fim dentro do Column). today_screen.dart e
  // inbox_screen.dart (mesma família de telas, ver PASSO 0) não usam
  // SafeArea nenhum, e o bottom inset é o próprio ÚLTIMO sliver —
  // SliverToBoxAdapter(child: SizedBox(height: bottomInset)), bottomInset
  // = MediaQuery.of(context).padding.bottom + 88 (não 120). Scaffold
  // mantido (não existe nas telas-irmãs, mas removê-lo perderia o
  // backgroundColor explícito — mudança maior que o pedido, fora de
  // escopo aqui); SafeArea removido e estrutura de slivers replicada.
  // ── BUILD ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 88;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadTasks(),
                  _loadProjects(),
                ]);
              },
              color: AppColors.accent,
              child: ScrollFadeOverlay(
                child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        _buildGreeting(context),
                        SizedBox(height: AppSpacing.xl),
                        if (_loadingTasks)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                            child: Center(child: CupertinoActivityIndicator()),
                          )
                        else ...[
                          _buildOverdueCard(context),
                          _buildTodayCard(context),
                        ],
                        SizedBox(height: AppSpacing.xl),
                        _buildShortcutsGrid(),
                        _buildProjectsList(context),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
                ],
              ),
              ),
            ),
    );
  }

  // ── HEADER ───────────────────────────────────────────
  // HEADER-OLD: avatar/nome/sino/engrenagem reimplementados do zero aqui,
  // sem o tratamento Liquid Glass real e sem abrir nada de fato. Trocado
  // pelos widgets reais de browse_screen.dart (UserPill, HeaderLiquidPill,
  // SettingsSheet, NotificationsSheet) — tornados públicos lá (sem prefixo
  // _) em vez de duplicados aqui, fonte única.
  Widget _buildHeader() {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '';
    final meta = user?.userMetadata ?? {};
    final apelido = (meta['apelido'] as String? ?? '').trim();
    final nome = (meta['nome'] as String? ?? '').trim();
    final avatarPath = meta['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Row(
        children: [
          // GESTURE-OLD: GestureDetector sem feedback visual
          Pressable(
            onTap: () => showProductivitySheet(context),
            child: UserPill(email: email, apelido: apelido, nome: nome, avatarPath: avatarPath),
          ),
          const Spacer(),
          HeaderLiquidPill(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pressable(
                  onTap: () => NotificationsSheet.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedNotification01, size: 22, color: AppColors.textSecondary),
                  ),
                ),
                Container(width: 1, height: 18, color: AppColors.textTertiary.withValues(alpha: 0.2)),
                Pressable(
                  onTap: () => SettingsSheet.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedSettings01, size: 22, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SAUDAÇÃO ─────────────────────────────────────────
  Widget _buildGreeting(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting, $_userName',
            style: textTheme.headlineMedium?.copyWith(letterSpacing: -0.3),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Vamos focar no que realmente importa hoje.',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // COLORS-OLD: static const _overdueColor = Color(0xFFEF4444);
  static const _overdueColor = AppColors.overdue;

  // PRIORITY-CENTRAL-OLD: _priorityColor/_priorityLabel locais — movidos
  // pra PriorityExtension em lib/models/task.dart.

  String _formatOverdueDate(DateTime date) {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(d).inDays;
    if (diff == 1) return 'Atrasada há 1 dia';
    if (diff > 1) return 'Atrasada há $diff dias';
    return 'Atrasada';
  }

  // TASK-NEXT-OLD: _buildNextTaskCard — label accent 'PRÓXIMA TAREFA',
  // chip de data fixo 'Hoje', sem prioridade, SizedBox.shrink() se vazio.
  // ── CARD TAREFA ATRASADA ─────────────────────────────
  Widget _buildOverdueCard(BuildContext context) {
    final task = _overdueTask;
    if (task == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 20, color: AppColors.success),
            ),
            SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tudo em dia!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.success)),
                Text('Nenhuma tarefa atrasada', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );
    }

    return Pressable(
      onTap: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
      child: Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _overdueDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedAlert01, size: 13, color: _overdueColor),
              const SizedBox(width: 6),
              Text(
                'TAREFA ATRASADA',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _overdueColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            task.title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (task.dueDate != null)
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 13, color: _overdueColor),
                const SizedBox(width: 4),
                Text(_formatOverdueDate(task.dueDate!), style: TextStyle(fontSize: 12, color: _overdueColor)),
              ],
            ),
          if (task.dueDate != null) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (task.priority != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: task.priority!.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: task.priority!.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.priority!.label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: task.priority!.color),
                        ),
                      ],
                    ),
                  ),
                ),
              ...task.labels.take(2).map((l) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TagChip(label: l.name, color: l.color),
                  )),
              const Spacer(),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16, color: AppColors.accent),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  // ── CARD HOJE ────────────────────────────────────────
  // TODAY-EMPTY-OLD: if (_todayTotal == 0) return const SizedBox.shrink();
  Widget _buildTodayCard(BuildContext context) {
    if (_todayTotal == 0) {
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: _emptyStateDecoration(context),
        child: Row(
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 18, color: AppColors.textTertiary),
            SizedBox(width: AppSpacing.md),
            Text('Nenhuma tarefa para hoje', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final percent = ((_todayDone / _todayTotal) * 100).round();
    final percentColor = percent > 0 ? AppColors.success : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _liquidGlassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Hoje', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(
                ' · $_todayTotal tarefa${_todayTotal == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: percentColor),
              ),
              const SizedBox(width: 4),
              Text('concluídas', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _todayTotal > 0 ? _todayDone / _todayTotal : 0,
              backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(percent > 0 ? AppColors.success : AppColors.textTertiary.withValues(alpha: 0.4)),
              minHeight: 5.0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$_todayDone concluídas • ${_todayTotal - _todayDone} restantes',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── GRID DE ATALHOS ──────────────────────────────────
  // GRID-OVERFLOW-OLD: GridView.count sem childAspectRatio (default 1.0)
  // não comportava ícone+label+número+"tarefas" → overflow vertical.
  // Trocado por Row+Expanded (altura segue o conteúdo via mainAxisSize.min,
  // não fixada por um aspect ratio arbitrário).
  Widget _buildShortcutsGrid() {
    const gap = AppSpacing.sm + 2.0;
    final items = [
      (
        icon: HugeIcons.strokeRoundedInbox,
        label: 'Inbox',
        count: _inboxCount,
        color: AppColors.shortcutInbox,
        onTap: () => widget.onNavigateToTab?.call(1),
      ),
      (
        icon: HugeIcons.strokeRoundedCalendar01,
        label: 'Hoje',
        count: _todayTotal,
        color: AppColors.shortcutToday,
        onTap: () => widget.onNavigateToTab?.call(2),
      ),
      (
        icon: HugeIcons.strokeRoundedClock01,
        label: 'Em breve',
        count: _upcomingCount,
        color: AppColors.shortcutUpcoming,
        onTap: () => widget.onNavigateToTab?.call(3),
      ),
      (
        icon: HugeIcons.strokeRoundedFilterHorizontal,
        label: 'Filtros',
        count: _filterCount,
        color: AppColors.shortcutFilters,
        onTap: () => widget.onNavigateToTab?.call(4),
      ),
    ];

    Widget shortcutAt(int i) => _buildShortcutItem(
          icon: items[i].icon,
          label: items[i].label,
          count: items[i].count,
          color: items[i].color,
          onTap: items[i].onTap,
        );

    Widget rowPair(int a, int b) => Row(
          children: [
            Expanded(child: shortcutAt(a)),
            const SizedBox(width: gap),
            Expanded(child: shortcutAt(b)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, 0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 380;
          if (!narrow) {
            return Row(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(child: shortcutAt(i)),
                ],
              ],
            );
          }
          return Column(
            children: [
              rowPair(0, 1),
              const SizedBox(height: gap),
              rowPair(2, 3),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShortcutItem({
    required List<List<dynamic>> icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    // GRID-OVERFLOW-OLD: sem padding vertical explícito + linha "tarefas"
    // extra — altura total não cabia no aspect ratio default do GridView.
    // GESTURE-OLD: GestureDetector sem feedback visual
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md + 2, horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(icon: icon, size: 18, color: color),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs / 2),
            Text(
              '$count',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ── SEÇÃO PROJETOS ───────────────────────────────────
  // HOME-PROJECTS-OLD: Padding solta, sem container/fundo/borda — seção
  // visualmente "flutuando" diferente dos cards de tarefa atrasada/hoje.
  Widget _buildProjectsList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, 0,
      ),
      child: Container(
        decoration: _liquidGlassDecoration(context),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 1, vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Projetos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                // GESTURE-OLD: GestureDetector sem feedback visual
                Pressable(
                  // VERTODOS-FIX: agora alterna expandir/colapsar lista de
                  // projetos inline, como um menu — sem tela de destino.
                  onTap: () {
                    HapticService().selectionClick();
                    setState(() => _projectsExpanded = !_projectsExpanded);
                  },
                  child: Row(
                    children: [
                      Text(_projectsExpanded ? 'Ver menos' : 'Ver todos', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: _projectsExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            if (_loadingProjects)
              const Center(child: CupertinoActivityIndicator())
            else
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                // VERTODOS-FIX2: "Ver todos" agora é um menu expansível de
                // fato — colapsado esconde a lista inteira, expandido mostra
                // todos os projetos (antes só limitava a 6, nunca minimizava).
                child: _projectsExpanded
                    ? Column(
                        children: [
                          for (int i = 0; i < _projects.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.textTertiary.withValues(alpha: 0.12),
                              ),
                            _buildProjectRow(_projects[i]),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  // LONGPRESS-OLD: row sem onLongPress — sem menu de contexto de projeto
  // na home. Mesmo padrão de browse_screen._showProjectOptions: Navigator
  // root + ModalSheetRoute + ProjectOptionsSheet, não duplicado.
  Widget _buildProjectRow(_HomeProject p) {
    // GESTURE-OLD: GestureDetector sem feedback visual
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(projectId: p.id, projectName: p.name),
        ),
      ),
      onLongPress: () {
        HapticService().selectionClick();
        Navigator.of(context, rootNavigator: true).push(
          ModalSheetRoute<void>(
            builder: (_) => ProjectOptionsSheet(
              project: ProjectSheetData(
                id: p.id,
                name: p.name,
                color: p.color,
                iconName: p.iconName,
              ),
              onEdited: () {
                if (mounted) _loadProjects();
              },
              onDeleted: () {
                if (mounted) _loadProjects();
              },
            ),
          ),
        );
      },
      // HOME-PROJECTS-OLD: padding: EdgeInsets.symmetric(vertical: 8)
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                border: Border.all(color: p.color.withValues(alpha: 0.75), width: 2),
              ),
              child: Center(
                child: HugeIcon(
                  icon: ProjectIcons.resolve(p.iconName),
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
            ),
            if (p.taskCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${p.taskCount}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
