import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import 'pixel_art_component.dart';

enum CanvasTool { line, circle, fill, hatch }

@immutable
class CanvasModel {
  final int? creationId;
  final String title;
  final int gridSize;
  final List<List<int>> grid;
  final int selectedColorIndex;
  final CanvasTool selectedTool;
  final String paletteName;
  final List<Color> palette;
  final Uint8List? referenceImage;
  final Uint8List? originalReferenceImage;
  final String userPrompt;
  final AiCoreStatus aiStatus;
  final bool isGenerating;
  final bool autoRun;
  final double autoRunSpeed; // in seconds
  final List<List<List<int>>> undoStack;
  final List<List<List<int>>> redoStack;
  final List<AgentHistoryEntry> aiHistory;
  final List<Color>? suggestedPalette;
  final bool isSuggestingPalette;
  final bool isSuggestingDescription;
  final bool isPausing;
  final bool showPaletteSuggestion;
  final String? nextFocus;
  final String modelReleaseStage;
  final String modelPreference;
  final List<List<PixelArtComponent>> pendingDecompositionOptions;
  final List<PixelArtComponent> decomposedComponents;
  final int activeComponentIndex;
  final int? decomposingComponentIndex;
  final String? sculptingStatus;

  const CanvasModel({
    this.creationId,
    this.title = 'Untitled',
    this.gridSize = 16,
    required this.grid,
    required this.selectedColorIndex,
    required this.selectedTool,
    required this.paletteName,
    required this.palette,
    this.referenceImage,
    this.originalReferenceImage,
    required this.userPrompt,
    required this.aiStatus,
    required this.isGenerating,
    required this.autoRun,
    required this.autoRunSpeed,
    required this.undoStack,
    required this.redoStack,
    required this.aiHistory,
    this.suggestedPalette,
    this.isSuggestingPalette = false,
    this.isSuggestingDescription = false,
    this.isPausing = false,
    this.showPaletteSuggestion = false,
    this.nextFocus,
    this.modelReleaseStage = 'stable',
    this.modelPreference = 'full',
    this.pendingDecompositionOptions = const [],
    this.decomposedComponents = const [],
    this.activeComponentIndex = 0,
    this.decomposingComponentIndex,
    this.sculptingStatus,
  });

