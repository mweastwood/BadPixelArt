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

              // Dropdown Preset Selector
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Preset',
                        prefixIcon: const Icon(Icons.tune),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      initialValue: _getPresetValue(canvasModel.paletteName),
                      items: const [
                        DropdownMenuItem(
                          value: 'primary',
                          child: Text('Primary 8'),
                        ),
                        DropdownMenuItem(
                          value: 'grayscale',
                          child: Text('Grayscale 4'),
                        ),
                        DropdownMenuItem(
                          value: 'gameboy',
                          child: Text('Game Boy (4-color)'),
                        ),
                        DropdownMenuItem(
                          value: 'nes',
                          child: Text('NES (8-color)'),
                        ),
                        DropdownMenuItem(
                          value: 'pico8',
                          child: Text('PICO-8 (16-color)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.selectPalette(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // AI & Local Generation Buttons (Stacked vertically to accommodate long text)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AI Generate Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: canvasModel.isSuggestingPalette
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('AI Suggest'),
                    onPressed: hasRefImage && !canvasModel.isSuggestingPalette
                        ? () => notifier.suggestPaletteFromReference()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // K-Means Algorithmic Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.filter_hdr),
                    label: const Text('K-Means Quantization'),
                    onPressed: hasRefImage
                        ? () => notifier.extractPaletteAlgorithmic()
                        : null,
                  ),
                ],
              ),
              if (!hasRefImage) ...[
                const SizedBox(height: 8),
                Text(
                  'Upload a reference image to unlock AI & Local Quantization.',
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

              // AI suggested palette confirmation banner
              if (canvasModel.showPaletteSuggestion &&
                  canvasModel.suggestedPalette != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'AI Suggestion Available',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: canvasModel.suggestedPalette!.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final color =
                                  canvasModel.suggestedPalette![index];
                              return Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                    width: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: notifier.rejectSuggestedPalette,
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: notifier.acceptSuggestedPalette,
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String? _getPresetValue(String currentName) {
    const validPresets = ['primary', 'grayscale', 'gameboy', 'nes', 'pico8'];
    if (validPresets.contains(currentName)) {
      return currentName;
    }
    return null;
  }
}
