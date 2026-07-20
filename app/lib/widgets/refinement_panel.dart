import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';

class RefinementPanel extends ConsumerStatefulWidget {
  const RefinementPanel({super.key});

  @override
  ConsumerState<RefinementPanel> createState() => _RefinementPanelState();
}

class _RefinementPanelState extends ConsumerState<RefinementPanel> {
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final canvasState = ref.read(canvasStateProvider);
    _promptController = TextEditingController(text: canvasState.userPrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            'Step 7: Refine Pixel Art',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'In this final step, all spatial constraints are removed. Describe any final touches, details, or shading you want the AI to apply globally across the canvas.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _promptController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText:
                'e.g. add metallic highlights, add shading at the bottom, refine edges...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            labelText: 'Refinement Prompt',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          icon: canvasState.isGenerating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            canvasState.isGenerating
                ? 'Refining Canvas...'
                : 'Apply Refinements',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: canvasState.isGenerating
              ? null
              : () async {
                  await notifier.refineCanvas(_promptController.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refinements applied to canvas!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
        ),
      ],
    );
  }
}
