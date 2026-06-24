import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  final _svc = NotificationService();

  bool _enabled = false;
  int _hour = 9;
  int _minute = 0;
  bool _dailySummary = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _svc.isEnabled;
    final time = await _svc.defaultTime;
    final daily = await _svc.dailySummaryEnabled;
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _hour = time.hour;
        _minute = time.minute;
        _dailySummary = daily;
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      final granted = await _svc.requestPermission();
      if (mounted) setState(() => _enabled = granted);
    } else {
      await _svc.setEnabled(false);
      if (mounted) setState(() => _enabled = false);
    }
  }

  Future<void> _pickTime() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        var tempH = _hour;
        var tempM = _minute;
        return Container(
          height: 280,
          color: AppColors.surface,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              CupertinoButton(
                child: Text('Cancelar',
                    style: TextStyle(color: AppColors.textSecondary)),
                onPressed: () => Navigator.pop(ctx),
              ),
              CupertinoButton(
                child: Text('OK',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w600)),
                onPressed: () async {
                  await _svc.setDefaultTime(tempH, tempM);
                  if (mounted) {
                    setState(() {
                      _hour = tempH;
                      _minute = tempM;
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ]),
            Expanded(
              child: Row(children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: _hour),
                    itemExtent: 44,
                    onSelectedItemChanged: (v) => tempH = v,
                    children: List.generate(
                      24,
                      (i) => Center(
                        child: Text(
                          '${i.toString().padLeft(2, '0')}h',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                        initialItem: _minute ~/ 15),
                    itemExtent: 44,
                    onSelectedItemChanged: (v) => tempM = v * 15,
                    children: [0, 15, 30, 45]
                        .map((m) => Center(
                              child: Text(
                                '${m.toString().padLeft(2, '0')}min',
                                style: TextStyle(
                                    color: AppColors.textPrimary, fontSize: 16),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Notificações',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Section(children: [
                  _Row(
                    icon: Icons.notifications_outlined,
                    label: 'Ativar notificações',
                    trailing: Switch.adaptive(
                      value: _enabled,
                      onChanged: _toggleEnabled,
                      activeThumbColor: AppColors.accent,
                    ),
                  ),
                ]),
                if (_enabled) ...[
                  const SizedBox(height: 20),
                  _Section(children: [
                    _Row(
                      icon: Icons.access_time_outlined,
                      label: 'Horário padrão',
                      trailing: GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _Section(children: [
                    _Row(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Resumo diário',
                      sublabel: 'Resumo das tarefas do dia às 8h da manhã',
                      trailing: Switch.adaptive(
                        value: _dailySummary,
                        onChanged: (v) async {
                          await _svc.setDailySummaryEnabled(v);
                          if (mounted) setState(() => _dailySummary = v);
                        },
                        activeThumbColor: AppColors.accent,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  Text(
                    'As notificações são agendadas automaticamente quando você salva uma tarefa com data de vencimento.',
                    style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.icon,
      required this.label,
      this.sublabel,
      required this.trailing});
  final IconData icon;
  final String label;
  final String? sublabel;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(sublabel!,
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                ],
              ]),
        ),
        trailing,
      ]),
    );
  }
}
