import 'steps/default_wizard_steps.dart';
import 'steps/template_wizard_steps.dart';
import 'wizard_definition.dart';

/// Registry holding all available wizard configurations.
class WizardRegistry {
  static const structuredPixelArtWizard = WizardDefinition(
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

  static const directPixelArtWizard = WizardDefinition(
    id: 'direct_pixel_art',
    title: 'Direct Painting Wizard',
    description:
        'Paints directly onto the canvas from the reference image, prompt description, and color palette.',
    steps: [
      SelectGridSizeStepDefinition(),
      SetupPromptStepDefinition(),
      SelectPaletteStepDefinition(),
      RefinementStepDefinition(),
    ],
  );

  static const templateSpriteWizard = WizardDefinition(
    id: 'template_pixel_art',
    title: 'Template Sprite Wizard',
    description:
        'Generates pixel art sprites starting from predefined or custom template grids.',
    steps: [
      SelectTemplateStepDefinition(),
      SetupPromptStepDefinition(),
      SelectPaletteStepDefinition(),
      SketchingPlanStepDefinition(),
      ComponentSculptingStepDefinition(),
      ColorAndOutlineStepDefinition(),
      LayerOrderingAndMergeStepDefinition(),
      RefinementStepDefinition(),
    ],
  );

  static const defaultPixelArtWizard = structuredPixelArtWizard;

  static final Map<String, WizardDefinition> _registeredWizards = {
    structuredPixelArtWizard.id: structuredPixelArtWizard,
    directPixelArtWizard.id: directPixelArtWizard,
    templateSpriteWizard.id: templateSpriteWizard,
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
