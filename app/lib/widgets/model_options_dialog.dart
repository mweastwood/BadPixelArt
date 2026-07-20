import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../logic/utils/settings_provider.dart';

class ModelOptionsDialog extends ConsumerStatefulWidget {
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
  ConsumerState<ModelOptionsDialog> createState() => _ModelOptionsDialogState();
}

class _ModelOptionsDialogState extends ConsumerState<ModelOptionsDialog> {
  late String _selectedStage;
  late String _selectedPreference;
  late AiEngine _selectedEngine;
  late TextEditingController _geminiKeyController;
  late TextEditingController _zhipuKeyController;
  late String _selectedGeminiModel;
  late String _selectedZhipuModel;
  late TextEditingController _customGeminiModelController;
  late TextEditingController _customZhipuModelController;
  late double _throttlePercentage;

  final List<String> _geminiModelsList =
      CloudModelDatabase.geminiModels.map((m) => m.modelName).toList()
        ..add('custom');
  final List<String> _zhipuModelsList =
      CloudModelDatabase.zhipuModels.map((m) => m.modelName).toList()
        ..add('custom');

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.currentReleaseStage;
    _selectedPreference = widget.currentPreference;

    final settings = ref.read(settingsProvider);
    _selectedEngine = settings.aiEngine;
    _geminiKeyController = TextEditingController(text: settings.geminiApiKey);
    _zhipuKeyController = TextEditingController(text: settings.zhipuApiKey);
    _throttlePercentage = settings.throttlePercentage;

    if (_geminiModelsList.contains(settings.geminiModel) &&
        settings.geminiModel != 'custom') {
      _selectedGeminiModel = settings.geminiModel;
      _customGeminiModelController = TextEditingController(text: '');
    } else {
      _selectedGeminiModel = 'custom';
      _customGeminiModelController = TextEditingController(
        text: settings.geminiModel,
      );
    }

    if (_zhipuModelsList.contains(settings.zhipuModel) &&
        settings.zhipuModel != 'custom') {
      _selectedZhipuModel = settings.zhipuModel;
      _customZhipuModelController = TextEditingController(text: '');
    } else {
      _selectedZhipuModel = 'custom';
      _customZhipuModelController = TextEditingController(
        text: settings.zhipuModel,
      );
    }
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _zhipuKeyController.dispose();
    _customGeminiModelController.dispose();
    _customZhipuModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Model Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Engine',
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
                  key: const ValueKey('engine_local'),
                  label: 'Local',
                  isSelected: _selectedEngine == AiEngine.local,
                  onTap: () => setState(() => _selectedEngine = AiEngine.local),
                ),
                const SizedBox(width: 8),
                _buildOptionCard(
                  key: const ValueKey('engine_gemini'),
                  label: 'Gemini Cloud',
                  isSelected: _selectedEngine == AiEngine.geminiCloud,
                  onTap: () =>
                      setState(() => _selectedEngine = AiEngine.geminiCloud),
                ),
                const SizedBox(width: 8),
                _buildOptionCard(
                  key: const ValueKey('engine_zhipu'),
                  label: 'Zhipu Cloud',
                  isSelected: _selectedEngine == AiEngine.zhipuCloud,
                  onTap: () =>
                      setState(() => _selectedEngine = AiEngine.zhipuCloud),
                ),
              ],
            ),
            if (_selectedEngine == AiEngine.geminiCloud) ...[
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('gemini_api_key_field'),
                controller: _geminiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('gemini_model_dropdown'),
                initialValue: _selectedGeminiModel,
                decoration: const InputDecoration(
                  labelText: 'Select Gemini Model',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _geminiModelsList.map((model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(model),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedGeminiModel = val;
                    });
                  }
                },
              ),
              if (_selectedGeminiModel == 'custom') ...[
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('gemini_custom_model_field'),
                  controller: _customGeminiModelController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Model ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildUsageLimitLabel(
                _selectedGeminiModel,
                _customGeminiModelController.text,
              ),
            ] else if (_selectedEngine == AiEngine.zhipuCloud) ...[
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('zhipu_api_key_field'),
                controller: _zhipuKeyController,
                decoration: const InputDecoration(
                  labelText: 'Zhipu API Key',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('zhipu_model_dropdown'),
                initialValue: _selectedZhipuModel,
                decoration: const InputDecoration(
                  labelText: 'Select Zhipu Model',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _zhipuModelsList.map((model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(model),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedZhipuModel = val;
                    });
                  }
                },
              ),
              if (_selectedZhipuModel == 'custom') ...[
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('zhipu_custom_model_field'),
                  controller: _customZhipuModelController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Model ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildUsageLimitLabel(
                _selectedZhipuModel,
                _customZhipuModelController.text,
              ),
            ],
            if (_selectedEngine != AiEngine.local) ...[
              const SizedBox(height: 20),
              Text(
                'Rate Limit Throttle: ${_throttlePercentage.round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Slider(
                key: const ValueKey('throttle_slider'),
                value: _throttlePercentage,
                min: 10.0,
                max: 100.0,
                divisions: 9,
                label: '${_throttlePercentage.round()}%',
                onChanged: (val) {
                  setState(() {
                    _throttlePercentage = val;
                  });
                },
              ),
              Text(
                'Delays requests to stay within free tier quotas and avoid rate limit errors.',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ],
            if (_selectedEngine == AiEngine.local) ...[
              const SizedBox(height: 20),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey('save_model_options'),
          onPressed: () async {
            final settingsNotifier = ref.read(settingsProvider.notifier);
            await settingsNotifier.setAiEngine(_selectedEngine);
            await settingsNotifier.setGeminiApiKey(_geminiKeyController.text);
            await settingsNotifier.setZhipuApiKey(_zhipuKeyController.text);
            await settingsNotifier.setThrottlePercentage(_throttlePercentage);

            final finalGeminiModel = _selectedGeminiModel == 'custom'
                ? _customGeminiModelController.text
                : _selectedGeminiModel;
            final finalZhipuModel = _selectedZhipuModel == 'custom'
                ? _customZhipuModelController.text
                : _selectedZhipuModel;

            await settingsNotifier.setGeminiModel(finalGeminiModel);
            await settingsNotifier.setZhipuModel(finalZhipuModel);

            widget.onChanged(_selectedStage, _selectedPreference);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildUsageLimitLabel(
    String selectedDropdownValue,
    String customTextValue,
  ) {
    final theme = Theme.of(context);
    final String resolvedModel = selectedDropdownValue == 'custom'
        ? customTextValue
        : selectedDropdownValue;
    final info = CloudModelDatabase.getModelInfo(resolvedModel);
    final String limit =
        info?.description ??
        'Rate limits: Vary by model provider / account tier';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        limit,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          fontStyle: FontStyle.italic,
        ),
      ),
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
