import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/orchestrators/sculpting_orchestrator.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

import '../../test_helper.dart';

void main() {
  group('SculptingOrchestrator Unit Tests', () {
    late SculptingOrchestrator orchestrator;
    late TestMockAiService mockAiService;

    setUp(() {
      mockAiService = TestMockAiService(
        response: '''{
        "thought": "sculpting component",
        "tool": "apply_rectangle_filled",
        "params": [4, 4, 12, 12],
        "isComplete": true
      }''',
      );
      orchestrator = SculptingOrchestrator(mockAiService);
    });

    test('buildBackgroundGrid excludes specified index and places colors', () {
      final comp1Grid = List.generate(
        16,
        (y) => List.generate(16, (x) => y < 8 ? 1 : 0),
      );
      final comp2Grid = List.generate(
        16,
        (y) => List.generate(16, (x) => y >= 8 ? 1 : 0),
      );

      final comp1 = PixelArtComponent(
        name: 'Head',
        description: 'Head',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1.0, 0.5),
        shapes: const [],
        grid: comp1Grid,
      );
      final comp2 = PixelArtComponent(
        name: 'Body',
        description: 'Body',
        relativeBoundingBox: const Rect.fromLTWH(0, 0.5, 1.0, 0.5),
        shapes: const [],
        grid: comp2Grid,
      );

      final bgGrid = SculptingOrchestrator.buildBackgroundGrid(
        components: [comp1, comp2],
        excludeIndex: 0,
        gridSize: 16,
        paletteLength: 4,
      );

      expect(bgGrid[0][0], equals(0)); // comp1 is excluded
      expect(bgGrid[10][10], equals(2)); // comp2 is included: (1 % 3) + 1 = 2
    });

    test('buildBackgroundGrid handles paletteLength <= 1 without throwing', () {
      final comp1Grid = List.generate(
        16,
        (y) => List.generate(16, (x) => y < 8 ? 1 : 0),
      );
      final comp2Grid = List.generate(
        16,
        (y) => List.generate(16, (x) => y >= 8 ? 1 : 0),
      );
      final comp1 = PixelArtComponent(
        name: 'Head',
        description: 'Head',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1.0, 0.5),
        shapes: const [],
        grid: comp1Grid,
      );
      final comp2 = PixelArtComponent(
        name: 'Body',
        description: 'Body',
        relativeBoundingBox: const Rect.fromLTWH(0, 0.5, 1.0, 0.5),
        shapes: const [],
        grid: comp2Grid,
      );

      // paletteLength == 0 should not throw IntegerDivisionByZeroException
      final bgGridZero = SculptingOrchestrator.buildBackgroundGrid(
        components: [comp1, comp2],
        excludeIndex: 0,
        gridSize: 16,
        paletteLength: 0,
      );
      expect(bgGridZero[0][0], equals(0)); // comp1 is excluded
      expect(
        bgGridZero[10][10],
        equals(1),
      ); // comp2 is included, divisor defaults to 1 -> (1 % 1) + 1 = 1

      // paletteLength == 1 should not throw IntegerDivisionByZeroException
      final bgGridOne = SculptingOrchestrator.buildBackgroundGrid(
        components: [comp1, comp2],
        excludeIndex: 0,
        gridSize: 16,
        paletteLength: 1,
      );
      expect(bgGridOne[0][0], equals(0)); // comp1 is excluded
      expect(
        bgGridOne[10][10],
        equals(1),
      ); // comp2 is included, divisor defaults to 1 -> (1 % 1) + 1 = 1
    });

    test('sculptSingleComponent sculpts targeted component', () async {
      final comp = PixelArtComponent(
        name: 'Head',
        description: 'Head',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1.0, 1.0),
        shapes: const [],
      );

      final result = await orchestrator.sculptSingleComponent(
        component: comp,
        index: 0,
        allComponents: [comp],
        gridSize: 16,
        activePalette: [Colors.black, Colors.white, Colors.red],
        userPrompt: 'a simple character',
        referenceImage: null,
      );

      expect(result, isNotEmpty);
      expect(result.length, equals(16));
    });

    test(
      'sculptAllComponents iterates through components and updates them',
      () async {
        final comp1 = PixelArtComponent(
          name: 'Head',
          description: 'Head',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 0.5, 0.5),
          shapes: const [],
        );
        final comp2 = PixelArtComponent(
          name: 'Body',
          description: 'Body',
          relativeBoundingBox: const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
          shapes: const [],
        );

        final stepUpdates = <List<PixelArtComponent>>[];
        final results = await orchestrator.sculptAllComponents(
          components: [comp1, comp2],
          gridSize: 16,
          activePalette: [Colors.black, Colors.white, Colors.red],
          userPrompt: 'a simple character',
          onStep: (activeIndex, updated, status) {
            stepUpdates.add(List.from(updated));
          },
        );

        expect(results.length, equals(2));
        expect(results[0].isSculpted, isTrue);
        expect(results[1].isSculpted, isTrue);
        expect(stepUpdates, isNotEmpty);
      },
    );

    test(
      'sculptAllComponents skips already sculpted components and processes only unsculpted ones',
      () async {
        final comp1 = PixelArtComponent(
          name: 'Head',
          description: 'Head',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 0.5, 0.5),
          shapes: const [],
          isSculpted: true,
          grid: List.generate(16, (_) => List.filled(16, 1)),
        );
        final comp2 = PixelArtComponent(
          name: 'Body',
          description: 'Body',
          relativeBoundingBox: const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
          shapes: const [],
          isSculpted: false,
          grid: null,
        );

        final results = await orchestrator.sculptAllComponents(
          components: [comp1, comp2],
          gridSize: 16,
          activePalette: [Colors.black, Colors.white, Colors.red],
          userPrompt: 'a simple character',
          onStep: (activeIndex, updated, status) {},
        );

        expect(results.length, equals(2));
        expect(results[0].isSculpted, isTrue);
        expect(results[0].grid![0][0], equals(1));
        expect(results[1].isSculpted, isTrue);
        expect(mockAiService.callCount, equals(1)); // Only called for comp2!
      },
    );
  });
}
