import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/pixel_art_screen.dart';

void main() {
  mainCommon();
}

void mainCommon() {
  runApp(const ProviderScope(child: MyApp()));
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
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const PixelArtScreen(),
        );
      },
    );
  }
}
