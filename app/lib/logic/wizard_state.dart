import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wizard/wizard_definition.dart';
import 'wizard/wizard_registry.dart';
import 'wizard/wizard_step_definition.dart';

enum WizardStep {
  selectGridSize,
  setupPrompt,
  selectPalette,
  sketchingPlan,
  componentSculpting,
  colorAndOutline,
  layerOrderingAndMerge,
  refinement,
}

class WizardState {
  final WizardDefinition wizard;
  final WizardStep currentStep;
  final WizardStep prevStep;
  final bool autoAdvanced;

  const WizardState({
    this.wizard = WizardRegistry.defaultPixelArtWizard,
    this.currentStep = WizardStep.selectGridSize,
    this.prevStep = WizardStep.selectGridSize,
    this.autoAdvanced = false,
  });

  WizardStepDefinition get currentStepDefinition {
    return wizard.getStepDefinition(currentStep) ?? wizard.steps.first;
  }

  int get currentStepIndex => wizard.indexOfStep(currentStep);

  bool get isFirstStep => currentStepIndex <= 0;

  bool get isLastStep => currentStepIndex >= wizard.steps.length - 1;

  int get stepCount => wizard.stepCount;

  WizardState copyWith({
    WizardDefinition? wizard,
    WizardStep? currentStep,
    WizardStep? prevStep,
    bool? autoAdvanced,
  }) {
    return WizardState(
      wizard: wizard ?? this.wizard,
      currentStep: currentStep ?? this.currentStep,
      prevStep: prevStep ?? this.prevStep,
      autoAdvanced: autoAdvanced ?? this.autoAdvanced,
    );
  }
}

class WizardNotifier extends StateNotifier<WizardState> {
  WizardNotifier([
    Object initialStep = WizardStep.selectGridSize,
    WizardDefinition? initialWizard,
  ]) : super(
         WizardState(
           wizard: initialWizard ?? WizardRegistry.defaultWizard,
           currentStep: parseStep(initialStep),
           prevStep: parseStep(initialStep),
         ),
       );

  WizardState get wizardState => state;
  WizardStep get currentStep => state.currentStep;
  WizardDefinition get wizard => state.wizard;
  WizardStepDefinition get currentStepDefinition => state.currentStepDefinition;

  @visibleForTesting
  static WizardStep parseStep(Object? step) {
    if (step is WizardStep) return step;
    if (step is int) {
      return WizardStep.values[step.clamp(0, WizardStep.values.length - 1)];
    }
    return WizardStep.selectGridSize;
  }

  void setWizard(WizardDefinition wizard) {
    final firstStep = wizard.steps.isNotEmpty
        ? wizard.steps.first.step
        : WizardStep.selectGridSize;
    state = WizardState(
      wizard: wizard,
      currentStep: firstStep,
      prevStep: firstStep,
      autoAdvanced: false,
    );
  }

  void setStep(WizardStep step) {
    state = state.copyWith(
      prevStep: state.currentStep,
      currentStep: step,
      autoAdvanced: false,
    );
  }

  void autoAdvance(WizardStep step) {
    state = state.copyWith(
      prevStep: state.currentStep,
      currentStep: step,
      autoAdvanced: true,
    );
  }

  void reset() {
    final firstStep = state.wizard.steps.isNotEmpty
        ? state.wizard.steps.first.step
        : WizardStep.selectGridSize;
    state = WizardState(
      wizard: state.wizard,
      currentStep: firstStep,
      prevStep: firstStep,
      autoAdvanced: false,
    );
  }
}

final wizardStateProvider = StateNotifierProvider<WizardNotifier, WizardState>((
  ref,
) {
  return WizardNotifier();
});
