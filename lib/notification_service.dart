import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> initialize() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_ti'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (_) {},
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationsEnabledKey) ?? false;
  }

  Future<void> setEnabled(
    bool enabled, {
    Iterable<String> currentSeriesIds = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsEnabledKey, enabled);
    if (enabled) {
      await prefs.setStringList(
        notifiedSeriesKey,
        currentSeriesIds.toSet().toList()..sort(),
      );
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

    // A migration or first launch should establish a baseline rather than send
    // a burst of notifications for every historical result.
    if (storedIds == null) {
      await prefs.setStringList(notifiedSeriesKey, currentIds.toList()..sort());
      return const [];
    }

    final seen = storedIds.toSet();
    final fresh = completed.where((item) => !seen.contains(item.id)).toList();
    if (fresh.isEmpty) return const [];

    await initialize();
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

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'dashboard',
    );

    await prefs.setStringList(notifiedSeriesKey, currentIds.toList()..sort());
    return fresh;
  }

  Future<void> showTestNotification() async {
    await initialize();
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
    await _plugin.show(
      id: 2026,
      title: 'TI alerts are ready',
      body: 'You will be notified when a new completed series is synced.',
      notificationDetails: details,
      payload: 'settings',
    );
  }
}

String _seriesLine(LiveSeries series) =>
    '${series.teamA} ${series.scoreA}–${series.scoreB} ${series.teamB}';
