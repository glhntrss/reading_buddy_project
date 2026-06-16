from pathlib import Path
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Flowable,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
OUTPUT = ROOT / "output" / "pdf" / "sistemin_gerceklenmesi_bulgular.pdf"

sys.path.insert(0, str(BACKEND))

from database import get_connection  # noqa: E402


def register_fonts():
    regular = Path("C:/Windows/Fonts/arial.ttf")
    bold = Path("C:/Windows/Fonts/arialbd.ttf")

    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont("Arial", str(regular)))
        pdfmetrics.registerFont(TTFont("Arial-Bold", str(bold)))
        return "Arial", "Arial-Bold"

    return "Helvetica", "Helvetica-Bold"


FONT, FONT_BOLD = register_fonts()


def get_project_stats():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT COUNT(*) AS count FROM reading_texts")
    total_texts = cursor.fetchone()["count"]

    cursor.execute(
        """
        SELECT level_id, COUNT(*) AS count
        FROM reading_texts
        GROUP BY level_id
        ORDER BY level_id
        """
    )
    level_counts = [(row["level_id"], row["count"]) for row in cursor.fetchall()]

    cursor.execute("SELECT COUNT(*) AS count FROM reading_sessions")
    total_sessions = cursor.fetchone()["count"]

    cursor.execute(
        """
        SELECT
            AVG(war) AS avg_war,
            AVG(wer) AS avg_wer,
            AVG(stars) AS avg_stars,
            SUM(passed) AS passed_count
        FROM reading_sessions
        """
    )
    summary = cursor.fetchone()

    cursor.execute(
        """
        SELECT reference_text, transcript, war, wer, stars, passed
        FROM reading_sessions
        ORDER BY id DESC
        LIMIT 5
        """
    )
    latest_sessions = [dict(row) for row in cursor.fetchall()]

    cursor.execute(
        """
        SELECT level_id, title, level, content, target_skill, word_count
        FROM reading_texts
        ORDER BY level_id ASC, id ASC
        LIMIT 8
        """
    )
    sample_texts = [dict(row) for row in cursor.fetchall()]

    connection.close()

    return {
        "total_texts": total_texts,
        "level_counts": level_counts,
        "total_sessions": total_sessions,
        "avg_war": summary["avg_war"] or 0,
        "avg_wer": summary["avg_wer"] or 0,
        "avg_stars": summary["avg_stars"] or 0,
        "passed_count": summary["passed_count"] or 0,
        "latest_sessions": latest_sessions,
        "sample_texts": sample_texts,
    }


class BoxFlow(Flowable):
    def __init__(self, width, height, boxes, arrows=None, title=None):
        super().__init__()
        self.width = width
        self.height = height
        self.boxes = boxes
        self.arrows = arrows or []
        self.title = title

    def wrap(self, avail_width, avail_height):
        return min(self.width, avail_width), self.height

    def draw_box(self, canvas, box):
        x, y, w, h = box["rect"]
        fill = box.get("fill", colors.white)
        stroke = box.get("stroke", colors.HexColor("#5B54A6"))
        canvas.setFillColor(fill)
        canvas.setStrokeColor(stroke)
        canvas.setLineWidth(1.1)
        canvas.roundRect(x, y, w, h, 8, fill=1, stroke=1)
        canvas.setFillColor(box.get("text_color", colors.HexColor("#20202A")))
        canvas.setFont(FONT_BOLD, box.get("font_size", 9))

        lines = box["text"].split("\n")
        start_y = y + h - 14 if len(lines) > 1 else y + h / 2 + 3
        for index, line in enumerate(lines):
            font = FONT_BOLD if index == 0 else FONT
            size = box.get("font_size", 9) if index == 0 else box.get("sub_size", 7.5)
            canvas.setFont(font, size)
            canvas.drawCentredString(x + w / 2, start_y - index * 11, line)

    def draw_arrow(self, canvas, arrow):
        x1, y1, x2, y2 = arrow
        canvas.setStrokeColor(colors.HexColor("#6C63FF"))
        canvas.setFillColor(colors.HexColor("#6C63FF"))
        canvas.setLineWidth(1.2)
        canvas.line(x1, y1, x2, y2)

        if abs(x2 - x1) >= abs(y2 - y1):
            direction = 1 if x2 >= x1 else -1
            canvas.line(x2, y2, x2 - direction * 6, y2 + 4)
            canvas.line(x2, y2, x2 - direction * 6, y2 - 4)
        else:
            direction = 1 if y2 >= y1 else -1
            canvas.line(x2, y2, x2 - 4, y2 - direction * 6)
            canvas.line(x2, y2, x2 + 4, y2 - direction * 6)

    def draw(self):
        canvas = self.canv
        if self.title:
            canvas.setFont(FONT_BOLD, 10)
            canvas.setFillColor(colors.HexColor("#20202A"))
            canvas.drawString(0, self.height - 12, self.title)

        for arrow in self.arrows:
            self.draw_arrow(canvas, arrow)

        for box in self.boxes:
            self.draw_box(canvas, box)


