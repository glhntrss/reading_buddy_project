import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/daily_goal_card.dart';
import '../widgets/home_header_card.dart';
import '../widgets/level_progress_card.dart';
import '../widgets/mascot_card.dart';
import '../widgets/streak_card.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onStartReading;
  final VoidCallback onOpenLevels;

  const HomePage({
    super.key,
    required this.student,
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
  Map<String, dynamic>? nextAssignment;

  List<dynamic> progress = [];
  List<dynamic> assignments = [];

  bool isLoading = true;
  int sideCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    try {
      final selectedStudent = widget.student;
      final studentId = selectedStudent["id"];

      if (studentId != null) {
        final texts = await ApiService.getStudentTexts(studentId);
        final studentProgress = await ApiService.getStudentProgress(studentId);
        final summary = await ApiService.getHomeSummary(studentId);
        final studentAssignments = await ApiService.getAssignments(
          studentId: studentId,
        );
        final pendingAssignment = firstPendingAssignment(studentAssignments);

        setState(() {
          student = selectedStudent;
          firstText = pendingAssignment == null
              ? texts.isNotEmpty
                    ? texts.first
                    : null
              : findTextById(texts, pendingAssignment["text_id"]) ??
                    (texts.isNotEmpty ? texts.first : null);
          progress = studentProgress;
          assignments = studentAssignments;
          nextAssignment = pendingAssignment;
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

  Map<String, dynamic>? firstPendingAssignment(List<dynamic> items) {
    final pending = items.where((item) {
      if (item is! Map) return false;
      return item["status"] != "completed";
    }).toList();

    if (pending.isEmpty) return null;

    pending.sort((a, b) {
      final left = (a["due_date"] ?? "").toString();
      final right = (b["due_date"] ?? "").toString();
      if (left.isEmpty && right.isEmpty) return 0;
      if (left.isEmpty) return 1;
      if (right.isEmpty) return -1;
      return left.compareTo(right);
    });

    return Map<String, dynamic>.from(pending.first as Map);
  }

  Map<String, dynamic>? findTextById(List<dynamic> texts, dynamic textId) {
    for (final item in texts) {
      if (item is Map && item["id"] == textId) {
        return Map<String, dynamic>.from(item);
      }
    }

    return null;
  }

  String assignmentTitle() {
    if (nextAssignment == null) return "";

    final title = (nextAssignment!["text_title"] ?? "").toString();
    final level = nextAssignment!["level_id"];

    if (title.isNotEmpty) return title;
    if (level != null) return "Seviye $level okumasını tamamla";
    return "Okuma ödevini tamamla";
  }

  String dueDateText() {
    final value = (nextAssignment?["due_date"] ?? "").toString();
    return value.isEmpty ? "Tarih belirtilmedi" : value;
  }

  Widget buildAssignmentReminder({bool compact = false}) {
    if (nextAssignment == null) return const SizedBox.shrink();

    final note = (nextAssignment!["note"] ?? "").toString();
    final pendingCount = assignments.where((item) {
      if (item is! Map) return false;
      return item["status"] != "completed";
    }).length;

    return Container(
      height: compact ? double.infinity : null,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFFF),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.assignment, color: Color(0xFF6C63FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Ödev Hatırlatması",
                        style: TextStyle(
                          color: Color(0xFF5B4BC4),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pendingCount > 1
                            ? "$pendingCount bekleyen ödev var"
                            : "1 bekleyen ödev var",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const Row(
              children: [
                Icon(Icons.assignment, color: Color(0xFF6C63FF), size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Ödev",
                    style: TextStyle(
                      color: Color(0xFF5B4BC4),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            "Ödev: ${assignmentTitle()}",
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 14 : 17,
              height: 1.25,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            "Son teslim tarihi: ${dueDateText()}",
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 14,
            ),
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: compact ? 6 : 8),
            Text(
              note,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
              style: TextStyle(
                color: Colors.black54,
                height: 1.35,
                fontSize: compact ? 12 : 14,
              ),
            ),
          ],
          if (compact) const Spacer() else const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(compact ? "Başla" : "Ödeve Başla"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: widget.onStartReading,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMascotAssignmentCarousel() {
    if (nextAssignment == null) {
      return const MascotCard();
    }

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView(
            onPageChanged: (index) {
              setState(() {
                sideCarouselIndex = index;
              });
            },
            children: [
              const MascotCard(),
              buildAssignmentReminder(compact: true),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                final selected = sideCarouselIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFFD8D1FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
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
      return const Center(child: CircularProgressIndicator());
    }

    final studentName = student?["name"] ?? "Test Öğrencisi";

    final currentLevel =
        ((homeSummary?["current_level"] ?? student?["current_level"] ?? 1)
                as num)
            .toInt();

    final levelProgress =
        ((homeSummary?["level_progress"] ?? calculateLevelProgress()) as num)
            .toDouble();

    final dailyGoalMinutes = ((homeSummary?["daily_goal_minutes"] ?? 5) as num)
        .toInt();

    final todayCompletedMinutes =
        ((homeSummary?["today_completed_minutes"] ?? 0) as num).toInt();

    final streakDays = ((homeSummary?["streak_days"] ?? 0) as num).toInt();

    return RefreshIndicator(
      onRefresh: loadHomeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),

            HomeHeaderCard(studentName: studentName),

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

                      StreakCard(streakDays: streakDays),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(child: buildMascotAssignmentCarousel()),
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
