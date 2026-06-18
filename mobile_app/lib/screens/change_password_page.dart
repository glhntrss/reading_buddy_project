import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ChangePasswordPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const ChangePasswordPage({super.key, required this.student});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const Color primaryColor = Color(0xFF6C63FF);

  final formKey = GlobalKey<FormState>();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isSaving = false;
  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  int studentId() {
    final rawId = widget.student["id"];
    if (rawId is int) return rawId;
    return int.tryParse(rawId.toString()) ?? 1;
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> savePassword() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      isSaving = true;
    });

    try {
      await ApiService.changeStudentPassword(
        studentId: studentId(),
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      showMessage(e.toString().replaceFirst("Exception: ", ""));
    }

    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: obscureText ? "Şifreyi göster" : "Şifreyi gizle",
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7FF),
      appBar: AppBar(
        title: const Text("Şifremi Değiştir"),
        centerTitle: true,
        backgroundColor: const Color(0xFFFCF7FF),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.14),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.shield_outlined, color: primaryColor),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        "Hesabın güvenliği için önce mevcut şifreni doğrulayalım.",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              buildPasswordField(
                controller: currentPasswordController,
                label: "Mevcut Şifre",
                obscureText: obscureCurrent,
                onToggle: () {
                  setState(() {
                    obscureCurrent = !obscureCurrent;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Mevcut şifre boş bırakılamaz.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              buildPasswordField(
                controller: newPasswordController,
                label: "Yeni Şifre",
                obscureText: obscureNew,
                onToggle: () {
                  setState(() {
                    obscureNew = !obscureNew;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Yeni şifre boş bırakılamaz.";
                  }
                  if (value.trim().length < 4) {
                    return "Yeni şifre en az 4 karakter olmalı.";
                  }
                  if (value == currentPasswordController.text) {
                    return "Yeni şifre mevcut şifreden farklı olmalı.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              buildPasswordField(
                controller: confirmPasswordController,
                label: "Yeni Şifre Tekrar",
                obscureText: obscureConfirm,
                textInputAction: TextInputAction.done,
                onToggle: () {
                  setState(() {
                    obscureConfirm = !obscureConfirm;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Yeni şifre tekrar boş bırakılamaz.";
                  }
                  if (value != newPasswordController.text) {
                    return "Yeni şifreler aynı olmalı.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: isSaving ? null : savePassword,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(isSaving ? "Güncelleniyor..." : "Şifreyi Güncelle"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
