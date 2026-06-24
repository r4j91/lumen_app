import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/haptic_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';

// SQL para rodar no Supabase antes de usar:
// ALTER TABLE profiles ADD COLUMN IF NOT EXISTS apelido text;
// ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url text;
// ALTER TABLE profiles ADD COLUMN IF NOT EXISTS meta_diaria integer DEFAULT 5;

Future<void> showProductivitySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProductivitySheet(),
  );
}

class _ProductivitySheet extends StatefulWidget {
  const _ProductivitySheet();
  @override
  State<_ProductivitySheet> createState() => _ProductivitySheetState();
}

class _ProductivitySheetState extends State<_ProductivitySheet> {
  int _tab = 1; // 0=Config, 1=Diário, 2=Semanal, 3=Karma
  bool _loading = true;

  // Dados brutos do Supabase
  List<DateTime> _completionDates = [];
  int _totalCompleted = 0;

  // Preferências
  int _dailyGoal = 5;

  // Perfil
  String _displayName = '';
  String? _avatarPath;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Recarrega quando o perfil é salvo (foto, nome, apelido)
    _authSub = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyGoal = prefs.getInt('meta_diaria') ?? 5;

    try {
      final taskRows = await supabase
          .from('tasks')
          .select('data_vencimento')
          .eq('concluida', true)
          .not('data_vencimento', 'is', null)
          .order('data_vencimento', ascending: false);

      // Carregar nome dos user metadata (sem tabela profiles)
      final meta = supabase.auth.currentUser?.userMetadata ?? {};
      final apelido = (meta['apelido'] as String? ?? '').trim();
      final nome = (meta['nome'] as String? ?? '').trim();
      _displayName = apelido.isNotEmpty
          ? apelido
          : nome.isNotEmpty
              ? nome.split(' ').first
              : supabase.auth.currentUser?.email?.split('@').first ?? '';
      _avatarPath = meta['avatar_url'] as String?;

      _completionDates = taskRows
          .map((r) => DateTime.tryParse(r['data_vencimento'] as String? ?? ''))
          .whereType<DateTime>()
          .toList();
      _totalCompleted = _completionDates.length;
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  // ── Métricas ───────────────────────────────────────────────────────────────

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int get _todayCount => _completionDates
      .where((d) => DateTime(d.year, d.month, d.day) == _today)
      .length;

  /// Dias seguidos com pelo menos 1 tarefa concluída
  int get _currentStreak {
    final Set<DateTime> days = _completionDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    int streak = 0;
    var day = _today;
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Streak mais longa já registrada e suas datas de início/fim
  ({int length, DateTime? start, DateTime? end}) get _longestStreak {
    if (_completionDates.isEmpty) return (length: 0, start: null, end: null);
    final days = _completionDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();

    int best = 1, cur = 1;
    DateTime bestStart = days.first, bestEnd = days.first, curStart = days.first;

    for (int i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        cur++;
        if (cur > best) {
          best = cur;
          bestStart = curStart;
          bestEnd = days[i];
        }
      } else {
        cur = 1;
        curStart = days[i];
      }
    }
    return (length: best, start: bestStart, end: bestEnd);
  }

  List<int> get _last7Days {
    return List.generate(7, (i) {
      final day = _today.subtract(Duration(days: 6 - i));
      return _completionDates
          .where((d) => DateTime(d.year, d.month, d.day) == day)
          .length;
    });
  }

  int get _thisWeekTotal {
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    return _completionDates
        .where((d) => !DateTime(d.year, d.month, d.day).isBefore(monday))
        .length;
  }

  int get _lastWeekTotal {
    final thisMonday = _today.subtract(Duration(days: _today.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    return _completionDates.where((d) {
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(lastMonday) && day.isBefore(thisMonday);
    }).length;
  }

  List<int> get _weekByDay {
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      return _completionDates
          .where((d) => DateTime(d.year, d.month, d.day) == day)
          .length;
    });
  }

  int get _karma => _totalCompleted;

  String get _karmaLevel {
    if (_karma >= 500) return 'Platina';
    if (_karma >= 200) return 'Ouro';
    if (_karma >= 50) return 'Prata';
    return 'Bronze';
  }

  Color get _karmaColor {
    if (_karma >= 500) return const Color(0xFF7FD7F0);
    if (_karma >= 200) return const Color(0xFFFFD166);
    if (_karma >= 50) return const Color(0xFFB0B8C1);
    return const Color(0xFFCD7F32);
  }

  double get _karmaProgress {
    if (_karma >= 500) return 1.0;
    if (_karma >= 200) return (_karma - 200) / 300;
    if (_karma >= 50) return (_karma - 50) / 150;
    return _karma / 50;
  }

  int get _karmaNextLevel {
    if (_karma >= 500) return 500;
    if (_karma >= 200) return 500;
    if (_karma >= 50) return 200;
    return 50;
  }

  String get _karmaNextName {
    if (_karma >= 500) return 'Platina (máximo)';
    if (_karma >= 200) return 'Platina';
    if (_karma >= 50) return 'Ouro';
    return 'Prata';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header: chips + fechar
          _buildHeader(context),
          // Body
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                : _buildContent(mq),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text('Produtividade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MediaQueryData mq) {
    return CustomScrollView(
      slivers: [
        // Card de perfil
        SliverToBoxAdapter(child: _buildProfileCard()),
        // Segmented control
        SliverToBoxAdapter(child: _buildSegmentedControl()),
        // Conteúdo da aba
        SliverToBoxAdapter(child: _buildTabContent(mq)),
        SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 24)),
      ],
    );
  }

