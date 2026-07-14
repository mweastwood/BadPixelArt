class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => '($x, $y)';
}

enum IssueType { doublePixel, jaggy }

class OutlineIssue {
  final IssueType type;
  final List<Point> pixels;
  final String description;

  OutlineIssue({
    required this.type,
    required this.pixels,
    required this.description,
  });
}

class AlgorithmicHelpers {
  /// Scans the outline grid and returns a list of detected jaggies/double-pixels.
  static List<OutlineIssue> detectOutlineIssues(
    List<List<int>> grid,
    int gridSize,
  ) {
    final List<OutlineIssue> issues = [];

    // 1. Detect Double-pixels (2x2 corners / L-shapes of outline pixels)
    for (int y = 0; y < gridSize - 1; y++) {
      for (int x = 0; x < gridSize - 1; x++) {
        final p00 = grid[y][x] != 0;
        final p01 = grid[y][x + 1] != 0;
        final p10 = grid[y + 1][x] != 0;
        final p11 = grid[y + 1][x + 1] != 0;

        // If any 3 of the 4 pixels in a 2x2 box are active, it's a corner bloat/double-pixel
        int activeCount =
            (p00 ? 1 : 0) + (p01 ? 1 : 0) + (p10 ? 1 : 0) + (p11 ? 1 : 0);
        if (activeCount >= 3) {
          final List<Point> involved = [];
          if (p00) involved.add(Point(x, y));
          if (p01) involved.add(Point(x + 1, y));
          if (p10) involved.add(Point(x, y + 1));
          if (p11) involved.add(Point(x + 1, y + 1));

          issues.add(
            OutlineIssue(
              type: IssueType.doublePixel,
              pixels: involved,
              description: 'Double-pixel corner bloat at ($x, $y)',
            ),
          );
        }
      }
    }

    // 2. Detect Jaggies (simple single-pixel step breaks in continuous lines)
    // We check for T-junctions or single offset pixels along cardinal directions.
    for (int y = 1; y < gridSize - 1; y++) {
      for (int x = 1; x < gridSize - 1; x++) {
        if (grid[y][x] != 0) {
          // Check horizontal line step
          final left = grid[y][x - 1] != 0;
          final right = grid[y][x + 1] != 0;
          final top = grid[y - 1][x] != 0;
          final bottom = grid[y + 1][x] != 0;

          // An offset single-pixel "jaggy" is active cardinally in one axis but has diagonal neighbors
          // that step offset, e.g. top-left and bottom-right are active, but cardinals are not.
          final tl = grid[y - 1][x - 1] != 0;
          final br = grid[y + 1][x + 1] != 0;
          if (tl && br && !left && !right && !top && !bottom) {
            issues.add(
              OutlineIssue(
                type: IssueType.jaggy,
                pixels: [Point(x, y)],
                description: 'Jagged staircase step at ($x, $y)',
              ),
            );
          }
        }
      }
    }

    return issues;
  }

  /// Proposes alternative grid configurations (solutions) to resolve a specific issue.
  static List<List<List<int>>> proposeSolutions(
    List<List<int>> grid,
    OutlineIssue issue,
    int gridSize,
  ) {
    final List<List<List<int>>> solutions = [];

    if (issue.type == IssueType.doublePixel) {
      // For double pixels, we propose removing one of the redundant corner pixels
      for (final p in issue.pixels) {
        final List<List<int>> candidate = List.generate(
          gridSize,
          (y) => List<int>.from(grid[y]),
        );
        candidate[p.y][p.x] = 0; // Erase this corner
        solutions.add(candidate);
      }
    } else if (issue.type == IssueType.jaggy) {
      // For jaggies, we propose smoothing the step by shifting the pixel cardinally
      for (final p in issue.pixels) {
        // Try shifting left/right/up/down
        final directions = [
          Point(0, -1),
          Point(0, 1),
          Point(-1, 0),
          Point(1, 0),
        ];

        for (final dir in directions) {
          final targetX = p.x + dir.x;
          final targetY = p.y + dir.y;

          if (targetX >= 0 &&
              targetX < gridSize &&
              targetY >= 0 &&
              targetY < gridSize) {
            final List<List<int>> candidate = List.generate(
              gridSize,
              (y) => List<int>.from(grid[y]),
            );
            // Move pixel from original position to new cardinal position
            final originalColor = candidate[p.y][p.x];
            candidate[p.y][p.x] = 0;
            candidate[targetY][targetX] = originalColor;
            solutions.add(candidate);
          }
        }
      }
    }

    return solutions;
  }
}
