import 'package:flutter/material.dart';

import 'auth_page.dart';
import 'student_report_page.dart';
import '../widgets/app_logo_header.dart';

class TeacherDashboardPage extends StatelessWidget {
  final Map<String, dynamic> teacher;

  const TeacherDashboardPage({
    super.key,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    final teacherName = teacher["name"] ?? "Öğretmen";

    return Scaffold(
      backgroundColor: const Color(0xFFFCF7FF),
      appBar: AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      toolbarHeight: 82,
      backgroundColor: const Color(0xFFFCF7FF),
      elevation: 0,
      title: const AppLogoHeader(
        height: 58,
      ),
      actions: [
        IconButton(
          tooltip: "Çıkış Yap",
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthPage(),
              ),
            );
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hoş geldiniz",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        teacherName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        teacher["branch"] ?? "Branş bilgisi yok",
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _TeacherMenuCard(
                  icon: Icons.groups,
                  title: "Öğrenciler",
                  description: "Öğrenci listesini görüntüle",
                  onTap: () {},
                ),

                const SizedBox(height: 14),

                _TeacherMenuCard(
                  icon: Icons.bar_chart,
                  title: "Okuma Raporları",
                  description: "Öğrencilerin analiz sonuçlarını incele",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentReportPage(
                          teacherView: true,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                _TeacherMenuCard(
                  icon: Icons.assignment,
                  title: "Ödev / Metin Atama",
                  description: "Öğrencilere okuma metni atama",
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeacherMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _TeacherMenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF1EFFF),
              child: Icon(
                icon,
                color: const Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
