// ignore_for_file: deprecated_member_use
import 'dart:io' as io;
import 'package:flutter/material.dart';

class FileBrowserDialog extends StatefulWidget {
  final List<String> allowedExtensions;
  const FileBrowserDialog({
    super.key,
    this.allowedExtensions = const ['png', 'jpg', 'jpeg', 'bmp'],
  });

  @override
  State<FileBrowserDialog> createState() => _FileBrowserDialogState();
}

class _FileBrowserDialogState extends State<FileBrowserDialog> {
  late io.Directory _currentDirectory;
  List<io.FileSystemEntity> _entities = [];
  io.FileSystemEntity? _selectedFile;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final homePath =
        io.Platform.environment['HOME'] ??
        io.Platform.environment['USERPROFILE'];
    if (homePath != null && io.Directory(homePath).existsSync()) {
      _currentDirectory = io.Directory(homePath);
    } else {
      _currentDirectory = io.Directory.current;
    }
    _loadDirectoryContents();
  }

  String _getBasename(String path) {
    return path.split(io.Platform.pathSeparator).last;
  }

  String _getExtension(String path) {
    final parts = path.split('.');
    if (parts.length <= 1) return '';
    return parts.last.toLowerCase();
  }

  Future<void> _loadDirectoryContents() async {
    setState(() {
      _loading = true;
      _error = '';
      _selectedFile = null;
    });

    try {
      final list = await _currentDirectory.list().toList();

      list.sort((a, b) {
        final aIsDir = a is io.Directory;
        final bIsDir = b is io.Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return _getBasename(
          a.path,
        ).toLowerCase().compareTo(_getBasename(b.path).toLowerCase());
      });

      final filtered = list.where((entity) {
        final name = _getBasename(entity.path);
        if (name.startsWith('.')) return false;

        if (entity is io.Directory) {
          return true;
        }
        if (entity is io.File) {
          final ext = _getExtension(entity.path);
          return widget.allowedExtensions.contains(ext);
        }
        return false;
      }).toList();

      setState(() {
        _entities = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not read directory: $e';
        _entities = [];
        _loading = false;
      });
    }
  }

  void _navigateToParent() {
    final parent = _currentDirectory.parent;
    if (parent.path != _currentDirectory.path) {
      _currentDirectory = parent;
      _loadDirectoryContents();
    }
  }

  void _navigateToDirectory(io.Directory dir) {
    _currentDirectory = dir;
    _loadDirectoryContents();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRoot = _currentDirectory.path == _currentDirectory.parent.path;

    return AlertDialog(
      title: const Text('Browse Files'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Go to parent directory',
                  onPressed: isRoot ? null : _navigateToParent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _currentDirectory.path,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                  ? Center(
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : _entities.isEmpty
                  ? const Center(
                      child: Text('No supported files or folders found.'),
                    )
                  : ListView.builder(
                      itemCount: _entities.length,
                      itemBuilder: (context, index) {
                        final entity = _entities[index];
                        final isDir = entity is io.Directory;
                        final name = _getBasename(entity.path);
                        final isSelected = _selectedFile?.path == entity.path;

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isDir ? Icons.folder : Icons.image,
                            color: isDir
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                          ),
                          title: Text(name),
                          selected: isSelected,
                          selectedTileColor: theme.colorScheme.primaryContainer
                              .withOpacity(0.3),
                          onTap: () {
                            if (entity is io.Directory) {
                              _navigateToDirectory(entity);
                            } else {
                              setState(() {
                                _selectedFile = entity;
                              });
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedFile == null
              ? null
              : () {
                  Navigator.of(context).pop(_selectedFile!.path);
                },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
