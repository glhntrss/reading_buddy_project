import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/api_service.dart';
import 'analysis_result_page.dart';
import '../widgets/progress_metric.dart';
import '../widgets/stat_card.dart';

class ReadingPage extends StatefulWidget {
  final Map<String, dynamic> student;
  final int? selectedLevelId;

  const ReadingPage({super.key, required this.student, this.selectedLevelId});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final AudioRecorder recorder = AudioRecorder();

  bool isLoading = true;
  bool isRecording = false;
  bool isAnalyzing = false;
  bool hasAnalysisResult = false;

  String? recordedFilePath;

  Map<String, dynamic>? selectedStudent;
  Map<String, dynamic>? selectedText;

  List<dynamic> readingTexts = [];

  String referenceText = "";
  String detectedText = "";

  double war = 0;
  double wer = 0;

  int correctCount = 0;
  int substitutionCount = 0;
  int deletionCount = 0;
  int insertionCount = 0;

  int stars = 0;
  bool passed = false;

  final Color primaryColor = const Color(0xFF6C63FF);
  final Color softPurple = const Color(0xFFF1EFFF);
  final Color softGreen = const Color(0xFFE8F8EF);
  final Color softLilac = const Color(0xFFF3EFFF);
  final Color softYellow = const Color(0xFFFFF8E1);

  @override
  void initState() {
    super.initState();
    loadReadingData();
  }

