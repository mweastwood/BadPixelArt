import 'package:bad_pixel_art/logic/models/canvas_model.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';
import 'package:bad_pixel_art/logic/wizard/steps/default_wizard_steps.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:flutter_test/flutter_test.dart';

CanvasModel _createTestModel({
  String userPrompt = '',
  List<Color> palette = const [Colors.black],
  List<PixelArtComponent> decomposedComponents = const [],
}) {
  return CanvasModel(
    grid: List.generate(16, (_) => List.filled(16, 0)),
    selectedColorIndex: 0,
    selectedTool: CanvasTool.circle,
    paletteName: 'default',
    palette: palette,
    userPrompt: userPrompt,
    aiStatus: AiCoreStatus.available,
    isGenerating: false,
    autoRun: false,
    autoRunSpeed: 1.0,
    undoStack: const [],
    redoStack: const [],
    aiHistory: const [],
    decomposedComponents: decomposedComponents,
  );
}

void main() {
  group('Default Wizard Step Definitions Tests', () {
    test('SelectGridSizeStepDefinition basic properties', () {
      const step = SelectGridSizeStepDefinition();
      expect(step.step, equals(WizardStep.selectGridSize));
      expect(step.title, equals('Select Grid Size'));
      expect(step.isStepComplete(_createTestModel()), isTrue);
    });

    test('SetupPromptStepDefinition completion checks userPrompt', () {
      const step = SetupPromptStepDefinition();
      expect(step.step, equals(WizardStep.setupPrompt));
      expect(step.title, equals('Setup Prompt'));
      expect(step.isStepComplete(_createTestModel(userPrompt: '')), isFalse);
      expect(
        step.isStepComplete(_createTestModel(userPrompt: 'a dragon')),
        isTrue,
      );
    });

    test('SelectPaletteStepDefinition completion checks palette', () {
      const step = SelectPaletteStepDefinition();
      expect(step.step, equals(WizardStep.selectPalette));
      expect(step.title, equals('Select Palette'));
      expect(step.isStepComplete(_createTestModel(palette: [])), isFalse);
      expect(
        step.isStepComplete(_createTestModel(palette: [Colors.black])),
        isTrue,
      );
    });

    test(
      'SketchingPlanStepDefinition completion checks decomposedComponents',
      () {
        const step = SketchingPlanStepDefinition();
        expect(step.step, equals(WizardStep.sketchingPlan));
        expect(step.title, equals('Sketching Plan'));
        expect(
          step.isStepComplete(_createTestModel(decomposedComponents: [])),
          isFalse,
        );
        expect(
          step.isStepComplete(
            _createTestModel(
              decomposedComponents: [
                PixelArtComponent(
                  name: 'head',
                  description: 'head',
                  relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
                ),
              ],
            ),
          ),
          isTrue,
        );
      },
    );

    test('ComponentSculptingStepDefinition checks all components sculpted', () {
      const step = ComponentSculptingStepDefinition();
      expect(step.step, equals(WizardStep.componentSculpting));
      expect(step.title, equals('Component Sculpting'));

      final unsculpted = _createTestModel(
        decomposedComponents: [
          PixelArtComponent(
            name: 'head',
            description: 'head',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            isSculpted: false,
            grid: null,
          ),
        ],
      );
      expect(step.isStepComplete(unsculpted), isFalse);

      final sculpted = _createTestModel(
        decomposedComponents: [
          PixelArtComponent(
            name: 'head',
            description: 'head',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            isSculpted: true,
            grid: List.generate(8, (_) => List.filled(8, 1)),
          ),
        ],
      );
      expect(step.isStepComplete(sculpted), isTrue);
    });

    test('ColorAndOutlineStepDefinition checks fillColor', () {
      const step = ColorAndOutlineStepDefinition();
      expect(step.step, equals(WizardStep.colorAndOutline));
      expect(step.title, equals('Color & Outline'));

      final uncolored = _createTestModel(
        decomposedComponents: [
          PixelArtComponent(
            name: 'head',
            description: 'head',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            fillColor: null,
          ),
        ],
      );
      expect(step.isStepComplete(uncolored), isFalse);

      final colored = _createTestModel(
        decomposedComponents: [
          PixelArtComponent(
            name: 'head',
            description: 'head',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            fillColor: const Color(0xFF112233),
          ),
        ],
      );
      expect(step.isStepComplete(colored), isTrue);
    });

    test(
      'LayerOrderingAndMergeStepDefinition & RefinementStepDefinition properties',
      () {
        const layerStep = LayerOrderingAndMergeStepDefinition();
        expect(layerStep.step, equals(WizardStep.layerOrderingAndMerge));
        expect(layerStep.title, equals('Layer Ordering & Merge'));

        const refineStep = RefinementStepDefinition();
        expect(refineStep.step, equals(WizardStep.refinement));
        expect(refineStep.title, equals('Refinement'));
      },
    );
  });
}
