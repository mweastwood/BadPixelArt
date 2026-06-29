import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart' as gt;

/// Wraps the widget under test in ProviderScope and MaterialApp.
Widget buildTestableWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
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
      overrides: overrides,
      child: gt.materialAppWrapper(platform: platform, theme: ThemeData.dark())(
        child,
      ),
    );
  };
}
