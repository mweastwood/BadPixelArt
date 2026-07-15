import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class ColorPaletteGenerator extends ConsumerStatefulWidget {
  final bool initialCollapsed;

  const ColorPaletteGenerator({super.key, this.initialCollapsed = false});

  @override
  ConsumerState<ColorPaletteGenerator> createState() =>
      _ColorPaletteGeneratorState();
}

class _ColorPaletteGeneratorState extends ConsumerState<ColorPaletteGenerator> {
  late bool _isCollapsed;
  int _kmeansColors = 8;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initialCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    final hasRefImage = canvasModel.referenceImage != null;

    final List<DropdownMenuItem<String>> dropdownItems = [
      const DropdownMenuItem(
        value: 'primary',
        child: Text('Preset: Primary 8'),
      ),
      const DropdownMenuItem(
        value: 'grayscale',
        child: Text('Preset: Grayscale 4'),
      ),
      const DropdownMenuItem(
        value: 'gameboy',
        child: Text('Preset: Game Boy (4-color)'),
      ),
      const DropdownMenuItem(
        value: 'nes',
        child: Text('Preset: NES (8-color)'),
      ),
      const DropdownMenuItem(
        value: 'pico8',
        child: Text('Preset: PICO-8 (16-color)'),
      ),
    ];

    if (hasRefImage) {
      dropdownItems.addAll([
        const DropdownMenuItem(value: 'suggested', child: Text('AI Suggested')),
        const DropdownMenuItem(
          value: 'algorithmic',
          child: Text('K-Means Quantized'),
        ),
      ]);
    }

    final isCustomMode =
        canvasModel.paletteName == 'suggested' ||
        canvasModel.paletteName == 'algorithmic';

    final showRefreshIcon = hasRefImage && isCustomMode;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title and Action Tools
            InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Color Palette',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Mini swatches inside title area when collapsed
                    if (_isCollapsed)
                      Expanded(
                        child: SizedBox(
                          height: 20,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: canvasModel.palette.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 4),
                            itemBuilder: (context, index) {
                              final color = canvasModel.palette[index];
                              return Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    if (!_isCollapsed) const Spacer(),
                    Icon(
                      _isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            if (!_isCollapsed) ...[
              const SizedBox(height: 12),

              // Dropdown Selector Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(canvasModel.paletteName),
                      decoration: InputDecoration(
                        labelText: 'Color Palette Mode',
                        prefixIcon: const Icon(Icons.tune),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      initialValue:
                          dropdownItems.any(
                            (item) => item.value == canvasModel.paletteName,
                          )
                          ? canvasModel.paletteName
                          : null,
                      items: dropdownItems,
                      onChanged: (val) {
                        if (val != null) {
                          if (val == 'suggested') {
                            if (canvasModel.suggestedPalette == null) {
                              notifier.suggestPaletteFromReference().then((_) {
                                notifier.acceptSuggestedPalette();
                              });
                            } else {
                              notifier.acceptSuggestedPalette();
                            }
                          } else if (val == 'algorithmic') {
                            notifier.extractPaletteAlgorithmic(_kmeansColors);
                          } else {
                            notifier.selectPalette(val);
                          }
                        }
                      },
                    ),
                  ),
                  if (canvasModel.isSuggestingPalette) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ] else if (showRefreshIcon) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: canvasModel.paletteName == 'suggested'
                          ? 'Re-suggest AI Palette'
                          : 'Re-extract K-Means Palette',
                      onPressed: () {
                        if (canvasModel.paletteName == 'suggested') {
                          notifier.suggestPaletteFromReference().then((_) {
                            notifier.acceptSuggestedPalette();
                          });
                        } else {
                          notifier.extractPaletteAlgorithmic(_kmeansColors);
                        }
                      },
                    ),
                  ],
                ],
              ),

              if (canvasModel.paletteName == 'algorithmic') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Colors:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...[4, 8, 16].map((count) {
                      final isSelected = _kmeansColors == count;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text('$count'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _kmeansColors = count;
                              });
                              notifier.extractPaletteAlgorithmic(count);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ],

              if (!hasRefImage) ...[
                const SizedBox(height: 8),
                Text(
                  'Upload a reference image to unlock AI & K-Means Quantization.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),

              // Color Swatches Grid Display
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: canvasModel.palette.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final color = canvasModel.palette[index];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
