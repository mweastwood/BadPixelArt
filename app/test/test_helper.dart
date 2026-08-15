import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart' as gt;
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/logic/utils/settings_provider.dart';

class TestMockAiService extends AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    if (prompt.contains('pixel art describer')) {
      return 'Mock description of the canvas';
    }
    if (prompt.contains('palette') || prompt.contains('colors')) {
      return '["#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff"]';
    }
    return null;
  }

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

class FakeSharedPreferences implements SharedPreferences {
  final Map<String, dynamic> _values = {};

  @override
  Set<String> getKeys() => _values.keys.toSet();

  @override
  Object? get(String key) => _values[key];

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  double? getDouble(String key) => _values[key] as double?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  List<String>? getStringList(String key) => _values[key] as List<String>?;

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Future<bool> setBool(String key, bool value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _values.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}
}

/// Wraps the widget under test in ProviderScope and MaterialApp.
Widget buildTestableWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      aiServiceProvider.overrideWithValue(TestMockAiService()),
      sharedPreferencesProvider.overrideWithValue(FakeSharedPreferences()),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: child,
    ),
  );
}

/// A wrapper for golden tests that includes ProviderScope wrapper.
gt.WidgetWrapper testMaterialAppWrapper({
  TargetPlatform platform = TargetPlatform.android,
  List<Override> overrides = const [],
}) {
  return (Widget child) {
    return ProviderScope(
      overrides: [
        aiServiceProvider.overrideWithValue(TestMockAiService()),
        sharedPreferencesProvider.overrideWithValue(FakeSharedPreferences()),
        ...overrides,
      ],
      child: gt.materialAppWrapper(platform: platform, theme: ThemeData.dark())(
        child,
      ),
    );
  };
}

/// Reusable JSON fixtures for testing AI agents and mock responses.
abstract final class TestJsonFixtures {
  /// Mock ColorSelectionAgent JSON response with blade gradient and hilt line.
  static const String colorSelectionResponse = '''
{
  "reasoning": "Selected blue to red gradient for solid blade, and single dark color for thin line hilt.",
  "componentColors": [
    {
      "name": "blade",
      "fillColorHex": "#0000FF",
      "fillColor2Hex": "#FF0000",
      "gradientAngle": 45.0,
      "outlineColorHex": "#000000"
    },
    {
      "name": "hilt_line",
      "fillColorHex": "#FF0000",
      "fillColor2Hex": "#0000FF",
      "gradientAngle": 90.0,
      "outlineColorHex": "#000000"
    }
  ]
}
''';

  /// Mock flat DecomposerAgent JSON response with blade and hilt bounding boxes.
  static const String decomposerFlatResponse = '''
[
  {
    "name": "blade",
    "description": "sharp blue blade",
    "relativeBoundingBox": { "left": 0.45, "top": 0.1, "width": 0.1, "height": 0.6 }
  },
  {
    "name": "hilt",
    "description": "wooden hilt",
    "relativeBoundingBox": { "left": 0.4375, "top": 0.7, "width": 0.125, "height": 0.2 }
  }
]
''';

  /// Mock DecomposerAgent JSON response with nested shape primitives.
  static const String decomposerShapesResponse = '''
[
  {
    "name": "blade",
    "description": "sharp blue blade",
    "relativeBoundingBox": { "left": 0.45, "top": 0.1, "width": 0.1, "height": 0.6 },
    "shapes": [
      {
        "type": "rectangle",
        "description": "blue blade body",
        "relativeBoundingBox": { "left": 0.0, "top": 0.0, "width": 1.0, "height": 0.8 }
      },
      {
        "type": "triangle",
        "description": "sharp tip",
        "relativeBoundingBox": { "left": 0.0, "top": 0.8, "width": 1.0, "height": 0.2 }
      }
    ]
  }
]
''';

  /// Mock DecomposerAgent JSON response with a single off-center bounding box.
  static const String decomposerOffCenterResponse = '''
[
  {
    "name": "offCenterBox",
    "description": "off-center box",
    "relativeBoundingBox": { "left": 0.1, "top": 0.1, "width": 0.1, "height": 0.1 }
  }
]
''';

  /// Mock DecomposerAgent JSON response with multiple bounding boxes.
  static const String decomposerMultiBoxResponse = '''
[
  {
    "name": "large",
    "description": "large box",
    "relativeBoundingBox": { "left": 0.1, "top": 0.1, "width": 0.2, "height": 0.2 }
  },
  {
    "name": "small",
    "description": "small box",
    "relativeBoundingBox": { "left": 0.5, "top": 0.5, "width": 0.1, "height": 0.1 }
  }
]
''';
}
