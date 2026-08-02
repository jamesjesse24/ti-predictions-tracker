import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'background_worker.dart';
import 'professional_app.dart';
import 'tracker_controller.dart';

export 'professional_app.dart';
export 'tracker_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await TrackerController.load();
  runApp(TrackerApp(controller: controller));

  unawaited(controller.hydrateTeamLogos());
  unawaited(_initializeOptionalServices(controller));
}

Future<void> _initializeOptionalServices(
  TrackerController controller,
) async {
  try {
    await controller.initializeNotifications();
  } catch (_) {
    // Notifications are optional and never block startup.
  }

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await configureBackgroundResultChecks();
    } catch (_) {
      // Foreground result synchronization remains available.
    }
  }
}
