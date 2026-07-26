import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/screens/creations_screen.dart';
import 'package:bad_pixel_art/screens/canvas_screen.dart';
import 'package:bad_pixel_art/screens/logs_screen.dart';
import 'package:bad_pixel_art/widgets/grid_size_selection_card.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../test_helper.dart';

void main() {
  group('PixelArtScreen Screen & Golden Tests', () {
    testWidgets('renders full responsive layout components', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );

      // Verify the appBar title is visible
      expect(find.text('Bad Pixel Art'), findsOneWidget);
    });

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

    testGoldens('PixelArtScreen component confirmation dialog golden render', (
      tester,
    ) async {
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
          ),
        ],
        confirmingComponentIndex: null,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => mockNotifier)],
        ),
      );

      // Now change it to trigger the listener
      mockNotifier.state = mockNotifier.state.copyWith(
        confirmingComponentIndex: 0,
      );

      // Let dialog anim settle
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('component_confirmation_dialog')),
        findsOneWidget,
      );

      await screenMatchesGolden(
        tester,
        'pixel_art_screen_component_confirmation',
      );
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
    testWidgets(
      'shows Choose Drawing Plan dialog when pendingDecompositionOptions is populated',
      (tester) async {
        final mockAiService = MockAiService();
        final mockNotifier = CanvasNotifier(mockAiService);
        final option = [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          ),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
            ],
          ),
        );

        // Now populate pendingDecompositionOptions to trigger the listener
        mockNotifier.state = mockNotifier.state.copyWith(
          pendingDecompositionOptions: [option, option, option, option],
        );

        // Let the dialog open
        await tester.pumpAndSettle();

        // Verify the dialog is visible
        expect(find.text('Choose Drawing Plan'), findsOneWidget);
        expect(find.text('OPTION 1'), findsOneWidget);
        expect(find.text('• blade'), findsWidgets);

        // Tap on Option 1 card
        await tester.tap(find.text('OPTION 1'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed, and option 1 applied
        expect(find.text('Choose Drawing Plan'), findsNothing);
        expect(mockNotifier.state.decomposedComponents, hasLength(1));
        expect(
          mockNotifier.state.decomposedComponents.first.name,
          equals('blade'),
        );
        expect(mockNotifier.state.pendingDecompositionOptions, isEmpty);
      },
    );

    testWidgets(
      'renders 3 bottom navigation destinations (Canvas, Creations, Logs) with correct icons',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );

        // Verify NavigationBar destinations (Creations: 0, Canvas: 1, Logs: 2)
        final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(navBar.destinations, hasLength(3));

        final dests = navBar.destinations.cast<NavigationDestination>();
        expect(dests[0].label, equals('Creations'));
        expect(dests[1].label, equals('Canvas'));
        expect(dests[2].label, equals('Logs'));

        // Verify destination icons
        expect(
          (dests[0].icon as Icon).icon,
          equals(Icons.collections_outlined),
        );
        expect((dests[1].icon as Icon).icon, equals(Icons.palette_outlined));
        expect(
          dests[2].icon,
          isA<Icon>().having(
            (i) => i.icon,
            'icon',
            equals(Icons.chat_bubble_outline),
          ),
        );
      },
    );

    testWidgets(
      'switches between Canvas, Creations, and Logs tabs on bottom navigation tap',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );

        // Initially on Canvas tab (CanvasScreen visible)
        expect(find.byType(CanvasScreen), findsOneWidget);
        expect(find.byType(GridSizeSelectionCard), findsOneWidget);

        // Tap Creations tab (index 0)
        await tester.tap(find.text('Creations'));
        await tester.pumpAndSettle();

        // Verify CreationsScreen is visible
        expect(find.byType(CreationsScreen), findsOneWidget);
        expect(find.text('Creations Gallery'), findsOneWidget);

        // Tap Logs tab (index 2)
        await tester.tap(find.text('Logs'));
        await tester.pumpAndSettle();

        // Verify LogsScreen is visible
        expect(find.byType(LogsScreen), findsOneWidget);
        expect(find.text('Conversation History'), findsOneWidget);

        // Tap Canvas tab (index 1) to return
        await tester.tap(find.text('Canvas'));
        await tester.pumpAndSettle();

        expect(find.byType(CanvasScreen), findsOneWidget);
      },
    );

    testWidgets('shows correct FloatingActionButton per tab', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );

      // Default on Canvas tab (index 1): wizard navigation FAB is visible
      expect(find.byKey(const ValueKey('wizard_next_fab')), findsOneWidget);
      expect(find.byKey(const ValueKey('export_logs_fab')), findsNothing);

      // Tap Creations tab (index 0)
      await tester.tap(find.text('Creations'));
      await tester.pumpAndSettle();

      // No FAB visible on Creations tab
      expect(find.byType(FloatingActionButton), findsNothing);

      // Tap Logs tab (index 2)
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      // Export FAB is visible on Logs tab, wizard FAB is not
      expect(find.byKey(const ValueKey('export_logs_fab')), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard_next_fab')), findsNothing);

      // Return to Canvas tab (index 1)
      await tester.tap(find.text('Canvas'));
      await tester.pumpAndSettle();

      // Wizard FAB is visible again
      expect(find.byKey(const ValueKey('wizard_next_fab')), findsOneWidget);
    });
    testWidgets(
      'tapping New Canvas in Creations tab resets wizard step to Step 0 and navigates back to Canvas tab',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(child: const PixelArtScreen()),
        );

        // Advance wizard to Step 1 (Reference & Prompt) by tapping Next FAB
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(find.byType(ReferenceImagePrompt), findsOneWidget);

        // Switch to Creations tab
        await tester.tap(find.text('Creations'));
        await tester.pumpAndSettle();

        expect(find.text('Creations Gallery'), findsOneWidget);

        // Tap + New Canvas button in header
        await tester.tap(find.byTooltip('New Canvas'));
        await tester.pumpAndSettle();

        // Should auto-navigate back to Canvas tab and reset wizard to Step 0 (GridSizeSelectionCard)
        expect(find.byType(GridSizeSelectionCard), findsOneWidget);
        expect(find.text('Canvas Resolution'), findsOneWidget);
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

    testWidgets('renders Export Logs FAB on Logs screen tab', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );

      // Default active tab is Canvas (tab index 1)
      expect(find.byKey(const ValueKey('export_logs_fab')), findsNothing);

      // Tap Logs tab (tab index 2)
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      // Verify Export Logs FAB appears on Logs tab
      expect(find.byKey(const ValueKey('export_logs_fab')), findsOneWidget);
    });

    testWidgets('Auto-Play FAB is disabled when reference image is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byKey(const ValueKey('auto_play_fab')),
      );
      expect(fab.onPressed, isNull);
    });

    testWidgets(
      'Auto-Play FAB is enabled with reference image, toggles auto-play and displays Pause FAB',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );
        await tester.pumpAndSettle();

        // FAB is enabled with play icon
        final playFab = tester.widget<FloatingActionButton>(
          find.byKey(const ValueKey('auto_play_fab')),
        );
        expect(playFab.onPressed, isNotNull);

        // Tap Auto-Play FAB
        await tester.tap(find.byKey(const ValueKey('auto_play_fab')));
        await tester.pump();

        // Verify Auto-Play active state
        expect(notifier.state.autoRun, isTrue);
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(
          find.byKey(const ValueKey('auto_play_active_banner')),
          findsOneWidget,
        );

        // Clean up active loop before ending test
        notifier.stopAutoPlay();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'navigating away from Canvas tab automatically stops auto-play',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          autoRun: true,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );
        await tester.pumpAndSettle();

        expect(notifier.state.autoRun, isTrue);

        // Switch to Creations tab
        await tester.tap(find.text('Creations'));
        await tester.pumpAndSettle();

        expect(notifier.state.autoRun, isFalse);
      },
    );

    testGoldens('PixelArtScreen Auto-Play active banner golden render', (
      tester,
    ) async {
      final mockAi = MockAiService();
      final notifier = CanvasNotifier(mockAi);
      notifier.state = notifier.state.copyWith(
        referenceImage: Uint8List.fromList([1, 2, 3]),
        autoRun: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: const PixelArtScreen(),
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

      await tester.pumpWidget(
        buildTestableWidget(
          child: const PixelArtScreen(),
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
