import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/widgets/template_selection_card.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import '../test_helper.dart';

void main() {
  group('TemplateSelectionCard Widget Tests', () {
    testWidgets('renders all template preset chips and mode selector', (
      tester,
    ) async {
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);
      final wizardNotifier = WizardNotifier(
        WizardStep.selectTemplate,
        null,
        WizardMode.template,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasStateProvider.overrideWith((ref) => notifier),
            wizardStateProvider.overrideWith((ref) => wizardNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TemplateSelectionCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TemplateSelectionCard), findsOneWidget);
      expect(find.text('Select Sprite Template'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('template_chip_sprite_character')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('template_chip_sword')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('template_chip_potion')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('template_chip_heart')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('template_chip_custom')),
        findsOneWidget,
      );
    });

    testWidgets('tapping sword preset updates text field and canvas grid', (
      tester,
    ) async {
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);
      final wizardNotifier = WizardNotifier(
        WizardStep.selectTemplate,
        null,
        WizardMode.template,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasStateProvider.overrideWith((ref) => notifier),
            wizardStateProvider.overrideWith((ref) => wizardNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TemplateSelectionCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap sword chip
      await tester.tap(find.byKey(const ValueKey('template_chip_sword')));
      await tester.pumpAndSettle();

      // Verify canvas prompt updated with sword prompt
      expect(notifier.state.userPrompt, contains('sword'));
      expect(notifier.state.grid.any((r) => r.any((c) => c > 0)), isTrue);
    });

    testWidgets('editing template text field applies custom grid to canvas', (
      tester,
    ) async {
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);
      final wizardNotifier = WizardNotifier(
        WizardStep.selectTemplate,
        null,
        WizardMode.template,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasStateProvider.overrideWith((ref) => notifier),
            wizardStateProvider.overrideWith((ref) => wizardNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TemplateSelectionCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byKey(const ValueKey('template_text_field'));
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '1234\n5678\n....\n0000');
      await tester.pumpAndSettle();

      expect(notifier.state.grid[0][0], equals(1));
      expect(notifier.state.grid[0][1], equals(2));
      expect(notifier.state.grid[0][2], equals(3));
      expect(notifier.state.grid[0][3], equals(4));
    });

    testWidgets('switching mode via SegmentedButton updates wizard notifier', (
      tester,
    ) async {
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);
      final wizardNotifier = WizardNotifier(
        WizardStep.selectTemplate,
        null,
        WizardMode.template,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasStateProvider.overrideWith((ref) => notifier),
            wizardStateProvider.overrideWith((ref) => wizardNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TemplateSelectionCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(wizardNotifier.mode, equals(WizardMode.template));

      await tester.tap(find.text('Structured'));
      await tester.pumpAndSettle();

      expect(wizardNotifier.mode, equals(WizardMode.structured));
    });

    testWidgets(
      'preserves whitespace indentation and calculates dynamic width for irregular rows',
      (tester) async {
        final mockAiService = TestMockAiService();
        final notifier = CanvasNotifier(mockAiService);
        final wizardNotifier = WizardNotifier(
          WizardStep.selectTemplate,
          null,
          WizardMode.template,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: TemplateSelectionCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textField = find.byKey(const ValueKey('template_text_field'));
        // Row 0 has 2 leading spaces and length 4
        // Row 1 has length 6
        await tester.enterText(textField, '  12\n123456\n  34');
        await tester.pumpAndSettle();

        // Dynamic width must be max line length = 6
        expect(notifier.state.gridSize, equals(6));
        expect(notifier.state.grid.length, equals(3));
        // Row 0: leading 2 spaces (0, 0), then 1, 2, then trailing padded 0, 0
        expect(notifier.state.grid[0], equals([0, 0, 1, 2, 0, 0]));
        // Row 1: 1, 2, 3, 4, 5, 6
        expect(notifier.state.grid[1], equals([1, 2, 3, 4, 5, 6]));
        // Row 2: leading 2 spaces (0, 0), then 3, 4, then trailing padded 0, 0
        expect(notifier.state.grid[2], equals([0, 0, 3, 4, 0, 0]));
      },
    );

    testWidgets(
      'does not throw when widget is disposed before post frame callback',
      (tester) async {
        final mockAiService = TestMockAiService();
        final notifier = CanvasNotifier(mockAiService);
        final wizardNotifier = WizardNotifier(
          WizardStep.selectTemplate,
          null,
          WizardMode.template,
        );

        // Build widget without pumping settle
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: TemplateSelectionCard()),
              ),
            ),
          ),
        );

        // Replace widget tree immediately to trigger dispose before next frame
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