  @override
  void didUpdateWidget(covariant ReadingPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedLevelId != oldWidget.selectedLevelId) {
      selectTextByLevel(widget.selectedLevelId);
    }
  }

  void selectTextByLevel(int? levelId) {
    if (levelId == null || readingTexts.isEmpty) return;

    final matchedTexts = readingTexts.where(
      (text) => text["level_id"] == levelId,
    );

    if (matchedTexts.isNotEmpty) {
      final pendingTexts = matchedTexts.where((text) => text["is_passed"] != 1);
      final chosenText = pendingTexts.isNotEmpty
          ? pendingTexts.first
          : matchedTexts.first;

      setState(() {
        selectedText = chosenText;
        referenceText = chosenText["content"] ?? "";
        resetAnalysisResult();
      });
    }
  }

  void selectTextById(int? textId) {
    if (textId == null || readingTexts.isEmpty) return;

    final matchedTexts = readingTexts.where((text) => text["id"] == textId);

    if (matchedTexts.isEmpty) return;

    final chosenText = matchedTexts.first;

    setState(() {
      selectedText = chosenText;
      referenceText = chosenText["content"] ?? "";
      recordedFilePath = null;
      resetAnalysisResult();
    });
  }

  void selectNextPendingTextByLevel(int? levelId) {
    if (levelId == null || readingTexts.isEmpty) return;

    final levelTexts = readingTexts
        .where((text) => text["level_id"] == levelId)
        .toList();

    if (levelTexts.isEmpty) return;

    final pendingTexts = levelTexts.where((text) => text["is_passed"] != 1);

    final chosenText = pendingTexts.isNotEmpty
        ? pendingTexts.first
        : levelTexts.first;

    setState(() {
      selectedText = chosenText;
      referenceText = chosenText["content"] ?? "";
      recordedFilePath = null;
      resetAnalysisResult();
    });
  }

  double selectedLevelProgressPercent() {
    final levelId = selectedText?["level_id"];
    if (levelId == null || readingTexts.isEmpty) return 0;

    final levelTexts = readingTexts.where(
      (text) => text["level_id"] == levelId,
    );

    final total = levelTexts.length;
    if (total == 0) return 0;

    final completed = levelTexts.where((text) => text["is_passed"] == 1).length;

    return (completed / total) * 100;
  }

  String selectedLevelProgressLabel() {
    final levelId = selectedText?["level_id"];
    if (levelId == null || readingTexts.isEmpty) {
      return "Seviye ilerlemesi";
    }

    final levelTexts = readingTexts.where(
      (text) => text["level_id"] == levelId,
    );
    final completed = levelTexts.where((text) => text["is_passed"] == 1).length;

    return "$completed / ${levelTexts.length} okuma tamamlandı";
  }

  dynamic firstPendingText(Iterable<dynamic> texts) {
    final assignedTexts = texts.where(
      (text) => text["is_assigned"] == 1 && text["is_passed"] != 1,
    );

    if (assignedTexts.isNotEmpty) return assignedTexts.first;

    final pendingTexts = texts.where((text) => text["is_passed"] != 1);

    return pendingTexts.isNotEmpty ? pendingTexts.first : texts.first;
  }

  @override
  void dispose() {
    recorder.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String starsText(int count) {
    if (count <= 0) return "";
    return List.generate(count, (_) => "⭐").join();
  }

  Future<void> loadReadingData() async {
    try {
      selectedStudent = widget.student;

      if (selectedStudent?["id"] != null) {
        readingTexts = await ApiService.getStudentTexts(selectedStudent!["id"]);

        if (readingTexts.isNotEmpty) {
          if (widget.selectedLevelId != null) {
            final matchedTexts = readingTexts.where(
              (text) => text["level_id"] == widget.selectedLevelId,
            );

            if (matchedTexts.isNotEmpty) {
              selectedText = firstPendingText(matchedTexts);
            } else {
              selectedText = firstPendingText(readingTexts);
            }
          } else {
            selectedText = firstPendingText(readingTexts);
          }

          referenceText = selectedText!["content"] ?? "";
        }
      }
    } catch (e) {
      showMessage("Okuma verileri alınamadı: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void resetAnalysisResult() {
    detectedText = "";
    war = 0;
    wer = 0;
    correctCount = 0;
    substitutionCount = 0;
    deletionCount = 0;
    insertionCount = 0;
    stars = 0;
    passed = false;
    hasAnalysisResult = false;
  }

  Future<void> startRecording() async {
    final hasPermission = await recorder.hasPermission();

    if (!hasPermission) {
      showMessage("Mikrofon izni verilmedi.");
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        "${directory.path}/reading_audio_${DateTime.now().millisecondsSinceEpoch}.wav";

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: filePath,
    );

    setState(() {
      recordedFilePath = filePath;
      isRecording = true;
      resetAnalysisResult();
    });
  }

  Future<void> stopRecording() async {
    final path = await recorder.stop();

    if (path == null) {
      showMessage("Ses kaydı alınamadı.");
      return;
    }

    final file = File(path);
    final fileSize = await file.length();

    setState(() {
      recordedFilePath = path;
      isRecording = false;
    });

    showMessage(
      "Ses kaydı tamamlandı. Dosya boyutu: ${(fileSize / 1024).toStringAsFixed(1)} KB",
    );
  }

  Future<void> analyzeAudio() async {
    if (recordedFilePath == null) {
      showMessage("Önce ses kaydı almalısın.");
      return;
    }

    if (referenceText.trim().isEmpty) {
      showMessage("Okunacak metin bulunamadı.");
      return;
    }

    setState(() {
      isAnalyzing = true;
    });

    try {
      final data = await ApiService.analyzeAudio(
        audioPath: recordedFilePath!,
        referenceText: referenceText,
        studentId: selectedStudent?["id"] ?? 1,
        textId: selectedText?["id"],
      );

      if (data["error"] != null) {
        setState(() {
          detectedText = "Backend hata verdi: ${data["error"]}";
          hasAnalysisResult = true;
        });
        showMessage("Backend hata verdi.");
      } else {
        final transcript = (data["transcript"] ?? "").toString().trim();

        setState(() {
          detectedText = transcript.isEmpty
              ? "Ses algılanamadı. Lütfen mikrofona yakın şekilde tekrar oku."
              : transcript;

          war = (data["war"] ?? 0).toDouble();
          wer = (data["wer"] ?? 0).toDouble();

          correctCount = data["correct_count"] ?? 0;
          substitutionCount = data["substitution_count"] ?? 0;
          deletionCount = data["deletion_count"] ?? 0;
          insertionCount = data["insertion_count"] ?? 0;

          stars = data["stars"] ?? 0;
          passed = data["passed"] == 1;

          hasAnalysisResult = true;
        });

        if (!mounted) return;

        final action = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AnalysisResultPage(data: data, selectedText: selectedText),
          ),
        );

        await loadReadingData();

        if (action != null) {
          final actionType = action["action"];
          final levelId = action["level_id"];

          if (actionType == "next_level" || actionType == "next_reading") {
            selectNextPendingTextByLevel(levelId);
          } else if (actionType == "retry") {
            selectTextById(action["text_id"]);
          }
        }

        setState(() {
          hasAnalysisResult = false;
        });
      }
    } catch (e) {
      setState(() {
        detectedText = "Ses analizi sırasında hata oluştu: $e";
        hasAnalysisResult = true;
      });
    }

    setState(() {
      isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Okuma Görevi",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedText == null
                      ? "Metin bulunamadı"
                      : "${selectedText!["title"]} • ${selectedText!["level"]}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: ProgressMetric(
              title: selectedLevelProgressLabel(),
              value: selectedLevelProgressPercent(),
            ),
          ),

          const SizedBox(height: 18),

          if (readingTexts.length > 1)
            DropdownButtonFormField<int>(
              initialValue: selectedText?["id"],
              decoration: InputDecoration(
                labelText: "Okuma metni seç",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                prefixIcon: const Icon(Icons.menu_book),
              ),
              items: readingTexts.map<DropdownMenuItem<int>>((text) {
                final isAssigned = text["is_assigned"] == 1;
                return DropdownMenuItem<int>(
                  value: text["id"],
                  child: Text(
                    isAssigned ? "Ödev • ${text["title"]}" : text["title"],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                final chosenText = readingTexts.firstWhere(
                  (text) => text["id"] == value,
                );

                setState(() {
                  selectedText = chosenText;
                  referenceText = chosenText["content"] ?? "";
                  resetAnalysisResult();
                });
              },
            ),

          if (readingTexts.length > 1) const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: softPurple,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.record_voice_over,
                  size: 42,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Okunacak Metin",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Text(
                  referenceText.isEmpty
                      ? "Henüz okuma metni bulunamadı."
                      : referenceText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRecording ? softLilac : softGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  isRecording ? Icons.mic : Icons.mic_none,
                  size: 30,
                  color: isRecording ? primaryColor : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isRecording
                        ? "Kayıt alınıyor... Şimdi metni oku."
                        : "Kayıt başlatılmadı.",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.mic),
                  label: const Text("Başlat"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: isRecording ? null : startRecording,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text("Durdur"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: isRecording ? stopRecording : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_graph),
              label: Text(
                isAnalyzing ? "Analiz ediliyor..." : "Ses Kaydını Analiz Et",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: isAnalyzing ? null : analyzeAudio,
            ),
          ),

          if (hasAnalysisResult) const SizedBox(height: 22),

          if (hasAnalysisResult)
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
                    "Sistemin Algıladığı Metin",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    detectedText.isEmpty
                        ? "Ses algılanamadı. Lütfen tekrar dene."
                        : detectedText,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),

          if (hasAnalysisResult) const SizedBox(height: 18),

          if (hasAnalysisResult)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: softYellow,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  const Text(
                    "Okuma Sonucu",
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stars <= 0 ? "Yıldız kazanılamadı" : starsText(stars),
                    style: TextStyle(
                      fontSize: stars <= 0 ? 18 : 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    passed
                        ? "Tebrikler! Bu seviyeyi geçtin."
                        : "Bu seviyeyi tekrar çalışalım.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  ProgressMetric(title: "Okuma Başarısı", value: war),
                  const SizedBox(height: 14),
                  ProgressMetric(title: "Hata Oranı", value: wer),
                ],
              ),
            ),

          if (hasAnalysisResult) const SizedBox(height: 16),

          if (hasAnalysisResult)
            Row(
              children: [
                Expanded(
                  child: StatCard(title: "Doğru", value: "$correctCount"),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(title: "Yanlış", value: "$substitutionCount"),
                ),
              ],
            ),

          if (hasAnalysisResult) const SizedBox(height: 10),

          if (hasAnalysisResult)
            Row(
              children: [
                Expanded(
                  child: StatCard(title: "Eksik", value: "$deletionCount"),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(title: "Fazla", value: "$insertionCount"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
