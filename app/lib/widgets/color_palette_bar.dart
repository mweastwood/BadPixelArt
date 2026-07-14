import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class ColorPaletteBar extends ConsumerStatefulWidget {
  const ColorPaletteBar({super.key});

  @override
  ConsumerState<ColorPaletteBar> createState() => _ColorPaletteBarState();
}

class _ColorPaletteBarState extends ConsumerState<ColorPaletteBar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row (Tappable to expand/collapse)
            InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4.0,
                  horizontal: 4.0,
                ),
                child: Row(
                  children: [
                    Text(
                      'Color Palette',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (!_isCollapsed) ...[
              const SizedBox(height: 12),
              // Palette Selectors and Action Buttons (Undo/Redo/Reset)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Segmented Palette Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
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
                        if (canvasModel.paletteName == 'suggested' ||
                            canvasModel.suggestedPalette != null) ...[
                          const SizedBox(width: 4),
                          _PaletteTabButton(
                            label: 'AI 16',
                            isSelected: canvasModel.paletteName == 'suggested',
                            onTap: () {
                              if (canvasModel.suggestedPalette != null) {
                                notifier.acceptSuggestedPalette();
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Canvas Tools (Undo, Redo, Reset)
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Undo',
                        icon: const Icon(Icons.undo),
                        onPressed: canvasModel.undoStack.isNotEmpty
                            ? notifier.undo
                            : null,
                      ),
                      IconButton(
                        tooltip: 'Redo',
                        icon: const Icon(Icons.redo),
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

                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
