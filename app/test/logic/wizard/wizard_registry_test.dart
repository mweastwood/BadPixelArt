import 'package:bad_pixel_art/logic/wizard/wizard_definition.dart';
import 'package:bad_pixel_art/logic/wizard/wizard_registry.dart';
import 'package:bad_pixel_art/logic/wizard/steps/default_wizard_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WizardRegistry Tests', () {
    test('defaultWizard contains all standard 8 steps', () {
      final defaultWizard = WizardRegistry.defaultWizard;
      expect(defaultWizard.id, equals('default_pixel_art'));
      expect(defaultWizard.stepCount, equals(8));
      expect(WizardRegistry.allWizards, contains(defaultWizard));
    });

    test('getById returns registered wizard or null', () {
      expect(
        WizardRegistry.getById('default_pixel_art'),
        equals(WizardRegistry.defaultWizard),
      );
      expect(WizardRegistry.getById('non_existent'), isNull);
    });

    test('register adds custom wizard definition', () {
      const customWizard = WizardDefinition(
        id: 'sprite_anim_wizard',
        title: 'Sprite Animation Wizard',
        steps: [SelectGridSizeStepDefinition(), RefinementStepDefinition()],
      );

      WizardRegistry.register(customWizard);

      expect(
        WizardRegistry.getById('sprite_anim_wizard'),
        equals(customWizard),
      );
      expect(WizardRegistry.allWizards, contains(customWizard));
    });
  });
}
