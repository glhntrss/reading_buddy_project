import 'package:flutter/material.dart';

import '../widgets/progress_metric.dart';
import '../widgets/stat_card.dart';

class AnalysisResultPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? selectedText;

  const AnalysisResultPage({
    super.key,
    required this.data,
    required this.selectedText,
  });

  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color softYellow = Color(0xFFFFF8E1);
  static const Color softGreen = Color(0xFFE8F8EF);
  static const Color softRed = Color(0xFFFFECEC);

  int get stars => data["stars"] ?? 0;
  bool get passed => data["passed"] == 1 || data["passed"] == true;
  double get war => (data["war"] ?? 0).toDouble();
  double get wer => (data["wer"] ?? 0).toDouble();

  Map<String, dynamic> get levelProgress {
    final progress = data["level_progress"];
    if (progress is Map<String, dynamic>) return progress;
    return {};
  }

  List<dynamic> get wordAnalysis {
    final analysis = data["word_analysis"];
    if (analysis is List) return analysis;
    return [];
  }

  String starsText(int count) {
    if (count <= 0) return "Yildiz kazanilamadi";
    return List.generate(count, (_) => "★").join(" ");
  }

  Color statusColor(String status) {
    switch (status) {
      case "correct":
        return Colors.green.shade700;
      case "missing":
        return Colors.grey.shade600;
      case "extra":
      case "wrong":
        return Colors.red.shade700;
      default:
        return Colors.black87;
    }
  }

  TextDecoration statusDecoration(String status) {
    return status == "wrong" || status == "extra"
        ? TextDecoration.underline
        : TextDecoration.none;
  }

  List<TextSpan> buildStudentTextSpans() {
    if (wordAnalysis.isEmpty) {
      return [
        TextSpan(text: (data["transcript"] ?? "").toString()),
      ];
    }

    final spans = <TextSpan>[];

    for (final item in wordAnalysis) {
      if (item is! Map) continue;

      final status = (item["status"] ?? "").toString();
      final referenceWord = (item["reference_word"] ?? "").toString();
      final studentWord = (item["student_word"] ?? "").toString();
      final displayWord = status == "missing" ? referenceWord : studentWord;

      if (displayWord.trim().isEmpty) continue;

      spans.add(
        TextSpan(
          text: "$displayWord ",
          style: TextStyle(
            color: statusColor(status),
            decoration: statusDecoration(status),
            decorationColor: Colors.red.shade700,
            decorationThickness: 2,
            fontWeight: status == "correct" ? FontWeight.w600 : FontWeight.bold,
          ),
        ),
      );
    }

    return spans;
  }

  List<Widget> buildErrorCards() {
    final problemItems = wordAnalysis.where((item) {
      if (item is! Map) return false;
      return item["status"] != "correct";
    }).toList();

    if (problemItems.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Bu okumada belirgin bir hata bulunmadı.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return problemItems.map((item) {
      final map = item as Map;
      final referenceWord = (map["reference_word"] ?? "").toString();
      final studentWord = (map["student_word"] ?? "").toString();
      final feedback = (map["feedback"] ?? "").toString();

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: softRed,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              referenceWord.isEmpty ? studentWord : referenceWord,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (studentWord.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text("Algılanan: $studentWord"),
            ],
            const SizedBox(height: 8),
            Text(
              feedback.isEmpty
                  ? "Bu kelimeyi daha yavaş ve net okumayı deneyelim."
                  : feedback,
              style: const TextStyle(height: 1.35),
            ),
          ],
        ),
      );
    }).toList();
  }

  String progressText() {
    final completed = levelProgress["completed_texts"] ?? 0;
    final total = levelProgress["total_texts"] ?? 0;
    return "$completed / $total okuma tamamlandı";
  }

  double progressPercent() {
    return (levelProgress["progress_percent"] ?? 0).toDouble();
  }

  String actionLabel() {
    final completed = levelProgress["level_completed"] == 1;
    final canGoNext = levelProgress["can_go_next"] == true;
    if (completed && passed && canGoNext) return "Sonraki Seviyeye Geç";
    if (completed && passed) return "Okuma Ekranına Dön";
    if (passed) return "Sıradaki Okumaya Geç";
    return "Tekrar Oku";
  }

  Map<String, dynamic> actionResult() {
    final completed = levelProgress["level_completed"] == 1;
    final canGoNext = levelProgress["can_go_next"] == true;
    if (completed && passed && canGoNext) {
      return {
        "action": "next_level",
        "level_id": levelProgress["next_level_id"],
      };
    }

    if (completed && passed) {
      return {
        "action": "done",
        "level_id": selectedText?["level_id"],
      };
    }

    if (passed) {
      return {
        "action": "next_reading",
        "level_id": selectedText?["level_id"],
      };
    }

    return {
      "action": "retry",
      "level_id": selectedText?["level_id"],
      "text_id": selectedText?["id"],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Okuma Analizi"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: softYellow,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Text(
                    "Seviye İlerlemesi",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProgressMetric(
                    title: progressText(),
                    value: progressPercent(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Çocuğun Okuduğu Cümle",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.black87,
                        height: 1.45,
                      ),
                      children: buildStudentTextSpans(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: softYellow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    "Okuma Sonucu",
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    starsText(stars),
                    style: TextStyle(
                      color: stars > 0 ? Colors.amber.shade700 : Colors.black87,
                      fontSize: stars > 0 ? 34 : 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    passed
                        ? "Tebrikler! Bu okuma tamamlandı."
                        : "Bu okumayı tekrar çalışalım.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ProgressMetric(
                    title: "Okuma Başarısı",
                    value: war,
                  ),
                  const SizedBox(height: 14),
                  ProgressMetric(
                    title: "Hata Oranı",
                    value: wer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: "Doğru",
                    value: "${data["correct_count"] ?? 0}",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: "Yanlış",
                    value: "${data["substitution_count"] ?? 0}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: "Eksik",
                    value: "${data["deletion_count"] ?? 0}",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: "Fazla",
                    value: "${data["insertion_count"] ?? 0}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              "Dikkat Edilecekler",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...buildErrorCards(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: Text(actionLabel()),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, actionResult());
              },
            ),
          ],
        ),
      ),
    );
  }
}
