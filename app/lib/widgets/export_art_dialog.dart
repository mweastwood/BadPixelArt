import 'package:flutter/material.dart';
import '../logic/utils/art_export_utils.dart';
import 'canvas/scaled_canvas_preview.dart';

/// Interactive dialog for configuring and exporting pixel art to PNG or SVG.
class ExportArtDialog extends StatefulWidget {
  final List<List<int>> grid;
  final List<Color> palette;
  final String? initialTitle;

  const ExportArtDialog({
    super.key,
    required this.grid,
    required this.palette,
    this.initialTitle,
  });

  @override
  State<ExportArtDialog> createState() => _ExportArtDialogState();
}

class _ExportArtDialogState extends State<ExportArtDialog> {
  late final TextEditingController _titleController;
  ExportFormat _format = ExportFormat.png;
  int _scale = 8;
  bool _transparentBackground = true;
  bool _isExporting = false;

  static const List<int> _availableScales = [1, 2, 4, 8, 16, 32];

  @override
  void initState() {
    super.initState();
    final defaultTitle =
        (widget.initialTitle != null &&
            widget.initialTitle!.trim().isNotEmpty &&
            widget.initialTitle != 'Untitled Creation')
        ? widget.initialTitle!
        : 'pixel_art_${DateTime.now().millisecondsSinceEpoch}';
    _titleController = TextEditingController(
      text: sanitizeFileName(defaultTitle),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final title = _titleController.text.trim().isEmpty
          ? 'pixel_art'
          : _titleController.text.trim();

      bool success = false;
      if (_format == ExportFormat.png) {
        success = await exportArtworkAsPng(
          context,
          grid: widget.grid,
          palette: widget.palette,
          title: title,
          scale: _scale,
          transparentBackground: _transparentBackground,
        );
      } else {
        success = await exportArtworkAsSvg(
          context,
          grid: widget.grid,
          palette: widget.palette,
          title: title,
          scale: _scale,
          transparentBackground: _transparentBackground,
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int gridSize = widget.grid.length;
    final int outputDimension = gridSize * _scale;

    return AlertDialog(
      key: const ValueKey('export_art_dialog'),
      title: Row(
        children: [
          Icon(Icons.file_download_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Export Pixel Art'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview & Resolution card
              Center(
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: _transparentBackground
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CustomPaint(
                    size: const Size(128, 128),
                    painter: MiniPixelPainter(
                      grid: widget.grid,
                      palette: widget.palette,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$gridSize×$gridSize px original ➔ $outputDimension×$outputDimension px (${_scale}x)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // File Name field
              TextField(
                key: const ValueKey('export_filename_input'),
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'File Name',
                  suffixText: _format == ExportFormat.png ? '.png' : '.svg',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Format selector
              Text(
                'Format',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<ExportFormat>(
                key: const ValueKey('export_format_segmented_button'),
                segments: const [
                  ButtonSegment(
                    value: ExportFormat.png,
                    label: Text('PNG (Raster)'),
                    icon: Icon(Icons.image_outlined),
                  ),
                  ButtonSegment(
                    value: ExportFormat.svg,
                    label: Text('SVG (Vector)'),
                    icon: Icon(Icons.polyline_outlined),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (selected) {
                  setState(() => _format = selected.first);
                },
              ),
              const SizedBox(height: 16),

              // Scale factor selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scale / Resolution',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$outputDimension×$outputDimension px',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _availableScales.map((scale) {
                  final isSelected = (_scale == scale);
                  return ChoiceChip(
                    key: ValueKey('scale_chip_${scale}x'),
                    label: Text('${scale}x'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _scale = scale);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Transparency switch
              SwitchListTile.adaptive(
                key: const ValueKey('export_transparency_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Transparent Background'),
                subtitle: Text(
                  _transparentBackground
                      ? 'Empty canvas cells remain transparent'
                      : 'Fills canvas background with solid dark color',
                  style: theme.textTheme.bodySmall,
                ),
                value: _transparentBackground,
                onChanged: (val) =>
                    setState(() => _transparentBackground = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('export_cancel_button'),
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('export_confirm_button'),
          onPressed: _isExporting ? null : _handleExport,
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download),
          label: Text(_isExporting ? 'Exporting...' : 'Export'),
        ),
      ],
    );
  }
}

/// Helper to display the [ExportArtDialog].
Future<bool?> showExportArtDialog(
  BuildContext context, {
  required List<List<int>> grid,
  required List<Color> palette,
  String? initialTitle,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => ExportArtDialog(
      grid: grid,
      palette: palette,
      initialTitle: initialTitle,
    ),
  );
}
