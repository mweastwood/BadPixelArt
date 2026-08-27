import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../canvas_state.dart';
import '../../wizard_state.dart';
import '../wizard_step_definition.dart';
import '../../../widgets/template_selection_card.dart';

/// Step 0 for Template Wizard: Template selection and grid customization
class SelectTemplateStepDefinition extends WizardStepDefinition {
  const SelectTemplateStepDefinition();

  @override
  WizardStep get step => WizardStep.selectTemplate;

  @override
  String get title => 'Select Template';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const TemplateSelectionCard();

  @override
  bool canGoBack(WidgetRef ref) => false;

  @override
  bool canAdvance(WidgetRef ref) => true;

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    final hasPixels = notifier.model.grid.any(
      (row) => row.any((cell) => cell > 0),
    );
    if (!hasPixels) {
      final defaultTemplate = SpriteTemplate.characterPreset;
      notifier.loadTemplateGrid(
        defaultTemplate.parseToGrid(),
        prompt: defaultTemplate.defaultPrompt,
        gridSize: defaultTemplate.width,
      );
    }
    return true;
  }

  @override
  bool isStepComplete(CanvasModel model) =>
      model.grid.any((row) => row.any((cell) => cell > 0));
}
