import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../models/color_palette.dart';
import '../models/pixel_art_component.dart';

/// Helper function to create a blank [gridSize] x [gridSize] grid.
List<List<int>> createBlankGrid(int gridSize) {
  return List.generate(gridSize, (_) => List.filled(gridSize, 0));
}

String serializeGrid(List<List<int>> grid) {
  return jsonEncode(grid);
}

/// Returns [index] if it is a valid index into a palette of [paletteLength]
/// colors, otherwise 0 (or 0 when the palette is empty).
int clampColorIndex(int index, int paletteLength) {
  return (index >= 0 && index < paletteLength) ? index : 0;
}

/// Strictly deserializes a grid from JSON, returning null when the data is
/// missing, malformed or has mismatched dimensions.
///
/// When [gridSize] is provided the grid must be [gridSize] x [gridSize];
/// otherwise it must be a non-empty rectangular grid. When [paletteLength] is
/// provided, cell values outside `[0, paletteLength)` are reset to 0 so
/// rendering can never index past the palette. [logContext] (e.g. the creation
/// id) is included in the log message when the data is invalid.
List<List<int>>? tryDeserializeGrid(
  String data, {
  int? gridSize,
  int? paletteLength,
  String? logContext,
}) {
  List<List<int>>? invalid(String reason) {
    final prefix = logContext == null ? '' : '[$logContext] ';
    debugPrint('${prefix}Deserialized grid is invalid ($reason).');
    return null;
  }

  try {
    if (data.isEmpty) return invalid('empty data');
    final dynamic decoded = jsonDecode(data);
    if (decoded is! List) return invalid('not a list');

    int parseCell(dynamic cell) {
      final int value = switch (cell) {
        int c => c,
        num c => c.toInt(),
        String c => int.tryParse(c) ?? 0,
        _ => 0,
      };
      return paletteLength == null
          ? value
          : clampColorIndex(value, paletteLength);
    }

    final parsedGrid = <List<int>>[];
    for (final row in decoded) {
      if (row is! List) return invalid('non-list row');
      parsedGrid.add(row.map(parseCell).toList());
    }

    if (gridSize != null && gridSize > 0) {
      final isDimensionsValid =
          parsedGrid.length == gridSize &&
          parsedGrid.every((row) => row.length == gridSize);
      return isDimensionsValid
          ? parsedGrid
          : invalid('dimensions do not match $gridSize x $gridSize');
    }

    final firstRowLen = parsedGrid.isEmpty ? 0 : parsedGrid.first.length;
    if (firstRowLen > 0 && parsedGrid.every((r) => r.length == firstRowLen)) {
      return parsedGrid;
    }
    return invalid('ragged or empty grid');
  } catch (e) {
    return invalid('error: $e');
  }
}

/// Deserializes a grid from JSON.
///
/// When [gridSize] is provided, any invalid or mismatched data yields a blank
/// [gridSize] x [gridSize] grid; otherwise an empty grid is returned. Callers
/// that persist state should use [tryDeserializeGrid] to detect recovery so
/// the blank fallback is never written over the original data. See
/// [tryDeserializeGrid] for [paletteLength] and [logContext].
List<List<int>> deserializeGrid(
  String data, {
  int? gridSize,
  int? paletteLength,
  String? logContext,
}) {
  return tryDeserializeGrid(
        data,
        gridSize: gridSize,
        paletteLength: paletteLength,
        logContext: logContext,
      ) ??
      ((gridSize != null && gridSize > 0)
          ? createBlankGrid(gridSize)
          : <List<int>>[]);
}

String serializePalette(List<Color> palette) {
  final list = palette
      .map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}')
      .toList();
  return jsonEncode(list);
}

/// Color substituted for palette entries that are null or not valid hex, so
/// the indices of all other colors stay stable.
const Color invalidPaletteEntryColor = Color(0xFFFF00FF);

/// Deserializes a palette from JSON. Invalid or null entries are replaced with
/// [invalidPaletteEntryColor] rather than skipped, so grid cells keep
/// referencing the correct colors. [logContext] (e.g. the creation id) is
/// included in log messages.
List<Color> deserializePalette(
  String data, {
  List<Color>? fallback,
  String? logContext,
}) {
  final prefix = logContext == null ? '' : '[$logContext] ';
  List<Color> fallbackOrEmpty() => fallback ?? [];
  try {
    if (data.isEmpty) {
      return fallbackOrEmpty();
    }
    final dynamic decoded = jsonDecode(data);
    if (decoded is! List) {
      return fallbackOrEmpty();
    }
    final colors = <Color>[];
    var validCount = 0;
    for (final item in decoded) {
      final val = item == null
          ? null
          : int.tryParse(item.toString().replaceFirst('#', ''), radix: 16);
      if (val != null) {
        colors.add(Color(val));
        validCount++;
      } else {
        debugPrint(
          '${prefix}Invalid palette entry at index ${colors.length}: $item; '
          'using placeholder color.',
        );
        colors.add(invalidPaletteEntryColor);
      }
    }
    return validCount == 0 ? fallbackOrEmpty() : colors;
  } catch (e) {
    debugPrint('${prefix}Error deserializing palette data: $e');
    return fallbackOrEmpty();
  }
}

/// Deserializes palette colors from JSON, falling back to [fallback] (or
/// [PaletteRegistry.primaryPalette] if [fallback] is null or empty) when the
/// parsed palette is empty.
///
/// Callers that have no current canvas state (e.g. app startup and the
/// creations drawer/thumbnails) intentionally omit [fallback] and get the
/// primary palette. `CanvasRepository` passes `currentState.palette` instead
/// so an in-progress session keeps its own palette when stored colors are
/// corrupt.
List<Color> resolvePalette(
  String data, {
  List<Color>? fallback,
  String? logContext,
}) {
  return deserializePalette(
    data,
    logContext: logContext,
    fallback: (fallback == null || fallback.isEmpty)
        ? PaletteRegistry.primaryPalette
        : fallback,
  );
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
