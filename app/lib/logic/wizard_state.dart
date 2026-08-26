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

enum WizardMode { structured, direct }

class WizardState {
  final WizardDefinition wizard;
  final WizardStep currentStep;
  final WizardStep prevStep;
  final bool autoAdvanced;
  final WizardMode mode;

  const WizardState({
    this.wizard = WizardRegistry.defaultPixelArtWizard,
    this.currentStep = WizardStep.selectGridSize,
    this.prevStep = WizardStep.selectGridSize,
    this.autoAdvanced = false,
    this.mode = WizardMode.structured,
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
    WizardMode? mode,
  }) {
    return WizardState(
      wizard: wizard ?? this.wizard,
      currentStep: currentStep ?? this.currentStep,
      prevStep: prevStep ?? this.prevStep,
      autoAdvanced: autoAdvanced ?? this.autoAdvanced,
      mode: mode ?? this.mode,
    );
  }
}

class WizardNotifier extends StateNotifier<WizardState> {
  WizardNotifier([
    Object initialStep = WizardStep.selectGridSize,
    WizardDefinition? initialWizard,
    WizardMode? initialMode,
  ]) : super(
         WizardState(
           wizard:
               initialWizard ??
               (initialMode == WizardMode.direct
                   ? WizardRegistry.directPixelArtWizard
                   : WizardRegistry.defaultWizard),
           currentStep: parseStep(initialStep),
           prevStep: parseStep(initialStep),
           mode:
               initialMode ??
               (initialWizard?.id == WizardRegistry.directPixelArtWizard.id
                   ? WizardMode.direct
                   : WizardMode.structured),
         ),
       );

  WizardState get wizardState => state;
  WizardStep get currentStep => state.currentStep;
  WizardDefinition get wizard => state.wizard;
  WizardStepDefinition get currentStepDefinition => state.currentStepDefinition;
  WizardMode get mode => state.mode;

  @visibleForTesting
  static WizardStep parseStep(Object? step) {
    if (step is WizardStep) return step;
    if (step is int) {
      return WizardStep.values[step.clamp(0, WizardStep.values.length - 1)];
    }
    return WizardStep.selectGridSize;
  }

  void setMode(WizardMode mode) {
    final targetWizard = mode == WizardMode.direct
        ? WizardRegistry.directPixelArtWizard
        : WizardRegistry.defaultPixelArtWizard;
    final nextStep = targetWizard.steps.any((s) => s.step == state.currentStep)
        ? state.currentStep
        : (targetWizard.steps.isNotEmpty
              ? targetWizard.steps.first.step
              : WizardStep.selectGridSize);
    state = state.copyWith(
      mode: mode,
      wizard: targetWizard,
      currentStep: nextStep,
      prevStep: nextStep,
      autoAdvanced: false,
    );
  }

  void toggleMode() {
    setMode(
      state.mode == WizardMode.structured
          ? WizardMode.direct
          : WizardMode.structured,
    );
  }

  void setWizard(WizardDefinition wizard) {
    final firstStep = wizard.steps.isNotEmpty
        ? wizard.steps.first.step
        : WizardStep.selectGridSize;
    final newMode = wizard.id == WizardRegistry.directPixelArtWizard.id
        ? WizardMode.direct
        : WizardMode.structured;
    state = WizardState(
      wizard: wizard,
      currentStep: firstStep,
      prevStep: firstStep,
      autoAdvanced: false,
      mode: newMode,
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
      mode: state.mode,
    );
  }
}

final wizardStateProvider = StateNotifierProvider<WizardNotifier, WizardState>((
  ref,
) {
  return WizardNotifier();
});
