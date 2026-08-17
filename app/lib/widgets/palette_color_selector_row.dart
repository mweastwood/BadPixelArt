import 'package:flutter/material.dart';

class PaletteColorSelectorRow extends StatelessWidget {
  final String title;
  final Color? selectedColor;
  final List<Color> palette;
  final ValueChanged<Color?> onColorSelected;

  const PaletteColorSelectorRow({
    super.key,
    required this.title,
    required this.selectedColor,
    required this.palette,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "None" (Transparent / Clear) Selector
                GestureDetector(
                  onTap: () => onColorSelected(null),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: selectedColor == null ? 2.0 : 1.0,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.block,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                // Palette Colors Selectors
                ...palette.map((color) {
                  final isSelected =
                      selectedColor?.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => onColorSelected(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
