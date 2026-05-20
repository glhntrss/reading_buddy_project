from faster_whisper import WhisperModel
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from database import create_tables, save_reading_session, get_all_sessions

import os
import shutil
import string


app = FastAPI()

create_tables()

model = WhisperModel(
    "tiny",
    device="cpu",
    compute_type="int8",
    download_root="C:/HFCache"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.get("/")
def home():
    return {"message": "Reading Buddy backend çalışıyor"}


@app.post("/upload-audio")
async def upload_audio(
    audio: UploadFile = File(...),
    reference_text: str = Form(...)
):
    file_path = os.path.join(UPLOAD_DIR, audio.filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    return {
        "message": "Ses dosyası başarıyla alındı",
        "filename": audio.filename,
        "reference_text": reference_text
    }


def clean_text(text: str) -> str:
    """
    Metni karşılaştırmaya hazır hale getirir.
    Büyük/küçük harf farkını kaldırır.
    Noktalama işaretlerini temizler.
    """
    text = text.lower()
    text = text.translate(str.maketrans("", "", string.punctuation))
    return text.strip()


def align_words(reference_words, student_words):
    """
    Referans metin ile öğrencinin okuduğu metni kelime bazlı hizalar.
    Bu yöntem insertion, deletion ve substitution hatalarını daha doğru yakalar.
    """

    n = len(reference_words)
    m = len(student_words)

    # dp[i][j] = reference_words[:i] ile student_words[:j] arasındaki minimum hata maliyeti
    dp = [[0] * (m + 1) for _ in range(n + 1)]

    # İlk sütun: öğrencinin hiç kelime okumaması durumu -> deletion
    for i in range(1, n + 1):
        dp[i][0] = i

    # İlk satır: öğrencinin fazladan kelime okuması durumu -> insertion
    for j in range(1, m + 1):
        dp[0][j] = j

    # Tabloyu dolduruyoruz
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            if reference_words[i - 1] == student_words[j - 1]:
                cost = 0
            else:
                cost = 1

            dp[i][j] = min(
                dp[i - 1][j] + 1,      # deletion: referanstaki kelime atlanmış
                dp[i][j - 1] + 1,      # insertion: öğrenci fazladan kelime okumuş
                dp[i - 1][j - 1] + cost  # correct veya substitution
            )

    # Şimdi sondan başa giderek hangi hataların yapıldığını çıkarıyoruz
    i = n
    j = m
    analysis = []

    while i > 0 or j > 0:
        # Doğru kelime
        if i > 0 and j > 0 and reference_words[i - 1] == student_words[j - 1]:
            analysis.append({
                "reference_word": reference_words[i - 1],
                "student_word": student_words[j - 1],
                "status": "correct"
            })
            i -= 1
            j -= 1

        # Yanlış okuma / substitution
        elif i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + 1:
            analysis.append({
                "reference_word": reference_words[i - 1],
                "student_word": student_words[j - 1],
                "status": "wrong"
            })
            i -= 1
            j -= 1

        # Atlanan kelime / deletion
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            analysis.append({
                "reference_word": reference_words[i - 1],
                "student_word": "",
                "status": "missing"
            })
            i -= 1

        # Fazladan okunan kelime / insertion
        else:
            analysis.append({
                "reference_word": "",
                "student_word": student_words[j - 1],
                "status": "extra"
            })
            j -= 1

    analysis.reverse()
    return analysis


def compare_texts(reference_text: str, student_text: str):
    """
    Referans metin ile öğrencinin okuduğu metni karşılaştırır.
    Doğru, yanlış, eksik ve fazladan okunan kelimeleri bulur.
    WAR ve WER değerlerini hesaplar.
    """

    reference_words = clean_text(reference_text).split()
    student_words = clean_text(student_text).split()

    analysis = align_words(reference_words, student_words)

    correct_count = 0
    substitution_count = 0
    deletion_count = 0
    insertion_count = 0

    for item in analysis:
        if item["status"] == "correct":
            correct_count += 1
        elif item["status"] == "wrong":
            substitution_count += 1
        elif item["status"] == "missing":
            deletion_count += 1
        elif item["status"] == "extra":
            insertion_count += 1

    total_reference_words = len(reference_words)

    if total_reference_words > 0:
        war = round((correct_count / total_reference_words) * 100, 2)
        wer = round(
            ((substitution_count + deletion_count + insertion_count) / total_reference_words) * 100,
            2
        )
    else:
        war = 0
        wer = 0

    return {
        "war": war,
        "wer": wer,
        "correct_count": correct_count,
        "substitution_count": substitution_count,
        "deletion_count": deletion_count,
        "insertion_count": insertion_count,
        "analysis": analysis
    }

@app.post("/compare-text")
async def compare_text(
    reference_text: str = Form(...),
    student_text: str = Form(...)
):
    comparison = compare_texts(reference_text, student_text)

    return {
        "reference_text": reference_text,
        "student_text": student_text,
        "war": comparison["war"],
        "wer": comparison["wer"],
        "correct_count": comparison["correct_count"],
        "substitution_count": comparison["substitution_count"],
        "deletion_count": comparison["deletion_count"],
        "insertion_count": comparison["insertion_count"],
        "word_analysis": comparison["analysis"]
    }
@app.post("/analyze-audio")
async def analyze_audio(
    audio: UploadFile = File(...),
    reference_text: str = Form(...)
):
    """
    Flutter'dan gelen ses dosyasını alır.
    Local faster-whisper ile metne çevirir.
    Çıkan metni referans metinle karşılaştırır.
    WAR / WER ve kelime analizini döndürür.
    """

    file_path = os.path.join(UPLOAD_DIR, audio.filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    try:
        segments, info = model.transcribe(
            file_path,
            language="tr",
            beam_size=5
        )

        transcript = " ".join(segment.text.strip() for segment in segments).strip()

        comparison = compare_texts(reference_text, transcript)

        save_reading_session(
            student_name="Gülhan Test Öğrencisi",
            reference_text=reference_text,
            transcript=transcript,
            war=comparison["war"],
            wer=comparison["wer"],
            correct_count=comparison["correct_count"],
            substitution_count=comparison["substitution_count"],
            deletion_count=comparison["deletion_count"],
            insertion_count=comparison["insertion_count"]
        )

        return {
            "message": "Ses başarıyla analiz edildi",
            "reference_text": reference_text,
            "transcript": transcript,
            "war": comparison["war"],
            "wer": comparison["wer"],
            "correct_count": comparison["correct_count"],
            "substitution_count": comparison["substitution_count"],
            "deletion_count": comparison["deletion_count"],
            "insertion_count": comparison["insertion_count"],
            "word_analysis": comparison["analysis"]
        }

    except Exception as e:
        return {
            "message": "Ses analiz edilirken hata oluştu",
            "error": str(e)
        }
@app.get("/sessions")
def sessions():
    return {
    "sessions": get_all_sessions()
}