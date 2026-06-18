import 'package:flutter/material.dart';

import 'auth_page.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> student;
  final ValueChanged<Map<String, dynamic>> onStudentUpdated;

  const SettingsPage({
    super.key,
    required this.student,
    required this.onStudentUpdated,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color softLilac = Color(0xFFF1EFFF);

  late Map<String, dynamic> student;
  bool notificationsEnabled = true;
  bool voiceGuidanceEnabled = true;

  @override
  void initState() {
    super.initState();
    student = Map<String, dynamic>.from(widget.student);
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

  Future<void> openChangePassword() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ChangePasswordPage(student: student)),
    );

    if (changed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Şifre başarıyla güncellendi.")),
    );
  }

  String avatarAsset() {
    return (student["avatar_asset"] ?? "assets/images/avatars/avatar_1.png")
        .toString();
  }

  void logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: Image.asset(
                avatarAsset(),
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, color: primaryColor, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student["name"] ?? "Öğrenci",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  student["email"] ?? "Mail bilgisi yok",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(children: children),
    );
  }

  Widget settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: softLilac,
        child: Icon(icon, color: primaryColor, size: 21),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7FF),
      appBar: AppBar(
        title: const Text("Ayarlar"),
        backgroundColor: const Color(0xFFFCF7FF),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildHeader(),
            const SizedBox(height: 20),
            settingsCard([
              settingsTile(
                icon: Icons.manage_accounts_outlined,
                title: "Hesap Ayarları",
                subtitle: "Profil bilgilerini güncelle",
                onTap: openEditProfile,
              ),
              settingsTile(
                icon: Icons.password_outlined,
                title: "Şifremi Değiştir",
                subtitle: "Hesap şifresini güncelle",
                onTap: openChangePassword,
              ),
              settingsTile(
                icon: Icons.notifications_none,
                title: "Bildirim Ayarları",
                subtitle: "Ödev ve okuma hatırlatmaları",
                trailing: Switch(
                  value: notificationsEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: (value) {
                    setState(() {
                      notificationsEnabled = value;
                    });
                  },
                ),
              ),
              settingsTile(
                icon: Icons.record_voice_over_outlined,
                title: "Sesli Okuma Desteği",
                subtitle: "Analiz ekranında sesli rehberlik",
                trailing: Switch(
                  value: voiceGuidanceEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: (value) {
                    setState(() {
                      voiceGuidanceEnabled = value;
                    });
                  },
                ),
              ),
              settingsTile(
                icon: Icons.language,
                title: "Uygulama Dili",
                subtitle: "Türkçe",
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Dil seçeneği Türkçe olarak ayarlı."),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 26),
            settingsCard([
              settingsTile(
                icon: Icons.logout,
                title: "Çıkış Yap",
                subtitle: "Hesaptan güvenli şekilde çık",
                onTap: logout,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
