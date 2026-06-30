import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'supabase_client.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'stacked_tasks';
  static const _legacyChannelId = 'lumen_tasks';
  static const _prefChannelMigrated = 'notifications_channel_migrated_v2';
  static const _channelName = 'Tarefas';
  static const _prefEnabled = 'notifications_enabled';
  static const _prefDailySummary = 'notifications_daily_summary';

  // ── Inicialização ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _configureLocalTimeZone();

    const ios = fln.DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const android = fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const fln.InitializationSettings(android: android, iOS: ios),
    );
    await _migrateNotificationChannel();
    _initialized = true;
  }

  void _configureLocalTimeZone() {
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  /// Migra canal Android legado `lumen_tasks` → `stacked_tasks`.
  Future<void> _migrateNotificationChannel() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefChannelMigrated) ?? false) return;
    await _plugin.cancelAll();
    await prefs.setBool(_prefChannelMigrated, true);
    // _legacyChannelId mantido só como referência do id antigo.
    assert(_legacyChannelId == 'lumen_tasks');
  }

  // ── Permissão ──────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        fln.IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabled, granted ?? false);
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabled, granted ?? false);
      return granted ?? false;
    }

    return false;
  }

  Future<bool> _hasSystemPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        fln.IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final settings = await ios.checkPermissions();
      return settings?.isAlertEnabled ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? true;
    }

    return true;
  }

  /// Preferência do usuário no app + permissão do sistema.
  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    final userWants = prefs.getBool(_prefEnabled) ?? false;
    if (!userWants) return false;
    return _hasSystemPermission();
  }

  Future<bool> loadEnabledState() async => isEnabled;

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    if (!value) await cancelAllNotifications();
  }

  // ── Configurações ──────────────────────────────────────────────────────────

  Future<bool> get dailySummaryEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefDailySummary) ?? false;
  }

  Future<void> setDailySummaryEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDailySummary, value);
    if (value) {
      await _scheduleDailySummaryIfNeeded();
    } else {
      await _plugin.cancel(99999);
    }
  }

  // ── Agendamento ────────────────────────────────────────────────────────────

  Future<void> scheduleTaskNotification(
    String id,
    String title,
    DateTime dueDate, {
    String? time,
  }) async {
    if (!await isEnabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return;

    final resolved = _resolveScheduleTime(time, dueDate);
    if (resolved == null) return;

    final scheduled = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      resolved.hour,
      resolved.minute,
    );
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    final timeLabel =
        '${resolved.hour.toString().padLeft(2, '0')}:${resolved.minute.toString().padLeft(2, '0')}';

    final body = diff == 0
        ? 'Hoje às $timeLabel'
        : diff == 1
            ? 'Amanhã às $timeLabel'
            : 'Vence em $diff dias às $timeLabel';

    await _plugin.zonedSchedule(
      _notifId(id),
      title,
      body,
      scheduled,
      _details(),
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Lembrete em horário específico (ex.: 15 min antes do vencimento).
  Future<void> scheduleTaskReminder(
    String id,
    String title,
    DateTime reminderTime, {
    String body = 'Lembrete de tarefa',
  }) async {
    if (!await isEnabled) return;

    final scheduled = tz.TZDateTime.from(reminderTime, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _reminderNotifId(id),
      title,
      body,
      scheduled,
      _details(),
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleDailySummary(int taskCount) async {
    if (!await isEnabled) return;
    if (!await dailySummaryEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      99999,
      'Resumo do dia',
      taskCount == 1
          ? 'Você tem 1 tarefa para hoje'
          : 'Você tem $taskCount tarefas para hoje',
      scheduled,
      _details(),
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: fln.DateTimeComponents.time,
    );
  }

  /// Re-agenda todas as tarefas pendentes com data (ex.: ao abrir o app).
  Future<void> rescheduleAllPending() async {
    if (!await isEnabled) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final rows = await supabase
          .from('tasks')
          .select('id, titulo, data_vencimento, hora')
          .eq('user_id', userId)
          .eq('concluida', false)
          .gte('data_vencimento', todayStr);

      await cancelAllNotifications();

      for (final row in rows) {
        final id = row['id'].toString();
        final title = row['titulo'] as String? ?? '';
        final due = _parseDueDate(row['data_vencimento']);
        if (due == null) continue;
        final hora = row['hora'] as String?;
        if (hora == null && !_dueDateHasTime(due)) continue;
        await scheduleTaskNotification(
          id,
          title,
          due,
          time: hora,
        );
      }

      await _scheduleDailySummaryIfNeeded();
    } catch (e, st) {
      debugPrint('NotificationService.rescheduleAllPending failed: $e\n$st');
    }
  }

  Future<void> cancelTaskNotification(String id) async {
    await _plugin.cancel(_notifId(id));
    await _plugin.cancel(_reminderNotifId(id));
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  ({int hour, int minute})? _resolveScheduleTime(
    String? time,
    DateTime dueDate,
  ) {
    if (time != null && time.contains(':')) {
      final parts = time.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0');
      if (h != null && m != null) return (hour: h, minute: m);
    }

    if (_dueDateHasTime(dueDate)) {
      return (hour: dueDate.hour, minute: dueDate.minute);
    }

    return null;
  }

  bool _dueDateHasTime(DateTime dueDate) =>
      dueDate.hour != 0 || dueDate.minute != 0;

  DateTime? _parseDueDate(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  Future<void> _scheduleDailySummaryIfNeeded() async {
    if (!await dailySummaryEnabled) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final rows = await supabase
          .from('tasks')
          .select('id')
          .eq('user_id', userId)
          .eq('concluida', false)
          .eq('data_vencimento', todayStr);
      await scheduleDailySummary((rows as List).length);
    } catch (e) {
      debugPrint('NotificationService daily summary failed: $e');
    }
  }

  int _notifId(String taskId) {
    final hex = taskId.replaceAll('-', '');
    final s = hex.length >= 8 ? hex.substring(hex.length - 8) : hex;
    return int.parse(s, radix: 16) & 0x7FFFFFFF;
  }

  /// ID separado para lembretes (não colide com a notificação de vencimento).
  int _reminderNotifId(String taskId) => _notifId(taskId) ^ 0x40000000;

  fln.NotificationDetails _details() => const fln.NotificationDetails(
        iOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: fln.AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          enableVibration: true,
        ),
      );
}
