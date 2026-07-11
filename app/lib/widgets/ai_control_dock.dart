// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/ai_service.dart';

class AiControlDock extends ConsumerStatefulWidget {
  const AiControlDock({super.key});

  @override
  ConsumerState<AiControlDock> createState() => _AiControlDockState();
}

class _AiControlDockState extends ConsumerState<AiControlDock> {
  final TextEditingController _promptController = TextEditingController();

  // Helper to generate simulated image bytes for presets
  Uint8List _generateMockImageBytes(String presetName) {
    // Generate a simple grid string representing a 64x64 shape to mimic real reference image bytes
    final buffer = StringBuffer();
    buffer.write(presetName);
    for (int i = 0; i < 100; i++) {
      buffer.write('$i,');
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  @override
  void initState() {
    super.initState();
    final currentPrompt = ref.read(canvasStateProvider).userPrompt;
    _promptController.text = currentPrompt;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasModel = ref.watch(canvasStateProvider);
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Model Status and Trigger download if needed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'AICore Gemini Nano',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                _buildStatusChip(canvasModel.aiStatus, notifier),
              ],
            ),
            const SizedBox(height: 16),

            // Reference Image Preset Selector
            Text(
              'Reference Image Presets',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPresetButton(
                  label: 'Sword',
                  icon: Icons.shield_outlined,
                  isSelected:
                      canvasModel.referenceImage != null &&
                      utf8
                          .decode(canvasModel.referenceImage!)
                          .startsWith('Sword'),
                  onTap: () {
                    notifier.setReferenceImage(
                      _generateMockImageBytes('Sword'),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildPresetButton(
                  label: 'Heart',
                  icon: Icons.favorite_border,
                  isSelected:
                      canvasModel.referenceImage != null &&
                      utf8
                          .decode(canvasModel.referenceImage!)
                          .startsWith('Heart'),
                  onTap: () {
                    notifier.setReferenceImage(
                      _generateMockImageBytes('Heart'),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildPresetButton(
                  label: 'Clear',
                  icon: Icons.clear,
                  isSelected: canvasModel.referenceImage == null,
                  onTap: () {
                    notifier.setReferenceImage(null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prompt Box
            TextField(
              controller: _promptController,
              onChanged: notifier.updatePrompt,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'User Instructions / Prompt',
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                hintText: 'e.g., Draw a red sword outlined in black...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // AI Controls (Suggest, Auto-Run, Speed)
            Row(
              children: [
                // Suggest Next Stroke Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: canvasModel.isGenerating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(
                      canvasModel.isGenerating
                          ? 'AI Drawing...'
                          : 'Suggest Stroke',
                    ),
                    onPressed:
                        canvasModel.isGenerating ||
                            canvasModel.aiStatus != AiCoreStatus.available
                        ? null
                        : notifier.triggerAiStroke,
                  ),
                ),
                const SizedBox(width: 12),

                // Auto Run Toggle
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: IconButton(
                    tooltip: canvasModel.autoRun
                        ? 'Pause Auto-Run'
                        : 'Start Auto-Run',
                    icon: Icon(
                      canvasModel.autoRun ? Icons.pause : Icons.play_arrow,
                      color: canvasModel.autoRun ? Colors.amber : Colors.green,
                      size: 28,
                    ),
                    onPressed: canvasModel.aiStatus == AiCoreStatus.available
                        ? notifier.toggleAutoRun
                        : null,
                  ),
                ),
              ],
            ),

            if (canvasModel.autoRun) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Speed:',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      value: canvasModel.autoRunSpeed,
                      label: '${canvasModel.autoRunSpeed}s',
                      onChanged: notifier.updateSpeed,
                    ),
                  ),
                  Text(
                    '${canvasModel.autoRunSpeed}s',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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

  Widget _buildStatusChip(AiCoreStatus status, CanvasNotifier notifier) {
    Color color;
    String label;
    VoidCallback? onTap;

    switch (status) {
      case AiCoreStatus.available:
        color = Colors.green;
        label = 'Ready';
        break;
      case AiCoreStatus.downloadable:
        color = Colors.blue;
        label = 'Download Model';
        onTap = notifier.triggerDownload;
        break;
      case AiCoreStatus.downloading:
        color = Colors.orange;
        label = 'Downloading...';
        break;
      case AiCoreStatus.unavailable:
        color = Colors.red;
        label = 'Unavailable';
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
