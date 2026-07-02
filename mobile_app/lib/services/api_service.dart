import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static String baseUrl = "http://localhost:8000";

  static Future<List<dynamic>> getStudents() async {
    final response = await http
        .get(Uri.parse("$baseUrl/students"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["students"] ?? [];
    }

    throw Exception("Öğrenciler alınamadı: ${response.body}");
  }

  static Future<Map<String, dynamic>> updateStudentProfile({
    required int studentId,
    required String fullName,
    required String email,
    required String identifier,
    required int age,
    required String grade,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/students/$studentId/profile"),
          body: {
            "full_name": fullName,
            "email": email,
            "identifier": identifier,
            "age": age.toString(),
            "grade": grade,
          },
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["error"] == null) {
      return data["student"] ?? {};
    }

    throw Exception(data["error"] ?? "Profil güncellenemedi.");
  }

  static Future<Map<String, dynamic>> updateStudentAvatar({
    required int studentId,
    required String avatarAsset,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/students/$studentId/avatar"),
          body: {"avatar_asset": avatarAsset},
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["error"] == null) {
      return data["student"] ?? {};
    }

    throw Exception(data["error"] ?? "Avatar güncellenemedi.");
  }

  static Future<void> changeStudentPassword({
    required int studentId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/students/$studentId/password"),
          body: {
            "current_password": currentPassword,
            "new_password": newPassword,
          },
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["error"] == null) {
      return;
    }

    throw Exception(data["error"] ?? "Şifre güncellenemedi.");
  }

  static Future<Map<String, dynamic>> loginUser({
    required String role,
    required String loginIdentifier,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/auth/login"),
          body: {
            "role": role,
            "login_identifier": loginIdentifier,
            "password": password,
          },
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["error"] == null) {
      return data;
    }

    throw Exception(data["error"] ?? "Giriş başarısız.");
  }

  static Future<Map<String, dynamic>> registerStudentUser({
    required String fullName,
    required String email,
    required String identifier,
    required int age,
    required String grade,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/auth/register/student"),
          body: {
            "full_name": fullName,
            "email": email,
            "identifier": identifier,
            "age": age.toString(),
            "grade": grade,
            "password": password,
          },
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["error"] == null) {
      return data;
    }

    throw Exception(data["error"] ?? "Öğrenci kaydı oluşturulamadı.");
  }

  static Future<Map<String, dynamic>> registerTeacherUser({
    required String fullName,
    required String email,
    required String identifier,
    required String branch,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/auth/register/teacher"),
          body: {
            "full_name": fullName,
            "email": email,
            "identifier": identifier,
            "branch": branch,
            "password": password,
          },
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["error"] == null) {
      return data;
    }

    throw Exception(data["error"] ?? "Öğretmen kaydı oluşturulamadı.");
  }

  static Future<List<dynamic>> getStudentTexts(int studentId) async {
    final response = await http
        .get(Uri.parse("$baseUrl/student-texts/$studentId"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["texts"] ?? [];
    }

    throw Exception("Okuma metinleri alınamadı: ${response.body}");
  }

  static Future<List<dynamic>> getReadingTexts() async {
    final response = await http
        .get(Uri.parse("$baseUrl/reading-texts"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["texts"] ?? [];
    }

    throw Exception("Okuma metinleri alınamadı: ${response.body}");
  }

  static Future<List<dynamic>> getAssignments({
    int? teacherId,
    int? studentId,
  }) async {
    final query = <String, String>{};
    if (teacherId != null) query["teacher_id"] = teacherId.toString();
    if (studentId != null) query["student_id"] = studentId.toString();

    final uri = Uri.parse(
      "$baseUrl/assignments",
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["assignments"] ?? [];
    }

    throw Exception("Ödevler alınamadı: ${response.body}");
  }

  static Future<Map<String, dynamic>> createAssignment({
    required int teacherId,
    required int studentId,
    required int textId,
    String dueDate = "",
    String note = "",
  }) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/assignments"),
          body: {
            "teacher_id": teacherId.toString(),
            "student_id": studentId.toString(),
            "text_id": textId.toString(),
            "due_date": dueDate,
            "note": note,
          },
        )
        .timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["error"] == null) {
      return data["assignment"] ?? {};
    }

    throw Exception(data["error"] ?? "Ödev atanamadı.");
  }

  static Future<List<dynamic>> getStudentProgress(int studentId) async {
    final response = await http
        .get(Uri.parse("$baseUrl/student-progress/$studentId"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["progress"] ?? [];
    }

    throw Exception("Seviye bilgileri alınamadı: ${response.body}");
  }

  static Future<List<dynamic>> getSessions() async {
    final response = await http
        .get(Uri.parse("$baseUrl/sessions"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["sessions"] ?? [];
    }

    throw Exception("Raporlar alınamadı: ${response.body}");
  }

  static Future<Map<String, dynamic>> getStudentReport(int studentId) async {
    final response = await http
        .get(Uri.parse("$baseUrl/student-report/$studentId"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["report"] ?? {};
    }

    throw Exception("Öğrenci raporu alınamadı: ${response.body}");
  }

  static Future<Map<String, dynamic>> analyzeAudio({
    required String audioPath,
    required String referenceText,
    required int studentId,
    int? textId,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/analyze-audio"),
    );

    request.files.add(await http.MultipartFile.fromPath("audio", audioPath));

    request.fields["reference_text"] = referenceText;
    request.fields["student_id"] = studentId.toString();

    if (textId != null) {
      request.fields["text_id"] = textId.toString();
    }

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      return jsonDecode(responseBody);
    }

    throw Exception("Ses analizi başarısız: $responseBody");
  }

  static Future<Map<String, dynamic>> getHomeSummary(int studentId) async {
    final response = await http
        .get(Uri.parse("$baseUrl/home-summary/$studentId"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["summary"] ?? {};
    }

    throw Exception("Ana sayfa özeti alınamadı: ${response.body}");
  }
}
