import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';

void main() {
  group('WizardState Unit Tests', () {
    test('default constructor initializes expected defaults', () {
      const state = WizardState();
      expect(state.currentStep, equals(WizardStep.selectGridSize));
      expect(state.prevStep, equals(WizardStep.selectGridSize));
      expect(state.autoAdvanced, isFalse);
      expect(state.mode, equals(WizardMode.structured));
    });

    test('copyWith updates specified fields and retains others', () {
      const initial = WizardState();
      final updated = initial.copyWith(
        currentStep: WizardStep.sketchingPlan,
        prevStep: WizardStep.setupPrompt,
        autoAdvanced: true,
        mode: WizardMode.direct,
      );

      expect(updated.currentStep, equals(WizardStep.sketchingPlan));
      expect(updated.prevStep, equals(WizardStep.setupPrompt));
      expect(updated.autoAdvanced, isTrue);
      expect(updated.mode, equals(WizardMode.direct));

      final partialUpdate = updated.copyWith(
        currentStep: WizardStep.componentSculpting,
      );
      expect(partialUpdate.currentStep, equals(WizardStep.componentSculpting));
      expect(partialUpdate.prevStep, equals(WizardStep.setupPrompt));
      expect(partialUpdate.autoAdvanced, isTrue);
      expect(partialUpdate.mode, equals(WizardMode.direct));
    });
  });

  group('WizardNotifier Unit Tests', () {
    test(
      'default constructor initializes to selectGridSize with autoAdvanced false and structured mode',
      () {
        final notifier = WizardNotifier();
        expect(notifier.state.currentStep, equals(WizardStep.selectGridSize));
        expect(notifier.state.prevStep, equals(WizardStep.selectGridSize));
        expect(notifier.state.autoAdvanced, isFalse);
        expect(notifier.mode, equals(WizardMode.structured));
      },
    );

    test('constructor with initialMode initializes state to direct mode', () {
      final notifier = WizardNotifier(
        WizardStep.selectGridSize,
        null,
        WizardMode.direct,
      );
      expect(notifier.mode, equals(WizardMode.direct));
      expect(notifier.wizard.id, equals('direct_pixel_art'));
      expect(notifier.wizard.steps.length, equals(4));
    });

    test('constructor with initialMode initializes state to template mode', () {
      final notifier = WizardNotifier(
        WizardStep.selectTemplate,
        null,
        WizardMode.template,
      );
      expect(notifier.mode, equals(WizardMode.template));
      expect(notifier.wizard.id, equals('template_pixel_art'));
      expect(notifier.wizard.steps.length, equals(4));
    });

    test('setMode switches between structured, direct, and template modes', () {
      final notifier = WizardNotifier();
      expect(notifier.mode, equals(WizardMode.structured));
      expect(notifier.wizard.id, equals('default_pixel_art'));

      notifier.setMode(WizardMode.direct);
      expect(notifier.mode, equals(WizardMode.direct));
      expect(notifier.wizard.id, equals('direct_pixel_art'));
      expect(notifier.wizard.steps.length, equals(4));

      notifier.setMode(WizardMode.template);
      expect(notifier.mode, equals(WizardMode.template));
      expect(notifier.wizard.id, equals('template_pixel_art'));
      expect(notifier.wizard.steps.length, equals(4));

      notifier.setMode(WizardMode.structured);
      expect(notifier.mode, equals(WizardMode.structured));
      expect(notifier.wizard.id, equals('default_pixel_art'));
      expect(notifier.wizard.steps.length, equals(8));
    });

    test(
      'toggleMode alternates between structured, direct, and template modes',
      () {
        final notifier = WizardNotifier();
        expect(notifier.mode, equals(WizardMode.structured));

        notifier.toggleMode();
        expect(notifier.mode, equals(WizardMode.direct));

        notifier.toggleMode();
        expect(notifier.mode, equals(WizardMode.template));

        notifier.toggleMode();
        expect(notifier.mode, equals(WizardMode.structured));
      },
    );

    test('constructor with WizardStep initializes state accurately', () {
      final notifier = WizardNotifier(WizardStep.componentSculpting);
      expect(notifier.state.currentStep, equals(WizardStep.componentSculpting));
      expect(notifier.state.prevStep, equals(WizardStep.componentSculpting));
      expect(notifier.state.autoAdvanced, isFalse);
    });

    test('constructor with integer index initializes state accurately', () {
      final notifier = WizardNotifier(3);
      expect(notifier.state.currentStep, equals(WizardStep.sketchingPlan));
      expect(notifier.state.prevStep, equals(WizardStep.sketchingPlan));
      expect(notifier.state.autoAdvanced, isFalse);
    });

    test('setStep updates currentStep and sets autoAdvanced to false', () {
      final notifier = WizardNotifier(WizardStep.selectGridSize);

      notifier.setStep(WizardStep.setupPrompt);
      expect(notifier.state.currentStep, equals(WizardStep.setupPrompt));
      expect(notifier.state.prevStep, equals(WizardStep.selectGridSize));
      expect(notifier.state.autoAdvanced, isFalse);

      notifier.setStep(WizardStep.selectPalette);
      expect(notifier.state.currentStep, equals(WizardStep.selectPalette));
      expect(notifier.state.prevStep, equals(WizardStep.setupPrompt));
      expect(notifier.state.autoAdvanced, isFalse);
    });

    test('autoAdvance updates currentStep and sets autoAdvanced to true', () {
      final notifier = WizardNotifier(WizardStep.selectGridSize);

      notifier.autoAdvance(WizardStep.setupPrompt);
      expect(notifier.state.currentStep, equals(WizardStep.setupPrompt));
      expect(notifier.state.prevStep, equals(WizardStep.selectGridSize));
      expect(notifier.state.autoAdvanced, isTrue);

      notifier.autoAdvance(WizardStep.selectPalette);
      expect(notifier.state.currentStep, equals(WizardStep.selectPalette));
      expect(notifier.state.prevStep, equals(WizardStep.setupPrompt));
      expect(notifier.state.autoAdvanced, isTrue);
    });

    test(
      'setStep clears autoAdvanced flag after an autoAdvance transition',
      () {
        final notifier = WizardNotifier(WizardStep.selectGridSize);

        notifier.autoAdvance(WizardStep.setupPrompt);
        expect(notifier.state.autoAdvanced, isTrue);

        notifier.setStep(WizardStep.selectPalette);
        expect(notifier.state.currentStep, equals(WizardStep.selectPalette));
        expect(notifier.state.prevStep, equals(WizardStep.setupPrompt));
        expect(notifier.state.autoAdvanced, isFalse);
      },
    );

    test(
      'reset resets step to selectGridSize and autoAdvanced to false while preserving mode',
      () {
        final notifier = WizardNotifier(
          WizardStep.refinement,
          null,
          WizardMode.direct,
        );
        notifier.autoAdvance(WizardStep.refinement);
        expect(notifier.state.autoAdvanced, isTrue);
        expect(notifier.mode, equals(WizardMode.direct));

        notifier.reset();
        expect(notifier.state.currentStep, equals(WizardStep.selectGridSize));
        expect(notifier.state.prevStep, equals(WizardStep.selectGridSize));
        expect(notifier.state.autoAdvanced, isFalse);
        expect(notifier.mode, equals(WizardMode.direct));
      },
    );
  });

  group('WizardNotifier.parseStep Edge Cases', () {
    test('returns WizardStep enum values directly', () {
      for (final step in WizardStep.values) {
        expect(WizardNotifier.parseStep(step), equals(step));
      }
    });

    test('parses in-bounds integer values to corresponding WizardStep', () {
      for (int i = 0; i < WizardStep.values.length; i++) {
        expect(WizardNotifier.parseStep(i), equals(WizardStep.values[i]));
      }
    });

    test('clamps negative integers to selectGridSize (index 0)', () {
      expect(WizardNotifier.parseStep(-1), equals(WizardStep.selectGridSize));
      expect(WizardNotifier.parseStep(-100), equals(WizardStep.selectGridSize));
    });

    test('clamps integers exceeding range to last index', () {
      expect(WizardNotifier.parseStep(8), equals(WizardStep.selectTemplate));
      expect(WizardNotifier.parseStep(999), equals(WizardStep.selectTemplate));
    });

    test('falls back to selectGridSize on invalid types and null', () {
      expect(WizardNotifier.parseStep(null), equals(WizardStep.selectGridSize));
      expect(
        WizardNotifier.parseStep('step0'),
        equals(WizardStep.selectGridSize),
      );
      expect(WizardNotifier.parseStep(3.14), equals(WizardStep.selectGridSize));
      expect(WizardNotifier.parseStep(true), equals(WizardStep.selectGridSize));
      expect(WizardNotifier.parseStep([]), equals(WizardStep.selectGridSize));
      expect(WizardNotifier.parseStep({}), equals(WizardStep.selectGridSize));
    });
  });

  group('wizardStateProvider Tests', () {
    test('provider container manages WizardNotifier lifecycle and state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(wizardStateProvider);
      expect(state.currentStep, equals(WizardStep.selectGridSize));

      final notifier = container.read(wizardStateProvider.notifier);
      notifier.setStep(WizardStep.setupPrompt);

      expect(
        container.read(wizardStateProvider).currentStep,
        equals(WizardStep.setupPrompt),
      );
      expect(container.read(wizardStateProvider).autoAdvanced, isFalse);
    });
  });
}
