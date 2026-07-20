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
