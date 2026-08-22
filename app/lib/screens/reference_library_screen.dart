import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/canvas_state.dart';
import '../logic/repositories/reference_library_repository.dart';
import '../logic/utils/database.dart';

class ReferenceLibraryScreen extends ConsumerStatefulWidget {
  final bool isPickerMode;
  final void Function(ReferenceImage selectedImage)? onImageSelected;

  const ReferenceLibraryScreen({
    super.key,
    this.isPickerMode = false,
    this.onImageSelected,
  });

  @override
  ConsumerState<ReferenceLibraryScreen> createState() =>
      _ReferenceLibraryScreenState();
}

class _ReferenceLibraryScreenState
    extends ConsumerState<ReferenceLibraryScreen> {
  String _searchQuery = '';
  String _sourceFilter = 'all'; // 'all', 'gemini', 'upload'
  late Future<List<ReferenceImage>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _imagesFuture = ref
          .read(referenceLibraryRepositoryProvider)
          .getAllReferenceImages();
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(referenceLibraryRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPickerMode
              ? 'Select Reference Image'
              : 'Reference Image Library',
        ),
        actions: [
          IconButton(
            key: const ValueKey('add_reference_image_button'),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Import Image',
            onPressed: () => _importImageFromFile(context, repository),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('reference_library_search_field'),
                    decoration: InputDecoration(
                      hintText: 'Search references...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Source Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Row(
              children: [
                ChoiceChip(
                  key: const ValueKey('filter_chip_all'),
                  label: const Text('All'),
                  selected: _sourceFilter == 'all',
                  onSelected: (selected) {
                    if (selected) setState(() => _sourceFilter = 'all');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const ValueKey('filter_chip_gemini'),
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Gemini'),
                  selected: _sourceFilter == 'gemini',
                  onSelected: (selected) {
                    if (selected) setState(() => _sourceFilter = 'gemini');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const ValueKey('filter_chip_upload'),
                  avatar: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Uploaded'),
                  selected: _sourceFilter == 'upload',
                  onSelected: (selected) {
                    if (selected) setState(() => _sourceFilter = 'upload');
                  },
                ),
              ],
            ),
          ),

          // Library Grid
          Expanded(
            child: FutureBuilder<List<ReferenceImage>>(
              future: _imagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snapshot.data ?? [];
                final filtered = list.where((item) {
                  if (_sourceFilter != 'all' &&
                      item.source.toLowerCase() != _sourceFilter) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final titleMatch = item.title.toLowerCase().contains(
                      _searchQuery,
                    );
                    final promptMatch =
                        item.prompt?.toLowerCase().contains(_searchQuery) ??
                        false;
                    return titleMatch || promptMatch;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          list.isEmpty
                              ? 'No reference images in your library yet'
                              : 'No matching reference images found',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const ValueKey('empty_state_import_button'),
                          onPressed: () =>
                              _importImageFromFile(context, repository),
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Import Reference Image'),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 800
                        ? 4
                        : (constraints.maxWidth > 500 ? 3 : 2);

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildReferenceCard(
                          context,
                          item,
                          repository,
                          theme,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceCard(
    BuildContext context,
    ReferenceImage item,
    ReferenceLibraryRepository repository,
    ThemeData theme,
  ) {
    final isGemini = item.source.toLowerCase() == 'gemini';

    return Card(
      key: ValueKey('reference_card_${item.id}'),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (widget.isPickerMode) {
            _selectImage(context, item);
          } else {
            _showDetailsDialog(context, item, repository);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview Container
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Image.memory(
                      item.imageData,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                  // Source Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isGemini
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.secondaryContainer)
                                .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGemini ? Icons.auto_awesome : Icons.image,
                            size: 12,
                            color: isGemini
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isGemini ? 'Gemini' : 'Upload',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isGemini
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Context Menu
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<String>(
                        key: ValueKey('reference_menu_${item.id}'),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        onSelected: (action) {
                          if (action == 'use') {
                            _selectImage(context, item);
                          } else if (action == 'details') {
                            _showDetailsDialog(context, item, repository);
                          } else if (action == 'edit') {
                            _showEditDialog(context, item, repository);
                          } else if (action == 'delete') {
                            _showDeleteDialog(context, item, repository);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'use',
                            child: ListTile(
                              leading: Icon(Icons.check_circle_outline),
                              title: Text('Use as Reference'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'details',
                            child: ListTile(
                              leading: Icon(Icons.visibility_outlined),
                              title: Text('View Details'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit Title & Prompt'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              title: Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info Bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(item.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectImage(BuildContext context, ReferenceImage item) {
    final notifier = ref.read(canvasStateProvider.notifier);
    if (item.bmpData != null) {
      notifier.setReferenceImage(item.bmpData, originalBytes: item.imageData);
    } else {
      notifier.setUploadedReferenceImage(item.imageData);
    }

    if (item.prompt != null && item.prompt!.isNotEmpty) {
      final currentPrompt = ref.read(canvasStateProvider).userPrompt;
      if (currentPrompt.isEmpty) {
        notifier.updatePrompt(item.prompt!);
      }
    }

    if (widget.onImageSelected != null) {
      widget.onImageSelected!(item);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${item.title}" as active reference'),
        duration: const Duration(seconds: 2),
      ),
    );

    if (widget.isPickerMode) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _importImageFromFile(
    BuildContext context,
    ReferenceLibraryRepository repository,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        int importedCount = 0;
        for (final file in result.files) {
          final bytes = file.bytes;
          if (bytes != null) {
            final fileName = file.name.split('.').first;
            await repository.addReferenceImage(
              imageBytes: bytes,
              title: fileName.isNotEmpty ? fileName : null,
              source: 'upload',
            );
            importedCount++;
          }
        }
        if (context.mounted) {
          _refreshList();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported $importedCount image${importedCount == 1 ? '' : 's'} into library',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import images: $e')));
      }
    }
  }

  void _showDetailsDialog(
    BuildContext context,
    ReferenceImage item,
    ReferenceLibraryRepository repository,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(item.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    color: Colors.black12,
                    child: Image.memory(item.imageData, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 12),
                if (item.prompt != null && item.prompt!.isNotEmpty) ...[
                  Text(
                    'Prompt / Description:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.prompt!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Source: ${item.source.toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatDate(item.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              key: const ValueKey('details_use_button'),
              icon: const Icon(Icons.check),
              label: const Text('Use in Canvas'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _selectImage(context, item);
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    ReferenceImage item,
    ReferenceLibraryRepository repository,
  ) {
    final titleController = TextEditingController(text: item.title);
    final promptController = TextEditingController(text: item.prompt ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Reference Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: promptController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Prompt / Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await repository.updateReferenceImageDetails(
                id: item.id,
                title: titleController.text,
                prompt: promptController.text,
              );
              _refreshList();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    ReferenceImage item,
    ReferenceLibraryRepository repository,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Reference Image'),
        content: Text(
          'Are you sure you want to delete "${item.title}" from your library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await repository.deleteReferenceImage(item.id);
              _refreshList();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
