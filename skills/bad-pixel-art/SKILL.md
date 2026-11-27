---
name: bad-pixel-art
description: Design, render, visually inspect, and refine crisp pixel art icons and sprites (PNG & SVG) using the bundled zero-dependency pure-Dart BadPixelArt engine.
---

# BadPixelArt Icon Studio

Use this skill whenever the user wants to create, iterate on, or export pixel art icons or sprites (16×16, 24×24, 32×32, etc.).

## Locating the Pure-Dart Engine

1. If `packages/pixel_art_core/bin/pixel_art.dart` exists in the current workspace, run it directly with:
   ```bash
   dart run packages/pixel_art_core/bin/pixel_art.dart <command> ...
   ```
2. Otherwise (in any workspace without the BadPixelArt repo), fetch the bundled zero-dependency standalone script via `get_skill_resources`:
   - Skill name: `bad-pixel-art`
   - Filenames: `["scripts/pixel_art.dart"]`
   - Save it to `<artifact-dir>/scratch/pixel_art.dart` and run it directly with `dart run <artifact-dir>/scratch/pixel_art.dart <command> ...` (no `pubspec.yaml` or `dart pub get` required).

## Workflow (Always Visually Inspect & Iterate!)

### Step 1: Plan Resolution, Silhouette & Hue-Shifted Palette
- Pick a grid size (`16` for classic tiny UI/RPG icons, `24` or `32` for ornate/detailed icons).
- Design a **named palette** of 8–16 cohesive, hue-shifted colors:
  - Avoid pure `#000000`; use a deep tinted ink (e.g., `#1a1226` plum-ink or `#181d2c` navy-ink) for outlines.
  - Shift shadows cooler/darker (toward purple/blue) and highlights warmer/brighter (toward peach/yellow/white).
  - Reserve distinct value ramps per material (e.g., glass, liquid, metal, wood, glow).

### Step 2: Build the Base Silhouette & Proportions
- Author a declarative JSON scene combining the 3 layer modes:
  - **Mask + Gradient Layers** (`shapes`, `fill`, `fill2`, `gradientAngle`, `dither`, optional `mirrorH`): ideal for base volumes and shaded forms.
  - **ASCII Row Layers** (`rows`, `legend`, `offsetX`, `offsetY`): ideal for pixel-precise features (stoppers, gems, runes, specular highlights, faces).
  - **Multi-Color Command Layers** (`ops`): ideal for targeted primitives (`circle_filled`, `ellipse_filled`, `polygon`, `line`, `pixels`, `mirror_h`, `replace_color`).
- Add a clean 4-connected outer silhouette in `postOps`:
  ```json
  { "tool": "auto_outline", "params": [4], "color": "ink" }
  ```
- Render both the clean PNG and the debug preview PNG:
  ```bash
  dart run <engine> render scene.json \
    --out out.png --svg out.svg --preview preview.png \
    --scale 16 --cell-size 20
  ```

### Step 3: Visually Inspect & Critique (`view_file`)
- Open BOTH `preview.png` (which includes `0..N-1` coordinate rulers, gridlines, checkerboard transparency, and palette swatches) and `out.png` via `view_file`.
- Check specifically:
  - **Silhouette readability & symmetry:** Does the shape read instantly? Any unintended 1px bumps or lopsided edges?
  - **Material & lighting clarity:** Is light direction consistent (usually top-left)? Do glass, metal, and liquid read as distinct materials?
  - **Clustered shading:** Prefer crisp clustered cel-shading and intentional specular highlights over noisy dithering on small grids.

### Step 4: Detail, Polish & Re-Verify
- Refine exact `(x, y)` coordinates read off the preview rulers (add inner rim shadows, glows, magical sparkles, selective outline softening if helpful).
- Re-render and visually inspect again until spotless.

### Step 5: Present Inline in Chat (Self-Contained HTML Viewer)
- Because VM file links aren't viewable when a cloud conversation is paused, export the resolved grids (`--json-grid`) and present the final sprite (and optional step-by-step progression) in a compact self-contained `.html` artifact embedded inline with `<agent-embed>` (following the `generative_ui` skill), including Clean / Grid & Rulers toggle and client-side PNG/SVG download buttons.

## CLI Reference

- `render <scene.json> --out <icon.png> [--svg <icon.svg>] [--preview <preview.png>] [--scale 16] [--cell-size 20] [--bg <#RRGGBB>] [--ascii]`
- `inspect <scene.json>` — prints dimensions, fill %, per-color pixel usage, and ASCII grid
- `palettes` — lists built-in retro palettes (`sweetie16`, `pico8`, `nes`, `gameboy`, `grayscale`, `primary`)
- `tools` — lists all 23 drawing & transform commands
