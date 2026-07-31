import 'package:flutter_test/flutter_test.dart';
import 'package:ti_predictions_tracker/main.dart';

void main() {
  testWidgets('shows the TI prediction dashboard', (tester) async {
    final controller = TrackerController.memory();

    await tester.pumpWidget(TrackerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Command Center'), findsOneWidget);
    expect(find.text('Prediction performance'), findsOneWidget);
    expect(find.text('TEAM VISION'), findsWidgets);
  });
}
