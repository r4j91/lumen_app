import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../services/supabase_client.dart';
import '../../theme/app_colors.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => NotificationsSheetState();
}

class NotificationsSheetState extends State<NotificationsSheet> {
  List<Map<String, dynamic>> _upcoming = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('tasks')
          .select('id, titulo, data_vencimento')
          .eq('user_id', userId)
          .eq('concluida', false)
          .gte('data_vencimento', now)
          .order('data_vencimento')
          .limit(20);
      if (mounted) {
        setState(() {
          _upcoming = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final topPad = view.padding.top / view.devicePixelRatio;
    final botPad = view.padding.bottom / view.devicePixelRatio;
    return Container(
      margin: EdgeInsets.only(top: topPad + 60),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Próximas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                  )
                : _upcoming.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedNotification01,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma notificação agendada',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: botPad + 16),
                        itemCount: _upcoming.length,
                        itemBuilder: (_, i) {
                          final item = _upcoming[i];
                          final due = DateTime.tryParse(item['data_vencimento'] ?? '');
                          final today = DateTime.now();
                          final diff = due == null
                              ? null
                              : DateTime(due.year, due.month, due.day)
                                  .difference(DateTime(today.year, today.month, today.day))
                                  .inDays;
                          final label = diff == null
                              ? ''
                              : diff == 0
                                  ? 'Hoje'
                                  : diff == 1
                                      ? 'Amanhã'
                                      : 'Em $diff dias';
                          return ListTile(
                            leading: HugeIcon(
                              icon: HugeIcons.strokeRoundedNotification01,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            title: Text(
                              item['titulo'] ?? '',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: label.isNotEmpty
                                ? Text(
                                    label,
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  )
                                : null,
                            dense: true,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
