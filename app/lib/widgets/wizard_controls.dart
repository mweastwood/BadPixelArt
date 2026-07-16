import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'reference_image_prompt.dart';
import 'color_palette_generator.dart';
import 'decomposed_components_list.dart';
import 'ai_history_dock.dart';

class WizardState {
  final int currentStep;
  final int prevStep;
  final bool autoAdvanced;

  const WizardState({
    this.currentStep = 0,
    this.prevStep = 0,
    this.autoAdvanced = false,
  });

  WizardState copyWith({int? currentStep, int? prevStep, bool? autoAdvanced}) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      prevStep: prevStep ?? this.prevStep,
      autoAdvanced: autoAdvanced ?? this.autoAdvanced,
    );
  }
}

class WizardNotifier extends StateNotifier<WizardState> {
  WizardNotifier([int initialStep = 0])
    : super(WizardState(currentStep: initialStep, prevStep: initialStep));

  void setStep(int step) {
    state = state.copyWith(
      prevStep: state.currentStep,
      currentStep: step,
      autoAdvanced: true,
    );
  }

  void autoAdvance(int step) {
    state = state.copyWith(
      prevStep: state.currentStep,
      currentStep: step,
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
        wizardState.currentStep < 2 &&
        canvasState.decomposedComponents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final hasShapes = canvasState.decomposedComponents.any(
          (c) => c.shapes.isNotEmpty,
        );
        ref.read(wizardStateProvider.notifier).autoAdvance(hasShapes ? 3 : 2);
      });
    }

    Widget stepWidget;
    if (wizardState.currentStep == 0) {
      stepWidget = const Column(
        key: ValueKey('step_0'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ReferenceImagePrompt(initialCollapsed: false)],
      );
    } else if (wizardState.currentStep == 1) {
      stepWidget = const Column(
        key: ValueKey('step_1'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ColorPaletteGenerator()],
      );
    } else if (wizardState.currentStep == 2) {
      stepWidget = const Column(
        key: ValueKey('step_2'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [DecomposedComponentsList(initialCollapsed: false)],
      );
    } else {
      stepWidget = const Column(
        key: ValueKey('step_3'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecomposedComponentsList(initialCollapsed: false),
          SizedBox(height: 16),
          AiHistoryDock(),
        ],
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isEntering =
              child.key == ValueKey('step_${wizardState.currentStep}');
          final isForward = wizardState.currentStep >= wizardState.prevStep;

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
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
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
    );
  }
}
