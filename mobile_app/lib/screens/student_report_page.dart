import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/stat_card.dart';

class StudentReportPage extends StatefulWidget {
  final int? studentId;
  final bool teacherView;

  const StudentReportPage({
    super.key,
    this.studentId,
    this.teacherView = false,
  });

  @override
  State<StudentReportPage> createState() => _StudentReportPageState();
}

class _StudentReportPageState extends State<StudentReportPage> {
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color deepLilac = Color(0xFF5B4BC4);
  static const Color softLilac = Color(0xFFF1EFFF);

  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? report;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    try {
      int studentId = widget.studentId ?? 1;

      if (widget.studentId == null) {
        final students = await ApiService.getStudents();
        if (students.isNotEmpty) {
          studentId = students.first["id"] ?? 1;
        }
      }

      final data = await ApiService.getStudentReport(studentId);

      setState(() {
        report = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  Map<String, dynamic> get summary {
    final data = report?["summary"];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Map<String, dynamic> get model {
    final data = report?["model"];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Map<String, dynamic> get recommendation {
    final data = report?["recommendation"];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Map<String, dynamic> get charts {
    final data = report?["charts"];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  List<dynamic> get sessions {
    final data = report?["sessions"];
    if (data is List) return data;
    return [];
  }

  List<dynamic> get featureImportance {
    final data = model["feature_importance"];
    if (data is List) return data;
    return [];
  }

  double numberValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double percentValue(dynamic value) {
    return numberValue(value).clamp(0.0, 100.0).toDouble();
  }

  String formatPercent(dynamic value) {
    final percent = percentValue(value);
    if (percent == percent.roundToDouble()) {
      return "%${percent.toStringAsFixed(0)}";
    }
    return "%${percent.toStringAsFixed(1)}";
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildSuccessCard() {
    final successPercent = percentValue(summary["average_war"]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: softLilac,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph, color: deepLilac),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Öğrencinin Başarı Yüzdesi",
                  style: TextStyle(
                    color: deepLilac,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            formatPercent(successPercent),
            style: const TextStyle(
              color: deepLilac,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: successPercent / 100,
            minHeight: 9,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: const Color(0xFFE3DFFF),
            valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 12),
          Text(
            "Bir sonraki okuma önerisi: ${recommendation["next_text_difficulty"] ?? "-"}",
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            (recommendation["message"] ?? "").toString(),
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget buildFocusLetters() {
    final letters = recommendation["focus_letters"];
    final items = letters is List ? letters : [];

    if (items.isEmpty) {
      return const Text("Belirgin harf/ses zorlanması bulunmadı.");
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final map = item is Map ? item : {};
        return Chip(
          backgroundColor: softLilac,
          side: BorderSide(color: primaryColor.withValues(alpha: 0.25)),
          label: Text(
            "${map["letter"] ?? "-"} (${map["count"] ?? 0})",
            style: const TextStyle(
              color: deepLilac,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildFeatureImportance() {
    if (featureImportance.isEmpty) {
      return const Text("Başarı ölçütleri için yeterli veri yok.");
    }

    return Column(
      children: featureImportance.take(5).map((item) {
        final map = item is Map ? item : {};
        final value = numberValue(map["value"]).clamp(0.0, 1.0).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (map["label"] ?? "").toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text("%${(value * 100).toStringAsFixed(0)}"),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: const Color(0xFFE8E4FF),
                valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildSessionList() {
    if (sessions.isEmpty) {
      return const Text("Henüz okuma geçmişi bulunmuyor.");
    }

    return Column(
      children: sessions.take(6).map((item) {
        final map = item is Map ? item : {};
        final successPercent = percentValue(map["war"]);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (map["reference_text"] ?? "").toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Algılanan: ${map["transcript"] ?? "-"}",
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text("Başarı: ${formatPercent(map["war"])}")),
                  Expanded(child: Text("Hata: ${formatPercent(map["wer"])}")),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.insights, color: primaryColor, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Başarı yüzdesi ${formatPercent(successPercent)}",
                      style: const TextStyle(
                        color: deepLilac,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildBody() {
    final student = report?["student"];
    final studentMap =
        student is Map<String, dynamic> ? student : <String, dynamic>{};
    final modelTrained = model["trained"] == true;

    return RefreshIndicator(
      onRefresh: loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              studentMap["name"] ?? "Öğrenci Raporu",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              modelTrained
                  ? "Başarı modeli ${model["training_count"]} okuma kaydı ile hazırlandı."
                  : (model["note"] ?? "Model için yeterli veri yok.").toString(),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: "Okuma",
                    value: "${summary["total_sessions"] ?? 0}",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: "Başarılı Okuma",
                    value: "${summary["passed_sessions"] ?? 0}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: "Ortalama Başarı",
                    value: formatPercent(summary["average_war"]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    title: "Akıcılık",
                    value: "${summary["average_fluency_wpm"] ?? 0}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            buildSuccessCard(),
            const SizedBox(height: 18),
            sectionTitle("Zorlanılan Harf / Sesler"),
            buildFocusLetters(),
            const SizedBox(height: 22),
            sectionTitle("Hata Dağılımı"),
            _ChartPanel(
              child: _BarChart(
                data: charts["error_breakdown"] is List
                    ? charts["error_breakdown"]
                    : [],
              ),
            ),
            const SizedBox(height: 22),
            sectionTitle("Başarı Eğrisi"),
            _ChartPanel(
              child: _LineChart(
                data: charts["war_trend"] is List ? charts["war_trend"] : [],
              ),
            ),
            const SizedBox(height: 22),
            sectionTitle("Başarıyı Etkileyen Ölçütler"),
            buildFeatureImportance(),
            const SizedBox(height: 22),
            sectionTitle("Geçmiş Okuma Raporları"),
            buildSessionList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teacherView ? "Öğrenci Raporu" : "Okuma Raporu"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : buildBody(),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final Widget child;

  const _ChartPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<dynamic> data;

  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(data),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<dynamic> data;

  const _LineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(data),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<dynamic> data;

  _BarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6C63FF);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final values = data.map((item) {
      if (item is Map && item["value"] is num) {
        return (item["value"] as num).toDouble();
      }
      return 0.0;
    }).toList();

    final maxValue =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final chartHeight = size.height - 48;
    final barWidth =
        data.isEmpty ? 0.0 : (size.width - 18 * (data.length + 1)) / data.length;

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final value = values[index];
      final left = 18 + index * (barWidth + 18);
      final height = maxValue == 0 ? 0.0 : (value / maxValue) * chartHeight;
      final top = chartHeight - height;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          const Radius.circular(8),
        ),
        paint,
      );

      final label = item is Map ? (item["label"] ?? "").toString() : "";
      textPainter.text = TextSpan(
        text: label.split(" ").first,
        style: const TextStyle(fontSize: 10, color: Colors.black87),
      );
      textPainter.layout(maxWidth: barWidth + 16);
      textPainter.paint(canvas, Offset(left - 4, size.height - 34));

      textPainter.text = TextSpan(
        text: value.toInt().toString(),
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(left + barWidth / 2 - textPainter.width / 2, top - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _LineChartPainter extends CustomPainter {
  final List<dynamic> data;

  _LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = const Color(0xFF6C63FF);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    canvas.drawLine(
      Offset(0, size.height - 28),
      Offset(size.width, size.height - 28),
      axisPaint,
    );
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height - 28), axisPaint);

    if (data.isEmpty) {
      textPainter.text = const TextSpan(
        text: "Grafik için yeterli veri yok.",
        style: TextStyle(color: Colors.black54),
      );
      textPainter.layout(maxWidth: size.width);
      textPainter.paint(canvas, Offset(12, size.height / 2 - 10));
      return;
    }

    final points = <Offset>[];
    final usableHeight = size.height - 44;
    final stepX = data.length <= 1 ? size.width : size.width / (data.length - 1);

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final value = item is Map && item["value"] is num
          ? (item["value"] as num).toDouble().clamp(0.0, 100.0).toDouble()
          : 0.0;
      final x = index * stepX;
      final y = usableHeight - (value / 100.0) * usableHeight;
      points.add(Offset(x, y));
    }

    if (points.length == 1) {
      canvas.drawCircle(points.first, 5, pointPaint);
    } else {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(point, 4, pointPaint);
      final item = data[index];
      final label = item is Map ? (item["label"] ?? "").toString() : "";
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, size.height - 22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
