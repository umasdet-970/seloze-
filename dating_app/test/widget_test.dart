import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_dating_app/main.dart';

void main() {
  testWidgets('App boots and renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ConnectApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
