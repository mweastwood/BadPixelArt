import 'package:bad_pixel_art/logic/wizard/wizard_definition.dart';
import 'package:bad_pixel_art/logic/wizard/steps/default_wizard_steps.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WizardDefinition Tests', () {
    test('instantiates with custom steps and computes stepCount', () {
      const wizard = WizardDefinition(
        id: 'custom_wizard',
        title: 'Custom Wizard',
        description: 'Test description',
        steps: [
          SelectGridSizeStepDefinition(),
          SetupPromptStepDefinition(),
          RefinementStepDefinition(),
        ],
      );

      expect(wizard.id, equals('custom_wizard'));
      expect(wizard.title, equals('Custom Wizard'));
      expect(wizard.description, equals('Test description'));
      expect(wizard.stepCount, equals(3));
    });

    test('indexOfStep returns correct index or -1 if not found', () {
      const wizard = WizardDefinition(
        id: 'short_wizard',
        title: 'Short Wizard',
        steps: [SelectGridSizeStepDefinition(), SetupPromptStepDefinition()],
      );

      expect(wizard.indexOfStep(WizardStep.selectGridSize), equals(0));
      expect(wizard.indexOfStep(WizardStep.setupPrompt), equals(1));
      expect(wizard.indexOfStep(WizardStep.refinement), equals(-1));
    });

    test('getStepDefinition returns corresponding definition or null', () {
      const wizard = WizardDefinition(
        id: 'short_wizard',
        title: 'Short Wizard',
        steps: [SelectGridSizeStepDefinition(), RefinementStepDefinition()],
      );

      expect(
        wizard.getStepDefinition(WizardStep.selectGridSize),
        isA<SelectGridSizeStepDefinition>(),
      );
      expect(
        wizard.getStepDefinition(WizardStep.refinement),
        isA<RefinementStepDefinition>(),
      );
      expect(wizard.getStepDefinition(WizardStep.setupPrompt), isNull);
    });
  });
}
