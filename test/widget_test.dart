import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const RepCounterApp(showOnboarding: false));
    expect(find.text('Rep AI'), findsOneWidget);
  });
}
