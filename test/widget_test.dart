import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_tracker/main.dart';

void main() {
  testWidgets('App renders login screen on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const SleepTrackerApp());
    expect(find.text('Welcome back 👋'), findsNothing); // login mode default
    await tester.pump(const Duration(milliseconds: 500));
  });
}
