import 'package:flutter/material.dart';

import '../services/api_service.dart';

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
        final texts = await ApiService.getStudentTexts(students.first["id"]);

        setState(() {
          student = students.first;
          firstText = texts.isNotEmpty ? texts.first : null;
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student == null
                      ? "Merhaba"
                      : "Merhaba, ${student!["name"]}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  student == null
                      ? "Bugün okumaya hazır mısın?"
                      : "Mevcut seviyen: ${student!["current_level"]}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EFFF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.menu_book,
                  size: 42,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Bugünkü Okuma Görevi",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  firstText?["title"] ?? "Okuma metni bulunamadı.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Okumaya Başla"),
                    onPressed: widget.onStartReading,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          OutlinedButton.icon(
            icon: const Icon(Icons.emoji_events),
            label: const Text("Seviyeleri Gör"),
            onPressed: widget.onOpenLevels,
          ),
        ],
      ),
    );
  }
}