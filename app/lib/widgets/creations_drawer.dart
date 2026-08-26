import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/canvas_state.dart';
import '../logic/repositories/canvas_repository.dart';
import '../logic/utils/database.dart';
import '../logic/utils/database_helpers.dart';
import '../logic/wizard_state.dart';
import 'export_art_dialog.dart';

class CreationsDrawer extends ConsumerStatefulWidget {
  final VoidCallback? onCreationSelected;

  const CreationsDrawer({super.key, this.onCreationSelected});

  @override
  ConsumerState<CreationsDrawer> createState() => _CreationsDrawerState();
}

class _CreationsDrawerState extends ConsumerState<CreationsDrawer> {
  String _searchQuery = '';
  late Future<List<Creation>> _creationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _creationsFuture = ref.read(canvasRepositoryProvider).getAllCreations();
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentCreationId = ref.watch(
      canvasStateProvider.select((s) => s.creationId),
    );
    final notifier = ref.read(canvasStateProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search creations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          // Creations List
          Expanded(
            child: FutureBuilder<List<Creation>>(
              future: _creationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final list = snapshot.data ?? [];
                final filteredList = list.where((item) {
                  return item.title.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.brush_outlined,
                          size: 48,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No creations yet'
                              : 'No matching creations',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final creation = filteredList[index];
                    final isCurrent = creation.id == currentCreationId;

                    return ListTile(
                      key: ValueKey('creation_item_${creation.id}'),
                      selected: isCurrent,
                      selectedTileColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      leading: CreationThumbnail(
                        gridData: creation.gridData,
                        paletteColors: creation.paletteColors,
                        gridSize: creation.gridSize,
                      ),
                      title: Text(
                        creation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${creation.gridSize}x${creation.gridSize} • ${_formatDate(creation.updatedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        await notifier.loadFromDb(creation.id);
                        if (widget.onCreationSelected != null) {
                          widget.onCreationSelected!();
                        } else if (context.mounted && navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) async {
                          if (action == 'export') {
                            showExportArtDialog(
                              context,
                              grid: deserializeGrid(creation.gridData),
                              palette: deserializePalette(
                                creation.paletteColors,
                              ),
                              initialTitle: creation.title,
                            );
                          } else if (action == 'rename') {
                            _showRenameDialog(context, creation, notifier);
                          } else if (action == 'duplicate') {
                            await notifier.duplicateCanvas(creation.id);
                            _refreshList();
                          } else if (action == 'delete') {
                            _showDeleteConfirmDialog(
                              context,
                              creation,
                              notifier,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                              leading: Icon(Icons.file_download_outlined),
                              title: Text('Export...'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Rename'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: ListTile(
                              leading: Icon(Icons.copy),
                              title: Text('Duplicate'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red),
                              title: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
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

  void _showRenameDialog(
    BuildContext context,
    Creation creation,
    CanvasNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => _RenameDialog(
        initialTitle: creation.title,
        onConfirm: (newTitle) async {
          await notifier.renameCanvasById(creation.id, newTitle);
          _refreshList();
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    Creation creation,
    CanvasNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Creation'),
        content: Text(
          'Are you sure you want to delete "${creation.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await notifier.deleteCanvas(creation.id);
              if (ref.read(canvasStateProvider).creationId == null) {
                ref.read(wizardStateProvider.notifier).reset();
              }
              _refreshList();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class CreationThumbnail extends StatefulWidget {
  final String gridData;
  final String paletteColors;
  final int gridSize;

  const CreationThumbnail({
    super.key,
    required this.gridData,
    required this.paletteColors,
    required this.gridSize,
  });

  @override
  State<CreationThumbnail> createState() => _CreationThumbnailState();
}

class _CreationThumbnailState extends State<CreationThumbnail> {
  late List<List<int>> _grid;
  late List<Color> _palette;

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    _grid = deserializeGrid(widget.gridData);
    _palette = deserializePalette(widget.paletteColors);
  }

  @override
  void didUpdateWidget(covariant CreationThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gridData != widget.gridData ||
        oldWidget.paletteColors != widget.paletteColors) {
      _parseData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey[300]!, width: 0.5),
        ),
        child: CustomPaint(
          painter: _GridPainter(grid: _grid, palette: _palette),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final List<List<int>> grid;
  final List<Color> palette;

  _GridPainter({required this.grid, required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length;
    if (rows == 0) return;
    final cols = grid[0].length;
    if (cols == 0) return;

    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final colorIdx = grid[y][x];
        if (colorIdx > 0 && colorIdx <= palette.length) {
          paint.color = palette[colorIdx - 1];
          canvas.drawRect(
            Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.1, cellH + 0.1),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.grid != grid || oldDelegate.palette != palette;
}

class _RenameDialog extends StatefulWidget {
  final String initialTitle;
  final Future<void> Function(String newTitle) onConfirm;

  const _RenameDialog({required this.initialTitle, required this.onConfirm});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Creation'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Enter new title'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey('rename_dialog_confirm_button'),
          onPressed: () async {
            final newTitle = _controller.text.trim();
            if (newTitle.isNotEmpty) {
              await widget.onConfirm(newTitle);
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
