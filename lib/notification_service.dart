import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_worker.dart';
import 'live_models.dart';

const notificationsEnabledKey = 'ti_notifications_enabled_v1';
const notifiedSeriesKey = 'ti_notified_series_v1';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'ti_result_updates';
  static const _channelName = 'TI result updates';
  static const _channelDescription =
      'Completed series, standings changes, and prediction results.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _available = true;

  bool get isAvailable => _available;

  Future<void> initialize() async {
    if (_initialized || !_available) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_ti'),
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (_) {},
      );
      _initialized = true;
    } catch (_) {
      // Notifications are optional. A missing Android resource, unsupported
      // plugin implementation, or vendor-specific initialization failure must
      // never prevent the main application from opening.
      _available = false;
      _initialized = false;
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_available) return false;
    if (!Platform.isAndroid) return true;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationsEnabledKey) ?? false;
  }

  Future<void> setEnabled(
    bool enabled, {
    Iterable<String> currentSeriesIds = const [],
  }) async {
    final active = enabled && _available;
    final ids = currentSeriesIds.toSet().toList()..sort();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(notificationsEnabledKey, active);
    if (active) {
      await prefs.setStringList(notifiedSeriesKey, ids);
      await configureBackgroundResultChecks(currentSeriesIds: ids);
    } else {
      await disableBackgroundResultChecks();
    }
  }

  Future<List<LiveSeries>> notifyForNewSeries(
    Iterable<LiveSeries> allSeries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationsEnabledKey) ?? false)) {
      return const [];
    }

    final completed = allSeries.where((item) => item.completed).toList()
      ..sort((a, b) =>
          (a.startedAt ?? DateTime(1970)).compareTo(b.startedAt ?? DateTime(1970)));
    final currentIds = completed.map((item) => item.id).toSet();
    final storedIds = prefs.getStringList(notifiedSeriesKey);

    if (storedIds == null) {
      await prefs.setStringList(notifiedSeriesKey, currentIds.toList()..sort());
      return const [];
    }

    final seen = storedIds.toSet();
    final fresh = completed.where((item) => !seen.contains(item.id)).toList();
    if (fresh.isEmpty) return const [];

    await initialize();
    if (!_available) {
      await prefs.setBool(notificationsEnabledKey, false);
      await disableBackgroundResultChecks();
      return const [];
    }

    final latest = fresh.last;
    final title = fresh.length == 1
        ? 'TI result: ${latest.winner} wins'
        : '${fresh.length} new TI results';
    final body = fresh.length == 1
        ? '${latest.teamA} ${latest.scoreA}–${latest.scoreB} ${latest.teamB} • ${latest.stage}'
        : '${fresh.take(3).map(_seriesLine).join('  •  ')}${fresh.length > 3 ? '  •  +${fresh.length - 3} more' : ''}';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_ti',
      ticker: 'New TI tournament result',
      category: AndroidNotificationCategory.status,
      groupKey: 'ti_2026_results',
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title: title,
        body: body,
        notificationDetails: details,
        payload: 'dashboard',
      );
      await prefs.setStringList(notifiedSeriesKey, currentIds.toList()..sort());
      return fresh;
    } catch (_) {
      _available = false;
      await prefs.setBool(notificationsEnabledKey, false);
      await disableBackgroundResultChecks();
      return const [];
    }
  }

  Future<void> showTestNotification() async {
    await initialize();
    if (!_available) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_ti',
      ),
    );

    try {
      await _plugin.show(
        id: 2026,
        title: 'TI alerts are ready',
        body: 'You will be notified when a new completed series is synced.',
        notificationDetails: details,
        payload: 'settings',
      );
    } catch (_) {
      _available = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(notificationsEnabledKey, false);
      await disableBackgroundResultChecks();
    }
  }
}

String _seriesLine(LiveSeries series) =>
    '${series.teamA} ${series.scoreA}–${series.scoreB} ${series.teamB}';
