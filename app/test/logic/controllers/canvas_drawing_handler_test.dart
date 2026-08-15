import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/line_command.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_command.dart';
import 'package:bad_pixel_art/logic/commands/circle_command.dart';
import 'package:bad_pixel_art/logic/commands/fill_command.dart';
import 'package:bad_pixel_art/logic/controllers/canvas_drawing_handler.dart';

void main() {
  group('CanvasDrawingHandler Unit Tests', () {
    const handler = CanvasDrawingHandler();

    test(
      'drawPixel sets pixel within bounds without mutating original grid',
      () {
        final original = List.generate(4, (_) => List.filled(4, 0));

        final updated = handler.drawPixel(original, 2, 3, 5, 4);

        expect(updated, isNotNull);
        expect(updated![3][2], equals(5));
        // Original must remain untouched
        expect(original[3][2], equals(0));
      },
    );

    test('drawPixel returns null for out of bounds coordinates', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));

      expect(handler.drawPixel(grid, -1, 0, 1, 4), isNull);
      expect(handler.drawPixel(grid, 0, -1, 1, 4), isNull);
      expect(handler.drawPixel(grid, 4, 0, 1, 4), isNull);
      expect(handler.drawPixel(grid, 0, 4, 1, 4), isNull);
      expect(handler.drawPixel(grid, 10, 10, 1, 4), isNull);
    });

    test('executeCommand executes LineCommand cleanly on a cloned grid', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      final command = LineCommand(0, 0, 3, 0);

      final result = handler.executeCommand(grid, command, 2, 8);

      for (int x = 0; x <= 3; x++) {
        expect(result[0][x], equals(2));
      }
      expect(result[0][4], equals(0));
      // Original remains 0
      expect(grid[0][0], equals(0));
    });

    test('executeCommand executes RectangleCommand on a cloned grid', () {
      final grid = List.generate(6, (_) => List.filled(6, 0));
      final command = RectangleCommand(1, 1, 4, 4);

      final result = handler.executeCommand(grid, command, 3, 6);

      expect(result[1][1], equals(3));
      expect(result[1][4], equals(3));
      expect(result[4][1], equals(3));
      expect(result[4][4], equals(3));
      // Center remains 0 for non-filled rectangle
      expect(result[2][2], equals(0));
      expect(grid[1][1], equals(0));
    });

    test('executeCommand executes CircleCommand on a cloned grid', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      final command = CircleCommand(4, 4, 2);

      final result = handler.executeCommand(grid, command, 1, 8);

      expect(result[4][6], equals(1));
      expect(result[4][2], equals(1));
      expect(result[6][4], equals(1));
      expect(result[2][4], equals(1));
      expect(grid[4][6], equals(0));
    });

    test('executeCommand executes FillCommand on a cloned grid', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      final command = FillCommand(0, 0);

      final result = handler.executeCommand(grid, command, 4, 4);

      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          expect(result[y][x], equals(4));
        }
      }
      expect(grid[0][0], equals(0));
    });
  });
}
