import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'live_service.dart';
import 'notification_service.dart';

const backgroundResultsTask = 'ti-background-results-sync';
const backgroundResultsUniqueName = 'ti-background-results-periodic';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(notificationsEnabledKey) ?? false;
    if (!enabled) return true;

    final liveService = LiveResultsService();
    try {
      final feed = await liveService.fetch();
      final notifications = NotificationService();
      await notifications.initialize();
      await notifications.notifyForNewSeries(feed.series);
      return true;
    } catch (_) {
      // Returning false lets Android retry according to WorkManager policy.
      return false;
    } finally {
      liveService.close();
    }
  });
}

Future<void> configureBackgroundResultChecks() async {
  await Workmanager().initialize(backgroundCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    backgroundResultsUniqueName,
    backgroundResultsTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
