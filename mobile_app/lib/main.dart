import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const ReadingBuddyApp());
}

class ReadingBuddyApp extends StatelessWidget {
  const ReadingBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reading Buddy',
      debugShowCheckedModeBanner: false,
      home: const ReadingPage(),
    );
  }
}

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final TextEditingController referenceController =
      TextEditingController(text: "Ali ata bak");

  final TextEditingController studentController =
      TextEditingController(text: "Ali bak");

  final AudioRecorder recorder = AudioRecorder();

  bool isLoading = false;
  bool isRecording = false;

  String? recordedFilePath;

  double war = 0;
  double wer = 0;

  int correctCount = 0;
  int substitutionCount = 0;
  int deletionCount = 0;
  int insertionCount = 0;

  List<dynamic> wordAnalysis = [];

 Future<void> startRecording() async {
 try {
    final permissionStatus = await Permission.microphone.request();

    if (!permissionStatus.isGranted) {
      showMessage("Mikrofon izni verilmedi.");
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/reading_audio.wav";

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    setState(() {
      isRecording = true;
      recordedFilePath = path;
    });

    showMessage("Ses kaydı başladı. Durdurmak için durdur butonunu tıkla.");
  } catch (e) {
    showMessage("Kayıt başlatılamadı: $e");
  }
}

Future<void> stopRecording() async {
  final path = await recorder.stop();

  setState(() {
    isRecording = false;
    recordedFilePath = path;
  });

  showMessage("Ses kaydı durduruldu.");
}

Future<void> sendRecordedAudioToBackend() async {
  if (recordedFilePath == null) {
    showMessage("Önce ses kaydı almalısın.");
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    final uri = Uri.parse("http://127.0.0.1:8000/analyze-audio");

    final request = http.MultipartRequest("POST", uri);

    request.fields["reference_text"] = referenceController.text;

    request.files.add(
      await http.MultipartFile.fromPath(
        "audio",
        recordedFilePath!,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);

      if (data["error"] != null) {
        showMessage("Analiz hatası: ${data["error"]}");
      } else {
        setState(() {
          studentController.text = data["transcript"];
          war = data["war"];
          wer = data["wer"];
          correctCount = data["correct_count"];
          substitutionCount = data["substitution_count"];
          deletionCount = data["deletion_count"];
          insertionCount = data["insertion_count"];
          wordAnalysis = data["word_analysis"];
        });

        showMessage("Ses başarıyla metne çevrildi ve analiz edildi.");
      }
    } else {
      showMessage("Backend hatası: $responseBody");
    }
  } catch (e) {
    showMessage("Ses analiz hatası: $e");
  }

  setState(() {
    isLoading = false;
  });
}

  Future<void> compareText() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Chrome'da çalıştırıyorsan bu adres doğru:
      final uri = Uri.parse("http://127.0.0.1:8000/compare-text");

      // Android emulator'da çalıştırırsan yukarıdakini kapatıp bunu kullan:
      // final uri = Uri.parse("http://10.0.2.2:8000/compare-text");

      final response = await http.post(
        uri,
        body: {
          "reference_text": referenceController.text,
          "student_text": studentController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          war = data["war"];
          wer = data["wer"];
          correctCount = data["correct_count"];
          substitutionCount = data["substitution_count"];
          deletionCount = data["deletion_count"];
          insertionCount = data["insertion_count"];
          wordAnalysis = data["word_analysis"];
        });
      } else {
        showMessage("Backend hatası: ${response.body}");
      }
    } catch (e) {
      showMessage("Bağlantı hatası: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color getStatusColor(String status) {
    if (status == "correct") {
      return Colors.green;
    } else if (status == "wrong") {
      return Colors.red;
    } else if (status == "missing") {
      return Colors.orange;
    } else {
      return Colors.blueGrey;
    }
  }

  String getStatusText(String status) {
    if (status == "correct") {
      return "Doğru";
    } else if (status == "wrong") {
      return "Yanlış";
    } else if (status == "missing") {
      return "Eksik";
    } else {
      return "Fazladan";
    }
  }

  Widget buildWordAnalysis() {
    if (wordAnalysis.isEmpty) {
      return const Text(
        "Henüz analiz yapılmadı.",
        style: TextStyle(fontSize: 16),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: wordAnalysis.map((item) {
        final status = item["status"];
        final color = getStatusColor(status);

        final referenceWord = item["reference_word"];
        final studentWord = item["student_word"];

        String visibleText;

        if (status == "extra") {
          visibleText = studentWord;
        } else if (status == "wrong") {
          visibleText = "$referenceWord → $studentWord";
        } else {
          visibleText = referenceWord;
        }

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                visibleText,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                getStatusText(status),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildScoreCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    referenceController.dispose();
    studentController.dispose();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yapay Zeka Destekli Okuma Arkadaşı"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Referans Metin",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Okunması gereken metni yaz",
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 18),

            const Text(
              "Öğrencinin Okuduğu Metin",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: studentController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Şimdilik ASR çıktısı yerine elle yazıyoruz",
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRecording ? null : startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text("Ses Kaydını Başlat"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRecording ? stopRecording : null,
                    icon: const Icon(Icons.stop),
                    label: const Text("Durdur"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              isRecording
                  ? "Kayıt durumu: Kayıt alınıyor..."
                  : "Kayıt durumu: Kayıt alınmıyor",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isRecording ? Colors.red : Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            if (recordedFilePath != null)
              Text(
                "Kaydedilen dosya: $recordedFilePath",
                style: const TextStyle(fontSize: 12),
              ),

            const SizedBox(height: 20),

           SizedBox(
             width: double.infinity,
             child: ElevatedButton.icon(
              onPressed: isLoading ? null : sendRecordedAudioToBackend,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Ses Kaydını Analiz Et"),
            ),
           ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : compareText,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Metin Analizi Yap"),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                buildScoreCard("WAR", "%$war"),
                const SizedBox(width: 10),
                buildScoreCard("WER", "%$wer"),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                buildScoreCard("Doğru", "$correctCount"),
                const SizedBox(width: 10),
                buildScoreCard("Yanlış", "$substitutionCount"),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                buildScoreCard("Eksik", "$deletionCount"),
                const SizedBox(width: 10),
                buildScoreCard("Fazla", "$insertionCount"),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              "Kelime Analizi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            buildWordAnalysis(),
          ],
        ),
      ),
    );
  }
}