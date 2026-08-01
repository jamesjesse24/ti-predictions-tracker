import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ti_predictions_tracker/main.dart';

void main() {
  testWidgets('shows compact professional dashboard', (tester) async {
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
      find.text('Latest results'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Latest results'), findsOneWidget);
    expect(find.text('No completed series yet'), findsOneWidget);
    expect(find.text('Field snapshot'), findsOneWidget);
  });
}
