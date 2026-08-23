import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/wizard_state.dart';

class WizardControls extends ConsumerWidget {
  const WizardControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decomposedComponents = ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents),
    );
    final isPausing = ref.watch(canvasStateProvider.select((s) => s.isPausing));
    final autoRun = ref.watch(canvasStateProvider.select((s) => s.autoRun));
    final wizardState = ref.watch(wizardStateProvider);

    // Auto-advancing logic
    if (!wizardState.autoAdvanced &&
        wizardState.currentStep.index < WizardStep.sketchingPlan.index &&
        decomposedComponents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final hasShapes = decomposedComponents.any((c) => c.shapes.isNotEmpty);
        ref
            .read(wizardStateProvider.notifier)
            .autoAdvance(
              hasShapes
                  ? WizardStep.componentSculpting
                  : WizardStep.sketchingPlan,
            );
      });
    }

    final stepWidget = Column(
      key: ValueKey('step_${wizardState.currentStep.index}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [wizardState.currentStepDefinition.buildWidget(context, ref)],
    );

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPausing) ...[
          Container(
            key: const ValueKey('auto_play_pausing_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.error),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pausing... Waiting for current AI step to finish before returning control.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (autoRun) ...[
          Container(
            key: const ValueKey('auto_play_active_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill,
                  size: 20,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Auto-Play Active — Stepping through wizard...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final isEntering =
                  child.key ==
                  ValueKey('step_${wizardState.currentStep.index}');
              final isForward =
                  wizardState.currentStep.index >= wizardState.prevStep.index;

              Offset beginOffset;
              if (isEntering) {
                beginOffset = isForward
                    ? const Offset(1.0, 0.0)
                    : const Offset(-1.0, 0.0);
              } else {
                beginOffset = isForward
                    ? const Offset(-1.0, 0.0)
                    : const Offset(1.0, 0.0);
              }

              final slide = Tween<Offset>(
                begin: beginOffset,
                end: Offset.zero,
              ).animate(animation);

              return SlideTransition(
                position: slide,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren.map((w) {
                        return Positioned(left: 0, right: 0, child: w);
                      }),
                      currentChild ?? const SizedBox.shrink(),
                    ],
                  );
                },
            child: stepWidget,
          ),
        ),
      ],
    );
  }
}