  CanvasModel copyWith({
    int? creationId,
    bool clearCreationId = false,
    String? title,
    int? gridSize,
    List<List<int>>? grid,
    int? selectedColorIndex,
    CanvasTool? selectedTool,
    String? paletteName,
    List<Color>? palette,
    Uint8List? referenceImage,
    Uint8List? originalReferenceImage,
    bool clearReference = false,
    String? userPrompt,
    bool clearUserPrompt = false,
    AiCoreStatus? aiStatus,
    bool? isGenerating,
    bool? autoRun,
    double? autoRunSpeed,
    List<List<List<int>>>? undoStack,
    List<List<List<int>>>? redoStack,
    List<AgentHistoryEntry>? aiHistory,
    List<Color>? suggestedPalette,
    bool? isSuggestingPalette,
    bool? isSuggestingDescription,
    bool? isPausing,
    bool? showPaletteSuggestion,
    bool clearSuggestedPalette = false,
    String? nextFocus,
    bool clearNextFocus = false,
    String? modelReleaseStage,
    String? modelPreference,
    List<List<PixelArtComponent>>? pendingDecompositionOptions,
    List<PixelArtComponent>? decomposedComponents,
    int? activeComponentIndex,
    int? decomposingComponentIndex,
    bool clearDecomposingComponent = false,
    String? sculptingStatus,
    bool clearSculptingStatus = false,
  }) {
    return CanvasModel(
      creationId: clearCreationId ? null : (creationId ?? this.creationId),
      title: title ?? this.title,
      gridSize: gridSize ?? this.gridSize,
      grid: grid ?? this.grid,
      selectedColorIndex: selectedColorIndex ?? this.selectedColorIndex,
      selectedTool: selectedTool ?? this.selectedTool,
      paletteName: paletteName ?? this.paletteName,
      palette: palette ?? this.palette,
      referenceImage: clearReference
          ? null
          : (referenceImage ?? this.referenceImage),
      originalReferenceImage: clearReference
          ? null
          : (originalReferenceImage ?? this.originalReferenceImage),
      userPrompt: userPrompt ?? this.userPrompt,
      aiStatus: aiStatus ?? this.aiStatus,
      isGenerating: isGenerating ?? this.isGenerating,
      autoRun: autoRun ?? this.autoRun,
      autoRunSpeed: autoRunSpeed ?? this.autoRunSpeed,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      aiHistory: aiHistory ?? this.aiHistory,
      suggestedPalette: clearSuggestedPalette
          ? null
          : (suggestedPalette ?? this.suggestedPalette),
      isSuggestingPalette: isSuggestingPalette ?? this.isSuggestingPalette,
      isSuggestingDescription:
          isSuggestingDescription ?? this.isSuggestingDescription,
      isPausing: isPausing ?? this.isPausing,
      showPaletteSuggestion:
          showPaletteSuggestion ?? this.showPaletteSuggestion,
      nextFocus: clearNextFocus ? null : (nextFocus ?? this.nextFocus),
      modelReleaseStage: modelReleaseStage ?? this.modelReleaseStage,
      modelPreference: modelPreference ?? this.modelPreference,
      pendingDecompositionOptions:
          pendingDecompositionOptions ?? this.pendingDecompositionOptions,
      decomposedComponents: decomposedComponents ?? this.decomposedComponents,
      activeComponentIndex: activeComponentIndex ?? this.activeComponentIndex,
      decomposingComponentIndex: clearDecomposingComponent
          ? null
          : (decomposingComponentIndex ?? this.decomposingComponentIndex),
      sculptingStatus: clearSculptingStatus
          ? null
          : (sculptingStatus ?? this.sculptingStatus),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CanvasModel) return false;
    return creationId == other.creationId &&
        title == other.title &&
        gridSize == other.gridSize &&
        _gridEquals(grid, other.grid) &&
        selectedColorIndex == other.selectedColorIndex &&
        selectedTool == other.selectedTool &&
        paletteName == other.paletteName &&
        userPrompt == other.userPrompt &&
        aiStatus == other.aiStatus &&
        isGenerating == other.isGenerating &&
        autoRun == other.autoRun &&
        autoRunSpeed == other.autoRunSpeed &&
        _stackEquals(undoStack, other.undoStack) &&
        _stackEquals(redoStack, other.redoStack) &&
        isSuggestingPalette == other.isSuggestingPalette &&
        isSuggestingDescription == other.isSuggestingDescription &&
        isPausing == other.isPausing &&
        showPaletteSuggestion == other.showPaletteSuggestion &&
        nextFocus == other.nextFocus &&
        modelReleaseStage == other.modelReleaseStage &&
        modelPreference == other.modelPreference &&
        activeComponentIndex == other.activeComponentIndex &&
        decomposingComponentIndex == other.decomposingComponentIndex &&
        sculptingStatus == other.sculptingStatus &&
        listEquals(palette, other.palette) &&
        listEquals(suggestedPalette, other.suggestedPalette) &&
        listEquals(referenceImage, other.referenceImage) &&
        listEquals(originalReferenceImage, other.originalReferenceImage) &&
        listEquals(aiHistory, other.aiHistory) &&
        listEquals(decomposedComponents, other.decomposedComponents) &&
        _nestedComponentListEquals(
          pendingDecompositionOptions,
          other.pendingDecompositionOptions,
        );
  }

  @override
  int get hashCode => Object.hash(
    Object.hash(
      creationId,
      title,
      gridSize,
      _hashGrid(grid),
      selectedColorIndex,
      selectedTool,
      paletteName,
      Object.hashAll(palette),
      referenceImage != null ? Object.hashAll(referenceImage!) : null,
      originalReferenceImage != null
          ? Object.hashAll(originalReferenceImage!)
          : null,
      userPrompt,
      aiStatus,
      isGenerating,
      autoRun,
      autoRunSpeed,
      _hashStack(undoStack),
      _hashStack(redoStack),
      Object.hashAll(aiHistory),
      suggestedPalette != null ? Object.hashAll(suggestedPalette!) : null,
      isSuggestingPalette,
    ),
    Object.hash(
      isSuggestingDescription,
      isPausing,
      showPaletteSuggestion,
      nextFocus,
      modelReleaseStage,
      modelPreference,
      _hashNestedComponents(pendingDecompositionOptions),
      Object.hashAll(decomposedComponents),
      activeComponentIndex,
      decomposingComponentIndex,
      sculptingStatus,
    ),
  );
}

bool _gridEquals(List<List<int>>? a, List<List<int>>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (!listEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _stackEquals(List<List<List<int>>>? a, List<List<List<int>>>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (!_gridEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _nestedComponentListEquals(
  List<List<PixelArtComponent>>? a,
  List<List<PixelArtComponent>>? b,
) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (!listEquals(a[i], b[i])) return false;
  }
  return true;
}

int _hashGrid(List<List<int>> grid) => Object.hashAll(grid.map(Object.hashAll));

int _hashStack(List<List<List<int>>> stack) =>
    Object.hashAll(stack.map(_hashGrid));

int _hashNestedComponents(List<List<PixelArtComponent>> list) =>
    Object.hashAll(list.map(Object.hashAll));
