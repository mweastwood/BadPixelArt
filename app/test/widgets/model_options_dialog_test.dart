import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/model_options_dialog.dart';
import '../test_helper.dart';

void main() {
  group('ModelOptionsDialog Widget & Golden Tests', () {
    testWidgets('renders all options and changes state on tap', (tester) async {
      String? savedStage;
      String? savedPreference;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ModelOptionsDialog(
              currentReleaseStage: 'stable',
              currentPreference: 'full',
              onChanged: (stage, preference) {
                savedStage = stage;
                savedPreference = preference;
              },
            ),
          ),
        ),
      );

      // Verify headings and cards render
      expect(find.text('Model Options'), findsOneWidget);
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

    testWidgets('Cancel button dismisses without saving', (tester) async {
      bool onChangedCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ModelOptionsDialog(
                        currentReleaseStage: 'stable',
                        currentPreference: 'full',
                        onChanged: (stage, pref) {
                          onChangedCalled = true;
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Model Options'), findsOneWidget);

      // Change selections
      await tester.tap(find.byKey(const ValueKey('stage_preview')));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed, callback should NOT be called
      expect(find.text('Model Options'), findsNothing);
      expect(onChangedCalled, isFalse);
    });

    testGoldens('ModelOptionsDialog renders correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Stable & Full Selected',
          ModelOptionsDialog(
            currentReleaseStage: 'stable',
            currentPreference: 'full',
            onChanged: (stage, pref) {},
          ),
        )
        ..addScenario(
          'Preview & Fast Selected',
          ModelOptionsDialog(
            currentReleaseStage: 'preview',
            currentPreference: 'fast',
            onChanged: (stage, pref) {},
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
        surfaceSize: const Size(600, 1000),
      );
      await screenMatchesGolden(tester, 'model_options_dialog');
    });
  });
}
