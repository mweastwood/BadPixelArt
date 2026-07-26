import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:bad_pixel_art/widgets/ai_history_dock.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../test_helper.dart';

class MockFilePickerPlatform extends FilePickerPlatform {
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    return null; // Simulate user cancel to trigger fallback save logic
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    bool lockParentWindow = false,
  }) async {
    return null; // Simulate user cancel to trigger fallback save logic
  }
}

class LocalMockAiService extends AiService {
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
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    if (prompt.contains('pixel art describer')) {
      return 'Mock description of the canvas';
    }
    if (temperature <= 0.5) {
      final List<String> mockPalette = List.generate(16, (i) {
        final val = (i * 0x11).toRadixString(16).padLeft(2, '0');
        return '#$val$val$val';
      });
      return '["${mockPalette.join('", "')}"]';
    }
    return null;
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

void main() {
  group('AiHistoryDock Widget & Golden Tests', () {
    testWidgets('starts collapsed, expands on tap, and shows empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: AiHistoryDock())),
      );

      // Verify starts collapsed (empty state text should not be visible yet)
      expect(find.textContaining('No AI history logs yet.'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Verify empty state message is visible
      expect(find.textContaining('No AI history logs yet.'), findsOneWidget);
    });

    testWidgets('renders log entries and handles detail expand tap', (
      tester,
    ) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response:
            '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        isError: false,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(
              CanvasNotifier.gridSize,
              (_) => List.filled(CanvasNotifier.gridSize, 0),
            ),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      final widget = ProviderScope(
        overrides: [
          aiServiceProvider.overrideWithValue(mockService),
          canvasStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        ),
      );

      await tester.pumpWidget(widget);

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Verify log summary exists
      expect(find.text('10:15:30'), findsOneWidget);
      expect(find.text('Stroke suggested successfully'), findsOneWidget);

      // Verify details are collapsed initially but raw AI exchange button is in the header
      expect(find.byTooltip('View Raw AI Exchange'), findsOneWidget);

      // Tap log summary row to expand details
      await tester.tap(find.text('Stroke suggested successfully'));
      await tester.pumpAndSettle();

      // Tap the raw AI exchange button to open popup
      expect(find.byTooltip('View Raw AI Exchange'), findsOneWidget);
      await tester.tap(find.byTooltip('View Raw AI Exchange'));
      await tester.pumpAndSettle();

      // Verify prompt and response headers/texts are shown in dialog and expanded card
      expect(find.text('RAW PROMPT:'), findsNWidgets(2));
      expect(find.text('RAW RESPONSE:'), findsNWidgets(2));
      expect(
        find.text('System Instructions:\nDraw a test sword.'),
        findsNWidgets(2),
      );
      expect(
        find.text(
          '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        ),
        findsNWidgets(2),
      );
    });

    testGoldens('AiHistoryDock renders correctly', (tester) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response:
            '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        isError: false,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(
              CanvasNotifier.gridSize,
              (_) => List.filled(CanvasNotifier.gridSize, 0),
            ),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.5)
        ..addScenario(
          'History Dock Collapsed',
          const SingleChildScrollView(child: AiHistoryDock()),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );
      await screenMatchesGolden(tester, 'ai_history_dock');
    });

    testGoldens('AiHistoryDock renders expanded correctly', (tester) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response:
            '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        isError: false,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(
              CanvasNotifier.gridSize,
              (_) => List.filled(CanvasNotifier.gridSize, 0),
            ),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      await tester.pumpWidgetBuilder(
        const Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        wrapper: testMaterialAppWrapper(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Expand history item details so we see prompt/response in the golden
      await tester.tap(find.text('Stroke suggested successfully'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'ai_history_dock_expanded');
    });

    testWidgets('Export Logs button is present and exports history to file', (
      tester,
    ) async {
      // Mock FilePicker platform instance to prevent FFI / channel hang
      final originalPlatform = FilePickerPlatform.instance;
      FilePickerPlatform.instance = MockFilePickerPlatform();

      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response: '{"tool":"line"}',
        isError: false,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(
              CanvasNotifier.gridSize,
              (_) => List.filled(CanvasNotifier.gridSize, 0),
            ),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      final widget = ProviderScope(
        overrides: [
          aiServiceProvider.overrideWithValue(mockService),
          canvasStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        ),
      );

      await tester.pumpWidget(widget);

      // Verify download button is not visible initially when collapsed
      expect(find.byIcon(Icons.file_download_outlined), findsNothing);

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Find the download button
      final exportButton = find.byIcon(Icons.file_download_outlined);
      expect(exportButton, findsOneWidget);

      bool fileFoundAndVerified = false;

      await tester.runAsync(() async {
        // Tap the download button (triggers _exportHistory)
        await tester.tap(exportButton);
        await tester.pump();

        // Wait a short moment for the file system write to complete
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify generated file in exports or current folder
        final pathsToCheck = [
          '/home/mweastwood/projects/BadPixelArt/exports',
          Directory.current.path,
        ];

        for (final dirPath in pathsToCheck) {
          final dir = Directory(dirPath);
          if (await dir.exists()) {
            final List<FileSystemEntity> entities = await dir.list().toList();
            for (final entity in entities) {
              if (entity is File &&
                  entity.path.contains('ai_drawing_history_') &&
                  entity.path.endsWith('.json')) {
                // Read and parse
                final content = await entity.readAsString();
                final decoded = jsonDecode(content);

                // Verify contents
                expect(decoded, isA<List>());
                expect(decoded.length, 1);
                expect(
                  decoded[0]['prompt'],
                  'System Instructions:\nDraw a test sword.',
                );
                expect(decoded[0]['response'], '{"tool":"line"}');
                expect(decoded[0]['isError'], false);
                expect(decoded[0]['image'], isNotNull);
                expect(decoded[0]['image']['mimeType'], 'image/bmp');
                expect(decoded[0]['image']['base64'], isNotNull);

                // Clean up
                await entity.delete();
                fileFoundAndVerified = true;
                break;
              }
            }
          }
          if (fileFoundAndVerified) break;
        }
      });

      expect(
        fileFoundAndVerified,
        isTrue,
        reason: 'Log file should be exported and verified',
      );

      // Restore platform instance
      FilePickerPlatform.instance = originalPlatform;
    });

    testGoldens('AiHistoryDock renders tournament details correctly', (
      tester,
    ) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt:
            'Co-creative Multi-Agent Drawing Step (AI pixel art assistant):\n- 3 Painter Agent Runs each ran for 5 turns starting from the current canvas.\n- Critic evaluated all three candidates on a 2x2 comparison grid and selected the best progression.',
        response: jsonEncode({
          'criticChoice': 2,
          'criticReasoning':
              'Painter 2 added beautiful highlights to the blade that align perfectly with the target reference art style.',
          'criticNextFocus': 'Refine the blade highlights with light blue.',
          'painter1Strokes': [
            {
              'tool': 'circle',
              'params': [8, 8, 4],
              'color': 1,
            },
            {
              'tool': 'fill',
              'params': [8, 8],
              'color': 1,
            },
          ],
          'painter2Strokes': [
            {
              'tool': 'line',
              'params': [2, 2, 14, 14],
              'color': 2,
            },
            {
              'tool': 'pixel',
              'params': [7, 8],
              'color': 3,
            },
            {
              'tool': 'pixel',
              'params': [8, 7],
              'color': 3,
            },
          ],
          'painter3Strokes': [
            {
              'tool': 'rectangle_filled',
              'params': [4, 4, 12, 12],
              'color': 4,
            },
          ],
        }),
        isError: false,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      await tester.pumpWidgetBuilder(
        const Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        wrapper: testMaterialAppWrapper(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Expand history item details
      await tester.tap(find.text('Critic picked Painter 2'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'ai_history_dock_tournament_expanded');
    });

    testGoldens('AiHistoryDock renders raw exchange dialog correctly', (
      tester,
    ) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt:
            'Co-creative Multi-Agent Drawing Step (AI pixel art assistant):\n- 3 Painter Agent Runs each ran for 5 turns starting from the current canvas.\n- Critic evaluated all three candidates on a 2x2 comparison grid and selected the best progression.',
        response: jsonEncode({
          'criticChoice': 2,
          'criticReasoning':
              'Painter 2 added beautiful highlights to the blade that align perfectly with the target reference art style.',
          'criticNextFocus': 'Refine the blade highlights with light blue.',
          'criticRawPrompt':
              'This is the raw critic prompt. It contains system instructions and candidate comparison details.',
          'criticRawResponse':
              '{"choice": 2, "reasoning": "Painter 2 added beautiful highlights..."}',
          'painter1Strokes': [],
          'painter2Strokes': [
            {
              'tool': 'line',
              'params': [2, 2, 14, 14],
              'color': 2,
              'rawPrompt':
                  'This is the raw painter prompt. It has color lists and canvas state.',
              'rawResponse':
                  '{"tool": "line", "params": [2, 2, 14, 14], "color": 2}',
            },
          ],
          'painter3Strokes': [],
        }),
        isError: false,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
          generateBmp(
            List.generate(16, (_) => List.filled(16, 0)),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      await tester.pumpWidgetBuilder(
        const Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        wrapper: testMaterialAppWrapper(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Expand history item details
      await tester.tap(find.text('Critic picked Painter 2'));
      await tester.pumpAndSettle();

      // Tap raw exchange dialog button
      await tester.tap(find.byTooltip('View Raw Critic Exchange'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'ai_history_dock_raw_exchange_dialog');
    });

    testWidgets(
      'renders chat message bubbles for user prompt and AI response with model and token badges',
      (tester) async {
        final entry = AgentHistoryEntry(
          timestamp: DateTime(2026, 7, 11, 10, 15, 30),
          prompt: 'User Prompt: Draw a futuristic pixel sword.',
          response:
              '{"understanding":"Analyzing blade request","reasoning":"Drawing sword outline","tool":"line","params":[0,0,10,10]}',
          isError: false,
          modelName: 'Gemini 3.6 Flash',
          inputTokens: 150,
          outputTokens: 85,
          totalTokens: 235,
          estimatedCostUsd: 0.0003,
        );

        final mockService = LocalMockAiService();
        final notifier = CanvasNotifier(mockService);
        notifier.state = notifier.state.copyWith(aiHistory: [entry]);

        final widget = ProviderScope(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
          ),
        );

        await tester.pumpWidget(widget);

        // Expand history dock
        await tester.tap(find.text('AI History & Debugger'));
        await tester.pumpAndSettle();

        // Verify User Message Bubble components
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Draw a futuristic pixel sword.'), findsOneWidget);
        expect(find.text('In: 150'), findsOneWidget);

        // Verify AI Response Bubble components
        expect(find.text('AI Assistant'), findsOneWidget);
        expect(find.text('Gemini 3.6 Flash'), findsOneWidget);
        expect(find.text('Out: 85'), findsOneWidget);
        expect(find.text('\$0.0003'), findsOneWidget);
        expect(find.text('Stroke suggested successfully'), findsOneWidget);
        expect(find.text('Drawing sword outline'), findsOneWidget);
      },
    );

    testWidgets('renders error state chat message bubble correctly', (
      tester,
    ) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 20, 00),
        prompt: 'User Prompt: Generate complex pattern',
        response: 'API Quota Exceeded (429)',
        isError: true,
        modelName: 'Gemini 3.5 Flash',
        inputTokens: 100,
        outputTokens: 0,
        totalTokens: 100,
        estimatedCostUsd: 0.0,
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      final widget = ProviderScope(
        overrides: [
          aiServiceProvider.overrideWithValue(mockService),
          canvasStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        ),
      );

      await tester.pumpWidget(widget);

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Verify Error state title and error icons
      expect(find.text('AI Generation Error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Gemini 3.5 Flash'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets(
      'renders multi-turn conversation feed with date pill dividers and total session cost',
      (tester) async {
        final entries = [
          AgentHistoryEntry(
            timestamp: DateTime(2026, 7, 11, 10, 0, 0),
            prompt: 'color palette generator for retro cyber arcade',
            response: '{"palette":["#000000","#00FFFF","#FF00FF"]}',
            isError: false,
            modelName: 'Gemini 3.6 Flash',
            inputTokens: 50,
            outputTokens: 30,
            estimatedCostUsd: 0.0001,
          ),
          AgentHistoryEntry(
            timestamp: DateTime(2026, 7, 11, 10, 5, 0),
            prompt: 'Decompose the drawing instruction: cyber dragon',
            response: '{"components":[{"name":"wing"},{"name":"head"}]}',
            isError: false,
            modelName: 'Gemini 3.6 Flash',
            inputTokens: 120,
            outputTokens: 60,
            estimatedCostUsd: 0.0002,
          ),
          AgentHistoryEntry(
            timestamp: DateTime(2026, 7, 11, 10, 10, 0),
            prompt: 'User Prompt: Add glowing eyes to dragon head',
            response: '{"tool":"pixel","params":[5,5],"color":1}',
            isError: false,
            modelName: 'Gemini 3.6 Flash',
            inputTokens: 200,
            outputTokens: 90,
            estimatedCostUsd: 0.0003,
          ),
        ];

        final mockService = LocalMockAiService();
        final notifier = CanvasNotifier(mockService);
        notifier.state = notifier.state.copyWith(aiHistory: entries);

        final widget = ProviderScope(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
          ),
        );

        await tester.pumpWidget(widget);

        // Expand history dock
        await tester.tap(find.text('AI History & Debugger'));
        await tester.pumpAndSettle();

        // Verify top total cost summary badge ($0.0001 + $0.0002 + $0.0003 = $0.0006)
        expect(find.text('Total: \$0.0006'), findsOneWidget);

        // Verify inference titles in timestamp dividers and response status cards
        expect(find.text('AI Palette Suggestion'), findsNWidgets(2));
        expect(find.text('Semantic Component Breakdown'), findsNWidgets(2));
        expect(find.text('AI Core Inference'), findsOneWidget);
      },
    );

    testGoldens(
      'AiHistoryDock renders chat message feed multi-turn conversation',
      (tester) async {
        final entries = [
          AgentHistoryEntry(
            timestamp: DateTime(2026, 7, 11, 10, 0, 0),
            prompt: 'color palette generator for retro cyber arcade',
            response: '{"palette":["#000000","#00FFFF","#FF00FF"]}',
            isError: false,
            modelName: 'Gemini 3.6 Flash',
            inputTokens: 50,
            outputTokens: 30,
            estimatedCostUsd: 0.0001,
          ),
          AgentHistoryEntry(
            timestamp: DateTime(2026, 7, 11, 10, 5, 0),
            prompt: 'User Prompt: Draw a glowing cyber dragon',
            response:
                '{"understanding":"Drawing dragon layout","reasoning":"Adding wing outline","tool":"line","params":[0,0,10,10]}',
            isError: false,
            modelName: 'Gemini 3.6 Flash',
            inputTokens: 150,
            outputTokens: 75,
            estimatedCostUsd: 0.0002,
          ),
        ];

        final mockService = LocalMockAiService();
        final notifier = CanvasNotifier(mockService);
        notifier.state = notifier.state.copyWith(aiHistory: entries);

        await tester.pumpWidgetBuilder(
          const Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
          wrapper: testMaterialAppWrapper(
            overrides: [
              aiServiceProvider.overrideWithValue(mockService),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
          ),
        );

        // Expand history dock
        await tester.tap(find.text('AI History & Debugger'));
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'ai_history_dock_chat_multi_turn');
      },
    );
  });
}
