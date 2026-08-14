import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../logic/canvas_state.dart';

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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: optComponents.take(4).map((
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
    return !listEquals(oldDelegate.components, components);
  }
}
