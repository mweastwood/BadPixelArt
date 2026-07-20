import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/widgets/refinement_panel.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

class RefinementMockAiService extends AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double? temperature,
    int? maxOutputTokens,
  }) async {
    return '{"thought": "refine details", "tool": "pixel", "params": [2, 2], "colorIndex": 1}';
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 10;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('RefinementPanel Widget & Golden Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      AppDatabaseHelper.db = db;
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('submits refinement prompt to notifier', (tester) async {
      String? submittedPrompt;

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            aiServiceProvider.overrideWithValue(RefinementMockAiService()),
            canvasStateProvider.overrideWith((ref) {
              final aiService = ref.watch(aiServiceProvider);
              final notifier = _MockRefinementCanvasNotifier(
                aiService,
                onRefine: (p) => submittedPrompt = p,
              );
              notifier.state = notifier.state.copyWith(
                userPrompt: 'sword plan',
              );
              return notifier;
            }),
          ],
          child: const Scaffold(body: RefinementPanel()),
        ),
      );

      // Verify prefilled prompt is visible
      expect(find.text('sword plan'), findsOneWidget);

      // Enter new text into refinement prompt text field
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'add shiny gold blade highlights');
      await tester.pumpAndSettle();

      // Tap refine button
      final refineButton = find.byType(ElevatedButton);
      await tester.tap(refineButton);
      await tester.pumpAndSettle();

      expect(submittedPrompt, equals('add shiny gold blade highlights'));
    });

    testGoldens('RefinementPanel renders correctly in multiple states', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Normal State with prefilled prompt',
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) {
                final aiService = ref.watch(aiServiceProvider);
                final notifier = CanvasNotifier(aiService);
                notifier.state = notifier.state.copyWith(
                  userPrompt: 'a pixel wizard hat',
                );
                return notifier;
              }),
            ],
            child: const SizedBox(width: 350, child: RefinementPanel()),
          ),
        )
        ..addScenario(
          'Refining State (Loading)',
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) {
                final aiService = ref.watch(aiServiceProvider);
                final notifier = CanvasNotifier(aiService);
                notifier.state = notifier.state.copyWith(
                  userPrompt: 'a pixel wizard hat',
                  isGenerating: true,
                );
                return notifier;
              }),
            ],
            child: const SizedBox(width: 350, child: RefinementPanel()),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
        surfaceSize: const Size(400, 900),
      );

      await screenMatchesGolden(
        tester,
        'refinement_panel',
        customPump: (tester) async => tester.pump(),
      );
    });
  });
}

class _MockRefinementCanvasNotifier extends CanvasNotifier {
  final Function(String)? onRefine;

  _MockRefinementCanvasNotifier(super.aiService, {this.onRefine});

  @override
  Future<void> refineCanvas(String refinementPrompt) async {
    if (onRefine != null) onRefine!(refinementPrompt);
    return super.refineCanvas(refinementPrompt);
  }
}
