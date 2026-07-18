import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'reference_image_prompt.dart';
import 'color_palette_generator.dart';
import 'decomposed_components_list.dart';
import 'shape_decomposition_list.dart';
import 'ai_history_dock.dart';

enum WizardStep {
  setupPrompt,
  selectPalette,
  sketchingPlan,
  componentSculpting,
}

class WizardState {
  final WizardStep currentStep;
  final WizardStep prevStep;
  final bool autoAdvanced;

  const WizardState({
    this.currentStep = WizardStep.setupPrompt,
    this.prevStep = WizardStep.setupPrompt,
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
  WizardNotifier([Object initialStep = WizardStep.setupPrompt])
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
    return WizardStep.setupPrompt;
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
}

final wizardStateProvider = StateNotifierProvider<WizardNotifier, WizardState>((
  ref,
) {
  return WizardNotifier();
});

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
    if (wizardState.currentStep == WizardStep.setupPrompt) {
      stepWidget = const Column(
        key: ValueKey('step_0'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ReferenceImagePrompt(initialCollapsed: false)],
      );
    } else if (wizardState.currentStep == WizardStep.selectPalette) {
      stepWidget = const Column(
        key: ValueKey('step_1'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ColorPaletteGenerator()],
      );
    } else if (wizardState.currentStep == WizardStep.sketchingPlan) {
      stepWidget = const Column(
        key: ValueKey('step_2'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SemanticComponentsList(initialCollapsed: false)],
      );
    } else {
      stepWidget = const Column(
        key: ValueKey('step_3'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ShapeDecompositionList(initialCollapsed: false)],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
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
        const SizedBox(height: 16),
        const AiHistoryDock(),
      ],
    );
  }
}
