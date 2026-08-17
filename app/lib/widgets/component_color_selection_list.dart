import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/agents/color_selection_agent.dart';
import '../logic/utils/logging_ai_service.dart';
import 'ai_color_confirmation_dialog.dart';
import 'gradient_angle_selector.dart';
import 'palette_color_selector_row.dart';

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
        return AiColorConfirmationDialog(
          result: result,
          onRetry: _triggerAiColorSuggestion,
          onConfirm: (updatedComponents) {
            final notifier = ref.read(canvasStateProvider.notifier);
            notifier.batchUpdateComponentColors(updatedComponents);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final decomposedComponents = ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents),
    );
    final activeComponentIndex = ref.watch(
      canvasStateProvider.select((s) => s.activeComponentIndex),
    );
    final palette = ref.watch(canvasStateProvider.select((s) => s.palette));
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    if (decomposedComponents.isEmpty) {
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
          itemCount: decomposedComponents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final comp = decomposedComponents[index];
            final isActive = index == activeComponentIndex;
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
                        PaletteColorSelectorRow(
                          title: 'Line Color',
                          selectedColor: comp.fillColor ?? comp.outlineColor,
                          palette: palette,
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
                                    comp.fillColor ?? palette.first,
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
                                      comp.fillColor ?? palette.first;
                                  final colorB = palette.length > 1
                                      ? palette[1]
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
                        PaletteColorSelectorRow(
                          title: isGradientEnabled
                              ? 'Fill Color A'
                              : 'Fill Color',
                          selectedColor: comp.fillColor,
                          palette: palette,
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
                          PaletteColorSelectorRow(
                            title: 'Fill Color B',
                            selectedColor: comp.fillColor2,
                            palette: palette,
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
                          GradientAngleSelector(
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
                        PaletteColorSelectorRow(
                          title: 'Outline Color',
                          selectedColor: comp.outlineColor,
                          palette: palette,
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
}
