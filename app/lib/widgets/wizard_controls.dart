import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import 'reference_image_prompt.dart';
import 'color_palette_generator.dart';
import 'decomposed_components_list.dart';
import 'ai_history_dock.dart';

class WizardControls extends ConsumerStatefulWidget {
  final int initialStep;

  const WizardControls({super.key, this.initialStep = 0});

  @override
  ConsumerState<WizardControls> createState() => _WizardControlsState();
}

class _WizardControlsState extends ConsumerState<WizardControls> {
  late int _currentStep;
  late int _prevStep;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _prevStep = widget.initialStep;
  }

  void _setStep(int step) {
    setState(() {
      _prevStep = _currentStep;
      _currentStep = step;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasStateProvider);
    final theme = Theme.of(context);

    // Let the user advance if they've provided a prompt.
    // If they have also provided a reference image, that is even better!
    final canGoToPalette = canvasState.userPrompt.trim().isNotEmpty;

    // Advance automatically to Step 2 if components are already decomposed,
    // so the user doesn't get stuck in Step 0/1 if reloading or starting with components.
    if (_currentStep < 2 && canvasState.decomposedComponents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentStep < 2) {
          _setStep(2);
        }
      });
    }

    Widget stepWidget;
    if (_currentStep == 0) {
      stepWidget = Column(
        key: const ValueKey('step_0_ref_prompt'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ReferenceImagePrompt(initialCollapsed: false),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const ValueKey('wizard_next_to_palette'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: canGoToPalette ? () => _setStep(1) : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next: Choose Color Palette',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      stepWidget = Column(
        key: const ValueKey('step_1_palette'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColorPaletteGenerator(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('wizard_back_to_prompt'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  onPressed: () => _setStep(0),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('wizard_next_to_decomposed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () => _setStep(2),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next: Sketch Plan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      stepWidget = Column(
        key: const ValueKey('step_2_sketch'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DecomposedComponentsList(initialCollapsed: false),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('wizard_back_to_palette'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            onPressed: () => _setStep(1),
            icon: const Icon(Icons.palette_outlined, size: 16),
            label: const Text('Back to Color Palette'),
          ),
          const SizedBox(height: 16),
          const AiHistoryDock(),
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
          final isEntering = child.key == ValueKey('step_$_currentStep');
          final isForward = _currentStep >= _prevStep;

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
              ?currentChild,
            ],
          );
        },
        child: stepWidget,
      ),
    );
  }
}
