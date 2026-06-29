// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class ColorPaletteBar extends ConsumerWidget {
  const ColorPaletteBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);

    return Card(
      color: Colors.grey[950],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[850]!, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Palette Selectors and Action Buttons (Undo/Redo/Reset)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Segmented Palette Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _PaletteTabButton(
                        label: 'Primary 8',
                        isSelected: canvasModel.paletteName == 'primary',
                        onTap: () => notifier.selectPalette('primary'),
                      ),
                      const SizedBox(width: 4),
                      _PaletteTabButton(
                        label: 'Grayscale 4',
                        isSelected: canvasModel.paletteName == 'grayscale',
                        onTap: () => notifier.selectPalette('grayscale'),
                      ),
                    ],
                  ),
                ),

                // Canvas Tools (Undo, Redo, Reset)
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo, color: Colors.white70),
                      onPressed: canvasModel.undoStack.isNotEmpty
                          ? notifier.undo
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      icon: const Icon(Icons.redo, color: Colors.white70),
                      onPressed: canvasModel.redoStack.isNotEmpty
                          ? notifier.redo
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Reset Canvas',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: notifier.resetCanvas,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color Swatches
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: canvasModel.palette.length,
                separatorBuilder: (_, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = canvasModel.palette[index];
                  final isSelected = canvasModel.selectedColorIndex == index;

                  return GestureDetector(
                    onTap: () => notifier.selectColor(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.amberAccent
                              : Colors.grey[800]!,
                          width: isSelected ? 3 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.amberAccent.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color:
                                  ThemeData.estimateBrightnessForColor(color) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Brush Tools Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BrushToolButton(
                  icon: Icons.gesture,
                  label: 'Line',
                  isSelected: canvasModel.selectedTool == CanvasTool.line,
                  onTap: () => notifier.selectTool(CanvasTool.line),
                ),
                _BrushToolButton(
                  icon: Icons.radio_button_unchecked,
                  label: 'Circle',
                  isSelected: canvasModel.selectedTool == CanvasTool.circle,
                  onTap: () => notifier.selectTool(CanvasTool.circle),
                ),
                _BrushToolButton(
                  icon: Icons.format_color_fill,
                  label: 'Fill',
                  isSelected: canvasModel.selectedTool == CanvasTool.fill,
                  onTap: () => notifier.selectTool(CanvasTool.fill),
                ),
                _BrushToolButton(
                  icon: Icons.grid_on,
                  label: 'Hatch',
                  isSelected: canvasModel.selectedTool == CanvasTool.hatch,
                  onTap: () => notifier.selectTool(CanvasTool.hatch),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[850] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _BrushToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BrushToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blueAccent : Colors.white60,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
