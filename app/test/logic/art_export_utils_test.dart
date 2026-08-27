import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:bad_pixel_art/logic/utils/art_export_utils.dart';

class FakeFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  final String? saveFilePath;
  final bool shouldThrow;
  String? lastDialogTitle;
  String? lastFileName;
  List<String>? lastAllowedExtensions;
  FileType? lastType;

  FakeFilePickerPlatform({this.saveFilePath, this.shouldThrow = false});

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    lastDialogTitle = dialogTitle;
    lastFileName = fileName;
    lastAllowedExtensions = allowedExtensions;
    lastType = type;
    if (shouldThrow) {
      throw Exception('FilePicker saveFile error');
    }
    return saveFilePath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('art_export_utils tests', () {
    test('ExportFormat enum values are defined', () {
      expect(ExportFormat.values, contains(ExportFormat.png));
      expect(ExportFormat.values, contains(ExportFormat.svg));
    });

    test('sanitizeFileName removes invalid characters and whitespace', () {
      expect(sanitizeFileName('My Cool Pixel Art!'), 'My_Cool_Pixel_Art!');
      expect(
        sanitizeFileName(
          'Art / Slash \\ Backslash : Colons * Star ? Query " Quote < Less > Greater | Pipe',
        ),
        'Art_Slash_Backslash_Colons_Star_Query_Quote_Less_Greater_Pipe',
      );
      expect(sanitizeFileName('   '), startsWith('pixel_art_'));
      expect(sanitizeFileName('___'), startsWith('pixel_art_'));
      expect(sanitizeFileName('spaceship'), 'spaceship');
    });

    test('colorToHex formats color as uppercase 6-char hex', () {
      expect(colorToHex(const Color(0xFFFF0000)), '#ff0000');
      expect(colorToHex(const Color(0xFF00FF00)), '#00ff00');
      expect(colorToHex(const Color(0xFF0000FF)), '#0000ff');
      expect(colorToHex(const Color(0xFFFFFFFF)), '#ffffff');
      expect(colorToHex(const Color(0xFF1E1E1E)), '#1e1e1e');
    });

    test(
      'generatePngBytes returns empty bytes for empty grid or scale <= 0',
      () async {
        final bytes1 = await generatePngBytes([], [Colors.red]);
        expect(bytes1, isEmpty);

        final bytes2 = await generatePngBytes(
          [
            [1],
          ],
          [Colors.red],
          scale: 0,
        );
        expect(bytes2, isEmpty);
      },
    );

    test('generatePngBytes produces valid PNG with header bytes', () async {
      final grid = [
        [1, 0],
        [0, 2],
      ];
      final palette = [const Color(0xFFFF0000), const Color(0xFF0000FF)];

      final pngBytes = await generatePngBytes(
        grid,
        palette,
        scale: 4,
        transparentBackground: true,
      );
      expect(pngBytes, isNotEmpty);
      // Check PNG magic bytes: 137 80 78 71 13 10 26 10
      expect(
        pngBytes.sublist(0, 8),
        equals(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
      );
    });

    test('generatePngBytes works with solid background', () async {
      final grid = [
        [0, 1],
        [1, 0],
      ];
      final palette = [const Color(0xFFFF0000)];

      final pngBytes = await generatePngBytes(
        grid,
        palette,
        scale: 1,
        transparentBackground: false,
        backgroundColor: const Color(0xFF000000),
      );
      expect(pngBytes, isNotEmpty);
      expect(
        pngBytes.sublist(0, 8),
        equals(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
      );
    });

    test('generateSvgString returns fallback for empty grid or scale <= 0', () {
      final svg1 = generateSvgString([], [Colors.red]);
      expect(svg1, contains('<svg'));
      expect(svg1, contains('viewBox="0 0 1 1"'));

      final svg2 = generateSvgString(
        [
          [1],
        ],
        [Colors.red],
        scale: -1,
      );
      expect(svg2, contains('viewBox="0 0 1 1"'));
    });

    test(
      'generateSvgString generates valid SVG with dimensions and optimized horizontal runs',
      () {
        final grid = [
          [1, 1, 1, 0],
          [0, 2, 2, 1],
        ];
        final palette = [const Color(0xFFFF0000), const Color(0xFF00FF00)];

        final svg = generateSvgString(
          grid,
          palette,
          scale: 8,
          transparentBackground: true,
        );

        expect(
          svg,
          contains(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4 2" width="32" height="16" shape-rendering="crispEdges">',
          ),
        );
        // Run length of 3 red pixels on row 0
        expect(
          svg,
          contains('<rect x="0" y="0" width="3" height="1" fill="#ff0000" />'),
        );
        // Run length of 2 green pixels on row 1
        expect(
          svg,
          contains('<rect x="1" y="1" width="2" height="1" fill="#00ff00" />'),
        );
        // Single red pixel at x=3, y=1
        expect(
          svg,
          contains('<rect x="3" y="1" width="1" height="1" fill="#ff0000" />'),
        );
        // Should NOT contain background rect because transparentBackground is true
        expect(svg, isNot(contains('<rect width="100%" height="100%"')));
        expect(svg.trim(), endsWith('</svg>'));
      },
    );

    test(
      'generateSvgString includes background rect when transparentBackground is false',
      () {
        final grid = [
          [1, 0],
          [0, 1],
        ];
        final palette = [const Color(0xFFFF0000)];

        final svg = generateSvgString(
          grid,
          palette,
          scale: 4,
          transparentBackground: false,
          backgroundColor: const Color(0xFF1E1E1E),
        );

        expect(
          svg,
          contains('<rect width="100%" height="100%" fill="#1e1e1e" />'),
        );
        expect(
          svg,
          contains('<rect x="0" y="0" width="1" height="1" fill="#ff0000" />'),
        );
        expect(
          svg,
          contains('<rect x="1" y="1" width="1" height="1" fill="#ff0000" />'),
        );
      },
    );

    test(
      'generateSvgString skips zero-opacity pixels and preserves precision for small alpha',
      () {
        final grid = [
          [1, 2],
        ];
        final palette = [
          const Color(0x00FF0000), // aInt == 0 (zero opacity)
          const Color(0x0100FF00), // aInt == 1 (small non-zero alpha, ~0.0039)
        ];

        final svg = generateSvgString(grid, palette, scale: 1);

        // Color 1 (zero opacity) should NOT produce a rect element
        expect(svg, isNot(contains('fill-opacity="0"')));
        expect(svg, isNot(contains('fill-opacity="0.00"')));
        expect(svg, isNot(contains('<rect x="0"')));

        // Color 2 (small non-zero alpha) should produce a rect element with non-zero fill-opacity
        expect(svg, contains('fill-opacity="0.0039"'));
        expect(
          svg,
          contains('<rect x="1" y="0" width="1" height="1" fill="#00ff00"'),
        );
      },
    );

    test(
      'sanitizeFileName handles extensions, path traversals, and max length capping',
      () {
        expect(sanitizeFileName('my_art.png'), 'my_art');
        expect(sanitizeFileName('my_art.svg'), 'my_art');
        expect(sanitizeFileName('my_art.PNG'), 'my_art');
        expect(sanitizeFileName('my_art.Svg'), 'my_art');
        expect(sanitizeFileName('my_art.png.png'), 'my_art');
        expect(sanitizeFileName('my_art.svg.png'), 'my_art');
        expect(sanitizeFileName('../secret/my_art.png'), 'secret_my_art');
        expect(sanitizeFileName('..'), startsWith('pixel_art_'));

        final longTitle = 'a' * 300;
        final sanitizedLong = sanitizeFileName(longTitle);
        expect(sanitizedLong.length, 200);
      },
    );

    test(
      'generatePngBytes and generateSvgString safely handle non-uniform ragged grids',
      () async {
        final raggedGrid = [
          [1, 2, 1],
          [1],
          [2, 1],
        ];
        final palette = [const Color(0xFFFF0000), const Color(0xFF00FF00)];

        final pngBytes = await generatePngBytes(raggedGrid, palette, scale: 2);
        expect(pngBytes, isNotEmpty);

        final svgString = generateSvgString(raggedGrid, palette, scale: 2);
        expect(svgString, contains('<svg'));
        expect(
          svgString,
          contains('<rect x="0" y="0" width="1" height="1" fill="#ff0000" />'),
        );
      },
    );
  });

  group('saveExportedArtFile tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('art_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('returns false and presents SnackBar when bytes are empty', (
      tester,
    ) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildContext = context;
                return const Text('Ready');
              },
            ),
          ),
        ),
      );

      bool? result;
      await tester.runAsync(() async {
        result = await saveExportedArtFile(
          context: buildContext,
          bytes: Uint8List(0),
          fileName: 'empty.png',
          mimeType: 'image/png',
          extension: 'png',
        );
      });
      await tester.pump();

      expect(result, isFalse);
      expect(find.text('Cannot export empty canvas'), findsOneWidget);
    });

    testWidgets('returns false when user cancels FilePicker saveFile dialog', (
      tester,
    ) async {
      final fakePicker = FakeFilePickerPlatform(saveFilePath: null);
      FilePickerPlatform.instance = fakePicker;

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildContext = context;
                return const Text('Ready');
              },
            ),
          ),
        ),
      );

      bool? result;
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
      await tester.runAsync(() async {
        result = await saveExportedArtFile(
          context: buildContext,
          bytes: sampleBytes,
          fileName: 'artwork.png',
          mimeType: 'image/png',
          extension: 'png',
        );
      });
      await tester.pump();

      expect(result, isFalse);
      expect(fakePicker.lastFileName, 'artwork.png');
      expect(fakePicker.lastAllowedExtensions, ['png']);
      expect(fakePicker.lastType, FileType.custom);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'writes bytes to file and displays success SnackBar with working Copy Path action',
      (tester) async {
        final targetPath = p.join(tempDir.path, 'exported_art.png');
        final fakePicker = FakeFilePickerPlatform(saveFilePath: targetPath);
        FilePickerPlatform.instance = fakePicker;

        String? clipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              clipboardText = (methodCall.arguments as Map)['text'] as String?;
              return null;
            }
            return null;
          },
        );

        late BuildContext buildContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildContext = context;
                  return const Text('Ready');
                },
              ),
            ),
          ),
        );

        final sampleBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01]);
        bool? result;
        await tester.runAsync(() async {
          result = await saveExportedArtFile(
            context: buildContext,
            bytes: sampleBytes,
            fileName: 'exported_art.png',
            mimeType: 'image/png',
            extension: 'png',
          );
        });
        await tester.pump();

        expect(result, isTrue);
        expect(File(targetPath).existsSync(), isTrue);
        expect(File(targetPath).readAsBytesSync(), equals(sampleBytes));
        expect(
          find.text('Exported successfully to: exported_art.png'),
          findsOneWidget,
        );

        // Tap Copy Path action button
        expect(find.byType(SnackBarAction), findsOneWidget);
        final action = tester.widget<SnackBarAction>(
          find.byType(SnackBarAction),
        );
        action.onPressed();
        await tester.pump();

        expect(clipboardText, equals(targetPath));
      },
    );

    testWidgets('catches file picker error and displays error SnackBar', (
      tester,
    ) async {
      FilePickerPlatform.instance = FakeFilePickerPlatform(shouldThrow: true);

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildContext = context;
                return const Text('Ready');
              },
            ),
          ),
        ),
      );

      bool? result;
      await tester.runAsync(() async {
        result = await saveExportedArtFile(
          context: buildContext,
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'error_test.png',
          mimeType: 'image/png',
          extension: 'png',
        );
      });
      await tester.pump();

      expect(result, isFalse);
      expect(find.textContaining('Error exporting pixel art:'), findsOneWidget);
    });

    testWidgets(
      'catches filesystem I/O write error and displays error SnackBar',
      (tester) async {
        // Pointing saveFilePath to an existing directory instead of a file causes File.writeAsBytes to throw FileSystemException
        FilePickerPlatform.instance = FakeFilePickerPlatform(
          saveFilePath: tempDir.path,
        );

        late BuildContext buildContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildContext = context;
                  return const Text('Ready');
                },
              ),
            ),
          ),
        );

        bool? result;
        await tester.runAsync(() async {
          result = await saveExportedArtFile(
            context: buildContext,
            bytes: Uint8List.fromList([1, 2, 3]),
            fileName: 'io_error.png',
            mimeType: 'image/png',
            extension: 'png',
          );
        });
        await tester.pump();

        expect(result, isFalse);
        expect(
          find.textContaining('Error exporting pixel art:'),
          findsOneWidget,
        );
      },
    );
  });

  group('exportArtworkAsPng & exportArtworkAsSvg tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('artwork_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'exportArtworkAsPng sanitizes title, generates valid PNG bytes, and forwards to saveExportedArtFile',
      (tester) async {
        final targetFile = p.join(tempDir.path, 'My_Pixel_Sprite.png');
        final fakePicker = FakeFilePickerPlatform(saveFilePath: targetFile);
        FilePickerPlatform.instance = fakePicker;

        late BuildContext buildContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildContext = context;
                  return const Text('Ready');
                },
              ),
            ),
          ),
        );

        final grid = [
          [1, 0],
          [0, 1],
        ];
        final palette = [const Color(0xFFFF0000)];

        bool? result;
        await tester.runAsync(() async {
          result = await exportArtworkAsPng(
            buildContext,
            grid: grid,
            palette: palette,
            title: 'My Pixel Sprite.png',
            scale: 4,
          );
        });
        await tester.pump();

        expect(result, isTrue);
        expect(fakePicker.lastFileName, 'My_Pixel_Sprite.png');
        expect(fakePicker.lastAllowedExtensions, ['png']);
        expect(File(targetFile).existsSync(), isTrue);

        final writtenBytes = File(targetFile).readAsBytesSync();
        expect(
          writtenBytes.sublist(0, 8),
          equals(
            Uint8List.fromList([
              0x89,
              0x50,
              0x4E,
              0x47,
              0x0D,
              0x0A,
              0x1A,
              0x0A,
            ]),
          ),
        );
      },
    );

    testWidgets(
      'exportArtworkAsSvg sanitizes title, generates UTF-8 SVG string bytes, and forwards to saveExportedArtFile',
      (tester) async {
        final targetFile = p.join(tempDir.path, 'Vector_Art.svg');
        final fakePicker = FakeFilePickerPlatform(saveFilePath: targetFile);
        FilePickerPlatform.instance = fakePicker;

        late BuildContext buildContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildContext = context;
                  return const Text('Ready');
                },
              ),
            ),
          ),
        );

        final grid = [
          [1, 2],
        ];
        final palette = [const Color(0xFFFF0000), const Color(0xFF00FF00)];

        bool? result;
        await tester.runAsync(() async {
          result = await exportArtworkAsSvg(
            buildContext,
            grid: grid,
            palette: palette,
            title: 'Vector/Art*.svg',
            scale: 8,
          );
        });
        await tester.pump();

        expect(result, isTrue);
        expect(fakePicker.lastFileName, 'Vector_Art.svg');
        expect(fakePicker.lastAllowedExtensions, ['svg']);
        expect(File(targetFile).existsSync(), isTrue);

        final writtenSvg = File(targetFile).readAsStringSync();
        expect(writtenSvg, contains('<svg'));
        expect(writtenSvg, contains('viewBox="0 0 2 1"'));
        expect(writtenSvg, contains('width="16" height="8"'));
        expect(writtenSvg, contains('fill="#ff0000"'));
        expect(writtenSvg, contains('fill="#00ff00"'));
      },
    );
  });
}