  Widget _buildProfileCard() {
    final email = supabase.auth.currentUser?.email ?? '';
    final initials = _displayName.isNotEmpty
        ? _displayName.substring(0, math.min(2, _displayName.length)).toUpperCase()
        : email.substring(0, math.min(2, email.length)).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _AvatarWidget(path: _avatarPath, initials: initials, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName.isNotEmpty ? _displayName : email.split('@').first,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_totalCompleted tarefas concluídas',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    const tabs = ['Diário', 'Semanal', 'Karma'];
    // Map tab index: 1=Diário, 2=Semanal, 3=Karma
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final tabIndex = i + 1;
            final active = _tab == tabIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () { HapticService().tabChanged(); setState(() => _tab = tabIndex); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.surfaceVariant : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent(MediaQueryData mq) {
    switch (_tab) {
      case 1: return _buildDailyTab();
      case 2: return _buildWeeklyTab();
      case 3: return _buildKarmaTab();
      default: return const SizedBox.shrink();
    }
  }

  // ── Aba Diária ─────────────────────────────────────────────────────────────

  Widget _buildDailyTab() {
    final streak = _currentStreak;
    final longest = _longestStreak;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Objetivo diário
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, size: 18, color: const Color(0xFFFFD166)),
                    const SizedBox(width: 8),
                    Text('Objetivo diário', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _editDailyGoal,
                      child: Text('Editar', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '$_todayCount',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1),
                    ),
                    Text(
                      ' / $_dailyGoal',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.textTertiary, height: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_todayCount / math.max(1, _dailyGoal)).clamp(0.0, 1.0),
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Streak
          _buildCard(
            child: Row(
              children: [
                Text('🔥', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$streak',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'dias seguidos',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (longest.length > 0 && longest.start != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Mais longa: ${longest.length} dias  '
                          '(${_fmtDate(longest.start!)} – ${_fmtDate(longest.end!)})',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Gráfico últimos 7 dias
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Últimos 7 dias', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                _HorizontalBarChart(values: _last7Days, maxValue: math.max(1, _last7Days.reduce(math.max))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDailyGoal() async {
    final ctrl = TextEditingController(text: '$_dailyGoal');
    try { await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Meta diária', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Número de tarefas',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('meta_diaria', val);
                if (mounted) setState(() => _dailyGoal = val);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text('Salvar', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ); } finally { ctrl.dispose(); }
  }

  // ── Aba Semanal ────────────────────────────────────────────────────────────

  Widget _buildWeeklyTab() {
    final thisWeek = _thisWeekTotal;
    final lastWeek = _lastWeekTotal;
    final diff = lastWeek == 0 ? null : ((thisWeek - lastWeek) / lastWeek * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Totais semana
          Row(
            children: [
              Expanded(
                child: _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Esta semana', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(height: 6),
                      Text('$thisWeek', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)),
                      Text('tarefas', style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Semana anterior', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(height: 6),
                      Text('$lastWeek', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)),
                      if (diff != null)
                        Row(
                          children: [
                            Icon(
                              diff >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 13,
                              color: diff >= 0 ? AppColors.tagGreen : AppColors.priorityHigh,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${diff.abs()}%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: diff >= 0 ? AppColors.tagGreen : AppColors.priorityHigh,
                              ),
                            ),
                          ],
                        )
                      else
                        Text('—', style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Por dia da semana', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                _HorizontalBarChart(
                  values: _weekByDay,
                  maxValue: math.max(1, _weekByDay.reduce(math.max)),
                  labels: const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aba Karma ──────────────────────────────────────────────────────────────

  Widget _buildKarmaTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Pontuação + nível
          _buildCard(
            child: Row(
              children: [
                _KarmaBadge(level: _karmaLevel, color: _karmaColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_karmaLevel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _karmaColor)),
                      const SizedBox(height: 2),
                      Text('$_karma pontos de karma', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Progresso para próximo nível
          if (_karma < 500)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Próximo nível: $_karmaNextName', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('$_karma / $_karmaNextLevel', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _karmaProgress,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(_karmaColor),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Faltam ${_karmaNextLevel - _karma} tarefas para $_karmaNextName',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Escala de níveis
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Escala de níveis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ...[
                  ('Bronze',  0,   50,   const Color(0xFFCD7F32)),
                  ('Prata',   50,  200,  const Color(0xFFB0B8C1)),
                  ('Ouro',    200, 500,  const Color(0xFFFFD166)),
                  ('Platina', 500, null, const Color(0xFF7FD7F0)),
                ].map((e) {
                  final (name, from, to, color) = e;
                  final isActive = _karmaLevel == name;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                              color: isActive ? color : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          to == null ? '$from+ pts' : '$from – $to pts',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 14, color: color),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ── Gráfico de barras horizontais ─────────────────────────────────────────────

class _HorizontalBarChart extends StatelessWidget {
  final List<int> values;
  final int maxValue;
  final List<String>? labels;

  const _HorizontalBarChart({
    required this.values,
    required this.maxValue,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    // Default: últimos 7 dias
    final defaultLabels = List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      return dayNames[day.weekday - 1];
    });
    final usedLabels = labels ?? defaultLabels;

    return Column(
      children: List.generate(values.length, (i) {
        final val = values[i];
        final ratio = maxValue > 0 ? val / maxValue : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  usedLabels[i],
                  style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) => Stack(
                    children: [
                      // Background track
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Filled bar with gradient
                      AnimatedContainer(
                        duration: Duration(milliseconds: 400 + i * 60),
                        curve: Curves.easeOutCubic,
                        height: 20,
                        width: constraints.maxWidth * ratio,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF5FD3DC)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text(
                  '$val',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: val > 0 ? AppColors.textSecondary : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Widgets menores ───────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String? path;
  final String initials;
  final double size;
  const _AvatarWidget({this.path, required this.initials, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = path != null && File(path!).existsSync();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: 0.15),
        image: hasPhoto
            ? DecorationImage(image: FileImage(File(path!)), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
    );
  }
}

class _KarmaBadge extends StatelessWidget {
  final String level;
  final Color color;
  const _KarmaBadge({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      child: Center(
        child: Text(
          level[0],
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
        ),
      ),
    );
  }
}
