import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final WizardStep currentStep;
  final WizardStep prevStep;
  final bool autoAdvanced;

  const WizardState({
    this.currentStep = WizardStep.selectGridSize,
    this.prevStep = WizardStep.selectGridSize,
    this.autoAdvanced = false,
  });

  WizardState copyWith({
    WizardStep? currentStep,
    WizardStep? prevStep,
    bool? autoAdvanced,
  }) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      prevStep: prevStep ?? this.prevStep,
      autoAdvanced: autoAdvanced ?? this.autoAdvanced,
    );
  }
}

class WizardNotifier extends StateNotifier<WizardState> {
  WizardNotifier([Object initialStep = WizardStep.selectGridSize])
    : super(
        WizardState(
          currentStep: _parseStep(initialStep),
          prevStep: _parseStep(initialStep),
        ),
      );

  static WizardStep _parseStep(Object step) {
    if (step is WizardStep) return step;
    if (step is int) {
      return WizardStep.values[step.clamp(0, WizardStep.values.length - 1)];
    }
    return WizardStep.selectGridSize;
  }

  void setStep(Object step) {
    final parsed = _parseStep(step);
    state = state.copyWith(
      prevStep: state.currentStep,
      currentStep: parsed,
      autoAdvanced: true,
    );
  }

  void autoAdvance(Object step) {
    final parsed = _parseStep(step);
    state = state.copyWith(
      prevStep: state.currentStep,
      currentStep: parsed,
      autoAdvanced: true,
    );
  }

  void reset() {
    state = const WizardState(
      currentStep: WizardStep.selectGridSize,
      prevStep: WizardStep.selectGridSize,
      autoAdvanced: false,
    );
  }
}

final wizardStateProvider = StateNotifierProvider<WizardNotifier, WizardState>((
  ref,
) {
  return WizardNotifier();
});
