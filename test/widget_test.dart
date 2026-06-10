import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thesis/main.dart';

void main() {
  testWidgets('App opens smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GestureControlApp());

    expect(find.text('Gesture Control'), findsOneWidget);
  });
}