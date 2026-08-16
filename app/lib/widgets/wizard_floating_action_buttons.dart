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

    final hasBack = step.index > 0;
    final hasNext = step.index < WizardStep.refinement.index;

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
    required bool isUserPromptNotEmpty,
    required bool isGenerating,
    required bool hasDecomposedComponents,
  }) {
    if (isAutoPlaying) return null;

    switch (step) {
      case WizardStep.selectGridSize:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.setupPrompt);
      case WizardStep.setupPrompt:
        return isUserPromptNotEmpty
            ? () => ref
                  .read(wizardStateProvider.notifier)
                  .setStep(WizardStep.selectPalette)
            : null;
      case WizardStep.selectPalette:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.sketchingPlan);
      case WizardStep.sketchingPlan:
        return (isGenerating || !hasDecomposedComponents)
            ? null
            : () => ref
                  .read(wizardStateProvider.notifier)
                  .setStep(WizardStep.componentSculpting);
      case WizardStep.componentSculpting:
        return !hasDecomposedComponents
            ? null
            : () => ref
                  .read(wizardStateProvider.notifier)
                  .setStep(WizardStep.colorAndOutline);
      case WizardStep.colorAndOutline:
        return !hasDecomposedComponents
            ? null
            : () => ref
                  .read(wizardStateProvider.notifier)
                  .setStep(WizardStep.layerOrderingAndMerge);
      case WizardStep.layerOrderingAndMerge:
        return () {
          ref.read(canvasStateProvider.notifier).mergeComponentsToCanvas();
          ref.read(wizardStateProvider.notifier).setStep(WizardStep.refinement);
        };
      case WizardStep.refinement:
        return null;
    }
  }

  /// Resolves the backward navigation handler for the current [WizardStep].
  static VoidCallback? resolveBackStepHandler(
    WidgetRef ref,
    WizardStep step,
    bool isAutoPlaying,
  ) {
    if (isAutoPlaying) return null;

    switch (step) {
      case WizardStep.selectGridSize:
        return null;
      case WizardStep.setupPrompt:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.selectGridSize);
      case WizardStep.selectPalette:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.setupPrompt);
      case WizardStep.sketchingPlan:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.selectPalette);
      case WizardStep.componentSculpting:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.sketchingPlan);
      case WizardStep.colorAndOutline:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.componentSculpting);
      case WizardStep.layerOrderingAndMerge:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.colorAndOutline);
      case WizardStep.refinement:
        return () => ref
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.layerOrderingAndMerge);
    }
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
