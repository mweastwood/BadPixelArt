import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/wizard_state.dart';
import 'grid_size_selection_card.dart';
import 'reference_image_prompt.dart';
import 'color_palette_generator.dart';
import 'semantic_components_list.dart';
import 'shape_decomposition_list.dart';
import 'component_color_selection_list.dart';
import 'layer_ordering_list.dart';
import 'refinement_panel.dart';

class WizardControls extends ConsumerWidget {
  const WizardControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasStateProvider);
    final wizardState = ref.watch(wizardStateProvider);

    // Auto-advancing logic
    if (!wizardState.autoAdvanced &&
        wizardState.currentStep.index < WizardStep.sketchingPlan.index &&
        canvasState.decomposedComponents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final hasShapes = canvasState.decomposedComponents.any(
          (c) => c.shapes.isNotEmpty,
        );
        ref
            .read(wizardStateProvider.notifier)
            .autoAdvance(
              hasShapes
                  ? WizardStep.componentSculpting
                  : WizardStep.sketchingPlan,
            );
      });
    }

    Widget stepWidget;
    if (wizardState.currentStep == WizardStep.selectGridSize) {
      stepWidget = const Column(
        key: ValueKey('step_0'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [GridSizeSelectionCard()],
      );
    } else if (wizardState.currentStep == WizardStep.setupPrompt) {
      stepWidget = const Column(
        key: ValueKey('step_1'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ReferenceImagePrompt()],
      );
    } else if (wizardState.currentStep == WizardStep.selectPalette) {
      stepWidget = const Column(
        key: ValueKey('step_2'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ColorPaletteGenerator()],
      );
    } else if (wizardState.currentStep == WizardStep.sketchingPlan) {
      stepWidget = const Column(
        key: ValueKey('step_3'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SemanticComponentsList()],
      );
    } else if (wizardState.currentStep == WizardStep.componentSculpting) {
      stepWidget = const Column(
        key: ValueKey('step_4'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ShapeDecompositionList()],
      );
    } else if (wizardState.currentStep == WizardStep.colorAndOutline) {
      stepWidget = const Column(
        key: ValueKey('step_5'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ComponentColorSelectionList()],
      );
    } else if (wizardState.currentStep == WizardStep.layerOrderingAndMerge) {
      stepWidget = const Column(
        key: ValueKey('step_6'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [LayerOrderingList()],
      );
    } else {
      stepWidget = const Column(
        key: ValueKey('step_7'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [RefinementPanel()],
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canvasState.isPausing) ...[
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
        ] else if (canvasState.autoRun) ...[
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
