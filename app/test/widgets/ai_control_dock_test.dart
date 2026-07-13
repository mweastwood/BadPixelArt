import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/ai_control_dock.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:local_agent/local_agent.dart';
import '../test_helper.dart';

class MockTestAiService implements AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    bool lowTemperature = false,
    int? maxOutputTokens,
  }) async {
    if (lowTemperature) {
      final List<String> mockPalette = List.generate(16, (i) {
        final val = (i * 0x11).toRadixString(16).padLeft(2, '0');
        return '#$val$val$val';
      });
      return '["${mockPalette.join('", "')}"]';
    }
    return null;
  }
}

void main() {
  group('AiControlDock Widget & Golden Tests', () {
    testWidgets('renders preset items and responds to collapse toggles', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: AiControlDock())),
      );

      // Verify started as expanded (Reference Image Selector should be visible)
      expect(find.text('Reference Image'), findsOneWidget);
      expect(find.text('User Instructions / Prompt'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('AI Assistant Controls'));
      await tester.pumpAndSettle();

      // Verify controls are hidden
      expect(find.text('Reference Image'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('AI Assistant Controls'));
      await tester.pumpAndSettle();

      // Verify controls are visible again
      expect(find.text('Reference Image'), findsOneWidget);
    });

    testGoldens('AiControlDock renders correctly', (tester) async {
      final mockAiService = MockTestAiService();
      final mockNotifier = CanvasNotifier(mockAiService);

      // Simple mock bytes (length < 10) to trigger safe preview placeholders under test
      final mockBytes = Uint8List.fromList([0, 1, 2, 3]);

      mockNotifier.setReferenceImage(mockBytes, originalBytes: mockBytes);

      final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 0.55)
        ..addScenario('AI Control Dock Default', const AiControlDock())
        ..addScenario(
          'AI Control Dock Active Reference',
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
            ],
            child: const AiControlDock(),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'ai_control_dock');
    });
  });
}
