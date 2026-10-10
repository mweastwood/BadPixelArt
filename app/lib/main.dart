import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'screens/pixel_art_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import 'logic/utils/settings_provider.dart';
import 'logic/canvas_state.dart';
import 'logic/utils/database.dart';
import 'logic/initial_canvas_state.dart';
import 'logic/utils/logging_ai_service.dart';
import 'logic/wizard_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await mainCommon();
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
          final aiService = ref.read(loggingAiServiceProvider);
          final wizardNotifier = ref.read(wizardStateProvider.notifier);
          final notifier = CanvasNotifier(
            aiService,
            initialModel: initialModel,
            wizardNotifier: wizardNotifier,
          );
          ref.listen<AiService>(loggingAiServiceProvider, (_, newService) {
            notifier.updateAiService(newService);
          });
          return notifier;
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
          title: 'Bad Pixel Art',
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
