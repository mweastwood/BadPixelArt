import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/canvas_grid.dart';
import '../widgets/color_palette_bar.dart';
import '../widgets/ai_control_dock.dart';

class PixelArtScreen extends ConsumerWidget {
  const PixelArtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070707),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.palette_outlined, color: Colors.blueAccent),
            const SizedBox(width: 8),
            const Text(
              'BadPixelArt Co-Creator',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
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
                  // Left side: Canvas + Palette
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: CanvasGrid()),
                        const SizedBox(height: 16),
                        const ColorPaletteBar(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right side: AI Controls
                  const Expanded(
                    flex: 2,
                    child: SingleChildScrollView(child: AiControlDock()),
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
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
