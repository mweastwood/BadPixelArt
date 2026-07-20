import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../models/pixel_art_component.dart';

String serializeGrid(List<List<int>> grid) {
  return jsonEncode(grid);
}

List<List<int>> deserializeGrid(String data) {
  final List<dynamic> list = jsonDecode(data);
  return list.map((row) => List<int>.from(row as List)).toList();
}

String serializePalette(List<Color> palette) {
  final list = palette
      .map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}')
      .toList();
  return jsonEncode(list);
}

List<Color> deserializePalette(String data) {
  final List<dynamic> list = jsonDecode(data);
  return list.map((hex) {
    final hexClean = hex.toString().replaceFirst('#', '');
    return Color(int.parse(hexClean, radix: 16));
  }).toList();
}

String serializeComponents(List<PixelArtComponent> components) {
  final list = components.map((c) => c.toJson()).toList();
  return jsonEncode(list);
}

List<PixelArtComponent> deserializeComponents(String data) {
  if (data.isEmpty) return [];
  final List<dynamic> list = jsonDecode(data);
  return list
      .map((item) => PixelArtComponent.fromJson(item as Map<String, dynamic>))
      .toList();
}

String serializeHistory(List<AgentHistoryEntry> history) {
  final list = history.map((e) => e.toJson()).toList();
  return jsonEncode(list);
}

List<AgentHistoryEntry> deserializeHistory(String data) {
  if (data.isEmpty) return [];
  final List<dynamic> list = jsonDecode(data);
  return list
      .map((item) => AgentHistoryEntry.fromJson(item as Map<String, dynamic>))
      .toList();
}
