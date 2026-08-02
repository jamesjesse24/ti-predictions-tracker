import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_predictions_tracker/main.dart';
import 'package:ti_predictions_tracker/team_branding.dart';

void main() {
  testWidgets('shows the professional dashboard and branded field snapshot', (
    tester,
  ) async {
    final controller = TrackerController.memory();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not checked yet'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Group stage'), findsOneWidget);
    expect(find.text('Enable result alerts'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Field snapshot'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Latest results'), findsOneWidget);
    expect(find.text('No completed series yet'), findsOneWidget);
    expect(find.text('Field snapshot'), findsOneWidget);
    expect(find.byType(TeamLogo), findsWidgets);
  });

  testWidgets('control screen exposes feed and team-logo controls', (
    tester,
  ) async {
    final controller = TrackerController.memory();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Result alerts'), findsOneWidget);
    expect(find.text('Sync results'), findsOneWidget);
    expect(find.text('Feed status'), findsOneWidget);
    expect(find.text('Refresh team logos'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Clear logo cache'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Clear logo cache'), findsOneWidget);
    expect(find.text('Reset tracker'), findsOneWidget);
  });
}
