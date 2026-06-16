import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/daily_goal_card.dart';
import '../widgets/home_header_card.dart';
import '../widgets/level_progress_card.dart';
import '../widgets/mascot_card.dart';
import '../widgets/streak_card.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onStartReading;
  final VoidCallback onOpenLevels;

  const HomePage({
    super.key,
    required this.onStartReading,
    required this.onOpenLevels,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? student;
  Map<String, dynamic>? firstText;
  Map<String, dynamic>? homeSummary;

  List<dynamic> progress = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    try {
      final students = await ApiService.getStudents();

      if (students.isNotEmpty) {
        final selectedStudent = students.first;
        final texts = await ApiService.getStudentTexts(selectedStudent["id"]);
        final studentProgress =
            await ApiService.getStudentProgress(selectedStudent["id"]);
        final summary = await ApiService.getHomeSummary(selectedStudent["id"]);

        setState(() {
          student = selectedStudent;
          firstText = texts.isNotEmpty ? texts.first : null;
          progress = studentProgress;
          homeSummary = summary;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  double calculateLevelProgress() {
    if (student == null || progress.isEmpty) {
      return 0.0;
    }

    final currentLevel = student!["current_level"] ?? 1;

    final matched = progress.where(
      (level) => level["level_id"] == currentLevel,
    );

    if (matched.isEmpty) {
      return 0.0;
    }

    final level = matched.first;
    final int bestStars = level["best_stars"] ?? 0;

    return (bestStars / 3).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final studentName = student?["name"] ?? "Test Öğrencisi";

    final currentLevel =
    ((homeSummary?["current_level"] ?? student?["current_level"] ?? 1) as num)
        .toInt();

    final levelProgress =
    ((homeSummary?["level_progress"] ?? calculateLevelProgress()) as num)
        .toDouble();

    final dailyGoalMinutes =
    ((homeSummary?["daily_goal_minutes"] ?? 5) as num).toInt();

    final todayCompletedMinutes =
    ((homeSummary?["today_completed_minutes"] ?? 0) as num).toInt();

    final streakDays =
    ((homeSummary?["streak_days"] ?? 0) as num).toInt();

    return RefreshIndicator(
      onRefresh: loadHomeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),

            HomeHeaderCard(
              studentName: studentName,
            ),

            const SizedBox(height: 26),

            LevelProgressCard(
              currentLevel: currentLevel,
              progress: levelProgress,
            ),

            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      DailyGoalCard(
                        completedMinutes: todayCompletedMinutes,
                        goalMinutes: dailyGoalMinutes,
                      ),

                      const SizedBox(height: 14),

                      StreakCard(
                        streakDays: streakDays,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                const Expanded(
                  child: MascotCard(),
                ),
              ],
            ),

            const SizedBox(height: 26),

            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(
                firstText == null
                    ? "Okumaya Başla"
                    : "${firstText!["title"]} ile Başla",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: widget.onStartReading,
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              icon: const Icon(Icons.emoji_events),
              label: const Text("Seviyeleri Gör"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: widget.onOpenLevels,
            ),
          ],
        ),
      ),
    );
  }
}