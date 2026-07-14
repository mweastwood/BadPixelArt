// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class ResolutionSelectorDialog extends StatelessWidget {
  final int currentGridSize;
  final ValueChanged<int> onSelected;

  const ResolutionSelectorDialog({
    super.key,
    required this.currentGridSize,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Select Grid Size'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose the canvas resolution for your pixel art. Changing the size will reset the canvas.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSizeCard(context, 8, '8 x 8'),
              _buildSizeCard(context, 16, '16 x 16'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildSizeCard(BuildContext context, int size, String label) {
    final theme = Theme.of(context);
    final isSelected = currentGridSize == size;

    return Card(
      key: ValueKey('size_card_$size'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceVariant.withOpacity(0.4),
      elevation: isSelected ? 2 : 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          onSelected(size);
          Navigator.of(context).pop();
        },
        child: Container(
          width: 110,
          height: 110,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_on,
                size: size == 8 ? 32 : 40,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
