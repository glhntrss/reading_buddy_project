import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../widgets/progress_metric.dart';
import '../widgets/stat_card.dart';

class AnalysisResultPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? selectedText;

  const AnalysisResultPage({
    super.key,
    required this.data,
    required this.selectedText,
  });

  @override
  State<AnalysisResultPage> createState() => _AnalysisResultPageState();
}

class _AnalysisResultPageState extends State<AnalysisResultPage> {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color softYellow = Color(0xFFFFF8E1);
  static const Color softGreen = Color(0xFFE8F8EF);
  static const Color softLavender = Color(0xFFF3EFFF);

  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text, double rate) async {
    if (text.isNotEmpty) {
      await flutterTts.setSpeechRate(rate);
      await flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  int get stars => widget.data["stars"] ?? 0;
  bool get passed => widget.data["passed"] == 1 || widget.data["passed"] == true;
  double get war => percentageValue(widget.data["war"]);
  double get wer => percentageValue(widget.data["wer"]);

  double percentageValue(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0.0;
    return parsed.clamp(0.0, 100.0).toDouble();
  }

  Map<String, dynamic> get mlPrediction {
    final prediction = widget.data["ml_prediction"];
    if (prediction is Map<String, dynamic>) return prediction;
    return {};
  }

  Map<String, dynamic> get levelProgress {
    final progress = widget.data["level_progress"];
    if (progress is Map<String, dynamic>) return progress;
    return {};
  }

  List<dynamic> get wordAnalysis {
    final analysis = widget.data["word_analysis"];
    if (analysis is List) return analysis;
    return [];
  }

  String starsText(int count) {
    if (count <= 0) return "Yıldız kazanılamadı";
    return List.generate(count, (_) => "★").join(" ");
  }

  Color statusColor(String status) {
    switch (status) {
      case "correct":
        return Colors.green.shade700;
      case "missing":
        return Colors.grey.shade500;
      case "extra":
      case "wrong":
        return primaryColor;
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
        TextSpan(text: (widget.data["transcript"] ?? "").toString()),
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
            decorationColor: primaryColor,
            decorationThickness: 2,
            fontWeight: status == "correct" ? FontWeight.w600 : FontWeight.bold,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _buildSpeedButton(String imageAsset, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 45,
                child: Center(
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.volume_up, color: primaryColor),
            ],
          ),
        ),
      ),
    );
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

      final textToSpeak = referenceWord.isEmpty ? studentWord : referenceWord;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: softLavender,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    textToSpeak,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSpeedButton(
                      "assets/images/turtle.png",
                      "Yavaş Oku",
                          () => _speak(textToSpeak, 0.25),
                    ),
                    _buildSpeedButton(
                      "assets/images/rabbit.png",
                      "Normal Oku",
                          () => _speak(textToSpeak, 0.60),
                    ),
                  ],
                ),
              ],
            ),
            if (studentWord.isNotEmpty) ...[
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

  Color mlRiskColor(String _) {
    return primaryColor;
  }

  Widget buildMlPredictionCard() {
    if (mlPrediction.isEmpty) {
      return const SizedBox.shrink();
    }

    final passProbability = mlPrediction["latest_pass_probability"] is num
        ? (mlPrediction["latest_pass_probability"] as num).toDouble()
        : 0.0;
    final successPercent = (passProbability * 100).clamp(0.0, 100.0).toDouble();
    final focusLetters = mlPrediction["focus_letters"];
    final focusItems = focusLetters is List ? focusLetters : [];
    final color = mlRiskColor("");

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Öğrencinin Başarı Yüzdesi",
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "%${successPercent.toStringAsFixed(0)}",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ProgressMetric(
            title: "Başarı Yüzdesi",
            value: successPercent,
          ),
          const SizedBox(height: 12),
          Text(
            "Sonraki okuma: ${mlPrediction["next_text_difficulty"] ?? "-"}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (focusItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: focusItems.take(5).map((item) {
                final map = item is Map ? item : {};
                return Chip(
                  backgroundColor: Colors.white,
                  label: Text("${map["letter"] ?? "-"}"),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
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
        "level_id": widget.selectedText?["level_id"],
      };
    }

    if (passed) {
      return {
        "action": "next_reading",
        "level_id": widget.selectedText?["level_id"],
      };
    }

    return {
      "action": "retry",
      "level_id": widget.selectedText?["level_id"],
      "text_id": widget.selectedText?["id"],
    };
  }

  @override
  Widget build(BuildContext context) {
    final referenceText = widget.data["reference_text"] ?? "";

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
                // BURAYI DEĞİŞTİRİYORUZ: Arka plan ve kenarlık rengi ML kartıyla aynı yapıldı
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: primaryColor.withValues(alpha: 0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ÜST KISIM: Çocuğun Okuduğu Cümle ---
                  const Text(
                    "Okunan Cümle",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
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

                  // Araya ince bir çizgi
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(height: 1, color: Colors.black12),
                  ),

                  // --- ALT KISIM: Doğru Cümle ve TTS Butonları Yan Yana ---
                  const Text(
                    "Doğru Cümle",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          referenceText,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.black87,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSpeedButton(
                            "assets/images/turtle.png",
                            "Yavaş Oku",
                                () => _speak(referenceText, 0.25),
                          ),
                          _buildSpeedButton(
                            "assets/images/rabbit.png",
                            "Normal Oku",
                                () => _speak(referenceText, 0.60),
                          ),
                        ],
                      ),
                    ],
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
            buildMlPredictionCard(),
            if (mlPrediction.isNotEmpty) const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: "Doğru",
                    value: "${widget.data["correct_count"] ?? 0}",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: "Yanlış",
                    value: "${widget.data["substitution_count"] ?? 0}",
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
                    value: "${widget.data["deletion_count"] ?? 0}",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: "Fazla",
                    value: "${widget.data["insertion_count"] ?? 0}",
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