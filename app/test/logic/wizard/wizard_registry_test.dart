import 'package:bad_pixel_art/logic/wizard/wizard_definition.dart';
import 'package:bad_pixel_art/logic/wizard/wizard_registry.dart';
import 'package:bad_pixel_art/logic/wizard/steps/default_wizard_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WizardRegistry Tests', () {
    setUp(WizardRegistry.reset);
    tearDown(WizardRegistry.reset);

    test('defaultWizard contains all standard 8 steps', () {
      final defaultWizard = WizardRegistry.defaultWizard;
      expect(defaultWizard.id, equals('default_pixel_art'));
      expect(defaultWizard.stepCount, equals(8));
      expect(WizardRegistry.allWizards, contains(defaultWizard));
    });

    test('directPixelArtWizard contains 4 direct steps', () {
      final directWizard = WizardRegistry.directPixelArtWizard;
      expect(directWizard.id, equals('direct_pixel_art'));
      expect(directWizard.stepCount, equals(4));
      expect(WizardRegistry.allWizards, contains(directWizard));
      expect(WizardRegistry.getById('direct_pixel_art'), equals(directWizard));
    });

    test('templateSpriteWizard contains all standard 8 steps', () {
      final templateWizard = WizardRegistry.templateSpriteWizard;
      expect(templateWizard.id, equals('template_pixel_art'));
      expect(templateWizard.stepCount, equals(8));
      expect(WizardRegistry.allWizards, contains(templateWizard));
      expect(
        WizardRegistry.getById('template_pixel_art'),
        equals(templateWizard),
      );
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

    test('reset restores default predefined wizard pipelines', () {
      const customWizard = WizardDefinition(
        id: 'sprite_anim_wizard',
        title: 'Sprite Animation Wizard',
        steps: [SelectGridSizeStepDefinition(), RefinementStepDefinition()],
      );
      const overriddenDefaultWizard = WizardDefinition(
        id: 'default_pixel_art',
        title: 'Overridden Pixel Art Generator',
        steps: [RefinementStepDefinition()],
      );

      WizardRegistry.register(customWizard);
      WizardRegistry.register(overriddenDefaultWizard);

      expect(
        WizardRegistry.getById('sprite_anim_wizard'),
        equals(customWizard),
      );
      expect(
        WizardRegistry.getById('default_pixel_art'),
        equals(overriddenDefaultWizard),
      );
      expect(WizardRegistry.allWizards, contains(customWizard));
      expect(WizardRegistry.allWizards, contains(overriddenDefaultWizard));

      WizardRegistry.reset();

      expect(WizardRegistry.getById('sprite_anim_wizard'), isNull);
      expect(WizardRegistry.allWizards, isNot(contains(customWizard)));
      expect(
        WizardRegistry.getById('default_pixel_art'),
        equals(WizardRegistry.structuredPixelArtWizard),
      );
      expect(WizardRegistry.allWizards, [
        WizardRegistry.structuredPixelArtWizard,
        WizardRegistry.directPixelArtWizard,
        WizardRegistry.templateSpriteWizard,
      ]);
    });
  });
}
