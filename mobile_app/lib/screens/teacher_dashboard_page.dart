import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_logo_header.dart';
import 'auth_page.dart';
import 'student_report_page.dart';

class TeacherDashboardPage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherDashboardPage({super.key, required this.teacher});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color softLilac = Color(0xFFF1EFFF);

  bool isLoading = true;
  String? errorMessage;
  List<dynamic> students = [];
  List<dynamic> readingTexts = [];
  List<dynamic> assignments = [];

  int get teacherId => widget.teacher["id"] ?? 1;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final loadedStudents = await ApiService.getStudents();
      final loadedTexts = await ApiService.getReadingTexts();
      final loadedAssignments = await ApiService.getAssignments(
        teacherId: teacherId,
      );

      if (!mounted) return;
      setState(() {
        students = loadedStudents;
        readingTexts = loadedTexts;
        assignments = loadedAssignments;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  List<dynamic> assignmentsForStudent(int studentId) {
    return assignments.where((item) {
      if (item is! Map) return false;
      return item["student_id"] == studentId;
    }).toList();
  }

  int completedAssignmentCount(int studentId) {
    return assignmentsForStudent(studentId).where((item) {
      if (item is! Map) return false;
      return item["status"] == "completed";
    }).length;
  }

  Future<void> openAssignmentSheet(Map<String, dynamic> student) async {
    if (readingTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ödev vermek için önce okuma metni gerekir."),
        ),
      );
      return;
    }

    int selectedTextId = readingTexts.first["id"] ?? 0;
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    final noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "${student["name"] ?? "Öğrenci"} için ödev",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedTextId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Okuma metni",
                      border: OutlineInputBorder(),
                    ),
                    items: readingTexts.map((item) {
                      final map = item is Map ? item : {};
                      final id = map["id"] ?? 0;
                      final title = map["title"] ?? "Okuma metni";
                      final content = map["content"] ?? "";
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          "$title - $content",
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedTextId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 120)),
                      );

                      if (selectedDate != null) {
                        setSheetState(() {
                          dueDate = selectedDate;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Teslim tarihi",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(formatDate(dueDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Öğretmen notu",
                      hintText:
                          "Örn. Metni iki kez oku ve zorlandığın kelimeleri işaretle.",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_turned_in),
                    label: const Text("Ödevi Ata"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(sheetContext);
                      final messenger = ScaffoldMessenger.of(this.context);

                      try {
                        await ApiService.createAssignment(
                          teacherId: teacherId,
                          studentId: student["id"] ?? 1,
                          textId: selectedTextId,
                          dueDate: formatDate(dueDate),
                          note: noteController.text.trim(),
                        );

                        await loadDashboard();

                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Ödev başarıyla atandı."),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text("Ödev atanamadı: $e")),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, "0");
    final day = date.day.toString().padLeft(2, "0");
    return "${date.year}-$month-$day";
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildHeader() {
    final teacherName = widget.teacher["name"] ?? "Öğretmen";

    return Container(
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
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            teacherName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            widget.teacher["branch"] ?? "Branş bilgisi yok",
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget buildStudentsSection() {
    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text("Henüz kayıtlı öğrenci bulunmuyor."),
      );
    }

    return Column(
      children: students.map((item) {
        final student = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        final studentId = student["id"] ?? 0;
        final assignedCount = assignmentsForStudent(studentId).length;
        final completedCount = completedAssignmentCount(studentId);

        return _StudentCard(
          student: student,
          assignedCount: assignedCount,
          completedCount: completedCount,
          onReportTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    StudentReportPage(studentId: studentId, teacherView: true),
              ),
            );
          },
          onAssignTap: () => openAssignmentSheet(student),
        );
      }).toList(),
    );
  }

  Widget buildAssignmentsSection() {
    if (assignments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text("Henüz verilmiş ödev bulunmuyor."),
      );
    }

    return Column(
      children: assignments.take(6).map((item) {
        final map = item is Map ? item : {};
        final completed = map["status"] == "completed";

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: completed
                  ? Colors.green.withValues(alpha: 0.35)
                  : primaryColor.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: completed
                    ? const Color(0xFFE8F8EF)
                    : softLilac,
                child: Icon(
                  completed ? Icons.check : Icons.menu_book,
                  color: completed ? Colors.green : primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map["student_name"] ?? "Öğrenci",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      map["text_title"] ?? "Okuma metni",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Teslim: ${map["due_date"]?.toString().isEmpty == false ? map["due_date"] : "-"}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                completed ? "Tamamlandı" : "Bekliyor",
                style: TextStyle(
                  color: completed ? Colors.green : primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildContent() {
    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildHeader(),
                const SizedBox(height: 22),
                sectionTitle("Öğrenciler"),
                buildStudentsSection(),
                const SizedBox(height: 24),
                sectionTitle("Verilen Ödevler"),
                buildAssignmentsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: 82,
        backgroundColor: const Color(0xFFFCF7FF),
        elevation: 0,
        title: const AppLogoHeader(height: 58),
        actions: [
          IconButton(
            tooltip: "Çıkış Yap",
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: loadDashboard,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              ),
            )
          : buildContent(),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final int assignedCount;
  final int completedCount;
  final VoidCallback onReportTap;
  final VoidCallback onAssignTap;

  const _StudentCard({
    required this.student,
    required this.assignedCount,
    required this.completedCount,
    required this.onReportTap,
    required this.onAssignTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF1EFFF),
                child: Icon(Icons.person, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student["name"] ?? "Öğrenci",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${student["grade"] ?? "Sınıf bilgisi yok"} • Seviye ${student["current_level"] ?? 1}",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$completedCount / $assignedCount ödev tamamlandı",
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReportTap,
                  icon: const Icon(Icons.bar_chart),
                  label: const Text("Rapor"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAssignTap,
                  icon: const Icon(Icons.assignment),
                  label: const Text("Ödev Ver"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
