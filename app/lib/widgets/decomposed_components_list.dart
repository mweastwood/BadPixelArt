import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/agents/base_agent.dart';
import 'package:local_agent/local_agent.dart';

class DecomposedComponentsList extends ConsumerStatefulWidget {
  final bool initialCollapsed;

  const DecomposedComponentsList({super.key, this.initialCollapsed = false});

  @override
  ConsumerState<DecomposedComponentsList> createState() =>
      _DecomposedComponentsListState();
}

class _DecomposedComponentsListState
    extends ConsumerState<DecomposedComponentsList> {
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
    final components = canvasModel.decomposedComponents;
    final activeIndex = canvasModel.activeComponentIndex;

    final hasPromptAndRef =
        canvasModel.referenceImage != null &&
        canvasModel.userPrompt.trim().isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row (Tappable to expand/collapse)
            InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_add_check_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drawing Plan Components',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (components.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Re-generate Drawing Plan',
                        onPressed:
                            !hasPromptAndRef ||
                                canvasModel.isGenerating ||
                                canvasModel.aiStatus != AiCoreStatus.available
                            ? null
                            : notifier.triggerDecomposition,
                      ),
                    const SizedBox(width: 12),
                    if (_isCollapsed && components.isNotEmpty)
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
                          '${components.length} parts',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    const Spacer(),
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
              if (components.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    children: [
                      Text(
                        'No components decomposed yet. Set a prompt and upload a reference image to generate your co-creation drawing plan.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: canvasModel.isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.psychology),
                        label: Text(
                          canvasModel.isGenerating
                              ? 'Generating Plan...'
                              : 'Generate Drawing Plan',
                        ),
                        onPressed:
                            !hasPromptAndRef ||
                                canvasModel.isGenerating ||
                                canvasModel.aiStatus != AiCoreStatus.available
                            ? null
                            : notifier.triggerDecomposition,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: components.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final comp = components[index];
                    final isActive = index == activeIndex;

                    return InkWell(
                      onTap: () => notifier.selectComponent(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                )
                              : theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: isActive ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // BBox icon indicator
                            Icon(
                              Icons.crop_free_outlined,
                              size: 18,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comp.name.toUpperCase(),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comp.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Bounding Box summary
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'BBox',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '[${(comp.relativeBoundingBox.left * 100).round()}%, ${(comp.relativeBoundingBox.top * 100).round()}%]',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: canvasModel.isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.draw_outlined),
                      label: Text(
                        canvasModel.isGenerating
                            ? 'Sketching...'
                            : 'Sketch Components',
                      ),
                      onPressed: canvasModel.isGenerating
                          ? null
                          : () => notifier.sketchComponents(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.merge_type),
                      label: const Text('Merge Outlines'),
                      onPressed:
                          canvasModel.isGenerating ||
                              components.every((c) => c.grid == null)
                          ? null
                          : () => notifier.mergeComponentsToCanvas(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DecompositionOptionsDialog extends StatelessWidget {
  final List<List<PixelArtComponent>> options;
  final ValueChanged<int> onSelected;
  final VoidCallback onCancel;

  const DecompositionOptionsDialog({
    super.key,
    required this.options,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: 700,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Drawing Plan',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'We generated 4 alternative drawing plans. Select the one that matches your vision:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 550;
                    return GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 2 : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 140,
                      ),
                      itemCount: options.length,
                      itemBuilder: (context, optIdx) {
                        final optComponents = options[optIdx];
                        return InkWell(
                          onTap: () => onSelected(optIdx),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              color: theme.colorScheme.surfaceContainerHigh,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Visual preview
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CustomPaint(
                                      painter: MiniBoundingBoxPainter(
                                        optComponents,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'OPTION ${optIdx + 1}',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: ListView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          children: optComponents.map((
                                            PixelArtComponent comp,
                                          ) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2.0,
                                              ),
                                              child: Text(
                                                '• ${comp.name}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniBoundingBoxPainter extends CustomPainter {
  final List<PixelArtComponent> components;

  MiniBoundingBoxPainter(this.components);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw 8x8 checkerboard cells
    final cellW = size.width / 8;
    final cellH = size.height / 8;
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.08);

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        if ((x + y) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH),
            gridPaint,
          );
        }
      }
    }

    // Draw component bounding boxes as tealAccent outlines
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.tealAccent
      ..strokeWidth = 1.5;

    for (final comp in components) {
      final rect = Rect.fromLTWH(
        comp.relativeBoundingBox.left * size.width,
        comp.relativeBoundingBox.top * size.height,
        comp.relativeBoundingBox.width * size.width,
        comp.relativeBoundingBox.height * size.height,
      );
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MiniBoundingBoxPainter oldDelegate) {
    return oldDelegate.components != components;
  }
}
