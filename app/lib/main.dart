import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/pixel_art_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'logic/utils/settings_provider.dart';
import 'logic/canvas_state.dart';
import 'logic/utils/database.dart';
import 'logic/utils/database_helpers.dart';
import 'logic/utils/logging_ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await mainCommon();
}

Future<CanvasModel> loadInitialCanvasState(AppDatabase db) async {
  try {
    final session = await db.getSession();
    if (session != null && session.activeCreationId != null) {
      final creation = await db.getCreationById(session.activeCreationId!);
      if (creation != null) {
        final grid = deserializeGrid(creation.gridData);
        final palette = deserializePalette(creation.paletteColors);
        final components = deserializeComponents(creation.decomposedComponents);
        final history = deserializeHistory(creation.aiHistoryLogs);
        final tool = CanvasTool.values.firstWhere(
          (t) => t.name == session.selectedTool,
          orElse: () => CanvasTool.line,
        );

        return CanvasModel(
          creationId: creation.id,
          title: creation.title,
          gridSize: creation.gridSize,
          grid: grid,
          paletteName: creation.paletteName,
          palette: palette,
          decomposedComponents: components,
          aiHistory: history,
          referenceImage: creation.referenceImage,
          originalReferenceImage: creation.originalReferenceImage,
          selectedColorIndex: session.selectedColorIndex,
          selectedTool: tool,
          userPrompt: session.userPrompt,
          undoStack: const [],
          redoStack: const [],
          aiStatus: AiCoreStatus.available,
          isGenerating: false,
          autoRun: false,
          autoRunSpeed: 1.5,
        );
      }
    }
  } catch (e) {
    debugPrint('Error loading initial canvas state: $e');
  }
  return CanvasModel(
    gridSize: 16,
    grid: List.generate(16, (_) => List.filled(16, 0)),
    selectedColorIndex: 1,
    selectedTool: CanvasTool.line,
    paletteName: 'primary',
    palette: CanvasNotifier.primaryPalette,
    userPrompt: '',
    aiStatus: AiCoreStatus.available,
    isGenerating: false,
    autoRun: false,
    autoRunSpeed: 1.5,
    undoStack: const [],
    redoStack: const [],
    aiHistory: const [],
  );
}

Future<void> mainCommon() async {
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabaseHelper.db;
  final initialModel = await loadInitialCanvasState(db);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        aiServiceProvider.overrideWith(
          (ref) => ref.watch(appAiServiceProvider),
        ),
        canvasStateProvider.overrideWith((ref) {
          final aiService = ref.watch(loggingAiServiceProvider);
          return CanvasNotifier(aiService, initialModel: initialModel);
        }),
      ],
      child: const MyApp(),
    ),
  );
}

enum AppEnvironment { dev, prod }

class AppConfig {
  static AppEnvironment environment = AppEnvironment.dev;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic;
          darkScheme = darkDynamic;
        } else {
          lightScheme = ColorScheme.fromSeed(
            seedColor: Colors.blueAccent,
            brightness: Brightness.light,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: Colors.blueAccent,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'BadPixelArt',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: const PixelArtScreen(),
        );
      },
    );
  }
}
