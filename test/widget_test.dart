import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readbook/main.dart';

void main() {
  testWidgets('App builds with ProviderScope', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ReadBookApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
