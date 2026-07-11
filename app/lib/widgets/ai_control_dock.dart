// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
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
  bool _isCollapsed = false;

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
            // Header Row (Tappable to expand/collapse)
            InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4.0,
                  horizontal: 4.0,
                ),
                child: Row(
                  children: [
                    Text(
                      'AI Assistant Controls',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(canvasModel.aiStatus, notifier),
                    const SizedBox(width: 8),
                    Icon(
                      _isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (!_isCollapsed) ...[
              const SizedBox(height: 12),

              // Reference Image Selector
              Text(
                'Reference Image',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              if (canvasModel.referenceImage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reference Image Active',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Change reference image',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                onPressed: () async {
                                  await _pickAndUploadReferenceImage(
                                    context,
                                    notifier,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: 'Remove reference image',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                onPressed: () {
                                  notifier.setReferenceImage(null);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Original Preview
                          Column(
                            children: [
                              Text(
                                'Original',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    canvasModel.originalReferenceImage != null
                                    ? (canvasModel
                                                  .originalReferenceImage!
                                                  .length <
                                              10
                                          ? const Center(
                                              child: Icon(
                                                Icons.image_outlined,
                                                size: 32,
                                              ),
                                            )
                                          : Image.memory(
                                              canvasModel
                                                  .originalReferenceImage!,
                                              fit: BoxFit.contain,
                                            ))
                                    : const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          // Arrow
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5),
                          ),
                          // Model Input Preview (64x64)
                          Column(
                            children: [
                              Text(
                                'Model Input (64x64)',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: canvasModel.referenceImage!.length < 10
                                    ? const Center(
                                        child: Icon(
                                          Icons.image_aspect_ratio_outlined,
                                          size: 32,
                                        ),
                                      )
                                    : Image.memory(
                                        canvasModel.referenceImage!,
                                        fit: BoxFit.contain,
                                        filterQuality:
                                            FilterQuality.none, // Pixelated
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _pickAndUploadReferenceImage(context, notifier);
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Reference Image'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                  ),
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
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: IconButton(
                      tooltip: canvasModel.autoRun
                          ? 'Pause Auto-Run'
                          : 'Start Auto-Run',
                      icon: Icon(
                        canvasModel.autoRun ? Icons.pause : Icons.play_arrow,
                        color: canvasModel.autoRun
                            ? Colors.amber
                            : Colors.green,
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

  Future<void> _pickAndUploadReferenceImage(
    BuildContext context,
    CanvasNotifier notifier,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          await notifier.setUploadedReferenceImage(bytes);
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }
}
