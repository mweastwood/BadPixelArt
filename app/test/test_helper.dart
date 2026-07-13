import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart' as gt;
import 'package:local_agent/local_agent.dart';

class TestMockAiService implements AiService {
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
    return null;
  }
}

/// Wraps the widget under test in ProviderScope and MaterialApp.
Widget buildTestableWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      aiServiceProvider.overrideWithValue(TestMockAiService()),
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
        ...overrides,
      ],
      child: gt.materialAppWrapper(platform: platform, theme: ThemeData.dark())(
        child,
      ),
    );
  };
}
