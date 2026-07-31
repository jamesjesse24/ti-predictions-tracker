import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_predictions_tracker/main.dart';

void main() {
  testWidgets('shows automatic results dashboard', (tester) async {
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

    expect(find.text('Automatic feed: offline'), findsOneWidget);
    expect(find.text('Prediction performance'), findsOneWidget);
    expect(find.text('Latest completed series'), findsOneWidget);
  });
}
