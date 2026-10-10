import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../models/pixel_art_component.dart';

String serializeGrid(List<List<int>> grid) {
  return jsonEncode(grid);
}

List<List<int>> deserializeGrid(String data, {int? gridSize}) {
  try {
    if (data.isEmpty) {
      if (gridSize != null && gridSize > 0) {
        return List.generate(gridSize, (_) => List.filled(gridSize, 0));
      }
      return [];
    }
    final dynamic decoded = jsonDecode(data);
    if (decoded is! List) {
      if (gridSize != null && gridSize > 0) {
        return List.generate(gridSize, (_) => List.filled(gridSize, 0));
      }
      return [];
    }

    final parsedGrid = <List<int>>[];
    for (final row in decoded) {
      if (row is List) {
        final parsedRow = <int>[];
        for (final cell in row) {
          if (cell is int) {
            parsedRow.add(cell);
          } else if (cell is num) {
            parsedRow.add(cell.toInt());
          } else if (cell is String) {
            parsedRow.add(int.tryParse(cell) ?? 0);
          } else {
            parsedRow.add(0);
          }
        }
        parsedGrid.add(parsedRow);
      }
    }

    if (gridSize != null && gridSize > 0) {
      final bool isDimensionsValid =
          parsedGrid.length == gridSize &&
          parsedGrid.every((row) => row.length == gridSize);
      if (!isDimensionsValid) {
        debugPrint(
          'Deserialized grid dimensions do not match expected gridSize ($gridSize x $gridSize). Rebuilding blank grid.',
        );
        return List.generate(gridSize, (_) => List.filled(gridSize, 0));
      }
      return parsedGrid;
    }

    if (parsedGrid.isNotEmpty) {
      final firstRowLen = parsedGrid.first.length;
      if (firstRowLen > 0 && parsedGrid.every((r) => r.length == firstRowLen)) {
        return parsedGrid;
      }
    }
    return [];
  } catch (e) {
    debugPrint('Error deserializing grid data: $e');
    if (gridSize != null && gridSize > 0) {
      return List.generate(gridSize, (_) => List.filled(gridSize, 0));
    }
    return [];
  }
}

String serializePalette(List<Color> palette) {
  final list = palette
      .map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}')
      .toList();
  return jsonEncode(list);
}

List<Color> deserializePalette(String data) {
  try {
    if (data.isEmpty) return [];
    final dynamic decoded = jsonDecode(data);
    if (decoded is! List) return [];
    final colors = <Color>[];
    for (final item in decoded) {
      if (item == null) continue;
      try {
        final hexClean = item.toString().replaceFirst('#', '');
        final val = int.tryParse(hexClean, radix: 16);
        if (val != null) {
          colors.add(Color(val));
        } else {
          debugPrint('Skipping invalid palette hex entry: $item');
        }
      } catch (e) {
        debugPrint('Error parsing palette color entry "$item": $e');
      }
    }
    return colors;
  } catch (e) {
    debugPrint('Error deserializing palette data: $e');
    return [];
  }
}

String serializeComponents(List<PixelArtComponent> components) {
  final list = components.map((c) => c.toJson()).toList();
  return jsonEncode(list);
}

List<PixelArtComponent> deserializeComponents(String data) {
  try {
    if (data.isEmpty) return [];
    final List<dynamic> list = jsonDecode(data);
    return list
        .map((item) => PixelArtComponent.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('Error deserializing components data: $e');
    return [];
  }
}

String serializeHistory(List<AgentHistoryEntry> history) {
  final list = history.map((e) => e.toJson()).toList();
  return jsonEncode(list);
}

List<AgentHistoryEntry> deserializeHistory(String data) {
  try {
    if (data.isEmpty) return [];
    final List<dynamic> list = jsonDecode(data);
    return list
        .map((item) => AgentHistoryEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('Error deserializing history data: $e');
    return [];
  }
}
