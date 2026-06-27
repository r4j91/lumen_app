import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/task.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../widgets/modal_media_query.dart' show ModalSheetRoute;
import '../widgets/project_options_sheet.dart';
import '../widgets/task_tile.dart' show TagChip;
import 'browse_screen.dart' show UserPill, HeaderLiquidPill, SettingsSheet, NotificationsSheet;
import 'productivity_screen.dart' show showProductivitySheet;
import 'project_detail_screen.dart';
import 'task_detail_sheet.dart';
import '../widgets/scroll_fade_overlay.dart';
import 'package:hugeicons/hugeicons.dart';
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

  String get _greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 18) return '👋';
    return '👋';
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
                        _buildGreeting(),
                        // HOME-SPACING-OLD: SizedBox(height: 4)
                        const SizedBox(height: 8),
                        if (_loadingTasks)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CupertinoActivityIndicator()),
                          )
                        else ...[
                          _buildOverdueCard(),
                          _buildTodayCard(),
                        ],
                        // HOME-SPACING-OLD: SizedBox(height: 4)
                        const SizedBox(height: 8),
                        _buildShortcutsGrid(),
                        _buildProjectsList(),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => showProductivitySheet(context),
            child: UserPill(email: email, apelido: apelido, nome: nome, avatarPath: avatarPath),
          ),
          const Spacer(),
          HeaderLiquidPill(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => NotificationsSheet.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedNotification01, size: 22, color: AppColors.textSecondary),
                  ),
                ),
                Container(width: 1, height: 18, color: AppColors.textTertiary.withValues(alpha: 0.2)),
                GestureDetector(
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

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  // ── SAUDAÇÃO ─────────────────────────────────────────
  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$_greeting, $_userName $_greetingEmoji',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Vamos focar no que realmente importa hoje.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _liquidGlassDecoration => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      );

  static const _overdueColor = Color(0xFFEF4444);

  Color _priorityColor(Priority p) => switch (p) {
        Priority.high => AppColors.priorityHigh,
        Priority.medium => AppColors.priorityMedium,
        Priority.low => AppColors.priorityLow,
      };

  String _priorityLabel(Priority p) => switch (p) {
        Priority.high => 'P1',
        Priority.medium => 'P2',
        Priority.low => 'P3',
      };

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
  Widget _buildOverdueCard() {
    final task = _overdueTask;
    if (task == null) {
      // HOME-OVERDUE-OLD: margin EdgeInsets.fromLTRB(16, 16, 16, 0)
      return Container(
        // HOME-SPACING-V1
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 20, color: Color(0xFF22C55E)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tudo em dia!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
                Text('Nenhuma tarefa atrasada', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45))),
              ],
            ),
          ],
        ),
      );
    }

    // HOME-OVERDUE-OLD: margin EdgeInsets.fromLTRB(16, 16, 16, 0)
    // HOME-OVERDUE-OLD: padding EdgeInsets.all(16)
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      // HOME-OVERDUE-V1
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: _liquidGlassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedAlert01, size: 12, color: _overdueColor),
              const SizedBox(width: 6),
              // HOME-OVERDUE-OLD: fontSize: 11
              Text(
                'TAREFA ATRASADA',
                // HOME-OVERDUE-V1
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _overdueColor),
              ),
            ],
          ),
          // HOME-OVERDUE-OLD: SizedBox(height: 10)
          const SizedBox(height: 3),
          // HOME-OVERDUE-OLD: fontSize: 20
          Text(
            task.title,
            // HOME-OVERDUE-V1
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // HOME-OVERDUE-OLD: SizedBox(height: 8)
          const SizedBox(height: 4),
          if (task.dueDate != null)
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 13, color: _overdueColor),
                const SizedBox(width: 4),
                // HOME-OVERDUE-OLD: fontSize: 12
                Text(_formatOverdueDate(task.dueDate!), style: TextStyle(fontSize: 11, color: _overdueColor)),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (task.priority != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _priorityColor(task.priority!).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: _priorityColor(task.priority!), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _priorityLabel(task.priority!),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _priorityColor(task.priority!)),
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
              // HOME-OVERDUE-OLD: width/height: 36
              GestureDetector(
                onTap: () => showTaskDetailSheet(context, task, onSaved: _loadTasks),
                child: Container(
                  // HOME-OVERDUE-V1
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 14, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CARD HOJE ────────────────────────────────────────
  // TODAY-EMPTY-OLD: if (_todayTotal == 0) return const SizedBox.shrink();
  Widget _buildTodayCard() {
    if (_todayTotal == 0) {
      // HOME-TODAY-OLD: margin EdgeInsets.fromLTRB(16, 12, 16, 0)
      return Container(
        // HOME-SPACING-V1
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 18, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            Text('Nenhuma tarefa para hoje', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      );
    }
    final percent = ((_todayDone / _todayTotal) * 100).round();

    // HOME-TODAY-OLD: margin EdgeInsets.fromLTRB(16, 12, 16, 0)
    // HOME-TODAY-OLD: padding EdgeInsets.all(16)
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      // HOME-TODAY-V1
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: _liquidGlassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HOME-TODAY-OLD: "Hoje" e contagem em Column (linhas separadas)
          // HOME-TODAY-V1: título e contagem inline
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Hoje', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(
                ' · $_todayTotal tarefa${_todayTotal == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              // HOME-TODAY-OLD: fontSize: 22
              Text(
                '$percent%',
                // HOME-TODAY-V1
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF22C55E)),
              ),
              const SizedBox(width: 4),
              Text('concluídas', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          // HOME-TODAY-OLD: SizedBox(height: 12)
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _todayTotal > 0 ? _todayDone / _todayTotal : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
              // HOME-TODAY-OLD: minHeight: 6
              minHeight: 3.0,
            ),
          ),
          // HOME-TODAY-OLD: SizedBox(height: 8)
          const SizedBox(height: 5),
          // HOME-TODAY-OLD: fontSize: 12
          Text(
            '$_todayDone concluídas • ${_todayTotal - _todayDone} restantes',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildShortcutItem(
              // HOME-SHORTCUTS-OLD: icon: Icons.inbox_rounded,
              icon: HugeIcons.strokeRoundedInbox,
              label: 'Inbox',
              count: _inboxCount,
              color: const Color(0xFF246FE0),
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildShortcutItem(
              // HOME-SHORTCUTS-OLD: icon: Icons.calendar_today_rounded,
              icon: HugeIcons.strokeRoundedCalendar01,
              label: 'Hoje',
              count: _todayTotal,
              color: const Color(0xFF22C55E),
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildShortcutItem(
              // HOME-SHORTCUTS-OLD: icon: Icons.schedule_rounded,
              icon: HugeIcons.strokeRoundedClock01,
              label: 'Em breve',
              count: _upcomingCount,
              color: const Color(0xFFEB8909),
              onTap: () => widget.onNavigateToTab?.call(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildShortcutItem(
              // HOME-SHORTCUTS-OLD: icon: Icons.filter_list_rounded,
              icon: HugeIcons.strokeRoundedFilterHorizontal,
              label: 'Filtros',
              count: _filterCount,
              color: const Color(0xFF884DFF),
              onTap: () => widget.onNavigateToTab?.call(4),
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // HOME-SHORTCUTS-OLD: Container 40x40, BoxDecoration retangular
            // com color: color.withValues(alpha: 0.15), borderRadius: 12,
            // child: Icon(icon, size: 20, color: color)
            // HOME-SHORTCUTS-V1: bolinha neutra, ícone colorido
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(icon: icon, size: 14, color: color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text('$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── SEÇÃO PROJETOS ───────────────────────────────────
  // HOME-PROJECTS-OLD: Padding solta, sem container/fundo/borda — seção
  // visualmente "flutuando" diferente dos cards de tarefa atrasada/hoje.
  Widget _buildProjectsList() {
    return Padding(
      // HOME-SPACING-V1
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      // HOME-PROJECTS-V1: mesmo estilo visual dos cards acima
      child: Container(
        decoration: _liquidGlassDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Text('Projetos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                GestureDetector(
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
            const SizedBox(height: 12),
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
                              // HOME-PROJECTS-V1: divisor interno
                              Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.08)),
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
    return GestureDetector(
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
              project: ProjectSheetData(id: p.id, name: p.name),
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
        // HOME-PROJECTS-V1
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            // PROJECT-SIZE-OLD: width: 36, height: 36, borderRadius: 9, HugeIcon size: 18
            // PROJECT-SIZE-V2
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: p.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7)),
              // PROJECT-ICONS-OLD: child: Icon(_iconFromName(p.iconName), size: 18, color: p.color),
              child: HugeIcon(icon: ProjectIcons.resolve(p.iconName), size: 14, color: p.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(p.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            ),
            if (p.taskCount > 0)
              Text('${p.taskCount}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
