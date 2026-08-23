import 'steps/default_wizard_steps.dart';
import 'wizard_definition.dart';

/// Registry holding all available wizard configurations.
class WizardRegistry {
  static const defaultPixelArtWizard = WizardDefinition(
    id: 'default_pixel_art',
    title: 'Pixel Art Generator',
    description:
        'Generates pixel art via decomposition, sculpting, and refinement.',
    steps: [
      SelectGridSizeStepDefinition(),
      SetupPromptStepDefinition(),
      SelectPaletteStepDefinition(),
      SketchingPlanStepDefinition(),
      ComponentSculptingStepDefinition(),
      ColorAndOutlineStepDefinition(),
      LayerOrderingAndMergeStepDefinition(),
      RefinementStepDefinition(),
    ],
  );

  static final Map<String, WizardDefinition> _registeredWizards = {
    defaultPixelArtWizard.id: defaultPixelArtWizard,
  };

  /// Returns all registered wizard pipelines.
  static List<WizardDefinition> get allWizards =>
      _registeredWizards.values.toList();

  /// Default pixel art generation wizard pipeline.
  static WizardDefinition get defaultWizard => defaultPixelArtWizard;

  /// Look up a wizard definition by its unique [id].
  static WizardDefinition? getById(String id) => _registeredWizards[id];

  /// Register a new custom wizard pipeline.
  static void register(WizardDefinition wizard) {
    _registeredWizards[wizard.id] = wizard;
  }
}