class BarChartFlow(Flowable):
    def __init__(self, width, height, data, title, y_label):
        super().__init__()
        self.width = width
        self.height = height
        self.data = data
        self.title = title
        self.y_label = y_label

    def wrap(self, avail_width, avail_height):
        return min(self.width, avail_width), self.height

    def draw(self):
        canvas = self.canv
        canvas.setFillColor(colors.HexColor("#20202A"))
        canvas.setFont(FONT_BOLD, 10)
        canvas.drawString(0, self.height - 14, self.title)

        chart_x = 38
        chart_y = 28
        chart_w = self.width - 58
        chart_h = self.height - 58
        max_value = max(value for _, value in self.data) or 1

        canvas.setStrokeColor(colors.HexColor("#D9D6EA"))
        canvas.line(chart_x, chart_y, chart_x, chart_y + chart_h)
        canvas.line(chart_x, chart_y, chart_x + chart_w, chart_y)

        bar_gap = 16
        bar_w = (chart_w - bar_gap * (len(self.data) + 1)) / len(self.data)

        for index, (label, value) in enumerate(self.data):
            x = chart_x + bar_gap + index * (bar_w + bar_gap)
            h = (value / max_value) * (chart_h - 18)
            canvas.setFillColor(colors.HexColor("#6C63FF"))
            canvas.roundRect(x, chart_y, bar_w, h, 4, fill=1, stroke=0)

            canvas.setFillColor(colors.HexColor("#20202A"))
            canvas.setFont(FONT_BOLD, 8)
            canvas.drawCentredString(x + bar_w / 2, chart_y + h + 5, str(value))
            canvas.setFont(FONT, 8)
            canvas.drawCentredString(x + bar_w / 2, chart_y - 12, str(label))

        canvas.saveState()
        canvas.translate(10, chart_y + chart_h / 2)
        canvas.rotate(90)
        canvas.setFont(FONT, 7.5)
        canvas.setFillColor(colors.HexColor("#555555"))
        canvas.drawCentredString(0, 0, self.y_label)
        canvas.restoreState()


def make_architecture_diagram(width):
    box_w = 142
    box_h = 44
    x_left = 16
    x_mid = 190
    x_right = 364
    y_top = 170
    y_mid = 95
    y_low = 20

    boxes = [
        {
            "rect": (x_left, y_top, box_w, box_h),
            "text": "Flutter Mobil Uygulama\nAna sayfa, okuma, analiz",
            "fill": colors.HexColor("#EAF6FF"),
        },
        {
            "rect": (x_mid, y_top, box_w, box_h),
            "text": "FastAPI Backend\nSes alma ve API katmanı",
            "fill": colors.HexColor("#F0EEFF"),
        },
        {
            "rect": (x_right, y_top, box_w, box_h),
            "text": "faster-whisper\nKonuşmadan metne",
            "fill": colors.HexColor("#FFF4D8"),
        },
        {
            "rect": (x_mid, y_mid, box_w, box_h),
            "text": "Hata Analizi\nKelime ve harf düzeyi",
            "fill": colors.HexColor("#E9F8EF"),
        },
        {
            "rect": (x_left, y_low, box_w, box_h),
            "text": "SQLite Veritabanı\nOturum ve ilerleme",
            "fill": colors.HexColor("#FFF0F0"),
        },
        {
            "rect": (x_right, y_low, box_w, box_h),
            "text": "Raporlama\nGrafik ve geçmiş analiz",
            "fill": colors.HexColor("#F5F5F5"),
        },
    ]
    arrows = [
        (x_left + box_w, y_top + 22, x_mid, y_top + 22),
        (x_mid + box_w, y_top + 22, x_right, y_top + 22),
        (x_right + box_w / 2, y_top, x_mid + box_w / 2, y_mid + box_h),
        (x_mid + box_w / 2, y_mid, x_left + box_w / 2, y_low + box_h),
        (x_mid + box_w / 2, y_mid, x_right + box_w / 2, y_low + box_h),
    ]
    return BoxFlow(width, 230, boxes, arrows, "Şekil 4.1. Sistem mimarisi")


