import 'package:flutter/material.dart';

/// Extension to extract R, G, B channels as integers from a Color.
extension _ColorRgbInt on Color {
  int get rInt => (r * 255.0).round().clamp(0, 255);
  int get gInt => (g * 255.0).round().clamp(0, 255);
  int get bInt => (b * 255.0).round().clamp(0, 255);
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

  // 2. Select initial centroids spread across the unique colors
  final List<Color> centroids = [];
  final step = uniqueColors.length ~/ k;
  for (int i = 0; i < k; i++) {
    centroids.add(
      Color(uniqueColors[(i * step).clamp(0, uniqueColors.length - 1)]),
    );
  }

  // 3. Iteratively refine centroids
  for (int iteration = 0; iteration < 5; iteration++) {
    final List<List<int>> clusters = List.generate(k, (_) => []);

    // Assign each unique color to the closest centroid
    for (final argb in uniqueColors) {
      final color = Color(argb);
      double minDistance = double.infinity;
      int bestCentroidIndex = 0;

      for (int c = 0; c < k; c++) {
        final cent = centroids[c];
        final dr = color.rInt - cent.rInt;
        final dg = color.gInt - cent.gInt;
        final db = color.bInt - cent.bInt;
        final dist = dr * dr + dg * dg + db * db;
        if (dist < minDistance) {
          minDistance = dist.toDouble();
          bestCentroidIndex = c;
        }
      }
      clusters[bestCentroidIndex].add(argb);
    }

    // Recompute centroids as weighted averages
    for (int c = 0; c < k; c++) {
      final cluster = clusters[c];
      if (cluster.isEmpty) continue;

      double totalWeight = 0;
      double sumR = 0;
      double sumG = 0;
      double sumB = 0;

      for (final argb in cluster) {
        final weight = colorCounts[argb]!.toDouble();
        final color = Color(argb);
        sumR += color.rInt * weight;
        sumG += color.gInt * weight;
        sumB += color.bInt * weight;
        totalWeight += weight;
      }

      if (totalWeight > 0) {
        centroids[c] = Color.fromARGB(
          255,
          (sumR / totalWeight).round().clamp(0, 255),
          (sumG / totalWeight).round().clamp(0, 255),
          (sumB / totalWeight).round().clamp(0, 255),
        );
      }
    }
  }

  return centroids;
}
