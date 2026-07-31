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
    try {
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
      } finally {
        liveService.close();
      }
    } catch (_) {
      // WorkManager may retry later. The background isolate must never bring
      // down the main application process because an OEM blocks scheduling,
      // a plugin is unavailable, or the network request fails.
      return false;
    }
  });
}

Future<bool> configureBackgroundResultChecks() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(notificationsEnabledKey) ?? false;

    // Do not initialize WorkManager during normal startup until the user has
    // explicitly enabled result notifications. This avoids making an optional
    // service part of the app's critical launch path.
    if (!enabled) return true;

    await Workmanager().initialize(backgroundCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundResultsUniqueName,
      backgroundResultsTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> disableBackgroundResultChecks() async {
  try {
    await Workmanager().cancelByUniqueName(backgroundResultsUniqueName);
  } catch (_) {
    // Disabling alerts must remain safe even when WorkManager was never
    // initialized successfully on this device.
  }
}