def make_workflow_diagram(width):
    labels = [
        "Metin Seçimi\nSeviye ve içerik",
        "Ses Kaydı\nMikrofon girişi",
        "Whisper\nTranskript",
        "Karşılaştırma\nWAR ve WER",
        "Geri Bildirim\nHata türleri",
        "İlerleme\nYıldız ve seviye",
    ]
    boxes = []
    arrows = []
    box_w = 75
    box_h = 48
    gap = 13
    y = 44
    x = 0

    for index, label in enumerate(labels):
        boxes.append(
            {
                "rect": (x, y, box_w, box_h),
                "text": label,
                "fill": colors.HexColor("#F7F5FF") if index % 2 == 0 else colors.HexColor("#EAF6FF"),
                "font_size": 7.7,
                "sub_size": 6.8,
            }
        )
        if index < len(labels) - 1:
            arrows.append((x + box_w, y + box_h / 2, x + box_w + gap - 3, y + box_h / 2))
        x += box_w + gap

    return BoxFlow(width, 118, boxes, arrows, "Şekil 4.2. Okuma oturumu iş akışı")


def make_database_diagram(width):
    boxes = [
        {
            "rect": (0, 130, 150, 62),
            "text": "students\nid, name, age, grade\ncurrent_level",
            "fill": colors.HexColor("#EAF6FF"),
        },
        {
            "rect": (190, 130, 150, 62),
            "text": "student_progress\nstudent_id, level_id\nbest_stars, is_completed",
            "fill": colors.HexColor("#F0EEFF"),
        },
        {
            "rect": (380, 130, 150, 62),
            "text": "levels\nid, title, description\nrequired_stars",
            "fill": colors.HexColor("#FFF4D8"),
        },
        {
            "rect": (380, 40, 150, 62),
            "text": "reading_texts\nlevel_id, content\ntarget_skill, word_count",
            "fill": colors.HexColor("#E9F8EF"),
        },
        {
            "rect": (95, 40, 185, 62),
            "text": "reading_sessions\nreference_text, transcript\nWAR, WER, stars, passed",
            "fill": colors.HexColor("#FFF0F0"),
        },
    ]
    arrows = [
        (150, 161, 190, 161),
        (340, 161, 380, 161),
        (455, 130, 455, 102),
        (380, 71, 280, 71),
        (95, 71, 75, 130),
    ]
    return BoxFlow(width, 205, boxes, arrows, "Şekil 4.3. Veritabanı mantıksal yapısı")


def make_metric_diagram(width):
    boxes = [
        {
            "rect": (18, 92, 135, 45),
            "text": "Referans Metin\nAli ata bak.",
            "fill": colors.HexColor("#EAF6FF"),
        },
        {
            "rect": (198, 92, 135, 45),
            "text": "Algılanan Metin\nali ata atapak",
            "fill": colors.HexColor("#FFF4D8"),
        },
        {
            "rect": (378, 92, 135, 45),
            "text": "Düzeltme\nata+pak -> bak",
            "fill": colors.HexColor("#F0EEFF"),
        },
        {
            "rect": (108, 22, 135, 45),
            "text": "Hata Analizi\nDoğru, yanlış, eksik",
            "fill": colors.HexColor("#FFF0F0"),
        },
        {
            "rect": (288, 22, 135, 45),
            "text": "Skor\nWAR, WER, yıldız",
            "fill": colors.HexColor("#E9F8EF"),
        },
    ]
    arrows = [
        (153, 114, 198, 114),
        (333, 114, 378, 114),
        (445, 92, 355, 67),
        (243, 44, 288, 44),
        (198, 92, 176, 67),
    ]
    return BoxFlow(width, 150, boxes, arrows, "Şekil 4.4. Hata analizi ve puanlama akışı")


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont(FONT, 8)
    canvas.setFillColor(colors.HexColor("#777777"))
    canvas.drawString(2 * cm, 1.15 * cm, "Yapay Zeka Destekli Okuma Arkadaşı")
    canvas.drawRightString(A4[0] - 2 * cm, 1.15 * cm, f"Sayfa {doc.page}")
    canvas.restoreState()


