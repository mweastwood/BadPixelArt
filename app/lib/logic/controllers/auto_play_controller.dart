import '../wizard_state.dart';
import '../canvas_state.dart';

/// Controller for executing the automated AutoPlay wizard step-by-step loop.
class AutoPlayWizardController {
  /// Starts the AutoPlay loop with the provided [notifier] and [wizardNotifier].
  Future<void> startAutoPlay(
    CanvasNotifier notifier,
    WizardNotifier wizardNotifier,
  ) async {
    if (notifier.model.referenceImage == null) return;
    if (notifier.model.autoRun) return;

    notifier.setAutoRunState(autoRun: true, isPausing: false);

    while (notifier.model.autoRun) {
      if (notifier.model.isPausing) {
        notifier.setAutoRunState(autoRun: false, isPausing: false);
        break;
      }

      final currentStep = wizardNotifier.currentStep;

      switch (currentStep) {
        case WizardStep.selectGridSize:
          await Future.delayed(const Duration(seconds: 1));
          if (!notifier.model.autoRun || notifier.model.isPausing) break;
          wizardNotifier.autoAdvance(WizardStep.setupPrompt);
          break;

        case WizardStep.setupPrompt:
          if (notifier.model.userPrompt.trim().isEmpty &&
              notifier.model.referenceImage != null) {
            await notifier.suggestDescriptionFromReference();
          }
          await Future.delayed(const Duration(seconds: 1));
          if (!notifier.model.autoRun || notifier.model.isPausing) break;
          wizardNotifier.autoAdvance(WizardStep.selectPalette);
          break;

        case WizardStep.selectPalette:
          if (notifier.model.suggestedPalette == null &&
              notifier.model.referenceImage != null) {
            await notifier.suggestPaletteFromReference();
            if (notifier.model.suggestedPalette != null) {
              notifier.acceptSuggestedPalette();
            }
          } else if (notifier.model.suggestedPalette != null &&
              notifier.model.showPaletteSuggestion) {
            notifier.acceptSuggestedPalette();
          }
          await Future.delayed(const Duration(seconds: 1));
          if (!notifier.model.autoRun || notifier.model.isPausing) break;
          wizardNotifier.autoAdvance(WizardStep.sketchingPlan);
          break;

        case WizardStep.sketchingPlan:
          if (notifier.model.decomposedComponents.isEmpty &&
              !notifier.model.isGenerating) {
            await notifier.triggerDecomposition();
            if (notifier.model.pendingDecompositionOptions.isNotEmpty) {
              notifier.applyDecompositionOption(0);
            }
          }
          await Future.delayed(const Duration(seconds: 1));
          if (!notifier.model.autoRun || notifier.model.isPausing) break;
          wizardNotifier.autoAdvance(WizardStep.componentSculpting);
          break;

        case WizardStep.componentSculpting:
          if (notifier.model.decomposedComponents.isNotEmpty) {
            bool allComplete = notifier.model.decomposedComponents.every(
              (c) => c.grid != null,
            );
            if (!allComplete && !notifier.model.isGenerating) {
              await notifier.sketchComponents();
            }
            await Future.delayed(const Duration(seconds: 1));
            if (!notifier.model.autoRun || notifier.model.isPausing) break;
            wizardNotifier.autoAdvance(WizardStep.colorAndOutline);
          } else {
            await Future.delayed(const Duration(seconds: 1));
            if (!notifier.model.autoRun || notifier.model.isPausing) break;
            wizardNotifier.autoAdvance(WizardStep.colorAndOutline);
          }
          break;

        case WizardStep.colorAndOutline:
          if (notifier.model.decomposedComponents.isNotEmpty &&
              notifier.model.referenceImage != null &&
              !notifier.model.isGenerating) {
            final result = await notifier.suggestComponentColors();
            if (result != null) {
              notifier.batchUpdateComponentColors(result.updatedComponents);
            }
          }
          await Future.delayed(const Duration(seconds: 1));
          if (!notifier.model.autoRun || notifier.model.isPausing) break;
          wizardNotifier.autoAdvance(WizardStep.layerOrderingAndMerge);
          break;

        case WizardStep.layerOrderingAndMerge:
          if (notifier.model.decomposedComponents.isNotEmpty) {
            notifier.mergeComponentsToCanvas();
          }
          await Future.delayed(const Duration(seconds: 1));
          if (!notifier.model.autoRun || notifier.model.isPausing) break;
          wizardNotifier.autoAdvance(WizardStep.refinement);
          break;

        case WizardStep.refinement:
          if (!notifier.model.isGenerating &&
              notifier.model.userPrompt.trim().isNotEmpty) {
            await notifier.refineCanvas(notifier.model.userPrompt);
          }
          notifier.setAutoRunState(autoRun: false, isPausing: false);
          return;
      }

      if (notifier.model.isPausing) {
        notifier.setAutoRunState(autoRun: false, isPausing: false);
        break;
      }
    }
  }
}
