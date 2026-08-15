import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/controllers/canvas_history_controller.dart';

void main() {
  group('CanvasHistoryController Unit Tests', () {
    const controller = CanvasHistoryController();

    test('cloneGrid produces an isolated deep copy of the grid', () {
      final original = [
        [1, 2],
        [3, 4],
      ];
      final clone = controller.cloneGrid(original);

      expect(clone, equals(original));
      expect(identical(clone, original), isFalse);
      expect(identical(clone[0], original[0]), isFalse);

      clone[0][0] = 99;
      expect(original[0][0], equals(1));
    });

    test(
      'push saves cloned grid snapshot to undoStack and clears redoStack',
      () {
        final currentGrid = [
          [0, 1],
          [2, 3],
        ];
        final initialUndo = <List<List<int>>>[];

        final result = controller.push(currentGrid, initialUndo);

        expect(result.undoStack.length, equals(1));
        expect(result.undoStack.first, equals(currentGrid));
        expect(identical(result.undoStack.first, currentGrid), isFalse);
        expect(result.redoStack, isEmpty);

        // Mutating currentGrid should not affect undo snapshot
        currentGrid[0][0] = 5;
        expect(result.undoStack.first[0][0], equals(0));
      },
    );

    test('push caps undoStack depth when exceeding maxHistory', () {
      List<List<List<int>>> undoStack = [];

      for (int i = 0; i < 60; i++) {
        final grid = [
          [i],
        ];
        final pushResult = controller.push(grid, undoStack, maxHistory: 50);
        undoStack = pushResult.undoStack;
      }

      expect(undoStack.length, equals(50));
      // First entry should be index 10 (since 0-9 were trimmed)
      expect(undoStack.first[0][0], equals(10));
      expect(undoStack.last[0][0], equals(59));
    });

    test('undo returns null when undoStack is empty', () {
      final result = controller.undo(
        undoStack: const [],
        redoStack: const [],
        currentGrid: [
          [1, 2],
        ],
      );

      expect(result, isNull);
    });

    test(
      'undo restores previous grid and records current grid in redoStack',
      () {
        final snapshot1 = [
          [0, 0],
        ];
        final currentGrid = [
          [1, 1],
        ];
        final undoStack = [snapshot1];
        final redoStack = <List<List<int>>>[];

        final result = controller.undo(
          undoStack: undoStack,
          redoStack: redoStack,
          currentGrid: currentGrid,
        );

        expect(result, isNotNull);
        expect(result!.grid, equals(snapshot1));
        expect(result.undoStack, isEmpty);
        expect(result.redoStack.length, equals(1));
        expect(result.redoStack.first, equals(currentGrid));
      },
    );

    test('redo returns null when redoStack is empty', () {
      final result = controller.redo(
        undoStack: const [],
        redoStack: const [],
        currentGrid: [
          [1, 2],
        ],
      );

      expect(result, isNull);
    });

    test(
      'redo advances to next grid and records current grid in undoStack',
      () {
        final redoSnapshot = [
          [2, 2],
        ];
        final currentGrid = [
          [1, 1],
        ];
        final undoStack = <List<List<int>>>[];
        final redoStack = [redoSnapshot];

        final result = controller.redo(
          undoStack: undoStack,
          redoStack: redoStack,
          currentGrid: currentGrid,
        );

        expect(result, isNotNull);
        expect(result!.grid, equals(redoSnapshot));
        expect(result.redoStack, isEmpty);
        expect(result.undoStack.length, equals(1));
        expect(result.undoStack.first, equals(currentGrid));
      },
    );

    test('multi-step undo and redo lifecycle maintains state consistency', () {
      List<List<int>> grid = [
        [0, 0],
        [0, 0],
      ];
      List<List<List<int>>> undoStack = [];
      List<List<List<int>>> redoStack = [];

      // Step 1: Draw (0, 0) = 1
      var push = controller.push(grid, undoStack);
      undoStack = push.undoStack;
      redoStack = push.redoStack;
      grid = [
        [1, 0],
        [0, 0],
      ];

      // Step 2: Draw (1, 1) = 2
      push = controller.push(grid, undoStack);
      undoStack = push.undoStack;
      redoStack = push.redoStack;
      grid = [
        [1, 0],
        [0, 2],
      ];

      expect(undoStack.length, equals(2));
      expect(redoStack, isEmpty);

      // Undo Step 2
      final undo1 = controller.undo(
        undoStack: undoStack,
        redoStack: redoStack,
        currentGrid: grid,
      )!;
      grid = undo1.grid;
      undoStack = undo1.undoStack;
      redoStack = undo1.redoStack;
      expect(
        grid,
        equals([
          [1, 0],
          [0, 0],
        ]),
      );
      expect(undoStack.length, equals(1));
      expect(redoStack.length, equals(1));

      // Undo Step 1
      final undo2 = controller.undo(
        undoStack: undoStack,
        redoStack: redoStack,
        currentGrid: grid,
      )!;
      grid = undo2.grid;
      undoStack = undo2.undoStack;
      redoStack = undo2.redoStack;
      expect(
        grid,
        equals([
          [0, 0],
          [0, 0],
        ]),
      );
      expect(undoStack, isEmpty);
      expect(redoStack.length, equals(2));

      // Redo Step 1
      final redo1 = controller.redo(
        undoStack: undoStack,
        redoStack: redoStack,
        currentGrid: grid,
      )!;
      grid = redo1.grid;
      undoStack = redo1.undoStack;
      redoStack = redo1.redoStack;
      expect(
        grid,
        equals([
          [1, 0],
          [0, 0],
        ]),
      );
      expect(undoStack.length, equals(1));
      expect(redoStack.length, equals(1));

      // Redo Step 2
      final redo2 = controller.redo(
        undoStack: undoStack,
        redoStack: redoStack,
        currentGrid: grid,
      )!;
      grid = redo2.grid;
      undoStack = redo2.undoStack;
      redoStack = redo2.redoStack;
      expect(
        grid,
        equals([
          [1, 0],
          [0, 2],
        ]),
      );
      expect(undoStack.length, equals(2));
      expect(redoStack, isEmpty);
    });
  });
}
