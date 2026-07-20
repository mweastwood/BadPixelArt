import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../test_helper.dart';

void main() {
  group('ReferenceImagePrompt Widget & Golden Tests', () {
    testWidgets(
      'renders initial expanded state correctly when no reference image',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        // Verify the header title
        expect(find.text('Reference & Prompt'), findsOneWidget);
        expect(find.text('Reference Image'), findsOneWidget);
        expect(find.text('Upload Reference Image'), findsOneWidget);
        expect(find.text('User Instructions / Prompt'), findsOneWidget);
      },
    );

    testWidgets(
      'collapses and expands on header tap, showing prompt text preview',
      (tester) async {
        final container = ProviderContainer();
        container
            .read(canvasStateProvider.notifier)
            .updatePrompt('Test Prompt String');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: ReferenceImagePrompt()),
            ),
          ),
        );

        // Verify initially expanded
        expect(find.text('Upload Reference Image'), findsOneWidget);
        expect(find.text('User Instructions / Prompt'), findsOneWidget);

        // Tap the header to collapse
        await tester.tap(find.text('Reference & Prompt'));
        await tester.pumpAndSettle();

        // Verify now collapsed (prompt preview is visible, detailed controls are gone)
        expect(find.text('Upload Reference Image'), findsNothing);
        expect(find.text('Test Prompt String'), findsOneWidget);

        // Tap again to expand
        await tester.tap(find.text('Reference & Prompt'));
        await tester.pumpAndSettle();

        expect(find.text('Upload Reference Image'), findsOneWidget);
      },
    );

    testWidgets(
      'renders previews and edit/delete options when reference image is present',
      (tester) async {
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
        );
        final notifier = container.read(canvasStateProvider.notifier);

        final mockBmp = generateBmp(
          List.generate(16, (_) => List.filled(16, 0)),
          CanvasNotifier.primaryPalette,
        );

        // Set reference image bytes
        notifier.setReferenceImage(mockBmp);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: ReferenceImagePrompt()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Previews should be visible
        expect(find.text('Active Reference'), findsOneWidget);
        expect(find.text('Original'), findsOneWidget);
        expect(find.text('Model Input (512x512)'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testGoldens('ReferenceImagePrompt renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario('Expanded Empty State', const ReferenceImagePrompt())
        ..addScenario(
          'Collapsed Empty State',
          const ReferenceImagePrompt(initialCollapsed: true),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'reference_image_prompt');
    });
  });
}
