import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_admin_dashboard/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));
    await tester.pumpAndSettle();

    expect(find.text('Connect Admin'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
