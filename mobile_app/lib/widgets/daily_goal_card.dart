import 'package:flutter/material.dart';

class DailyGoalCard extends StatelessWidget {
  final int completedMinutes;
  final int goalMinutes;

  const DailyGoalCard({
    super.key,
    required this.completedMinutes,
    required this.goalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goalMinutes == 0
        ? 0.0
        : (completedMinutes / goalMinutes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.calendar_month,
              size: 22,
              color: Color(0xFFFF7AAE),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Günlük hedefini tamamla",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$completedMinutes / $goalMinutes dk",
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }
}