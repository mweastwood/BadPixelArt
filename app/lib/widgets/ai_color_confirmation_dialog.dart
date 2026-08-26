import 'package:flutter/material.dart';

import '../logic/canvas_state.dart';

class AiColorConfirmationDialog extends StatelessWidget {
  final AiColorSelectionResult result;
  final VoidCallback onRetry;
  final ValueChanged<List<PixelArtComponent>> onConfirm;

  const AiColorConfirmationDialog({
    super.key,
    required this.result,
    required this.onRetry,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onRetry();
          },
          child: const Text('Re-suggest'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm(result.updatedComponents);
          },
          child: const Text('Confirm Colors'),
        ),
      ],
    );
  }
}
