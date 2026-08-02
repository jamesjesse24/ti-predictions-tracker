import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const backgroundResultsTask = 'ti-background-results-sync';
const backgroundResultsUniqueName = 'ti-background-results-periodic';

const _notificationsEnabledKey = 'ti_notifications_enabled_v1';
const _backgroundChannel = MethodChannel(
  'com.jamesjesse24.ti_predictions_tracker/background',
);

/// Schedules native AndroidX WorkManager polling without depending on the
/// incompatible Flutter workmanager plugin. Existing work is preserved across
/// process death and device restarts by Android itself.
Future<bool> configureBackgroundResultChecks({
  Iterable<String>? currentSeriesIds,
}) async {
  if (kIsWeb || !Platform.isAndroid) return true;

  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_notificationsEnabledKey) ?? false;
    if (!enabled) {
      await disableBackgroundResultChecks();
      return true;
    }

    final arguments = <String, Object?>{};
    if (currentSeriesIds != null) {
      arguments['seriesIds'] = currentSeriesIds.toSet().toList()..sort();
    }

    return await _backgroundChannel.invokeMethod<bool>(
          'enable',
          arguments,
        ) ??
        true;
  } catch (_) {
    // Background polling is optional. Foreground refresh and notifications
    // remain available even when an OEM blocks WorkManager scheduling.
    return false;
  }
}

Future<void> disableBackgroundResultChecks() async {
  if (kIsWeb || !Platform.isAndroid) return;

  try {
    await _backgroundChannel.invokeMethod<void>('disable');
  } catch (_) {
    // Disabling remains safe when the native bridge is unavailable.
  }
}
