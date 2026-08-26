import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/screens/model_options_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/settings_provider.dart';

import '../test_helper.dart';

void main() {
  group('ModelOptionsScreen Widget & Golden Tests', () {
    testWidgets('renders all options and changes state on tap and save', (
      tester,
    ) async {
      String? savedStage;
      String? savedPreference;

      await tester.pumpWidget(
        buildTestableWidget(
          child: ModelOptionsScreen(
            currentReleaseStage: 'stable',
            currentPreference: 'full',
            onChanged: (stage, preference) {
              savedStage = stage;
              savedPreference = preference;
            },
          ),
        ),
      );

      // Verify headings and cards render
      expect(find.text('Model Options'), findsOneWidget);
      expect(find.text('AI Engine'), findsOneWidget);
      expect(find.text('Release Stage'), findsOneWidget);
      expect(find.text('Performance Preference'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Full (Capable)'), findsOneWidget);
      expect(find.text('Fast (Low Latency)'), findsOneWidget);

      // Select 'Preview' and 'Fast'
      await tester.tap(find.byKey(const ValueKey('stage_preview')));
      await tester.tap(find.byKey(const ValueKey('preference_fast')));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.byKey(const ValueKey('save_model_options')));
      await tester.pumpAndSettle();

      // Verify callback triggered with correct updated parameters
      expect(savedStage, equals('preview'));
      expect(savedPreference, equals('fast'));
    });

    testWidgets(
      'updates UI and persists settings when configuring Gemini and Zhipu Cloud',
      (tester) async {
        final fakePrefs = FakeSharedPreferences();

        await tester.pumpWidget(
          buildTestableWidget(
            child: const ModelOptionsScreen(),
            overrides: [
              sharedPreferencesProvider.overrideWithValue(fakePrefs),
              settingsProvider.overrideWith(
                (ref) => SettingsNotifier(fakePrefs),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Gemini Cloud
        await tester.tap(find.byKey(const ValueKey('engine_gemini')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('gemini_api_key_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('gemini_model_dropdown')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('throttle_slider')), findsOneWidget);

        // Enter Gemini API key
        await tester.enterText(
          find.byKey(const ValueKey('gemini_api_key_field')),
          'test-gemini-key',
        );

        // Select custom model in Gemini dropdown
        await tester.ensureVisible(
          find.byKey(const ValueKey('gemini_model_dropdown')),
        );
        await tester.tap(find.byKey(const ValueKey('gemini_model_dropdown')));
        await tester.pumpAndSettle();

        final customItem = find.text('custom', skipOffstage: false).last;
        await tester.ensureVisible(customItem);
        await tester.pumpAndSettle();
        await tester.tap(customItem, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Enter custom model ID
        expect(
          find.byKey(const ValueKey('gemini_custom_model_field')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('gemini_custom_model_field')),
          'gemini-experimental-custom',
        );

        // Adjust slider
        await tester.ensureVisible(
          find.byKey(const ValueKey('throttle_slider')),
        );
        await tester.drag(
          find.byKey(const ValueKey('throttle_slider')),
          const Offset(50, 0),
        );
        await tester.pumpAndSettle();

        // Switch to Zhipu Cloud
        await tester.ensureVisible(find.byKey(const ValueKey('engine_zhipu')));
        await tester.tap(find.byKey(const ValueKey('engine_zhipu')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('zhipu_api_key_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('zhipu_model_dropdown')),
          findsOneWidget,
        );

        // Enter Zhipu API key
        await tester.enterText(
          find.byKey(const ValueKey('zhipu_api_key_field')),
          'test-zhipu-key',
        );

        // Select custom model in Zhipu dropdown
        await tester.ensureVisible(
          find.byKey(const ValueKey('zhipu_model_dropdown')),
        );
        await tester.tap(find.byKey(const ValueKey('zhipu_model_dropdown')));
        await tester.pumpAndSettle();

        final zhipuCustomItem = find.text('custom', skipOffstage: false).last;
        await tester.ensureVisible(zhipuCustomItem);
        await tester.pumpAndSettle();
        await tester.tap(zhipuCustomItem, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('zhipu_custom_model_field')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('zhipu_custom_model_field')),
          'glm-custom-id',
        );

        // Save via bottom button
        await tester.ensureVisible(
          find.byKey(const ValueKey('save_model_options_bottom')),
        );
        await tester.tap(
          find.byKey(const ValueKey('save_model_options_bottom')),
        );
        await tester.pumpAndSettle();

        expect(fakePrefs.getInt('aiEngine'), equals(AiEngine.zhipuCloud.index));
        expect(fakePrefs.getString('geminiApiKey'), equals('test-gemini-key'));
        expect(fakePrefs.getString('zhipuApiKey'), equals('test-zhipu-key'));
        expect(
          fakePrefs.getString('geminiModel'),
          equals('gemini-experimental-custom'),
        );
        expect(fakePrefs.getString('zhipuModel'), equals('glm-custom-id'));
      },
    );

    testWidgets(
      'initializes state from canvasStateProvider when not explicitly passed',
      (tester) async {
        final mockAiService = TestMockAiService();
        final mockCanvasNotifier = CanvasNotifier(mockAiService);
        mockCanvasNotifier.state = mockCanvasNotifier.state.copyWith(
          modelReleaseStage: 'preview',
          modelPreference: 'fast',
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: const ModelOptionsScreen(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockCanvasNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.byKey(const ValueKey('save_model_options')));
        await tester.pumpAndSettle();

        expect(mockCanvasNotifier.state.modelReleaseStage, equals('preview'));
        expect(mockCanvasNotifier.state.modelPreference, equals('fast'));
      },
    );

    testGoldens(
      'ModelOptionsScreen renders correctly in various configurations',
      (tester) async {
        final geminiPrefs = FakeSharedPreferences();
        await geminiPrefs.setInt('aiEngine', AiEngine.geminiCloud.index);
        await geminiPrefs.setString('geminiApiKey', 'mock-gemini-key');
        await geminiPrefs.setString('geminiModel', 'gemini-3.5-flash');

        final zhipuPrefs = FakeSharedPreferences();
        await zhipuPrefs.setInt('aiEngine', AiEngine.zhipuCloud.index);
        await zhipuPrefs.setString('zhipuApiKey', 'mock-zhipu-key');
        await zhipuPrefs.setString('zhipuModel', 'glm-4.7-flash');

        final zhipuCustomPrefs = FakeSharedPreferences();
        await zhipuCustomPrefs.setInt('aiEngine', AiEngine.zhipuCloud.index);
        await zhipuCustomPrefs.setString('zhipuApiKey', 'mock-zhipu-key');
        await zhipuCustomPrefs.setString('zhipuModel', 'my-custom-model-id');

        final builder = GoldenBuilder.column()
          ..addScenario(
            'Stable & Full Selected (Local)',
            const SizedBox(
              height: 700,
              width: 500,
              child: ModelOptionsScreen(
                currentReleaseStage: 'stable',
                currentPreference: 'full',
              ),
            ),
          )
          ..addScenario(
            'Gemini Cloud Selected',
            ProviderScope(
              overrides: [
                settingsProvider.overrideWith(
                  (ref) => SettingsNotifier(geminiPrefs),
                ),
              ],
              child: const SizedBox(
                height: 700,
                width: 500,
                child: ModelOptionsScreen(
                  currentReleaseStage: 'stable',
                  currentPreference: 'full',
                ),
              ),
            ),
          )
          ..addScenario(
            'Zhipu Cloud Selected',
            ProviderScope(
              overrides: [
                settingsProvider.overrideWith(
                  (ref) => SettingsNotifier(zhipuPrefs),
                ),
              ],
              child: const SizedBox(
                height: 700,
                width: 500,
                child: ModelOptionsScreen(
                  currentReleaseStage: 'stable',
                  currentPreference: 'full',
                ),
              ),
            ),
          )
          ..addScenario(
            'Zhipu Cloud Custom Model Selected',
            ProviderScope(
              overrides: [
                settingsProvider.overrideWith(
                  (ref) => SettingsNotifier(zhipuCustomPrefs),
                ),
              ],
              child: const SizedBox(
                height: 700,
                width: 500,
                child: ModelOptionsScreen(
                  currentReleaseStage: 'stable',
                  currentPreference: 'full',
                ),
              ),
            ),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: testMaterialAppWrapper(),
          surfaceSize: const Size(600, 3200),
        );
        await screenMatchesGolden(tester, 'model_options_screen');
      },
    );
  });
}
