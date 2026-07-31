import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_predictions_tracker/group_stage_status_panel.dart';
import 'package:ti_predictions_tracker/tracker_controller.dart';

void main() {
  testWidgets('shows waiting state before group-stage results', (tester) async {
    final controller = TrackerController.memory();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupStageStatusPanel(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('Group Stage Status'), findsOneWidget);
    expect(find.text('WAITING'), findsWidgets);
    expect(
      find.text('Standings will appear after the first synchronized series.'),
      findsOneWidget,
    );
  });

  testWidgets('shows live records and settled outcomes', (tester) async {
    final controller = TrackerController.memory();
    controller.teams[0]
      ..wins = 4
      ..losses = 0
      ..mapWins = 8
      ..mapLosses = 2
      ..actual = '4-0'
      ..live = true;
    controller.teams[1]
      ..wins = 2
      ..losses = 1
      ..mapWins = 5
      ..mapLosses = 3
      ..live = true;
    controller.teams[15]
      ..wins = 0
      ..losses = 4
      ..mapWins = 1
      ..mapLosses = 8
      ..actual = '0-4'
      ..live = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupStageStatusPanel(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('DIRECT'), findsWidgets);
    expect(find.text('IN PLAY'), findsOneWidget);
    expect(find.text('OUT'), findsWidgets);
    expect(find.text('4-0'), findsOneWidget);
  });
}