def p(text, style):
    return Paragraph(text, style)


def table_style(header=True):
    commands = [
        ("FONTNAME", (0, 0), (-1, -1), FONT),
        ("FONTSIZE", (0, 0), (-1, -1), 8.5),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#D8D5E8")),
        ("BACKGROUND", (0, 0), (-1, -1), colors.white),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    if header:
        commands += [
            ("FONTNAME", (0, 0), (-1, 0), FONT_BOLD),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#5B54A6")),
        ]
    return TableStyle(commands)


def build_pdf():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    stats = get_project_stats()

    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=2 * cm,
        leftMargin=2 * cm,
        topMargin=1.8 * cm,
        bottomMargin=1.8 * cm,
        title="Sistemin Gerçeklenmesi ve Bulgular",
        author="Okuma Arkadaşı Projesi",
    )

    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            "CoverTitle",
            fontName=FONT_BOLD,
            fontSize=20,
            leading=26,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#20202A"),
            spaceAfter=16,
        )
    )
    styles.add(
        ParagraphStyle(
            "CoverSubtitle",
            fontName=FONT,
            fontSize=12,
            leading=18,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#555555"),
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            "Heading1TR",
            fontName=FONT_BOLD,
            fontSize=16,
            leading=21,
            textColor=colors.HexColor("#20202A"),
            spaceBefore=10,
            spaceAfter=9,
        )
    )
    styles.add(
        ParagraphStyle(
            "Heading2TR",
            fontName=FONT_BOLD,
            fontSize=13,
            leading=18,
            textColor=colors.HexColor("#3A3478"),
            spaceBefore=9,
            spaceAfter=7,
        )
    )
    styles.add(
        ParagraphStyle(
            "BodyTR",
            fontName=FONT,
            fontSize=9.8,
            leading=14.2,
            alignment=TA_JUSTIFY,
            spaceAfter=7,
        )
    )
    styles.add(
        ParagraphStyle(
            "SmallTR",
            fontName=FONT,
            fontSize=8.3,
            leading=11.5,
            alignment=TA_LEFT,
            textColor=colors.HexColor("#444444"),
            spaceAfter=5,
        )
    )

    story = []
    content_width = A4[0] - 4 * cm

    story.append(Spacer(1, 2.1 * cm))
    story.append(p("4. SİSTEMİN GERÇEKLENMESİ VE BULGULAR", styles["CoverTitle"]))
    story.append(
        p(
            "Yapay Zeka Destekli Okuma Arkadaşı Uygulaması için tez kitapçığı bölüm taslağı",
            styles["CoverSubtitle"],
        )
    )
    story.append(
        p(
            "Bu belge, geliştirilen mobil uygulamanın çalışma mantığını, kullanılan yapay zeka katmanını, veri seti yapısını ve deneysel bulguları diyagramlar ve tablolar ile özetlemektedir.",
            styles["CoverSubtitle"],
        )
    )
    story.append(Spacer(1, 0.8 * cm))
    story.append(make_architecture_diagram(content_width))
    story.append(PageBreak())

    story.append(p("4. Sistemin Gerçeklenmesi ve Bulgular", styles["Heading1TR"]))
    story.append(
        p(
            "Bu çalışmada disleksi riski taşıyan veya okuma becerisini geliştirmesi hedeflenen çocuklara yönelik yapay zeka destekli bir okuma arkadaşı uygulaması geliştirilmiştir. Uygulama, mobil arayüz üzerinden seçilen okuma metnini öğrenciye sesli okutmakta, alınan ses kaydını backend tarafında konuşmadan metne dönüştürmekte ve elde edilen çıktıyı referans metin ile karşılaştırarak ayrıntılı okuma analizi üretmektedir.",
            styles["BodyTR"],
        )
    )
    story.append(
        p(
            "Sistem, Flutter tabanlı mobil uygulama, FastAPI tabanlı backend servisi, SQLite veritabanı ve faster-whisper tabanlı konuşma tanıma bileşenlerinden oluşmaktadır. Yapay zeka modeli bu proje kapsamında yeniden eğitilmemiştir; önceden eğitilmiş Whisper tabanlı model kullanılmış, projeye özgü katkı ise model çıktısının eğitimsel amaçla değerlendirilmesi, kelime ve harf düzeyinde hata analizi yapılması ve öğrenci ilerlemesinin oyunlaştırılmış biçimde izlenmesidir.",
            styles["BodyTR"],
        )
    )
    story.append(make_architecture_diagram(content_width))

    story.append(p("4.1 Uygulama Bileşenleri", styles["Heading2TR"]))
    components_table = Table(
        [
            ["Bileşen", "Görev"],
            ["Flutter mobil uygulama", "Ana sayfa, okuma ekranı, analiz sonucu, seviyeler ve profil ekranlarını sunar."],
            ["FastAPI backend", "Ses dosyasını alır, konuşma tanıma ve metin karşılaştırma işlemlerini yürütür."],
            ["faster-whisper", "Öğrencinin sesli okumasını Türkçe metne dönüştürür."],
            ["Hata analizi katmanı", "Doğru, yanlış, eksik ve fazla kelimeleri belirler; WAR ve WER hesaplar."],
            ["SQLite veritabanı", "Öğrenci, seviye, okuma metni, oturum ve ilerleme bilgilerini saklar."],
        ],
        colWidths=[4.2 * cm, 11.6 * cm],
        repeatRows=1,
    )
    components_table.setStyle(table_style())
    story.append(components_table)
    story.append(Spacer(1, 0.35 * cm))
    story.append(make_workflow_diagram(content_width))

    story.append(PageBreak())
    story.append(p("4.2 Okuma Oturumu İş Akışı", styles["Heading1TR"]))
    story.append(
        p(
            "Okuma oturumu, öğrencinin seviyesine uygun metnin seçilmesi ile başlar. Öğrenci metni sesli okuduktan sonra uygulama mikrofon üzerinden ses kaydı alır ve bu kayıt backend servisine gönderilir. Backend tarafında ses dosyası geçici olarak işlenir, faster-whisper modeli ile metne dönüştürülür ve elde edilen transkript referans metin ile karşılaştırılır.",
            styles["BodyTR"],
        )
    )
    story.append(
        p(
            "Karşılaştırma sonucunda doğru okunan kelimeler, hatalı algılanan kelimeler, atlanan kelimeler ve fazladan okunan kelimeler ayrıştırılır. Sistem ayrıca kısa çocuk okumasında sık görülen konuşma tanıma sapmalarını azaltmak amacıyla birleşik algılanan kelimeleri onarmaya ve küçük ASR hatalarını pedagojik olarak daha toleranslı değerlendirmeye çalışır.",
            styles["BodyTR"],
        )
    )
    story.append(make_metric_diagram(content_width))

    scoring_table = Table(
        [
            ["Başarı Durumu", "Koşul", "Yıldız", "Pedagojik Yorum"],
            ["Tam başarı", "WAR >= %90 ve WER <= %10", "3", "Öğrenci metni büyük ölçüde doğru okumuştur."],
            ["Geçer başarı", "WAR >= %66 ve WER <= %50", "2", "Özellikle 3 kelimelik cümlede 2 doğru kelime geçiş için yeterlidir."],
            ["Kısmi başarı", "WAR >= %33 ve WER <= %75", "1", "Öğrencinin tekrar çalışması önerilir."],
            ["Tekrar gerekli", "Diğer durumlar", "0", "Metin yeniden okutulur ve geri bildirim verilir."],
        ],
        colWidths=[3.2 * cm, 4.6 * cm, 2.0 * cm, 6.0 * cm],
        repeatRows=1,
    )
    scoring_table.setStyle(table_style())
    story.append(scoring_table)

    story.append(p("4.3 Veritabanı ve Veri Seti Yapısı", styles["Heading1TR"]))
    story.append(
        p(
            "Projede kullanılan veriler SQLite veritabanında saklanmaktadır. Okuma metinleri seviye, zorluk etiketi, hedef harfler, hedef beceri ve kelime sayısı bilgileri ile tutulmaktadır. Öğrencinin her okuma oturumu ise ayrı bir kayıt olarak saklanmakta; böylece geçmiş analizler birleştirilerek ilerleme raporu üretilebilmektedir.",
            styles["BodyTR"],
        )
    )
    story.append(make_database_diagram(content_width))

    story.append(PageBreak())
    story.append(p("4.4 Veri Seti Örnekleri", styles["Heading1TR"]))
    story.append(
        p(
            f"Uygulamada güncel veritabanı durumuna göre toplam {stats['total_texts']} okuma metni bulunmaktadır. Metinler 5 seviyeye ayrılmıştır ve seviyeler kısa kelime tanımadan akıcılık odaklı daha uzun metinlere doğru ilerlemektedir.",
            styles["BodyTR"],
        )
    )

    sample_rows = [["Seviye", "Başlık", "Metin", "Hedef Beceri", "Kelime"]]
    for row in stats["sample_texts"]:
        sample_rows.append(
            [
                str(row["level_id"]),
                row["title"],
                row["content"],
                row["target_skill"] or "-",
                str(row["word_count"] or "-"),
            ]
        )
    sample_table = Table(
        sample_rows,
        colWidths=[1.5 * cm, 4.0 * cm, 4.2 * cm, 4.3 * cm, 1.6 * cm],
        repeatRows=1,
    )
    sample_table.setStyle(table_style())
    story.append(sample_table)
    story.append(Spacer(1, 0.35 * cm))
    level_data = [(f"S{level}", count) for level, count in stats["level_counts"]]
    story.append(BarChartFlow(content_width, 185, level_data, "Şekil 4.5. Seviyelere göre okuma metni sayısı", "Metin sayısı"))

    story.append(PageBreak())
    story.append(p("4.5 Deneysel Sonuçlar", styles["Heading1TR"]))
    story.append(
        p(
            "Bu bölümde geliştirme sürecinde elde edilen ölçümler ve algoritmik doğrulama sonuçları sunulmaktadır. Verilen sonuçlar klinik geçerlik iddiası taşımamaktadır; sistemin teknik olarak çalıştığını, kayıtların veritabanında tutulduğunu ve metin karşılaştırma katmanının beklenen çıktıları ürettiğini göstermektedir. Daha kapsamlı bilimsel değerlendirme için çocuk katılımcılarla etik izinli ve kontrollü deneysel çalışma yürütülmelidir.",
            styles["BodyTR"],
        )
    )

    metric_table = Table(
        [
            ["Metrik", "Mevcut Değer", "Açıklama"],
            ["Okuma metni sayısı", str(stats["total_texts"]), "Veritabanında kayıtlı metin sayısı."],
            ["Okuma oturumu sayısı", str(stats["total_sessions"]), "Geliştirme sürecinde kaydedilen analiz oturumları."],
            ["Ortalama WAR", f"%{stats['avg_war']:.2f}", "Doğru okunan kelime oranı ortalaması."],
            ["Ortalama WER", f"%{stats['avg_wer']:.2f}", "Kelime hata oranı ortalaması."],
            ["Ortalama yıldız", f"{stats['avg_stars']:.2f}", "0 ile 3 arası puan ortalaması."],
            ["Başarılı oturum", str(stats["passed_count"]), "2 ve üzeri yıldız alan oturum sayısı."],
        ],
        colWidths=[4.0 * cm, 3.2 * cm, 8.6 * cm],
        repeatRows=1,
    )
    metric_table.setStyle(table_style())
    story.append(metric_table)

    story.append(p("4.5.1 Algoritmik Doğrulama Örnekleri", styles["Heading2TR"]))
    validation_table = Table(
        [
            ["Referans", "Algılanan", "WAR", "WER", "Yıldız", "Sonuç"],
            ["Ali ata bak.", "ali ata bak", "%100.00", "%0.00", "3", "Başarılı"],
            ["Ali ata bak.", "ali ata atapak", "%100.00", "%0.00", "3", "ASR birleşme hatası düzeltilmiştir."],
            ["Ali ata bak.", "ali ata", "%66.67", "%33.33", "2", "3 kelimede 2 doğru geçer kabul edilmiştir."],
            ["Ali ata bak.", "ali bak", "%66.67", "%33.33", "2", "Eksik kelimeye rağmen geçer başarı."],
        ],
        colWidths=[3.0 * cm, 3.4 * cm, 1.7 * cm, 1.7 * cm, 1.7 * cm, 4.3 * cm],
        repeatRows=1,
    )
    validation_table.setStyle(table_style())
    story.append(validation_table)

    story.append(PageBreak())
    story.append(p("4.5.2 Geliştirme Oturumlarından Örnek Kayıtlar", styles["Heading2TR"]))
    recent_rows = [["Referans Metin", "Algılanan Metin", "WAR", "WER", "Yıldız", "Durum"]]
    for row in stats["latest_sessions"]:
        recent_rows.append(
            [
                row["reference_text"],
                row["transcript"],
                f"%{row['war']:.2f}",
                f"%{row['wer']:.2f}",
                str(row["stars"]),
                "Geçti" if row["passed"] else "Tekrar",
            ]
        )
    recent_table = Table(
        recent_rows,
        colWidths=[4.0 * cm, 5.0 * cm, 1.7 * cm, 1.7 * cm, 1.5 * cm, 1.9 * cm],
        repeatRows=1,
    )
    recent_table.setStyle(table_style())
    story.append(recent_table)

    story.append(p("4.5.3 PCA ve Model Performansı Üzerine Değerlendirme", styles["Heading2TR"]))
    story.append(
        p(
            "Bu projede yeni bir sınıflandırma modeli eğitilmediği için PCA, model eğitim sürecinin zorunlu bir bileşeni olarak kullanılmamıştır. Bununla birlikte okuma oturumlarından elde edilen WAR, WER, doğru kelime sayısı, hata türleri, yıldız sayısı ve seviye bilgisi gibi sayısal özellikler ilerleyen çalışmalarda PCA ile iki boyuta indirgenebilir. Böylece başarılı ve başarısız okuma oturumlarının ölçülebilir özellikler üzerinden ayrışıp ayrışmadığı görselleştirilebilir.",
            styles["BodyTR"],
        )
    )
    story.append(
        p(
            "Model performansı açısından değerlendirildiğinde sistemin başarısı yalnızca konuşma tanıma modeline bağlı değildir. Whisper çıktısının çocuk sesi, düşük ses seviyesi, kısa heceler ve benzer sesler nedeniyle hatalı olabildiği görülmüştür. Bu nedenle proje kapsamında ham transkript doğrudan puanlanmamış; birleşik kelime onarımı, küçük ASR sapmalarına tolerans ve pedagojik yıldız eşiği gibi ek değerlendirme kuralları uygulanmıştır.",
            styles["BodyTR"],
        )
    )

    story.append(p("4.6 Bulguların Genel Yorumu", styles["Heading1TR"]))
    story.append(
        p(
            "Geliştirme sürecinde elde edilen bulgular, sistemin kısa ve net okumalarda referans metni yüksek doğrulukla eşleştirebildiğini göstermektedir. Buna karşın çocuk sesi, kısa sözcükler ve mikrofona bağlı değişkenler konuşma tanıma çıktısını etkileyebilmektedir. Bu durum, uygulamanın yalnızca otomatik transkripsiyona dayalı katı bir ölçme sistemi olarak değil, öğretici geri bildirim üreten destekleyici bir eğitim aracı olarak konumlandırılmasının daha uygun olduğunu göstermektedir.",
            styles["BodyTR"],
        )
    )
    story.append(
        p(
            "Sonuç olarak geliştirilen sistem, öğrencinin okuma denemelerini kaydeden, yapay zeka destekli biçimde metne dönüştüren, kelime ve harf düzeyinde hata analizi yapan ve öğrencinin seviye ilerlemesini izleyen bütünleşik bir prototip sunmaktadır. Gelecek çalışmalarda daha geniş çocuk sesi veri seti, öğretmen onaylı hata etiketleri ve kontrollü kullanıcı testleri ile sistemin doğruluk ve pedagojik etkililik düzeyi daha ayrıntılı biçimde ölçülebilir.",
            styles["BodyTR"],
        )
    )

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(OUTPUT)


if __name__ == "__main__":
    build_pdf()
