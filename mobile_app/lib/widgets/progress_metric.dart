import 'package:flutter/material.dart';

class ProgressMetric extends StatelessWidget {
  final String title;
  final double value;

  const ProgressMetric({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("%${value.toStringAsFixed(1)}"),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 11,
          borderRadius: BorderRadius.circular(20),
        ),
      ],
    );
  }
}