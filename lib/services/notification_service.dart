import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'lumen_tasks';
  static const _channelName = 'Tarefas';
  static const _prefEnabled = 'notifications_enabled';
  static const _prefDefaultHour = 'notifications_default_hour';
  static const _prefDefaultMinute = 'notifications_default_minute';
  static const _prefDailySummary = 'notifications_daily_summary';

  // ── Inicialização ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const ios = fln.DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const android = fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const fln.InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // ── Permissão ──────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                fln.IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, granted);
    return granted;
  }

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    if (!value) await cancelAllNotifications();
  }

  // ── Configurações ──────────────────────────────────────────────────────────

  Future<({int hour, int minute})> get defaultTime async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_prefDefaultHour) ?? 9,
      minute: prefs.getInt(_prefDefaultMinute) ?? 0,
    );
  }

  Future<void> setDefaultTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDefaultHour, hour);
    await prefs.setInt(_prefDefaultMinute, minute);
  }

  Future<bool> get dailySummaryEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefDailySummary) ?? false;
  }

  Future<void> setDailySummaryEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDailySummary, value);
  }

  // ── Agendamento ────────────────────────────────────────────────────────────

  Future<void> scheduleTaskNotification(
      String id, String title, DateTime dueDate) async {
    if (!await isEnabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return; // já vencida, não notificar

    final time = await defaultTime;
    final scheduled = tz.TZDateTime(
      tz.local,
      dueDate.year, dueDate.month, dueDate.day,
      time.hour, time.minute,
    );
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    final body = diff == 0
        ? 'Vence hoje'
        : diff == 1
            ? 'Vence amanhã'
            : 'Vence em $diff dias';

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

  Future<void> scheduleTaskReminder(
      String id, String title, DateTime reminderTime) async {
    if (!await isEnabled) return;

    final scheduled = tz.TZDateTime.from(reminderTime, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _notifId(id),
      title,
      'Lembrete de tarefa',
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
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
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

  Future<void> cancelTaskNotification(String id) async {
    await _plugin.cancel(_notifId(id));
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int _notifId(String taskId) {
    final hex = taskId.replaceAll('-', '');
    final s = hex.length >= 8 ? hex.substring(hex.length - 8) : hex;
    return int.parse(s, radix: 16) & 0x7FFFFFFF;
  }

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
