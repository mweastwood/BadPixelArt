@Tags(['golden'])
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../test_helper.dart';

void main() {
  group('PixelArtScreen Golden Tests', () {
    testGoldens('PixelArtScreen portrait golden render', (tester) async {
      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'pixel_art_screen_portrait');
    });

    testGoldens('PixelArtScreen landscape golden render', (tester) async {
      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(),
      );
      await multiScreenGolden(
        tester,
        'pixel_art_screen_landscape',
        devices: [
          const Device(name: 'landscape_tablet', size: Size(1280, 800)),
        ],
      );
    });

    testGoldens('PixelArtScreen suggested palette dialog golden render', (
      tester,
    ) async {
      final mockAiService = MockAiService();
      final mockNotifier = CanvasNotifier(mockAiService);
      mockNotifier.state = mockNotifier.state.copyWith(
        suggestedPalette: List.generate(
          16,
          (i) => Color(0xFF000000 | (i * 0x111111)),
        ),
        showPaletteSuggestion: true,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => mockNotifier)],
        ),
      );

      await screenMatchesGolden(tester, 'pixel_art_screen_palette_suggestion');
    });

    testGoldens('PixelArtScreen palette generation loading golden render', (
      tester,
    ) async {
      final mockAiService = MockAiService();
      final mockNotifier = CanvasNotifier(mockAiService);
      mockNotifier.state = mockNotifier.state.copyWith(
        isSuggestingPalette: true,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => mockNotifier)],
        ),
      );

      await screenMatchesGolden(
        tester,
        'pixel_art_screen_palette_loading',
        customPump: (tester) async => tester.pump(),
      );
    });

    testGoldens(
      'PixelArtScreen active component shapes highlighted golden render',
      (tester) async {
        final mockAiService = MockAiService();
        final mockNotifier = CanvasNotifier(mockAiService);
        final compGrid = List.generate(16, (_) => List.filled(16, 0));
        for (int y = 2; y <= 10; y++) {
          compGrid[y][8] = 1;
        }
        mockNotifier.state = mockNotifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
              grid: compGrid,
              shapes: [
                FundamentalShape(
                  type: 'rectangle',
                  description: 'steel body',
                  relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.6),
                ),
                FundamentalShape(
                  type: 'circle',
                  description: 'gem accent',
                  relativeBoundingBox: const Rect.fromLTWH(0.3, 0.7, 0.4, 0.2),
                ),
              ],
            ),
          ],
          activeComponentIndex: 0,
        );

        await tester.pumpWidgetBuilder(
          const PixelArtScreen(),
          wrapper: testMaterialAppWrapper(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
            ],
          ),
        );

        await screenMatchesGolden(
          tester,
          'pixel_art_screen_shapes_highlighted',
        );
      },
    );

    testGoldens('PixelArtScreen Creations tab golden render', (tester) async {
      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(),
      );

      // Switch to Creations tab
      await tester.tap(find.text('Creations'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'pixel_art_screen_creations_tab');
    });

    testGoldens('PixelArtScreen Logs tab golden render', (tester) async {
      final mockAiService = MockAiService();
      final mockNotifier = CanvasNotifier(mockAiService);
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'User Prompt: Draw a pixel sword',
        response:
            '{"understanding":"Analyzing request","reasoning":"Adding blade","tool":"line","params":[0,0,5,5]}',
        isError: false,
        modelName: 'Gemini 3.6 Flash',
        inputTokens: 150,
        outputTokens: 85,
        estimatedCostUsd: 0.0003,
      );
      mockNotifier.state = mockNotifier.state.copyWith(aiHistory: [entry]);

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => mockNotifier)],
        ),
      );

      // Switch to Logs tab
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'pixel_art_screen_logs_tab');
    });

    testGoldens('PixelArtScreen Auto-Play active banner golden render', (
      tester,
    ) async {
      final mockAi = MockAiService();
      final notifier = CanvasNotifier(mockAi);
      notifier.state = notifier.state.copyWith(
        referenceImage: Uint8List.fromList([1, 2, 3]),
        autoRun: true,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PixelArtScreen),
        matchesGoldenFile('goldens/pixel_art_screen_auto_play_active.png'),
      );
      notifier.stopAutoPlay();
    });

    testGoldens('PixelArtScreen Auto-Play pausing banner golden render', (
      tester,
    ) async {
      final mockAi = MockAiService();
      final notifier = CanvasNotifier(mockAi);
      notifier.state = notifier.state.copyWith(
        referenceImage: Uint8List.fromList([1, 2, 3]),
        autoRun: true,
        isPausing: true,
        isGenerating: true,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PixelArtScreen),
        matchesGoldenFile('goldens/pixel_art_screen_auto_play_pausing.png'),
      );
      notifier.stopAutoPlay();
    });
  });
}
