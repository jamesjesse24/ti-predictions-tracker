import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_predictions_tracker/main.dart';

void main() {
  testWidgets('shows redesigned TI command center', (tester) async {
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

    expect(find.text('THE INTERNATIONAL\nPREDICTION COMMAND'), findsOneWidget);
    expect(find.text('Prediction performance'), findsOneWidget);
    expect(find.text('Latest completed series'), findsOneWidget);
    expect(find.text('Enable result alerts'), findsOneWidget);
  });
}
