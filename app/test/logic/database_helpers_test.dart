import 'dart:convert';

import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';
import 'package:bad_pixel_art/logic/utils/database_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Grid Serialization & Recovery (serializeGrid / deserializeGrid)', () {
    test('roundtrips 2D integer matrix faithfully', () {
      final grid = [
        [1, 0, 1],
        [0, 2, 0],
      ];
      final jsonStr = serializeGrid(grid);
      expect(jsonDecode(jsonStr), isA<List<dynamic>>());
      expect(deserializeGrid(jsonStr), equals(grid));
    });

    test('handles empty grid roundtrip', () {
      final jsonStr = serializeGrid([]);
      expect(deserializeGrid(jsonStr), isEmpty);
    });

    test('handles empty string and corrupted JSON gracefully', () {
      expect(deserializeGrid(''), isEmpty);
      expect(deserializeGrid('invalid json'), isEmpty);
      expect(deserializeGrid('{"not": "a list"}'), isEmpty);
    });

    test(
      'recovers gracefully when array contains 1D primitive integers instead of 2D rows',
      () {
        expect(deserializeGrid('[1, 2, 3]'), isEmpty);
      },
    );
  });

  group(
    'Palette Serialization & ARGB Fidelity (serializePalette / deserializePalette)',
    () {
      test(
        'generates valid JSON array of 8-character hex strings prefixed with #',
        () {
          final colors = [
            const Color(0xFFFF0000), // opaque red -> #ffff0000
            const Color(0x80FF0000), // semi-transparent red -> #80ff0000
            const Color(0x00000000), // transparent black -> #00000000
          ];
          final jsonStr = serializePalette(colors);
          final decoded = jsonDecode(jsonStr);
          expect(decoded, isA<List<dynamic>>());
          expect(decoded, ['#ffff0000', '#80ff0000', '#00000000']);
        },
      );

      test(
        'exact ARGB roundtrip preserves alpha channel and 32-bit color values',
        () {
          final colors = [
            const Color(0xFF112233),
            const Color(0x80FF0000),
            const Color(0x00AABBCC),
            const Color(0x33445566),
          ];
          final roundtripped = deserializePalette(serializePalette(colors));
          expect(roundtripped.length, colors.length);
          for (int i = 0; i < colors.length; i++) {
            expect(roundtripped[i].toARGB32(), equals(colors[i].toARGB32()));
          }
        },
      );

      test('handles empty list roundtrip', () {
        expect(deserializePalette(serializePalette([])), isEmpty);
      });

      test('handles empty string and corrupted JSON gracefully', () {
        expect(deserializePalette(''), isEmpty);
        expect(deserializePalette('invalid json'), isEmpty);
        expect(deserializePalette('{"not": "a list"}'), isEmpty);
      });

      test(
        'recovers gracefully when palette contains invalid hex strings or null elements',
        () {
          expect(deserializePalette(jsonEncode(['#xyz123'])), isEmpty);
          expect(deserializePalette(jsonEncode([null])), isEmpty);
        },
      );
    },
  );

  group(
    'Component Serialization & Roundtrip (serializeComponents / deserializeComponents)',
    () {
      test(
        'full component fidelity roundtrip preserves all populated fields and operator ==',
        () {
          final originalComponents = [
            PixelArtComponent(
              name: 'body',
              description: 'character torso',
              relativeBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
              grid: [
                [1, 0],
                [0, 1],
              ],
              shapes: [
                FundamentalShape(
                  type: 'rectangle',
                  relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
                  description: 'base box',
                ),
              ],
              fillColor: const Color(0xFFFF5722),
              fillColor2: const Color(0xFF4CAF50),
              gradientAngle: 45.0,
              outlineColor: const Color(0xFF212121),
              isSculpted: true,
            ),
            PixelArtComponent(
              name: 'head',
              description: 'character head',
              relativeBoundingBox: const Rect.fromLTWH(0.3, 0.0, 0.4, 0.3),
              grid: [
                [1, 1, 1],
                [1, 0, 1],
                [1, 1, 1],
              ],
              shapes: [
                FundamentalShape(
                  type: 'circle',
                  relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
                  description: 'head circle',
                ),
              ],
              fillColor: const Color(0xFF2196F3),
              fillColor2: const Color(0xFF03A9F4),
              gradientAngle: 90.0,
              outlineColor: const Color(0xFF000000),
              isSculpted: false,
            ),
          ];

          final jsonStr = serializeComponents(originalComponents);
          final decoded = jsonDecode(jsonStr);
          expect(decoded, isA<List<dynamic>>());
          expect(decoded.length, 2);

          final deserialized = deserializeComponents(jsonStr);
          expect(deserialized.length, 2);
          for (int i = 0; i < originalComponents.length; i++) {
            expect(deserialized[i], equals(originalComponents[i]));
            expect(deserialized[i].name, equals(originalComponents[i].name));
            expect(
              deserialized[i].description,
              equals(originalComponents[i].description),
            );
            expect(
              deserialized[i].relativeBoundingBox,
              equals(originalComponents[i].relativeBoundingBox),
            );
            expect(deserialized[i].grid, equals(originalComponents[i].grid));
            expect(
              deserialized[i].shapes,
              equals(originalComponents[i].shapes),
            );
            expect(
              deserialized[i].fillColor?.toARGB32(),
              equals(originalComponents[i].fillColor?.toARGB32()),
            );
            expect(
              deserialized[i].fillColor2?.toARGB32(),
              equals(originalComponents[i].fillColor2?.toARGB32()),
            );
            expect(
              deserialized[i].gradientAngle,
              equals(originalComponents[i].gradientAngle),
            );
            expect(
              deserialized[i].outlineColor?.toARGB32(),
              equals(originalComponents[i].outlineColor?.toARGB32()),
            );
            expect(
              deserialized[i].isSculpted,
              equals(originalComponents[i].isSculpted),
            );
            expect(
              deserialized[i].hasInterior,
              equals(originalComponents[i].hasInterior),
            );
            expect(
              deserialized[i].outlineGrid,
              equals(originalComponents[i].outlineGrid),
            );
          }
        },
      );

      test(
        'roundtrip preserves minimal / nullable fields with nulls intact',
        () {
          final minimalComponent = PixelArtComponent(
            name: 'minimal',
            description: 'minimal component',
            relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
            grid: null,
            shapes: const [],
            fillColor: null,
            fillColor2: null,
            outlineColor: null,
          );

          final jsonStr = serializeComponents([minimalComponent]);
          final deserialized = deserializeComponents(jsonStr);

          expect(deserialized.length, 1);
          expect(deserialized.first, equals(minimalComponent));
          expect(deserialized.first.grid, isNull);
          expect(deserialized.first.shapes, isEmpty);
          expect(deserialized.first.fillColor, isNull);
          expect(deserialized.first.fillColor2, isNull);
          expect(deserialized.first.outlineColor, isNull);
        },
      );

      test('handles empty list roundtrip', () {
        expect(deserializeComponents(serializeComponents([])), isEmpty);
      });

      test('handles empty string and corrupted JSON gracefully', () {
        expect(deserializeComponents(''), isEmpty);
        expect(deserializeComponents('not a json array'), isEmpty);
        expect(deserializeComponents('{"key": "value"}'), isEmpty);
      });

      test('recovers gracefully when array contains non-map elements', () {
        expect(deserializeComponents(jsonEncode(['not_a_map'])), isEmpty);
      });
    },
  );

  group(
    'Agent History Serialization & Roundtrip (serializeHistory / deserializeHistory)',
    () {
      test(
        'multi-entry history roundtrip preserves all fields including tokens, errors, and image payload',
        () {
          final entries = [
            AgentHistoryEntry(
              timestamp: DateTime.parse('2026-10-02T15:30:00.000Z'),
              prompt: 'Draw a gold star',
              response: 'Drew star component',
              isError: false,
              modelName: 'Gemini 2.0 Flash',
              inputTokens: 150,
              outputTokens: 320,
              totalTokens: 470,
              estimatedCostUsd: 0.00045,
              imageBytes: Uint8List.fromList([0, 1, 2, 3, 255]),
              imageMimeType: 'image/png',
            ),
            AgentHistoryEntry(
              timestamp: DateTime.parse('2026-10-02T15:31:00.000Z'),
              prompt: 'Refine the outline',
              response: 'QuotaExceededException: 429',
              isError: true,
              modelName: 'Gemini 2.5 Flash',
              inputTokens: null,
              outputTokens: null,
              totalTokens: null,
              estimatedCostUsd: null,
              imageBytes: null,
            ),
          ];

          final jsonStr = serializeHistory(entries);
          final decoded = jsonDecode(jsonStr);
          expect(decoded, isA<List<dynamic>>());
          expect(decoded.length, 2);

          final deserialized = deserializeHistory(jsonStr);
          expect(deserialized.length, 2);

          for (int i = 0; i < entries.length; i++) {
            final original = entries[i];
            final restored = deserialized[i];

            expect(restored.prompt, equals(original.prompt));
            expect(restored.response, equals(original.response));
            expect(restored.timestamp, equals(original.timestamp));
            expect(restored.isError, equals(original.isError));
            expect(restored.modelName, equals(original.modelName));
            expect(restored.inputTokens, equals(original.inputTokens));
            expect(restored.outputTokens, equals(original.outputTokens));
            expect(restored.totalTokens, equals(original.totalTokens));
            expect(
              restored.estimatedCostUsd,
              equals(original.estimatedCostUsd),
            );
            expect(restored.imageMimeType, equals(original.imageMimeType));
            if (original.imageBytes != null) {
              expect(restored.imageBytes, isNotNull);
              expect(
                listEquals(restored.imageBytes, original.imageBytes),
                isTrue,
              );
            } else {
              expect(restored.imageBytes, isNull);
            }
          }
        },
      );

      test('handles empty list roundtrip', () {
        expect(deserializeHistory(serializeHistory([])), isEmpty);
      });

      test('handles empty string and corrupted JSON gracefully', () {
        expect(deserializeHistory(''), isEmpty);
        expect(deserializeHistory('{corrupted: json}'), isEmpty);
        expect(deserializeHistory('not json at all'), isEmpty);
        expect(deserializeHistory('{"not": "a list"}'), isEmpty);
      });

      test('recovers gracefully when array contains non-map elements', () {
        expect(deserializeHistory(jsonEncode(['not_a_map'])), isEmpty);
        expect(deserializeHistory(jsonEncode([123])), isEmpty);
      });
    },
  );
}
