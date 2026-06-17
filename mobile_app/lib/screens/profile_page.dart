import 'package:flutter/material.dart';

import 'student_report_page.dart';

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> student;

  const ProfilePage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 48,
            backgroundColor: Color(0xFFF1EFFF),
            child: Icon(Icons.person, size: 52, color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 16),
          Text(
            student["name"] ?? "Öğrenci",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "${student["age"] ?? "-"} yaş • ${student["grade"] ?? "Sınıf bilgisi yok"}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 26),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Profil Düzenle"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text("Raporlar ve Analizler"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentReportPage(studentId: student["id"] ?? 1),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Ayarlar"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
