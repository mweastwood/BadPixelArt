import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/wizard_state.dart';

/// Card widget for selecting and customizing sprite templates in the Template Wizard.
class TemplateSelectionCard extends ConsumerStatefulWidget {
  const TemplateSelectionCard({super.key});

  @override
  ConsumerState<TemplateSelectionCard> createState() =>
      _TemplateSelectionCardState();
}

class _TemplateSelectionCardState extends ConsumerState<TemplateSelectionCard> {
  late TextEditingController _textController;
  String _selectedPresetId = SpriteTemplate.characterPreset.id;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: SpriteTemplate.characterPreset.rawTemplate.trim(),
    );

    // Initial grid load if canvas is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyCurrentTemplate(autoPrompt: true);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onSelectPreset(String presetId) {
    setState(() {
      _selectedPresetId = presetId;
      _errorMessage = null;
      if (presetId != 'custom') {
        final preset = SpriteTemplate.getById(presetId);
        if (preset != null) {
          _textController.text = preset.rawTemplate.trim();
        }
      }
    });
    _applyCurrentTemplate(autoPrompt: true, overridePrompt: true);
  }

  void _applyCurrentTemplate({
    bool autoPrompt = false,
    bool overridePrompt = false,
  }) {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Template cannot be empty.';
      });
      return;
    }

    try {
      final lines = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final height = lines.length;
      final width = lines.isNotEmpty ? lines[0].length : 16;

      final preset = SpriteTemplate.getById(_selectedPresetId);
      final template = SpriteTemplate(
        id: _selectedPresetId,
        name: preset?.name ?? 'Custom Template',
        description: preset?.description ?? 'Custom pixel art template',
        width: width,
        height: height,
        rawTemplate: text,
        defaultPrompt: preset?.defaultPrompt ?? '',
      );

      final grid = template.parseToGrid();
      final notifier = ref.read(canvasStateProvider.notifier);
      notifier.loadTemplateGrid(
        grid,
        prompt: autoPrompt ? template.defaultPrompt : null,
        overridePrompt: overridePrompt,
        gridSize: width,
      );

      setState(() {
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error parsing template: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wizardMode = ref.watch(wizardStateProvider.select((s) => s.mode));
    final palette = ref.watch(canvasStateProvider.select((s) => s.palette));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Selector Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Generation Mode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose between structured step-by-step layer decomposition, direct freeform painting, or starting from a sprite template.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<WizardMode>(
              key: const ValueKey('wizard_mode_selector'),
              segments: const [
                ButtonSegment<WizardMode>(
                  value: WizardMode.structured,
                  label: Text('Structured'),
                  icon: Icon(Icons.account_tree_outlined),
                ),
                ButtonSegment<WizardMode>(
                  value: WizardMode.direct,
                  label: Text('Direct Paint'),
                  icon: Icon(Icons.brush_outlined),
                ),
                ButtonSegment<WizardMode>(
                  value: WizardMode.template,
                  label: Text('Template'),
                  icon: Icon(Icons.pattern_outlined),
                ),
              ],
              selected: {wizardMode},
              onSelectionChanged: (newSelection) {
                ref
                    .read(wizardStateProvider.notifier)
                    .setMode(newSelection.first);
              },
            ),
            const Divider(height: 32),

            // Template Header
            Row(
              children: [
                Icon(Icons.pattern, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Select Sprite Template',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a preset sprite silhouette or enter custom numeric indices (1-9) matching the color palette.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Preset selector chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...SpriteTemplate.presets.map((preset) {
                  final isSelected = _selectedPresetId == preset.id;
                  return ChoiceChip(
                    key: ValueKey('template_chip_${preset.id}'),
                    label: Text(preset.name),
                    selected: isSelected,
                    onSelected: (_) => _onSelectPreset(preset.id),
                  );
                }),
                ChoiceChip(
                  key: const ValueKey('template_chip_custom'),
                  label: const Text('Custom'),
                  selected: _selectedPresetId == 'custom',
                  onSelected: (_) => _onSelectPreset('custom'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Palette Index Reference Legend
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Color Palette Index Guide:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildIndexLegendItem(
                        context,
                        indexStr: '0 / .',
                        label: 'Empty',
                        color: Colors.transparent,
                        isBorder: true,
                      ),
                      for (int i = 0; i < palette.length && i < 4; i++)
                        _buildIndexLegendItem(
                          context,
                          indexStr: '${i + 1}',
                          label: i == 0
                              ? 'Outline'
                              : i == 1
                              ? 'Body'
                              : i == 2
                              ? 'Accent'
                              : 'Color ${i + 1}',
                          color: palette[i],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Template Editor / Text Box
            Text(
              'Template Grid Layout:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('template_text_field'),
              controller: _textController,
              maxLines: 17,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 2,
                height: 1.2,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
                hintText: 'Enter template grid...',
                errorText: _errorMessage,
              ),
              onChanged: (_) {
                if (_selectedPresetId != 'custom') {
                  setState(() {
                    _selectedPresetId = 'custom';
                  });
                }
                _applyCurrentTemplate();
              },
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const ValueKey('apply_template_button'),
                icon: const Icon(Icons.refresh),
                label: const Text('Reload Template to Canvas'),
                onPressed: () => _applyCurrentTemplate(autoPrompt: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexLegendItem(
    BuildContext context, {
    required String indexStr,
    required String label,
    required Color color,
    bool isBorder = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isBorder ? theme.colorScheme.outline : Colors.black26,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$indexStr = $label',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
