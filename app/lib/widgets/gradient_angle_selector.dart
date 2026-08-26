import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Returns a human-readable direction description for a given gradient angle (0..360 degrees).
String getGradientAngleDescription(double angle) {
  final normalized = (angle % 360 + 360) % 360;
  final index = ((normalized + 22.5) ~/ 45) % 8;
  switch (index) {
    case 0:
      return 'Left to Right (→)';
    case 1:
      return 'Top-Left to Bottom-Right (↘)';
    case 2:
      return 'Top to Bottom (↓)';
    case 3:
      return 'Top-Right to Bottom-Left (↙)';
    case 4:
      return 'Right to Left (←)';
    case 5:
      return 'Bottom-Right to Top-Left (↖)';
    case 6:
      return 'Bottom to Top (↑)';
    case 7:
      return 'Bottom-Left to Top-Right (↗)';
    default:
      return 'Left to Right (→)';
  }
}

/// Returns a short direction label (e.g. '0° (→)', '90° (↓)') for preset chips.
String getGradientShortLabel(double presetAngle) {
  final normalized = (presetAngle % 360 + 360) % 360;
  final deg = normalized.round();
  switch (deg) {
    case 0:
      return '0° (→ Left to Right)';
    case 45:
      return '45° (↘ Top-L to Bot-R)';
    case 90:
      return '90° (↓ Top to Bottom)';
    case 135:
      return '135° (↙ Top-R to Bot-L)';
    case 180:
      return '180° (← Right to Left)';
    case 225:
      return '225° (↖ Bot-R to Top-L)';
    case 270:
      return '270° (↑ Bottom to Top)';
    case 315:
      return '315° (↗ Bot-L to Top-R)';
    default:
      return '$deg°';
  }
}

/// Circular dial painter for rendering gradient angle direction.
class CircularGradientDialPainter extends CustomPainter {
  final double angle;
  final Color primaryColor;
  final Color outlineColor;
  final Color surfaceColor;

  CircularGradientDialPainter({
    required this.angle,
    required this.primaryColor,
    required this.outlineColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4.0;

    // Outer circle background
    final bgPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Outer rim border
    final rimPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, rimPaint);

    // 8 tick marks for 45-degree angle increments
    final tickPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final tickAngle = i * 45.0 * (math.pi / 180.0);
      final tickOffset = Offset(
        center.dx + (radius - 5.0) * math.cos(tickAngle),
        center.dy + (radius - 5.0) * math.sin(tickAngle),
      );
      final isCardinal = (i % 2 == 0);
      canvas.drawCircle(tickOffset, isCardinal ? 2.5 : 1.5, tickPaint);
    }

    // Direction arrow representing gradient flow (Color A -> Color B)
    final rad = angle * (math.pi / 180.0);
    final arrowLength = radius - 8.0;
    final endPoint = Offset(
      center.dx + arrowLength * math.cos(rad),
      center.dy + arrowLength * math.sin(rad),
    );
    final startPoint = Offset(
      center.dx - (arrowLength * 0.4) * math.cos(rad),
      center.dy - (arrowLength * 0.4) * math.sin(rad),
    );

    final arrowPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;
    canvas.drawLine(startPoint, endPoint, arrowPaint);

    // Arrow head
    const arrowHeadSize = 8.0;
    final headAngle = math.pi / 6;
    final path = Path()
      ..moveTo(endPoint.dx, endPoint.dy)
      ..lineTo(
        endPoint.dx - arrowHeadSize * math.cos(rad - headAngle),
        endPoint.dy - arrowHeadSize * math.sin(rad - headAngle),
      )
      ..lineTo(
        endPoint.dx - arrowHeadSize * math.cos(rad + headAngle),
        endPoint.dy - arrowHeadSize * math.sin(rad + headAngle),
      )
      ..close();

    final arrowHeadPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, arrowHeadPaint);

    // Center pivot knob
    final knobPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.5, knobPaint);
  }

  @override
  bool shouldRepaint(covariant CircularGradientDialPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}

/// Interactive circular angle dial widget for selecting gradient direction.
class CircularAngleDial extends StatelessWidget {
  final double angle;
  final ValueChanged<double> onAngleChanged;
  final double size;

  const CircularAngleDial({
    super.key,
    required this.angle,
    required this.onAngleChanged,
    this.size = 84.0,
  });

  void _handleTouch(Offset localPosition, Size widgetSize) {
    final center = Offset(widgetSize.width / 2, widgetSize.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final rad = math.atan2(dy, dx);
    double deg = rad * (180.0 / math.pi);
    if (deg < 0) deg += 360.0;

    // Snap to nearest 45-degree angle if within 7.5 degrees
    for (int i = 0; i < 8; i++) {
      final snapTarget = i * 45.0;
      final diff = (deg - snapTarget).abs();
      if (diff <= 7.5 || (360.0 - diff) <= 7.5) {
        deg = snapTarget;
        break;
      }
    }

    onAngleChanged(deg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          key: const ValueKey('circular_gradient_dial_gesture'),
          onPanDown: (details) =>
              _handleTouch(details.localPosition, Size(size, size)),
          onPanUpdate: (details) =>
              _handleTouch(details.localPosition, Size(size, size)),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: CircularGradientDialPainter(
                angle: angle,
                primaryColor: theme.colorScheme.primary,
                outlineColor: theme.colorScheme.outline,
                surfaceColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Gradient angle selector with an interactive circular dial, direction descriptions, and preset chips.
class GradientAngleSelector extends StatelessWidget {
  final double angle;
  final ValueChanged<double> onAngleChanged;

  const GradientAngleSelector({
    super.key,
    required this.angle,
    required this.onAngleChanged,
  });

  static const presets = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final directionDescription = getGradientAngleDescription(angle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Angle title & plain direction description
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Gradient Direction:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${angle.round()}° — $directionDescription',
                key: const ValueKey('gradient_angle_description_text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Main Selector Row: Circular Dial on left, preset chips on right
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Interactive Circular Dial
            CircularAngleDial(
              angle: angle,
              onAngleChanged: onAngleChanged,
              size: 84.0,
            ),
            const SizedBox(width: 14),

            // Directional Preset Chips
            Expanded(
              child: Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: presets.map((preset) {
                  final isSelected =
                      (angle.round() % 360) == (preset.round() % 360);
                  final labelText = getGradientShortLabel(preset);
                  return ChoiceChip(
                    key: ValueKey('gradient_preset_${preset.round()}'),
                    label: Text(
                      labelText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) onAngleChanged(preset);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
