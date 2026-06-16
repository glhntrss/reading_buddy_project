import 'package:flutter/material.dart';

class LevelCard extends StatelessWidget {
  final String title;
  final String description;
  final int bestStars;
  final bool isUnlocked;
  final bool isCompleted;
  final VoidCallback? onTap;

  const LevelCard({
    super.key,
    required this.title,
    required this.description,
    required this.bestStars,
    required this.isUnlocked,
    required this.isCompleted,
    this.onTap,
  });

  String get starsText {
    if (bestStars <= 0) return "";
    return List.generate(bestStars, (_) => "⭐").join();
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isCompleted
        ? const Color(0xFFE8F8EF)
        : isUnlocked
            ? const Color(0xFFF1EFFF)
            : const Color(0xFFEDE7F0);

    final Color iconColor = isUnlocked
        ? const Color(0xFF6C63FF)
        : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: isUnlocked ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isUnlocked
              ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
                : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(
                  isCompleted
                      ? Icons.star
                      : isUnlocked
                          ? Icons.lock_open
                          : Icons.lock,
                  color: iconColor,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isCompleted
                  ? "Tamamlandı $starsText"
                  : isUnlocked
                      ? "Açık • Devam et"
                      : "Kilitli",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}