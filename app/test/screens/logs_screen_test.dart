import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/screens/logs_screen.dart';
import 'package:bad_pixel_art/widgets/ai_history_dock.dart';
import '../test_helper.dart';

void main() {
  group('LogsScreen Unit & Golden Tests', () {
    testWidgets('renders LogsScreen with AiHistoryDock child', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: LogsScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AiHistoryDock), findsOneWidget);
      expect(find.text('AI History & Debugger'), findsOneWidget);
    });

    testWidgets('LogsScreen golden render', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: LogsScreen())),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LogsScreen),
        matchesGoldenFile('goldens/logs_screen.png'),
      );
    }, tags: 'golden');
  });
}
