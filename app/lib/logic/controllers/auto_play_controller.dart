import '../canvas_state.dart';
import '../wizard_state.dart';

/// Generic controller for executing automated AutoPlay step-by-step loops for any wizard pipeline.
class AutoPlayWizardController {
  final Duration stepDelay;

  const AutoPlayWizardController({this.stepDelay = const Duration(seconds: 1)});

  /// Starts the AutoPlay loop with the provided [notifier] and [wizardNotifier].
  Future<void> startAutoPlay(
    CanvasNotifier notifier,
    WizardNotifier wizardNotifier,
  ) async {
    if (notifier.model.referenceImage == null &&
        wizardNotifier.mode != WizardMode.template) {
      return;
    }
    if (notifier.model.autoRun) return;

    notifier.setAutoRunState(autoRun: true, isPausing: false);

    while (notifier.model.autoRun) {
      if (notifier.model.isPausing) {
        notifier.setAutoRunState(autoRun: false, isPausing: false);
        break;
      }

      final wizard = wizardNotifier.wizard;
      final currentStepDef = wizardNotifier.currentStepDefinition;

      bool success = false;
      try {
        success = await currentStepDef.executeAutoPlay(notifier);
      } catch (e) {
        notifier.setAutoRunState(autoRun: false, isPausing: false);
        break;
      }

      if (!success || !notifier.model.autoRun || notifier.model.isPausing) {
        notifier.setAutoRunState(autoRun: false, isPausing: false);
        break;
      }

      final currentIndex = wizard.indexOfStep(currentStepDef.step);
      if (currentIndex >= wizard.steps.length - 1) {
        notifier.setAutoRunState(autoRun: false, isPausing: false);
        return;
      }

      if (stepDelay > Duration.zero) {
        await Future.delayed(stepDelay);
      }
      if (!notifier.model.autoRun || notifier.model.isPausing) break;

      final nextStepDef = wizard.steps[currentIndex + 1];
      wizardNotifier.autoAdvance(nextStepDef.step);

      if (notifier.model.isPausing) {
        notifier.setAutoRunState(autoRun: false, isPausing: false);
        break;
      }
    }
  }
}
