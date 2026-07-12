import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/drawing_commands.dart';

void main() {
  group('DrawingCommand Tests', () {
    const int gridSize = 8;
    late List<List<int>> grid;

    setUp(() {
      grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    });

    test('LineCommand draws straight line', () {
      final cmd = LineCommand(0, 0, 7, 0);
      cmd.execute(grid, 5, gridSize);

      expect(grid[0], equals([5, 5, 5, 5, 5, 5, 5, 5]));
      expect(grid[1], equals([0, 0, 0, 0, 0, 0, 0, 0]));
    });

    test('RectangleCommand draws empty outline', () {
      final cmd = RectangleCommand(1, 1, 3, 3);
      cmd.execute(grid, 2, gridSize);

      // Top edge
      expect(grid[1].sublist(1, 4), equals([2, 2, 2]));
      // Bottom edge
      expect(grid[3].sublist(1, 4), equals([2, 2, 2]));
      // Left/Right edge
      expect(grid[2].sublist(1, 4), equals([2, 0, 2]));
    });

    test('RectangleFilledCommand fills area', () {
      final cmd = RectangleFilledCommand(1, 1, 3, 3);
      cmd.execute(grid, 3, gridSize);

      expect(grid[1].sublist(1, 4), equals([3, 3, 3]));
      expect(grid[2].sublist(1, 4), equals([3, 3, 3]));
      expect(grid[3].sublist(1, 4), equals([3, 3, 3]));
    });

    test('RectangleHatchedCommand fills checkerboard', () {
      final cmd = RectangleHatchedCommand(1, 1, 3, 3);
      cmd.execute(grid, 4, gridSize);

      // (x+y)%2 == 0 is filled.
      // (1,1) -> (1+1)=2 (filled)
      // (2,1) -> (2+1)=3 (empty)
      // (3,1) -> (3+1)=4 (filled)
      expect(grid[1].sublist(1, 4), equals([4, 0, 4]));
      expect(grid[2].sublist(1, 4), equals([0, 4, 0]));
      expect(grid[3].sublist(1, 4), equals([4, 0, 4]));
    });

    test('DrawingCommandFactory handles valid and invalid tools', () {
      expect(
        DrawingCommandFactory.create('line', [1, 2, 3, 4]),
        isA<LineCommand>(),
      );
      expect(
        DrawingCommandFactory.create('circle', [1, 2, 3]),
        isA<CircleCommand>(),
      );
      expect(DrawingCommandFactory.create('invalid', [1, 2]), isNull);
      expect(
        DrawingCommandFactory.create('line', [1, 2]),
        isNull,
      ); // insufficient params
    });
  });
}
