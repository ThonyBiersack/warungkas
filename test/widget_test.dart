// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tingtongapp/main.dart';

void main() {
  // Initialize sqflite_ffi for testing environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WarungKasApp());

    // Verify that our splash screen starts with 'WARUNGKAS' text.
    expect(find.text('WARUNGKAS'), findsOneWidget);
  });
}

