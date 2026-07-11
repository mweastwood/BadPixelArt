import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/canvas_grid.dart';
import '../widgets/color_palette_bar.dart';
import '../widgets/ai_control_dock.dart';
import '../widgets/ai_history_dock.dart';

class PixelArtScreen extends ConsumerWidget {
  const PixelArtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bad Pixel Art')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > 800;

          if (isLandscape) {
            // Desktop/Tablet Split Layout
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Just the Canvas
                  const Expanded(flex: 3, child: CanvasGrid()),
                  const SizedBox(width: 24),
                  // Right side: Controls (Palette & AI)
                  const Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ColorPaletteBar(),
                          SizedBox(height: 16),
                          AiControlDock(),
                          SizedBox(height: 16),
                          AiHistoryDock(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Mobile Portrait Layout
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 380, child: CanvasGrid()),
                  const SizedBox(height: 16),
                  const ColorPaletteBar(),
                  const SizedBox(height: 16),
                  const AiControlDock(),
                  const SizedBox(height: 16),
                  const AiHistoryDock(),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
