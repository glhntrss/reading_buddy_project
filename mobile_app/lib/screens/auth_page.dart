import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'main_navigation_page.dart';
import 'teacher_dashboard_page.dart';
import '../widgets/app_logo_header.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isStudentRole = true;
  bool isLoginMode = true;
  bool isSubmitting = false;
  bool obscurePassword = true;

  final TextEditingController loginIdentifierController =
      TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController gradeController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();

  @override
  void dispose() {
    loginIdentifierController.dispose();
    loginPasswordController.dispose();

    fullNameController.dispose();
    emailController.dispose();
    identifierController.dispose();
    ageController.dispose();
    gradeController.dispose();
    branchController.dispose();
    registerPasswordController.dispose();

    super.dispose();
  }

  String get selectedRole => isStudentRole ? "student" : "teacher";

  String get roleTitle => isStudentRole ? "Öğrenci" : "Öğretmen";

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void clearFields() {
    loginIdentifierController.clear();
    loginPasswordController.clear();

    fullNameController.clear();
    emailController.clear();
    identifierController.clear();
    ageController.clear();
    gradeController.clear();
    branchController.clear();
    registerPasswordController.clear();
  }

  void changeRole(bool studentSelected) {
    setState(() {
      isStudentRole = studentSelected;
      isLoginMode = true;
      clearFields();
    });
  }

  Future<void> login() async {
    final loginIdentifier = loginIdentifierController.text.trim();
    final password = loginPasswordController.text.trim();

    if (loginIdentifier.isEmpty || password.isEmpty) {
      showMessage("Lütfen giriş bilgilerini doldur.");
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await ApiService.loginUser(
        role: selectedRole,
        loginIdentifier: loginIdentifier,
        password: password,
      );

      if (!mounted) return;

      if (selectedRole == "student") {
        final student = result["student"];

        if (student == null) {
          showMessage("Öğrenci bilgisi bulunamadı.");
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigationPage(
              student: student,
            ),
          ),
        );
      } else {
        final teacher = result["teacher"];

        if (teacher == null) {
          showMessage("Öğretmen bilgisi bulunamadı.");
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherDashboardPage(
              teacher: teacher,
            ),
          ),
        );
      }
    } catch (e) {
      showMessage(e.toString().replaceFirst("Exception: ", ""));
    }

    if (mounted) {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Future<void> register() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final identifier = identifierController.text.trim();
    final password = registerPasswordController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        identifier.isEmpty ||
        password.isEmpty) {
      showMessage("Lütfen tüm zorunlu alanları doldur.");
      return;
    }

    if (password.length < 4) {
      showMessage("Şifre en az 4 karakter olmalı.");
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      if (selectedRole == "student") {
        final ageText = ageController.text.trim();
        final grade = gradeController.text.trim();

        if (ageText.isEmpty || grade.isEmpty) {
          showMessage("Lütfen yaş ve sınıf bilgisini doldur.");
          setState(() {
            isSubmitting = false;
          });
          return;
        }

        final age = int.tryParse(ageText);

        if (age == null) {
          showMessage("Yaş sayı olarak girilmeli.");
          setState(() {
            isSubmitting = false;
          });
          return;
        }

        final result = await ApiService.registerStudentUser(
          fullName: fullName,
          email: email,
          identifier: identifier,
          age: age,
          grade: grade,
          password: password,
        );

        final student = result["student"];

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigationPage(
              student: student,
            ),
          ),
        );
      } else {
        final branch = branchController.text.trim();

        if (branch.isEmpty) {
          showMessage("Lütfen branş bilgisini doldur.");
          setState(() {
            isSubmitting = false;
          });
          return;
        }

        final result = await ApiService.registerTeacherUser(
          fullName: fullName,
          email: email,
          identifier: identifier,
          branch: branch,
          password: password,
        );

        final teacher = result["teacher"];

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherDashboardPage(
              teacher: teacher,
            ),
          ),
        );
      }
    } catch (e) {
      showMessage(e.toString().replaceFirst("Exception: ", ""));
    }

    if (mounted) {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Widget roleSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RoleButton(
              title: "Öğrenci",
              icon: Icons.child_care,
              selected: isStudentRole,
              onTap: () => changeRole(true),
            ),
          ),
          Expanded(
            child: _RoleButton(
              title: "Öğretmen",
              icon: Icons.school,
              selected: !isStudentRole,
              onTap: () => changeRole(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget modeSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            setState(() {
              isLoginMode = true;
            });
          },
          child: Text(
            "Giriş Yap",
            style: TextStyle(
              fontWeight: isLoginMode ? FontWeight.bold : FontWeight.normal,
              color: isLoginMode
                  ? const Color(0xFF6C63FF)
                  : Colors.black54,
            ),
          ),
        ),
        const Text("|"),
        TextButton(
          onPressed: () {
            setState(() {
              isLoginMode = false;
            });
          },
          child: Text(
            "Kayıt Ol",
            style: TextStyle(
              fontWeight: !isLoginMode ? FontWeight.bold : FontWeight.normal,
              color: !isLoginMode
                  ? const Color(0xFF6C63FF)
                  : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget loginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "$roleTitle Girişi",
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          isStudentRole
              ? "Mail, öğrenci no veya kullanıcı ID ile giriş yap."
              : "Mail veya öğretmen ID ile giriş yap.",
          style: const TextStyle(
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 22),

        TextField(
          controller: loginIdentifierController,
          decoration: InputDecoration(
            labelText: isStudentRole
                ? "Mail / Öğrenci No / ID"
                : "Mail / Öğretmen ID",
            prefixIcon: const Icon(Icons.badge),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: loginPasswordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: "Şifre",
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
              icon: Icon(
                obscurePassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        const SizedBox(height: 22),

        ElevatedButton(
          onPressed: isSubmitting ? null : login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            isSubmitting ? "Giriş yapılıyor..." : "Giriş Yap",
          ),
        ),
      ],
    );
  }

  Widget registerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "$roleTitle Kaydı",
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          isStudentRole
              ? "Öğrenci profilini oluştur ve okuma yolculuğuna başla."
              : "Öğretmen hesabı oluştur ve öğrencileri takip et.",
          style: const TextStyle(
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 22),

        TextField(
          controller: fullNameController,
          decoration: InputDecoration(
            labelText: "Ad Soyad",
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: "Mail",
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: identifierController,
          decoration: InputDecoration(
            labelText: isStudentRole
                ? "Öğrenci No / Kullanıcı ID"
                : "Öğretmen ID",
            prefixIcon: const Icon(Icons.badge),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        const SizedBox(height: 14),

        if (isStudentRole)
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Yaş",
              prefixIcon: const Icon(Icons.cake),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),

        if (isStudentRole) const SizedBox(height: 14),

        if (isStudentRole)
          TextField(
            controller: gradeController,
            decoration: InputDecoration(
              labelText: "Sınıf",
              hintText: "Örn: 2. Sınıf",
              prefixIcon: const Icon(Icons.menu_book),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),

        if (!isStudentRole)
          TextField(
            controller: branchController,
            decoration: InputDecoration(
              labelText: "Branş / Ünvan",
              hintText: "Örn: Türkçe Öğretmeni",
              prefixIcon: const Icon(Icons.school),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),

        const SizedBox(height: 14),

        TextField(
          controller: registerPasswordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: "Şifre",
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
              icon: Icon(
                obscurePassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        const SizedBox(height: 22),

        ElevatedButton(
          onPressed: isSubmitting ? null : register,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            isSubmitting ? "Kaydediliyor..." : "Kayıt Ol",
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7FF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                const AppLogoHeader(
                  height: 200,

                ),

                const SizedBox(height: 14),

                
                const SizedBox(height: 8),

                const Text(
                  "Yapay zeka destekli okuma gelişim uygulaması",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 28),

                roleSwitch(),

                const SizedBox(height: 18),

                modeSwitch(),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: isLoginMode ? loginForm() : registerForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected
                  ? const Color(0xFF6C63FF)
                  : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected
                    ? const Color(0xFF6C63FF)
                    : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}