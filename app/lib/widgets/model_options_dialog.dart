import 'package:flutter/material.dart';

class ModelOptionsDialog extends StatefulWidget {
  final String currentReleaseStage;
  final String currentPreference;
  final void Function(String releaseStage, String preference) onChanged;

  const ModelOptionsDialog({
    super.key,
    required this.currentReleaseStage,
    required this.currentPreference,
    required this.onChanged,
  });

  @override
  State<ModelOptionsDialog> createState() => _ModelOptionsDialogState();
}

class _ModelOptionsDialogState extends State<ModelOptionsDialog> {
  late String _selectedStage;
  late String _selectedPreference;

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.currentReleaseStage;
    _selectedPreference = widget.currentPreference;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Model Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Release Stage',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildOptionCard(
                key: const ValueKey('stage_stable'),
                label: 'Stable',
                isSelected: _selectedStage == 'stable',
                onTap: () => setState(() => _selectedStage = 'stable'),
              ),
              const SizedBox(width: 12),
              _buildOptionCard(
                key: const ValueKey('stage_preview'),
                label: 'Preview',
                isSelected: _selectedStage == 'preview',
                onTap: () => setState(() => _selectedStage = 'preview'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Performance Preference',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildOptionCard(
                key: const ValueKey('preference_full'),
                label: 'Full (Capable)',
                isSelected: _selectedPreference == 'full',
                onTap: () => setState(() => _selectedPreference = 'full'),
              ),
              const SizedBox(width: 12),
              _buildOptionCard(
                key: const ValueKey('preference_fast'),
                label: 'Fast (Low Latency)',
                isSelected: _selectedPreference == 'fast',
                onTap: () => setState(() => _selectedPreference = 'fast'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey('save_model_options'),
          onPressed: () {
            widget.onChanged(_selectedStage, _selectedPreference);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        key: key,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        elevation: isSelected ? 2 : 0,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
