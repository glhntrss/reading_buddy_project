import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/stat_card.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  bool isLoading = true;
  List<dynamic> sessions = [];

  @override
  void initState() {
    super.initState();
    loadSessions();
  }

  Future<void> loadSessions() async {
    try {
      final data = await ApiService.getSessions();

      setState(() {
        sessions = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String starsText(int count) {
    if (count <= 0) return "Yıldız kazanılamadı";
    return List.generate(count, (_) => "⭐").join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Raporlar"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
              ? const Center(
                  child: Text("Henüz kayıtlı analiz bulunmuyor."),
                )
              : RefreshIndicator(
                  onRefresh: loadSessions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final int stars = session["stars"] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session["student_name"] ?? "Öğrenci",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text("Tarih: ${session["created_at"] ?? "-"}"),
                              const SizedBox(height: 8),
                              Text("Yıldız: ${starsText(stars)}"),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: StatCard(
                                      title: "WAR",
                                      value: "%${session["war"] ?? 0}",
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: StatCard(
                                      title: "WER",
                                      value: "%${session["wer"] ?? 0}",
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}