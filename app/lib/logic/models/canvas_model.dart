import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_agent/local_agent.dart';
import 'pixel_art_component.dart';

enum CanvasTool { line, circle, fill, hatch }

@immutable
class CanvasModel {
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
  final bool showPaletteSuggestion;
  final String? nextFocus;
  final String modelReleaseStage;
  final String modelPreference;
  final List<List<PixelArtComponent>> pendingDecompositionOptions;
  final List<PixelArtComponent> decomposedComponents;
  final int activeComponentIndex;
  final int? confirmingComponentIndex;
  final int? decomposingComponentIndex;

  const CanvasModel({
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
    this.showPaletteSuggestion = false,
    this.nextFocus,
    this.modelReleaseStage = 'stable',
    this.modelPreference = 'full',
    this.pendingDecompositionOptions = const [],
    this.decomposedComponents = const [],
    this.activeComponentIndex = 0,
    this.confirmingComponentIndex,
    this.decomposingComponentIndex,
  });

  CanvasModel copyWith({
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
    bool? showPaletteSuggestion,
    bool clearSuggestedPalette = false,
    String? nextFocus,
    bool clearNextFocus = false,
    String? modelReleaseStage,
    String? modelPreference,
    List<List<PixelArtComponent>>? pendingDecompositionOptions,
    List<PixelArtComponent>? decomposedComponents,
    int? activeComponentIndex,
    int? confirmingComponentIndex,
    bool clearConfirmingComponent = false,
    int? decomposingComponentIndex,
    bool clearDecomposingComponent = false,
  }) {
    return CanvasModel(
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
      showPaletteSuggestion:
          showPaletteSuggestion ?? this.showPaletteSuggestion,
      nextFocus: clearNextFocus ? null : (nextFocus ?? this.nextFocus),
      modelReleaseStage: modelReleaseStage ?? this.modelReleaseStage,
      modelPreference: modelPreference ?? this.modelPreference,
      pendingDecompositionOptions:
          pendingDecompositionOptions ?? this.pendingDecompositionOptions,
      decomposedComponents: decomposedComponents ?? this.decomposedComponents,
      activeComponentIndex: activeComponentIndex ?? this.activeComponentIndex,
      confirmingComponentIndex: clearConfirmingComponent
          ? null
          : (confirmingComponentIndex ?? this.confirmingComponentIndex),
      decomposingComponentIndex: clearDecomposingComponent
          ? null
          : (decomposingComponentIndex ?? this.decomposingComponentIndex),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CanvasModel) return false;
    return gridSize == other.gridSize &&
        selectedColorIndex == other.selectedColorIndex &&
        selectedTool == other.selectedTool &&
        paletteName == other.paletteName &&
        userPrompt == other.userPrompt &&
        aiStatus == other.aiStatus &&
        isGenerating == other.isGenerating &&
        autoRun == other.autoRun &&
        autoRunSpeed == other.autoRunSpeed &&
        isSuggestingPalette == other.isSuggestingPalette &&
        showPaletteSuggestion == other.showPaletteSuggestion &&
        activeComponentIndex == other.activeComponentIndex &&
        decomposingComponentIndex == other.decomposingComponentIndex &&
        listEquals(palette, other.palette) &&
        listEquals(suggestedPalette, other.suggestedPalette) &&
        listEquals(referenceImage, other.referenceImage) &&
        listEquals(originalReferenceImage, other.originalReferenceImage) &&
        listEquals(aiHistory, other.aiHistory) &&
        listEquals(decomposedComponents, other.decomposedComponents) &&
        listEquals(
          pendingDecompositionOptions,
          other.pendingDecompositionOptions,
        );
  }

  @override
  int get hashCode => Object.hash(
    gridSize,
    selectedColorIndex,
    selectedTool,
    paletteName,
    userPrompt,
    aiStatus,
    isGenerating,
    autoRun,
    autoRunSpeed,
    isSuggestingPalette,
    showPaletteSuggestion,
    activeComponentIndex,
    decomposingComponentIndex,
    Object.hashAll(palette),
    suggestedPalette != null ? Object.hashAll(suggestedPalette!) : null,
    referenceImage != null ? Object.hashAll(referenceImage!) : null,
    originalReferenceImage != null
        ? Object.hashAll(originalReferenceImage!)
        : null,
    Object.hashAll(aiHistory),
    Object.hashAll(decomposedComponents),
    Object.hashAll(pendingDecompositionOptions),
  );
}
