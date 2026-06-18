import 'package:flutter/material.dart';

import '../services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> student;

  const EditProfilePage({super.key, required this.student});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const Color primaryColor = Color(0xFF6C63FF);

  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController identifierController;
  late final TextEditingController ageController;
  late final TextEditingController gradeController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: (widget.student["name"] ?? "").toString(),
    );
    emailController = TextEditingController(
      text: (widget.student["email"] ?? "").toString(),
    );
    identifierController = TextEditingController(
      text: (widget.student["identifier"] ?? "").toString(),
    );
    ageController = TextEditingController(
      text: (widget.student["age"] ?? "").toString(),
    );
    gradeController = TextEditingController(
      text: (widget.student["grade"] ?? "").toString(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    identifierController.dispose();
    ageController.dispose();
    gradeController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String avatarAsset() {
    return (widget.student["avatar_asset"] ??
            "assets/images/avatars/avatar_1.png")
        .toString();
  }

  Future<void> saveProfile() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final age = int.tryParse(ageController.text.trim());
    if (age == null) {
      showMessage("Yaş sayısal olmalı.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final updatedStudent = await ApiService.updateStudentProfile(
        studentId: widget.student["id"] ?? 1,
        fullName: nameController.text.trim(),
        email: emailController.text.trim(),
        identifier: identifierController.text.trim(),
        age: age,
        grade: gradeController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, updatedStudent);
    } catch (e) {
      showMessage(e.toString().replaceFirst("Exception: ", ""));
    }

    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "$label boş bırakılamaz.";
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
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
        title: const Text("Profili Düzenle"),
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
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1EFFF),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.16),
                      width: 3,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    avatarAsset(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.person, size: 54, color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              buildField(
                controller: nameController,
                label: "İsim Soyisim",
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 14),
              buildField(
                controller: emailController,
                label: "Mail adresi",
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              buildField(
                controller: identifierController,
                label: "Öğrenci ID",
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              buildField(
                controller: ageController,
                label: "Yaş",
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              buildField(
                controller: gradeController,
                label: "Sınıf",
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Profili Güncelle"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
