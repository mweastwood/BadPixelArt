import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../canvas_state.dart';
import '../../wizard_state.dart';
import '../wizard_step_definition.dart';
import '../../../widgets/grid_size_selection_card.dart';
import '../../../widgets/reference_image_prompt.dart';
import '../../../widgets/color_palette_generator.dart';
import '../../../widgets/semantic_components_list.dart';
import '../../../widgets/shape_decomposition_list.dart';
import '../../../widgets/component_color_selection_list.dart';
import '../../../widgets/layer_ordering_list.dart';
import '../../../widgets/refinement_panel.dart';

/// Step 0: Grid size selection
class SelectGridSizeStepDefinition extends WizardStepDefinition {
  const SelectGridSizeStepDefinition();

  @override
  WizardStep get step => WizardStep.selectGridSize;

  @override
  String get title => 'Select Grid Size';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const GridSizeSelectionCard();

  @override
  bool canGoBack(WidgetRef ref) => false;

  @override
  bool canAdvance(WidgetRef ref) => true;

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async => true;

  @override
  bool isStepComplete(CanvasModel model) => true;
}

/// Step 1: Prompt and reference image setup
class SetupPromptStepDefinition extends WizardStepDefinition {
  const SetupPromptStepDefinition();

  @override
  WizardStep get step => WizardStep.setupPrompt;

  @override
  String get title => 'Setup Prompt';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const ReferenceImagePrompt();

  @override
  bool canAdvance(WidgetRef ref) {
    return ref.watch(
      canvasStateProvider.select((s) => s.userPrompt.trim().isNotEmpty),
    );
  }

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    if (notifier.model.userPrompt.trim().isEmpty &&
        notifier.model.referenceImage != null) {
      await notifier.suggestDescriptionFromReference();
    }
    return notifier.model.userPrompt.trim().isNotEmpty;
  }

  @override
  bool isStepComplete(CanvasModel model) => model.userPrompt.trim().isNotEmpty;
}

/// Step 2: Palette selection and generation
class SelectPaletteStepDefinition extends WizardStepDefinition {
  const SelectPaletteStepDefinition();

  @override
  WizardStep get step => WizardStep.selectPalette;

  @override
  String get title => 'Select Palette';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const ColorPaletteGenerator();

  @override
  bool canAdvance(WidgetRef ref) => true;

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    if (notifier.model.suggestedPalette == null &&
        notifier.model.referenceImage != null) {
      await notifier.suggestPaletteFromReference();
      if (notifier.model.suggestedPalette != null) {
        notifier.acceptSuggestedPalette();
      } else {
        return false;
      }
    } else if (notifier.model.suggestedPalette != null &&
        notifier.model.showPaletteSuggestion) {
      notifier.acceptSuggestedPalette();
    }
    return true;
  }

  @override
  bool isStepComplete(CanvasModel model) => model.palette.isNotEmpty;
}

/// Step 3: Semantic decomposition and sketching plan
class SketchingPlanStepDefinition extends WizardStepDefinition {
  const SketchingPlanStepDefinition();

  @override
  WizardStep get step => WizardStep.sketchingPlan;

  @override
  String get title => 'Sketching Plan';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const SemanticComponentsList();

  @override
  bool canAdvance(WidgetRef ref) {
    final isGenerating = ref.watch(
      canvasStateProvider.select((s) => s.isGenerating),
    );
    final hasComponents = ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents.isNotEmpty),
    );
    return !isGenerating && hasComponents;
  }

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    if (notifier.model.decomposedComponents.isEmpty &&
        !notifier.model.isGenerating) {
      await notifier.triggerDecomposition();
      if (notifier.model.pendingDecompositionOptions.isNotEmpty) {
        notifier.applyDecompositionOption(0);
      }
    }
    return notifier.model.decomposedComponents.isNotEmpty;
  }

  @override
  bool isStepComplete(CanvasModel model) =>
      model.decomposedComponents.isNotEmpty;
}

/// Step 4: Component sculpting
class ComponentSculptingStepDefinition extends WizardStepDefinition {
  const ComponentSculptingStepDefinition();

  @override
  WizardStep get step => WizardStep.componentSculpting;

  @override
  String get title => 'Component Sculpting';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const ShapeDecompositionList();

  @override
  bool canAdvance(WidgetRef ref) {
    return ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents.isNotEmpty),
    );
  }

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    if (notifier.model.decomposedComponents.isNotEmpty) {
      final allComplete = notifier.model.decomposedComponents.every(
        (c) => c.grid != null,
      );
      if (!allComplete && !notifier.model.isGenerating) {
        await notifier.sketchComponents();
      }
      return notifier.model.decomposedComponents.every((c) => c.grid != null);
    }
    return true;
  }

  @override
  bool isStepComplete(CanvasModel model) {
    return model.decomposedComponents.isNotEmpty &&
        model.decomposedComponents.every((c) => c.grid != null);
  }
}

/// Step 5: Component color and outline assignment
class ColorAndOutlineStepDefinition extends WizardStepDefinition {
  const ColorAndOutlineStepDefinition();

  @override
  WizardStep get step => WizardStep.colorAndOutline;

  @override
  String get title => 'Color & Outline';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const ComponentColorSelectionList();

  @override
  bool canAdvance(WidgetRef ref) {
    return ref.watch(
      canvasStateProvider.select((s) => s.decomposedComponents.isNotEmpty),
    );
  }

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    if (notifier.model.decomposedComponents.isNotEmpty &&
        notifier.model.referenceImage != null &&
        !notifier.model.isGenerating) {
      final result = await notifier.suggestComponentColors();
      if (result != null) {
        notifier.batchUpdateComponentColors(result.updatedComponents);
        return true;
      }
      return false;
    }
    return true;
  }

  @override
  bool isStepComplete(CanvasModel model) {
    return model.decomposedComponents.isNotEmpty &&
        model.decomposedComponents.any((c) => c.fillColor != null);
  }
}

/// Step 6: Layer ordering and canvas merge
class LayerOrderingAndMergeStepDefinition extends WizardStepDefinition {
  const LayerOrderingAndMergeStepDefinition();

  @override
  WizardStep get step => WizardStep.layerOrderingAndMerge;

  @override
  String get title => 'Layer Ordering & Merge';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const LayerOrderingList();

  @override
  bool canAdvance(WidgetRef ref) => true;

  @override
  void onManualAdvance(WidgetRef ref) {
    ref.read(canvasStateProvider.notifier).mergeComponentsToCanvas();
  }

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    if (notifier.model.decomposedComponents.isNotEmpty) {
      await notifier.reorderLayersWithAi();
      notifier.mergeComponentsToCanvas();
    }
    return true;
  }

  @override
  bool isStepComplete(CanvasModel model) => false;
}

/// Step 7: Final refinement
class RefinementStepDefinition extends WizardStepDefinition {
  const RefinementStepDefinition();

  @override
  WizardStep get step => WizardStep.refinement;

  @override
  String get title => 'Refinement';

  @override
  Widget buildWidget(BuildContext context, WidgetRef ref) =>
      const RefinementPanel();

  @override
  bool canAdvance(WidgetRef ref) => false;

  @override
  Future<bool> executeAutoPlay(CanvasNotifier notifier) async {
    if (!notifier.model.isGenerating &&
        notifier.model.userPrompt.trim().isNotEmpty) {
      await notifier.refineCanvas(notifier.model.userPrompt);
    }
    return true;
  }

  @override
  bool isStepComplete(CanvasModel model) => false;
}
