import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/level_card.dart';

class LevelsPage extends StatefulWidget {
  final void Function(int levelId) onLevelSelected;

  const LevelsPage({
    super.key,
    required this.onLevelSelected,
  });

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> {
  bool isLoading = true;
  List<dynamic> levelProgress = [];

  @override
  void initState() {
    super.initState();
    loadLevels();
  }

  Future<void> loadLevels() async {
    try {
      final progress = await ApiService.getStudentProgress(1);

      setState(() {
        levelProgress = progress;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: loadLevels,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Seviyeler",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "Okuma yolculuğunda ilerle ve yeni seviyeleri aç.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 22),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: levelProgress.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final level = levelProgress[index];

                final bool isUnlocked = level["is_unlocked"] == 1;
                final bool isCompleted = level["is_completed"] == 1;
                final int bestStars = level["best_stars"] ?? 0;

              return LevelCard(
                  title: level["title"] ?? "Seviye",
                  description: level["description"] ?? "",
                  bestStars: bestStars,
                  isUnlocked: isUnlocked,
                  isCompleted: isCompleted,
                  onTap: () {
                    widget.onLevelSelected(level["level_id"]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}