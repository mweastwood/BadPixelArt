import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/canvas_state.dart';
import '../widgets/canvas_grid.dart';
import '../widgets/wizard_controls.dart';

class CanvasScreen extends ConsumerWidget {
  const CanvasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDraggingCanvas = ref.watch(isDraggingCanvasProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > 800;

        if (isLandscape) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(flex: 3, child: CanvasGrid()),
                const SizedBox(width: 24),
                const Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 120.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [WizardControls()],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            physics: isDraggingCanvas
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 120.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 440, child: CanvasGrid()),
                const SizedBox(height: 16),
                const WizardControls(),
              ],
            ),
          );
        }
      },
    );
  }
}
