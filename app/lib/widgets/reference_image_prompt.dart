import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/repositories/reference_library_repository.dart';
import '../screens/reference_library_screen.dart';

class ReferenceImagePrompt extends ConsumerStatefulWidget {
  const ReferenceImagePrompt({super.key});

  @override
  ConsumerState<ReferenceImagePrompt> createState() =>
      _ReferenceImagePromptState();
}

class _ReferenceImagePromptState extends ConsumerState<ReferenceImagePrompt> {
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _promptController.text = ref.read(canvasStateProvider).userPrompt;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final referenceImage = ref.watch(
      canvasStateProvider.select((s) => s.referenceImage),
    );
    final originalReferenceImage = ref.watch(
      canvasStateProvider.select((s) => s.originalReferenceImage),
    );
    final isSuggestingDescription = ref.watch(
      canvasStateProvider.select((s) => s.isSuggestingDescription),
    );
    final notifier = ref.read(canvasStateProvider.notifier);
    final repository = ref.read(referenceLibraryRepositoryProvider);
    final theme = Theme.of(context);

    // Keep controller text in sync with provider state if updated externally
    ref.listen<String>(
      canvasStateProvider.select((state) => state.userPrompt),
      (_, next) {
        if (_promptController.text != next) {
          _promptController.text = next;
        }
      },
    );

    final hasRefImage = referenceImage != null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reference & Prompt',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Reference Image Upload Area
            Text(
              'Reference Image',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (hasRefImage)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Reference',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const ValueKey('library_button_active'),
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 18,
                              ),
                              tooltip: 'Choose from library',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _openReferenceLibrary(context),
                            ),
                            IconButton(
                              key: const ValueKey('save_to_library_button'),
                              icon: const Icon(
                                Icons.bookmark_add_outlined,
                                size: 18,
                              ),
                              tooltip: 'Save to library',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _saveCurrentToLibrary(
                                context,
                                repository,
                                originalReferenceImage ?? referenceImage,
                                referenceImage,
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('change_reference_button'),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Upload new image',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _pickAndUploadReferenceImage(
                                context,
                                notifier,
                                repository,
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('remove_reference_button'),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              tooltip: 'Remove reference image',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => notifier.setReferenceImage(null),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Original Image Preview
                        Column(
                          children: [
                            Text(
                              'Original',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  originalReferenceImage != null &&
                                      originalReferenceImage.length >= 10
                                  ? Image.memory(
                                      originalReferenceImage,
                                      fit: BoxFit.contain,
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 16,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          size: 16,
                        ),
                        // 512x512 Downscaled Preview
                        Column(
                          children: [
                            Text(
                              'Model Input (512x512)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.memory(
                                referenceImage,
                                fit: BoxFit.contain,
                                filterQuality:
                                    FilterQuality.none, // Keep pixelated style
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('upload_reference_button'),
                      onPressed: () => _pickAndUploadReferenceImage(
                        context,
                        notifier,
                        repository,
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Image'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('library_reference_button'),
                      onPressed: () => _openReferenceLibrary(context),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Library'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Prompt Box
            TextField(
              controller: _promptController,
              onChanged: notifier.updatePrompt,
              scrollPadding: const EdgeInsets.only(bottom: 140.0),
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'User Instructions / Prompt',
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
                hintText: 'e.g., Draw a red sword outlined in black...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
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
            if (hasRefImage) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('auto_suggest_description_button'),
                  onPressed: isSuggestingDescription
                      ? null
                      : () => notifier.suggestDescriptionFromReference(),
                  icon: isSuggestingDescription
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    isSuggestingDescription
                        ? 'Suggesting...'
                        : 'Auto-suggest Description',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openReferenceLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ReferenceLibraryScreen(isPickerMode: true),
      ),
    );
  }

  Future<void> _saveCurrentToLibrary(
    BuildContext context,
    ReferenceLibraryRepository repository,
    Uint8List originalBytes,
    Uint8List bmpBytes,
  ) async {
    try {
      final prompt = ref.read(canvasStateProvider).userPrompt;
      final saved = await repository.addReferenceImage(
        imageBytes: originalBytes,
        bmpBytes: bmpBytes,
        prompt: prompt.isNotEmpty ? prompt : null,
        source: 'upload',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${saved.title}" to Reference Library'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to library: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadReferenceImage(
    BuildContext context,
    CanvasNotifier notifier,
    ReferenceLibraryRepository repository,
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
          final fileName = file.name.split('.').first;
          await repository.addReferenceImage(
            imageBytes: bytes,
            title: fileName.isNotEmpty ? fileName : null,
            source: 'upload',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image set as reference & added to library'),
                duration: Duration(seconds: 2),
              ),
            );
          }
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
