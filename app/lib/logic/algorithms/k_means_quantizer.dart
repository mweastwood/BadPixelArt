import 'package:flutter/material.dart';

class _RgbPoint {
  final int r;
  final int g;
  final int b;
  final int weight;

  const _RgbPoint({
    required this.r,
    required this.g,
    required this.b,
    required this.weight,
  });
}

/// Extracted weighted K-Means color quantization algorithm.
List<Color> kMeansQuantize(List<List<Color>> colorGrid, int k) {
  // 1. Gather all pixel colors and count their frequency
  final Map<int, int> colorCounts = {};
  for (final row in colorGrid) {
    for (final color in row) {
      final argb = color.toARGB32();
      colorCounts[argb] = (colorCounts[argb] ?? 0) + 1;
    }
  }

  final List<int> uniqueColors = colorCounts.keys.toList();
  if (uniqueColors.length <= k) {
    final list = uniqueColors.map((argb) => Color(argb)).toList();
    while (list.length < k) {
      list.add(list.length % 2 == 0 ? Colors.black : Colors.white);
    }
    return list;
  }

  // Pre-extract integer RGB channels and weights using bitwise operations
  final List<_RgbPoint> points = [];
  for (final argb in uniqueColors) {
    points.add(
      _RgbPoint(
        r: (argb >> 16) & 0xFF,
        g: (argb >> 8) & 0xFF,
        b: argb & 0xFF,
        weight: colorCounts[argb]!,
      ),
    );
  }

  // 2. Select initial centroids spread across the unique colors
  final List<int> centroidR = List<int>.filled(k, 0);
  final List<int> centroidG = List<int>.filled(k, 0);
  final List<int> centroidB = List<int>.filled(k, 0);

  final step = points.length ~/ k;
  for (int i = 0; i < k; i++) {
    final pt = points[(i * step).clamp(0, points.length - 1)];
    centroidR[i] = pt.r;
    centroidG[i] = pt.g;
    centroidB[i] = pt.b;
  }

  // 3. Iteratively refine centroids
  for (int iteration = 0; iteration < 5; iteration++) {
    final List<List<_RgbPoint>> clusters = List.generate(k, (_) => []);

    // Assign each unique color to the closest centroid
    for (final pt in points) {
      int minDistance = 0x7FFFFFFF;
      int bestCentroidIndex = 0;
      final pr = pt.r;
      final pg = pt.g;
      final pb = pt.b;

      for (int c = 0; c < k; c++) {
        final dr = pr - centroidR[c];
        final dg = pg - centroidG[c];
        final db = pb - centroidB[c];
        final dist = dr * dr + dg * dg + db * db;
        if (dist < minDistance) {
          minDistance = dist;
          bestCentroidIndex = c;
        }
      }
      clusters[bestCentroidIndex].add(pt);
    }

    // Recompute centroids as weighted averages
    for (int c = 0; c < k; c++) {
      final cluster = clusters[c];
      if (cluster.isEmpty) continue;

      int totalWeight = 0;
      int sumR = 0;
      int sumG = 0;
      int sumB = 0;

      for (final pt in cluster) {
        final weight = pt.weight;
        sumR += pt.r * weight;
        sumG += pt.g * weight;
        sumB += pt.b * weight;
        totalWeight += weight;
      }

      if (totalWeight > 0) {
        centroidR[c] = (sumR / totalWeight).round().clamp(0, 255);
        centroidG[c] = (sumG / totalWeight).round().clamp(0, 255);
        centroidB[c] = (sumB / totalWeight).round().clamp(0, 255);
      }
    }
  }

  return List<Color>.generate(
    k,
    (c) => Color.fromARGB(255, centroidR[c], centroidG[c], centroidB[c]),
  );
}
