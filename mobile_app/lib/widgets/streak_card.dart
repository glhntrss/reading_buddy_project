import 'package:flutter/material.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;

  const StreakCard({
    super.key,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (streakDays / 7).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.topRight,
            child: Icon(
            Icons.local_fire_department,
            color: Color(0xFFFF7A59),
            size: 26,
          ),
          ),
          const SizedBox(height: 22),
          Text(
            "$streakDays Günlük Serini\nTamamladın!",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFFFF7A59),
            ),
          ),
        ],
      ),
    );
  }
}