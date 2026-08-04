import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/agents/color_selection_agent.dart';
import '../logic/utils/logging_ai_service.dart';

class ComponentColorSelectionList extends ConsumerStatefulWidget {
  const ComponentColorSelectionList({super.key});

  @override
  ConsumerState<ComponentColorSelectionList> createState() =>
      _ComponentColorSelectionListState();
}

class _ComponentColorSelectionListState
    extends ConsumerState<ComponentColorSelectionList> {
  bool _isSuggesting = false;

  Future<void> _triggerAiColorSuggestion() async {
    setState(() => _isSuggesting = true);
    try {
      final canvasState = ref.read(canvasStateProvider);
      final aiService = ref.read(loggingAiServiceProvider);
      final agent = ColorSelectionAgent(aiService);

      final result = await agent.suggestColors(
        userPrompt: canvasState.userPrompt,
        components: canvasState.decomposedComponents,
        palette: canvasState.palette,
        imageBytes: canvasState.referenceImage,
      );

      if (!mounted) return;
      setState(() => _isSuggesting = false);

      if (result != null) {
        _showAiConfirmationDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate AI color suggestions.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSuggesting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error suggesting colors: $e')));
      }
    }
  }

  void _showAiConfirmationDialog(AiColorSelectionResult result) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('AI Color Suggestions'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  result.reasoning,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Suggested Component Colors:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...result.updatedComponents.map((comp) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            comp.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (comp.fillColor != null) ...[
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: comp.fillColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (comp.fillColor2 != null) ...[
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: comp.fillColor2,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${comp.gradientAngle.round()}°)',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (comp.outlineColor != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: comp.outlineColor,
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _triggerAiColorSuggestion();
              },
              child: const Text('Re-suggest'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                final notifier = ref.read(canvasStateProvider.notifier);
                for (int i = 0; i < result.updatedComponents.length; i++) {
                  final c = result.updatedComponents[i];
                  notifier.updateComponentColors(
                    i,
                    c.fillColor,
                    c.outlineColor,
                    fillColor2: c.fillColor2,
                    gradientAngle: c.gradientAngle,
                  );
                }
              },
              child: const Text('Confirm Colors'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    if (canvasState.decomposedComponents.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No components available. Please sketch and sculpt components first.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 8.0,
              ),
              child: Text(
                'Step 5: Pick Component Colors',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ElevatedButton.icon(
              key: const ValueKey('ai_suggest_colors_button'),
              onPressed: _isSuggesting ? null : _triggerAiColorSuggestion,
              icon: _isSuggesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                _isSuggesting ? 'Suggesting...' : 'AI Suggest Colors',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: canvasState.decomposedComponents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final comp = canvasState.decomposedComponents[index];
            final isActive = index == canvasState.activeComponentIndex;
            final hasInterior = comp.hasInterior;
            final isGradientEnabled = hasInterior && comp.fillColor2 != null;

            return GestureDetector(
              onTap: () => notifier.selectComponent(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.8,
                        )
                      : theme.colorScheme.surfaceContainer.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.8)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                    width: isActive ? 2.0 : 1.0,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Component Header
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: PixelArtComponent.getColor(index),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              comp.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!hasInterior)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Line Only (1 Color)',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (comp.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          comp.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Divider(height: 24, thickness: 0.5),

                      if (!hasInterior) ...[
                        // Single Color mode for non-interior components
                        _buildColorSelectorRow(
                          context: context,
                          title: 'Line Color',
                          selectedColor: comp.fillColor ?? comp.outlineColor,
                          palette: canvasState.palette,
                          onColorSelected: (color) {
                            notifier.updateComponentColors(
                              index,
                              color,
                              color,
                              fillColor2: null,
                            );
                          },
                        ),
                      ] else ...[
                        // Fill Type Selector (Solid vs 2-Color Gradient)
                        Row(
                          children: [
                            const Text(
                              'Fill Mode:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 12),
                            FilterChip(
                              label: const Text('Solid Color'),
                              selected: !isGradientEnabled,
                              onSelected: (selected) {
                                if (selected) {
                                  notifier.updateComponentColors(
                                    index,
                                    comp.fillColor ?? canvasState.palette.first,
                                    comp.outlineColor,
                                    fillColor2: null,
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              key: ValueKey('gradient_fill_chip_$index'),
                              label: const Text('Hatching Gradient'),
                              selected: isGradientEnabled,
                              onSelected: (selected) {
                                if (selected) {
                                  final colorA =
                                      comp.fillColor ??
                                      canvasState.palette.first;
                                  final colorB = canvasState.palette.length > 1
                                      ? canvasState.palette[1]
                                      : colorA;
                                  notifier.updateComponentColors(
                                    index,
                                    colorA,
                                    comp.outlineColor,
                                    fillColor2: colorB,
                                    gradientAngle: comp.gradientAngle,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Primary Fill Color (Color A)
                        _buildColorSelectorRow(
                          context: context,
                          title: isGradientEnabled
                              ? 'Fill Color A'
                              : 'Fill Color',
                          selectedColor: comp.fillColor,
                          palette: canvasState.palette,
                          onColorSelected: (color) {
                            notifier.updateComponentColors(
                              index,
                              color,
                              comp.outlineColor,
                              fillColor2: comp.fillColor2,
                              gradientAngle: comp.gradientAngle,
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Secondary Fill Color (Color B) & Angle Selector (If Gradient Enabled)
                        if (isGradientEnabled) ...[
                          _buildColorSelectorRow(
                            context: context,
                            title: 'Fill Color B',
                            selectedColor: comp.fillColor2,
                            palette: canvasState.palette,
                            onColorSelected: (color) {
                              notifier.updateComponentColors(
                                index,
                                comp.fillColor,
                                comp.outlineColor,
                                fillColor2: color,
                                gradientAngle: comp.gradientAngle,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Gradient Angle Selector
                          _buildAngleSelectorRow(
                            context: context,
                            angle: comp.gradientAngle,
                            onAngleChanged: (newAngle) {
                              notifier.updateComponentColors(
                                index,
                                comp.fillColor,
                                comp.outlineColor,
                                fillColor2: comp.fillColor2,
                                gradientAngle: newAngle,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Outline Color Row
                        _buildColorSelectorRow(
                          context: context,
                          title: 'Outline Color',
                          selectedColor: comp.outlineColor,
                          palette: canvasState.palette,
                          onColorSelected: (color) {
                            notifier.updateComponentColors(
                              index,
                              comp.fillColor,
                              color,
                              fillColor2: comp.fillColor2,
                              gradientAngle: comp.gradientAngle,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAngleSelectorRow({
    required BuildContext context,
    required double angle,
    required ValueChanged<double> onAngleChanged,
  }) {
    final theme = Theme.of(context);
    final presets = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                'Angle',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: presets.map((preset) {
                    final isSelected =
                        (angle.round() % 360) == (preset.round() % 360);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ChoiceChip(
                        label: Text('${preset.round()}°'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) onAngleChanged(preset);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 90),
            Expanded(
              child: Slider(
                value: angle,
                min: 0.0,
                max: 360.0,
                divisions: 24,
                label: '${angle.round()}°',
                onChanged: onAngleChanged,
              ),
            ),
            Text(
              '${angle.round()}°',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSelectorRow({
    required BuildContext context,
    required String title,
    required Color? selectedColor,
    required List<Color> palette,
    required ValueChanged<Color?> onColorSelected,
  }) {
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
