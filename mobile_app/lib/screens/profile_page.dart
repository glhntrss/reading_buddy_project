import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'avatar_selection_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'student_report_page.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> student;
  final ValueChanged<Map<String, dynamic>> onStudentUpdated;

  const ProfilePage({
    super.key,
    required this.student,
    required this.onStudentUpdated,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color softLilac = Color(0xFFF1EFFF);

  late Map<String, dynamic> student;
  bool isReportLoading = true;
  Map<String, dynamic>? report;

  @override
  void initState() {
    super.initState();
    student = Map<String, dynamic>.from(widget.student);
    loadReport();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student["id"] != widget.student["id"] ||
        oldWidget.student["name"] != widget.student["name"]) {
      student = Map<String, dynamic>.from(widget.student);
      loadReport();
    }
  }

  Future<void> loadReport() async {
    try {
      final data = await ApiService.getStudentReport(student["id"] ?? 1);
      if (!mounted) return;
      setState(() {
        report = data;
        isReportLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isReportLoading = false;
      });
    }
  }

  double latestSuccessPercent() {
    final sessions = report?["sessions"];
    if (sessions is List && sessions.isNotEmpty) {
      final first = sessions.first;
      if (first is Map && first["war"] is num) {
        return (first["war"] as num).toDouble().clamp(0.0, 100.0).toDouble();
      }
    }

    final summary = report?["summary"];
    if (summary is Map && summary["average_war"] is num) {
      return (summary["average_war"] as num)
          .toDouble()
          .clamp(0.0, 100.0)
          .toDouble();
    }

    return 0;
  }

  String formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return "%${value.toStringAsFixed(0)}";
    }
    return "%${value.toStringAsFixed(1)}";
  }

  String avatarAsset() {
    return (student["avatar_asset"] ?? "assets/images/avatars/avatar_1.png")
        .toString();
  }

  int totalReadings() {
    final summary = report?["summary"];
    if (summary is Map && summary["total_sessions"] is num) {
      return (summary["total_sessions"] as num).toInt();
    }
    return 0;
  }

  int passedReadings() {
    final summary = report?["summary"];
    if (summary is Map && summary["passed_sessions"] is num) {
      return (summary["passed_sessions"] as num).toInt();
    }
    return 0;
  }

  int bestStarCount() {
    final sessions = report?["sessions"];
    if (sessions is! List) return 0;

    var best = 0;
    for (final item in sessions) {
      if (item is Map && item["stars"] is num) {
        final stars = (item["stars"] as num).toInt();
        if (stars > best) best = stars;
      }
    }
    return best;
  }

  Future<void> openEditProfile() async {
    final updatedStudent = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(student: student)),
    );

    if (updatedStudent == null || !mounted) return;

    setState(() {
      student = updatedStudent;
    });
    widget.onStudentUpdated(updatedStudent);
  }

  Future<void> openSettings() async {
    final updatedStudent = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          student: student,
          onStudentUpdated: widget.onStudentUpdated,
        ),
      ),
    );

    if (updatedStudent == null || !mounted) return;

    setState(() {
      student = updatedStudent;
    });
    widget.onStudentUpdated(updatedStudent);
  }

  Future<void> openAvatarSelection() async {
    final updatedStudent = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => AvatarSelectionPage(student: student)),
    );

    if (updatedStudent == null || !mounted) return;

    setState(() {
      student = updatedStudent;
    });
    widget.onStudentUpdated(updatedStudent);
  }

  Widget buildAvatar() {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: openAvatarSelection,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: softLilac,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.16),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: Image.asset(avatarAsset(), fit: BoxFit.cover),
            ),
          ),
          const Positioned(
            right: -2,
            bottom: 4,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: primaryColor,
              child: Icon(Icons.edit, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget badgeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool unlocked,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFFF1EFFF) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? primaryColor.withValues(alpha: 0.20)
              : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: unlocked ? Colors.white : Colors.white70,
            child: Icon(
              unlocked ? icon : Icons.lock_outline,
              color: unlocked ? primaryColor : Colors.black38,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: unlocked ? Colors.black87 : Colors.black38,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: unlocked ? Colors.black54 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBadgesCard() {
    final readings = totalReadings();
    final passed = passedReadings();
    final success = latestSuccessPercent();
    final bestStars = bestStarCount();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Rozetler",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          badgeTile(
            icon: Icons.menu_book,
            title: "İlk Okuma",
            subtitle: "İlk okuma tamamlandı",
            unlocked: readings >= 1,
          ),
          const SizedBox(height: 10),
          badgeTile(
            icon: Icons.star,
            title: "Yıldız Avcısı",
            subtitle: "3 yıldızlı okuma yaptın",
            unlocked: bestStars >= 3,
          ),
          const SizedBox(height: 10),
          badgeTile(
            icon: Icons.emoji_events,
            title: "Başarılı Okur",
            subtitle: "En az 3 okumayı geçtin",
            unlocked: passed >= 3,
          ),
          const SizedBox(height: 10),
          badgeTile(
            icon: Icons.trending_up,
            title: "Güçlü İlerleme",
            subtitle: "Başarı yüzdesi %80 ve üzeri",
            unlocked: success >= 80,
          ),
        ],
      ),
    );
  }

  Widget buildReportCard() {
    final percent = latestSuccessPercent();

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentReportPage(studentId: student["id"] ?? 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: softLilac,
                  child: Icon(Icons.bar_chart, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Raporlar ve Analizler",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isReportLoading
                            ? "Başarı yüzdesi yükleniyor"
                            : "Son başarı yüzdesi ${formatPercent(percent)}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percent / 100,
              minHeight: 9,
              borderRadius: BorderRadius.circular(20),
              backgroundColor: const Color(0xFFE8E4FF),
              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatPercent(percent),
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Profil",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: "Ayarlar",
                  onPressed: openSettings,
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(child: buildAvatar()),
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
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton.icon(
                onPressed: openEditProfile,
                icon: const Icon(Icons.edit),
                label: const Text("Profili Düzenle"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            buildReportCard(),
            const SizedBox(height: 16),
            buildBadgesCard(),
          ],
        ),
      ),
    );
  }
}
