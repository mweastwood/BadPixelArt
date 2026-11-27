# `pixel_art_core`

Zero-dependency pure-Dart pixel art raster engine, Bayer-dithered layer compositor, palette registry, and PNG/SVG/preview exporter extracted from BadPixelArt.

## CLI Usage

```bash
cd packages/pixel_art_core

# Render a scene JSON to PNG, SVG, and an upscaled debug preview with rulers
dart run bin/pixel_art.dart render examples/health_potion.json \
  --out /tmp/potion.png \
  --svg /tmp/potion.svg \
  --preview /tmp/potion_preview.png \
  --scale 16 \
  --cell-size 24

# Inspect pixel counts, palette usage, and ASCII grid
dart run bin/pixel_art.dart inspect examples/health_potion.json

# List built-in palettes and drawing tools
dart run bin/pixel_art.dart palettes
dart run bin/pixel_art.dart tools
```

### Compile to Native Binary

```bash
dart compile exe bin/pixel_art.dart -o build/pixel_art
```

## Declarative Scene JSON Schema

```json
{
  "title": "My Icon",
  "gridSize": 16,
  "palette": {
    "ink": "#1e1629",
    "base": "#d9264b",
    "hi": "#ff6670"
  },
  "layers": [
    {
      "name": "body",
      "shapes": [{ "tool": "circle_filled", "params": [7.5, 8.5, 5] }],
      "fill": "hi",
      "fill2": "base",
      "gradientAngle": 135,
      "dither": true
    },
    {
      "name": "detail_rows",
      "rows": ["..h.", ".h.."],
      "offsetX": 4,
      "offsetY": 5,
      "legend": { "h": "hi" }
    },
    {
      "name": "tweaks",
      "ops": [{ "tool": "pixel", "params": [7, 7], "color": "hi" }]
    }
  ],
  "postOps": [
    { "tool": "auto_outline", "params": [4], "color": "ink" }
  ]
}
```

## Tests

```bash
dart analyze
dart run test/pixel_art_core_test.dart
```
