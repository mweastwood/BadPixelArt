import 'package:flutter/material.dart';

class GradientAngleSelector extends StatelessWidget {
  final double angle;
  final ValueChanged<double> onAngleChanged;

  const GradientAngleSelector({
    super.key,
    required this.angle,
    required this.onAngleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const presets = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                'Angle',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: presets.map((preset) {
                    final isSelected =
                        (angle.round() % 360) == (preset.round() % 360);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ChoiceChip(
                        label: Text('${preset.round()}°'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) onAngleChanged(preset);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 90),
            Expanded(
              child: Slider(
                value: angle,
                min: 0.0,
                max: 360.0,
                divisions: 24,
                label: '${angle.round()}°',
                onChanged: onAngleChanged,
              ),
            ),
            Text(
              '${angle.round()}°',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
