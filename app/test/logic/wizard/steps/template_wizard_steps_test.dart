import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/wizard/steps/template_wizard_steps.dart';
import 'package:bad_pixel_art/logic/wizard/steps/default_wizard_steps.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../../../test_helper.dart';

void main() {
  group('SelectTemplateStepDefinition Tests', () {
    const step = SelectTemplateStepDefinition();

    test('step properties are configured correctly', () {
      expect(step.step, equals(WizardStep.selectTemplate));
      expect(step.title, equals('Select Template'));
    });

    test('isStepComplete returns true when grid has non-zero pixels', () {
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);

      expect(step.isStepComplete(notifier.model), isFalse);

      notifier.drawPixel(0, 0);
      expect(step.isStepComplete(notifier.model), isTrue);
    });

    test('executeAutoPlay loads characterPreset when grid is empty', () async {
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);

      expect(notifier.model.grid.every((r) => r.every((c) => c == 0)), isTrue);

      final result = await step.executeAutoPlay(notifier);
      expect(result, isTrue);
      expect(notifier.model.grid.any((r) => r.any((c) => c > 0)), isTrue);
      expect(notifier.model.userPrompt, contains('character sprite hero'));
    });
  });

  group('SelectPaletteStepDefinition in Template Mode Tests', () {
    const paletteStep = SelectPaletteStepDefinition();

    test(
      'executeAutoPlay generates template-aligned palette and accepts it',
      () async {
        final mockAiService = TestMockAiService();
        final wizardNotifier = WizardNotifier(
          WizardStep.selectPalette,
          null,
          WizardMode.template,
        );
        final notifier = CanvasNotifier(
          mockAiService,
          wizardNotifier: wizardNotifier,
        );

        notifier.updatePrompt('space bounty hunter');
        expect(notifier.model.suggestedPalette, isNull);

        final result = await paletteStep.executeAutoPlay(notifier);
        expect(result, isTrue);
        expect(notifier.model.paletteName, equals('suggested'));
        expect(
          mockAiService.capturedPrompts.last,
          contains('space bounty hunter'),
        );
        expect(
          mockAiService.capturedPrompts.last,
          contains('Sprite Character'),
        );
      },
    );
  });
}
