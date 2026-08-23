import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/wizard_state.dart';

/// Floating action buttons strategy container for navigating the pixel art wizard.
class WizardFloatingActionButtons extends ConsumerWidget {
  const WizardFloatingActionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizardState = ref.watch(wizardStateProvider);
    final autoRun = ref.watch(canvasStateProvider.select((s) => s.autoRun));
    final isPausing = ref.watch(canvasStateProvider.select((s) => s.isPausing));
    final hasRefImage = ref.watch(
      canvasStateProvider.select((s) => s.referenceImage != null),
    );
    final isUserPromptNotEmpty = ref.watch(
      canvasStateProvider.select((s) => s.userPrompt.trim().isNotEmpty),
    );
    final isGenerating = ref.watch(
      canvasStateProvider.select((s) => s.isGenerating),
    );
    final hasDecomposedComponents = ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents.isNotEmpty),
    );

    final isAutoPlaying = autoRun || isPausing;
    final step = wizardState.currentStep;

    final hasBack = !wizardState.isFirstStep;
    final hasNext = !wizardState.isLastStep;

    final onNext = resolveNextStepHandler(
      ref,
      step,
      isAutoPlaying: isAutoPlaying,
      isUserPromptNotEmpty: isUserPromptNotEmpty,
      isGenerating: isGenerating,
      hasDecomposedComponents: hasDecomposedComponents,
    );
    final onBack = resolveBackStepHandler(ref, step, isAutoPlaying);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasBack) ...[
          WizardBackFab(onBack: onBack),
          const SizedBox(width: 12),
        ],
        WizardAutoPlayFab(
          isAutoPlaying: isAutoPlaying,
          isPausing: isPausing,
          hasRefImage: hasRefImage,
          onStopAutoPlay: () =>
              ref.read(canvasStateProvider.notifier).stopAutoPlay(),
          onStartAutoPlay: hasRefImage
              ? () => ref.read(canvasStateProvider.notifier).startAutoPlay()
              : null,
        ),
        if (hasNext) ...[
          const SizedBox(width: 12),
          WizardNextFab(onNext: onNext),
        ],
      ],
    );
  }

  /// Resolves the forward navigation handler for the current [WizardStep].
  static VoidCallback? resolveNextStepHandler(
    WidgetRef ref,
    WizardStep step, {
    required bool isAutoPlaying,
    bool? isUserPromptNotEmpty,
    bool? isGenerating,
    bool? hasDecomposedComponents,
  }) {
    if (isAutoPlaying) return null;
    final wizardState = ref.read(wizardStateProvider);
    final stepDef = wizardState.wizard.getStepDefinition(step);
    if (stepDef == null) return null;
    if (wizardState.isLastStep && step == wizardState.wizard.steps.last.step) {
      return null;
    }

    if (!stepDef.canAdvance(ref)) return null;

    return () {
      stepDef.onManualAdvance(ref);
      final wizard = wizardState.wizard;
      final currentIndex = wizard.indexOfStep(step);
      if (currentIndex >= 0 && currentIndex < wizard.steps.length - 1) {
        final nextStep = wizard.steps[currentIndex + 1].step;
        ref.read(wizardStateProvider.notifier).setStep(nextStep);
      }
    };
  }

  /// Resolves the backward navigation handler for the current [WizardStep].
  static VoidCallback? resolveBackStepHandler(
    WidgetRef ref,
    WizardStep step,
    bool isAutoPlaying,
  ) {
    if (isAutoPlaying) return null;
    final wizardState = ref.read(wizardStateProvider);
    final stepDef = wizardState.wizard.getStepDefinition(step);
    if (stepDef == null) return null;
    if (wizardState.isFirstStep &&
        step == wizardState.wizard.steps.first.step) {
      return null;
    }

    if (!stepDef.canGoBack(ref)) return null;

    return () {
      final wizard = wizardState.wizard;
      final currentIndex = wizard.indexOfStep(step);
      if (currentIndex > 0) {
        final prevStep = wizard.steps[currentIndex - 1].step;
        ref.read(wizardStateProvider.notifier).setStep(prevStep);
      }
    };
  }
}

/// Dedicated FloatingActionButton for stepping backward in the wizard.
class WizardBackFab extends StatelessWidget {
  final VoidCallback? onBack;

  const WizardBackFab({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onBack != null;

    return FloatingActionButton(
      key: const ValueKey('wizard_back_fab'),
      heroTag: 'wizard_back_fab',
      onPressed: onBack,
      tooltip: 'Back',
      backgroundColor: isEnabled
          ? theme.colorScheme.surfaceContainerHigh
          : Color.alphaBlend(
              theme.colorScheme.onSurface.withValues(alpha: 0.12),
              theme.colorScheme.surface,
            ),
      foregroundColor: isEnabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
      elevation: isEnabled ? 6.0 : 0.0,
      child: const Icon(Icons.arrow_back),
    );
  }
}

/// Dedicated FloatingActionButton for starting and pausing auto-play wizard generation.
class WizardAutoPlayFab extends StatelessWidget {
  final bool isAutoPlaying;
  final bool isPausing;
  final bool hasRefImage;
  final VoidCallback? onStopAutoPlay;
  final VoidCallback? onStartAutoPlay;

  const WizardAutoPlayFab({
    super.key,
    required this.isAutoPlaying,
    required this.isPausing,
    required this.hasRefImage,
    required this.onStopAutoPlay,
    required this.onStartAutoPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isAutoPlaying) {
      return FloatingActionButton(
        key: const ValueKey('auto_play_fab'),
        heroTag: 'auto_play_fab',
        onPressed: onStopAutoPlay,
        tooltip: isPausing
            ? 'Pausing after current AI step...'
            : 'Pause Auto-Play',
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: isPausing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.pause),
      );
    }

    return FloatingActionButton(
      key: const ValueKey('auto_play_fab'),
      heroTag: 'auto_play_fab',
      onPressed: onStartAutoPlay,
      tooltip: hasRefImage
          ? 'Start Auto-Play Wizard'
          : 'Upload reference image to enable Auto-Play',
      backgroundColor: hasRefImage
          ? theme.colorScheme.tertiary
          : theme.colorScheme.surfaceContainerHigh,
      foregroundColor: hasRefImage
          ? theme.colorScheme.onTertiary
          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
      elevation: hasRefImage ? 6.0 : 0.0,
      child: const Icon(Icons.play_arrow),
    );
  }
}

/// Dedicated FloatingActionButton for stepping forward in the wizard.
class WizardNextFab extends StatelessWidget {
  final VoidCallback? onNext;

  const WizardNextFab({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onNext != null;

    return FloatingActionButton(
      key: const ValueKey('wizard_next_fab'),
      heroTag: 'wizard_next_fab',
      onPressed: onNext,
      tooltip: 'Next',
      backgroundColor: isEnabled
          ? theme.colorScheme.primary
          : Color.alphaBlend(
              theme.colorScheme.onSurface.withValues(alpha: 0.12),
              theme.colorScheme.surface,
            ),
      foregroundColor: isEnabled
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
      elevation: isEnabled ? 6.0 : 0.0,
      highlightElevation: isEnabled ? 12.0 : 0.0,
      child: const Icon(Icons.arrow_forward),
    );
  }
}
