import '../wizard_state.dart';
import 'wizard_step_definition.dart';

/// Defines an ordered pipeline of [WizardStepDefinition] instances.
class WizardDefinition {
  final String id;
  final String title;
  final String description;
  final List<WizardStepDefinition> steps;

  const WizardDefinition({
    required this.id,
    required this.title,
    this.description = '',
    required this.steps,
  });

  int get stepCount => steps.length;

  int indexOfStep(WizardStep step) {
    return steps.indexWhere((s) => s.step == step);
  }

  WizardStepDefinition? getStepDefinition(WizardStep step) {
    final index = indexOfStep(step);
    if (index >= 0) return steps[index];
    return null;
  }
}
