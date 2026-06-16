from faster_whisper import WhisperModel
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from difflib import SequenceMatcher
from database import (
    create_tables,
    seed_levels,
    seed_reading_texts,
    seed_default_student,
    save_reading_session,
    get_all_sessions,
    get_reading_texts,
    get_students,
    get_levels,
    get_student_progress,
    get_texts_by_unlocked_levels,
    refresh_all_student_progress,
    get_home_summary,
    register_student_user,
    register_teacher_user,
    login_user,
)
from ml_report import build_student_report
import os
import shutil
import string
import wave
import math
import sys
import unicodedata
import tempfile
from array import array


try:
    from dotenv import load_dotenv

    load_dotenv()
except Exception as e:
    print("dotenv yuklenemedi:", e)


WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", os.getenv("WHISPER_MODEL", "base"))
WHISPER_DOWNLOAD_ROOT = os.getenv("WHISPER_DOWNLOAD_ROOT", "C:/HFCache")
WHISPER_LANGUAGE = os.getenv("WHISPER_LANGUAGE", "tr")
WHISPER_VAD_FILTER = os.getenv("WHISPER_VAD_FILTER", "false").lower() in ("1", "true", "yes", "on")
WHISPER_NO_SPEECH_THRESHOLD = float(os.getenv("WHISPER_NO_SPEECH_THRESHOLD", "0.6"))
WHISPER_SENSITIVE_NO_SPEECH_THRESHOLD = float(os.getenv("WHISPER_SENSITIVE_NO_SPEECH_THRESHOLD", "0.95"))
WHISPER_MAX_NO_SPEECH_PROB = float(os.getenv("WHISPER_MAX_NO_SPEECH_PROB", "0.6"))
WHISPER_SENSITIVE_MAX_NO_SPEECH_PROB = float(os.getenv("WHISPER_SENSITIVE_MAX_NO_SPEECH_PROB", "0.85"))
WHISPER_INITIAL_PROMPT = os.getenv(
    "WHISPER_INITIAL_PROMPT",
    "Kisa Turkce cocuk okuma metni. Turkce karakterleri dogru yaz: c, g, i, o, s, u.",
)
TARGET_AUDIO_RMS = float(os.getenv("TARGET_AUDIO_RMS", "1200"))
MAX_AUDIO_GAIN = float(os.getenv("MAX_AUDIO_GAIN", "8"))

ACTIVE_WHISPER_DEVICE = "unknown"
ACTIVE_WHISPER_COMPUTE_TYPE = "unknown"

app = FastAPI()

create_tables()
seed_levels()
seed_reading_texts()
seed_default_student()
refresh_all_student_progress()


def cuda_is_available():
    try:
        import ctranslate2

        return ctranslate2.get_cuda_device_count() > 0
    except Exception as e:
        print("CUDA kontrolu yapilamadi, CPU kullanilacak:", e)
        return False


def create_whisper_model():
    global ACTIVE_WHISPER_DEVICE, ACTIVE_WHISPER_COMPUTE_TYPE

    requested_device = os.getenv("WHISPER_DEVICE", "cpu").lower()
    requested_compute_type = os.getenv("WHISPER_COMPUTE_TYPE", "auto").lower()

    if requested_device == "auto":
        device = "cuda" if cuda_is_available() else "cpu"
    else:
        device = requested_device

    if requested_compute_type == "auto":
        compute_type = "float16" if device == "cuda" else "int8"
    else:
        compute_type = requested_compute_type

    try:
        print(
            "Whisper modeli yukleniyor:",
            WHISPER_MODEL_SIZE,
            "device=",
            device,
            "compute_type=",
            compute_type,
        )
        model_instance = WhisperModel(
            WHISPER_MODEL_SIZE,
            device=device,
            compute_type=compute_type,
            download_root=WHISPER_DOWNLOAD_ROOT,
        )
        ACTIVE_WHISPER_DEVICE = device
        ACTIVE_WHISPER_COMPUTE_TYPE = compute_type
        return model_instance
    except Exception as e:
        if requested_device == "auto" and device == "cuda":
            print("CUDA ile model yuklenemedi, CPU/int8 deneniyor:", e)
            model_instance = WhisperModel(
                WHISPER_MODEL_SIZE,
                device="cpu",
                compute_type="int8",
                download_root=WHISPER_DOWNLOAD_ROOT,
            )
            ACTIVE_WHISPER_DEVICE = "cpu"
            ACTIVE_WHISPER_COMPUTE_TYPE = "int8"
            return model_instance

        raise


model = create_whisper_model()


def should_retry_whisper_on_cpu(error):
    if ACTIVE_WHISPER_DEVICE != "cuda":
        return False

    message = str(error).lower()
    cuda_error_markers = ("cuda", "cublas", "cudnn")
    return any(marker in message for marker in cuda_error_markers)


def switch_whisper_to_cpu(reason):
    global model, ACTIVE_WHISPER_DEVICE, ACTIVE_WHISPER_COMPUTE_TYPE

    print("CUDA transcribe hatasi, CPU/int8 modele geciliyor:", reason)
    model = WhisperModel(
        WHISPER_MODEL_SIZE,
        device="cpu",
        compute_type="int8",
        download_root=WHISPER_DOWNLOAD_ROOT,
    )
    ACTIVE_WHISPER_DEVICE = "cpu"
    ACTIVE_WHISPER_COMPUTE_TYPE = "int8"

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


@app.get("/health")
def health():
    return {
        "status": "ok",
        "whisper_model": WHISPER_MODEL_SIZE,
        "whisper_device": ACTIVE_WHISPER_DEVICE,
        "whisper_compute_type": ACTIVE_WHISPER_COMPUTE_TYPE,
        "whisper_vad_filter": WHISPER_VAD_FILTER,
        "whisper_no_speech_threshold": WHISPER_NO_SPEECH_THRESHOLD,
        "whisper_sensitive_no_speech_threshold": WHISPER_SENSITIVE_NO_SPEECH_THRESHOLD,
        "whisper_max_no_speech_prob": WHISPER_MAX_NO_SPEECH_PROB,
        "whisper_sensitive_max_no_speech_prob": WHISPER_SENSITIVE_MAX_NO_SPEECH_PROB,
        "whisper_language": WHISPER_LANGUAGE,
    }


@app.post("/upload-audio")
async def upload_audio(
    audio: UploadFile = File(...),
    reference_text: str = Form(...)
):
    audio_bytes = await audio.read()

    return {
        "message": "Ses dosyası başarıyla alındı",
        "filename": audio.filename,
        "size": len(audio_bytes),
        "reference_text": reference_text
    }


def clean_text(text: str) -> str:
    """
    Metni karşılaştırmaya hazır hale getirir.
    Büyük/küçük harf farkını kaldırır.
    Noktalama işaretlerini temizler.
    """
    text = normalize_turkish_text(text)
    text = text.lower()
    text = unicodedata.normalize("NFKD", text).replace("\u0307", "")
    text = unicodedata.normalize("NFC", text)
    text = text.translate(str.maketrans("", "", string.punctuation))
    return text.strip()


def normalize_turkish_text(text: str) -> str:
    replacements = {
        "ţ": "ş",
        "Ţ": "Ş",
        "þ": "ş",
        "Þ": "Ş",
        "ð": "ğ",
        "Ð": "Ğ",
        "ý": "ı",
        "Ý": "İ",
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    return unicodedata.normalize("NFKC", text).strip()


def text_similarity(reference_text: str, transcript: str) -> float:
    reference = clean_text(reference_text)
    candidate = clean_text(transcript)

    if not reference or not candidate:
        return 0

    return SequenceMatcher(None, reference, candidate).ratio()


def words_are_close(reference_word: str, student_word: str) -> bool:
    if reference_word == student_word:
        return True

    similarity = SequenceMatcher(None, reference_word, student_word).ratio()

    # Short words are very sensitive to ASR consonant drift, e.g. bak -> pak.
    if (
        len(reference_word) == len(student_word)
        and len(reference_word) <= 4
        and len(reference_word) >= 3
        and reference_word[1:] == student_word[1:]
    ):
        return True

    # Whisper can insert a short sound into very short child-reading words.
    if (
        len(student_word) == len(reference_word) + 1
        and reference_word
        and student_word
        and student_word[0] == reference_word[0]
        and student_word[-1] == reference_word[-1]
        and similarity >= 0.78
    ):
        return True

    if len(reference_word) >= 4 and similarity >= 0.84:
        return True

    return False


def repair_joined_student_words(reference_words, student_words):
    repaired_words = []
    reference_index = 0

    for student_word in student_words:
        matched_joined_word = False
        max_span = min(4, len(reference_words) - reference_index)

        for span in range(max_span, 1, -1):
            reference_chunk = reference_words[reference_index:reference_index + span]
            joined_reference = "".join(reference_chunk)
            similarity = SequenceMatcher(None, joined_reference, student_word).ratio()

            if student_word == joined_reference or similarity >= 0.90:
                repaired_words.extend(reference_chunk)
                reference_index += span
                matched_joined_word = True
                break

        if matched_joined_word:
            continue

        if reference_index < len(reference_words):
            max_backtrack = min(2, reference_index)

            for backtrack in range(max_backtrack, 0, -1):
                prefix = "".join(reference_words[reference_index - backtrack:reference_index])

                if not student_word.startswith(prefix):
                    continue

                tail = student_word[len(prefix):]

                if tail and words_are_close(reference_words[reference_index], tail):
                    repaired_words.append(reference_words[reference_index])
                    reference_index += 1
                    matched_joined_word = True
                    break

        if matched_joined_word:
            continue

        repaired_words.append(student_word)

        if (
            reference_index < len(reference_words)
            and words_are_close(reference_words[reference_index], student_word)
        ):
            reference_index += 1

    return repaired_words


def looks_like_whisper_hallucination(transcript: str) -> bool:
    text = clean_text(transcript)
    hallucination_markers = (
        "sesli betimleme",
        "trt tarafından",
        "trt tarafindan",
        "altyazı",
        "altyazi",
        "izlediğiniz için teşekkürler",
        "izlediginiz icin tesekkurler",
    )

    return any(marker in text for marker in hallucination_markers)


def analyze_letters(reference_word: str, student_word: str):
    reference_letters = list(normalize_turkish_text(reference_word).lower())
    student_letters = list(normalize_turkish_text(student_word).lower())
    n = len(reference_letters)
    m = len(student_letters)
    dp = [[0] * (m + 1) for _ in range(n + 1)]

    for i in range(1, n + 1):
        dp[i][0] = i

    for j in range(1, m + 1):
        dp[0][j] = j

    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if reference_letters[i - 1] == student_letters[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + cost,
            )

    i = n
    j = m
    analysis = []

    while i > 0 or j > 0:
        if i > 0 and j > 0 and reference_letters[i - 1] == student_letters[j - 1]:
            analysis.append({
                "reference_letter": reference_letters[i - 1],
                "student_letter": student_letters[j - 1],
                "status": "correct",
            })
            i -= 1
            j -= 1
        elif i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + 1:
            analysis.append({
                "reference_letter": reference_letters[i - 1],
                "student_letter": student_letters[j - 1],
                "status": "wrong",
            })
            i -= 1
            j -= 1
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            analysis.append({
                "reference_letter": reference_letters[i - 1],
                "student_letter": "",
                "status": "missing",
            })
            i -= 1
        else:
            analysis.append({
                "reference_letter": "",
                "student_letter": student_letters[j - 1],
                "status": "extra",
            })
            j -= 1

    analysis.reverse()
    return analysis


def build_word_feedback(item):
    status = item["status"]

    if status == "correct":
        return "Bu kelime doğru okundu."

    if status == "missing":
        return f"'{item['reference_word']}' kelimesi atlanmış olabilir. Bu kelimeyi tane tane tekrar okuyalım."

    if status == "extra":
        return f"'{item['student_word']}' kelimesi metinde yok. Okurken sadece ekrandaki kelimelere odaklanalım."

    focus_letters = []
    for letter_item in item.get("letter_analysis", []):
        if letter_item["status"] in ("wrong", "missing"):
            letter = letter_item["reference_letter"]
            if letter and letter not in focus_letters:
                focus_letters.append(letter)

    if focus_letters:
        letters = ", ".join(focus_letters[:3])
        return f"Bu kelimede {letters} sesine dikkat edelim. Kelimeyi yavaşça heceleyerek tekrar oku."

    return "Bu kelime biraz farklı algılandı. Kelimeyi daha yavaş ve net okumayı deneyelim."


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
            if words_are_close(reference_words[i - 1], student_words[j - 1]):
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
        if i > 0 and j > 0 and words_are_close(reference_words[i - 1], student_words[j - 1]):
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
    raw_student_words = clean_text(student_text).split()
    student_words = repair_joined_student_words(reference_words, raw_student_words)

    analysis = align_words(reference_words, student_words)

    for item in analysis:
        if item["status"] == "wrong":
            item["letter_analysis"] = analyze_letters(
                item["reference_word"],
                item["student_word"],
            )
        else:
            item["letter_analysis"] = []

        item["feedback"] = build_word_feedback(item)

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
        wer = min(100, wer)
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

def calculate_audio_rms(file_path):
    try:
        with wave.open(file_path, "rb") as wav_file:
            frames = wav_file.readframes(wav_file.getnframes())

            if wav_file.getsampwidth() != 2:
                return -1

            samples = array("h")
            samples.frombytes(frames)

            if sys.byteorder == "big":
                samples.byteswap()

            if len(samples) == 0:
                return 0

            rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
            return round(rms, 2)

    except Exception as e:
        print("Ses seviyesi ölçülemedi:", e)
        return -1

def calculate_audio_stats(file_path):
    stats = {
        "sample_rate": None,
        "channels": None,
        "sample_width": None,
        "duration_seconds": 0,
        "rms": -1,
        "peak": -1,
        "gain_applied": 1,
        "normalized": False,
    }

    try:
        with wave.open(file_path, "rb") as wav_file:
            stats["sample_rate"] = wav_file.getframerate()
            stats["channels"] = wav_file.getnchannels()
            stats["sample_width"] = wav_file.getsampwidth()
            frame_count = wav_file.getnframes()
            if stats["sample_rate"]:
                stats["duration_seconds"] = round(frame_count / stats["sample_rate"], 2)

            frames = wav_file.readframes(frame_count)

            if wav_file.getsampwidth() != 2:
                return stats

            samples = array("h")
            samples.frombytes(frames)

            if sys.byteorder == "big":
                samples.byteswap()

            if not samples:
                stats["rms"] = 0
                stats["peak"] = 0
                return stats

            rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
            stats["rms"] = round(rms, 2)
            stats["peak"] = max(abs(sample) for sample in samples)
            return stats

    except Exception as e:
        print("Ses seviyesi olculemedi:", e)
        return stats


def normalize_audio_if_quiet(file_path, audio_stats):
    rms = audio_stats.get("rms", -1)

    if audio_stats.get("sample_width") != 2 or rms <= 0 or rms >= TARGET_AUDIO_RMS:
        return file_path, audio_stats

    try:
        with wave.open(file_path, "rb") as source:
            params = source.getparams()
            frames = source.readframes(source.getnframes())

        samples = array("h")
        samples.frombytes(frames)

        if sys.byteorder == "big":
            samples.byteswap()

        gain = min(TARGET_AUDIO_RMS / rms, MAX_AUDIO_GAIN)
        boosted_samples = array(
            "h",
            (
                max(-32768, min(32767, int(sample * gain)))
                for sample in samples
            ),
        )

        if sys.byteorder == "big":
            boosted_samples.byteswap()

        normalized_path = os.path.splitext(file_path)[0] + "_normalized.wav"
        with wave.open(normalized_path, "wb") as target:
            target.setparams(params)
            target.writeframes(boosted_samples.tobytes())

        normalized_stats = calculate_audio_stats(normalized_path)
        normalized_stats["gain_applied"] = round(gain, 2)
        normalized_stats["normalized"] = True
        print("Dusuk ses normalize edildi:", normalized_stats)

        return normalized_path, normalized_stats

    except Exception as e:
        print("Ses normalize edilemedi:", e)
        return file_path, audio_stats


def run_whisper_transcribe(file_path, vad_filter, options):
    no_speech_threshold = options.get("no_speech_threshold", WHISPER_NO_SPEECH_THRESHOLD)
    log_prob_threshold = options.get("log_prob_threshold")
    compression_ratio_threshold = options.get("compression_ratio_threshold")

    transcribe_kwargs = {
        "language": WHISPER_LANGUAGE,
        "beam_size": 5,
        "vad_filter": vad_filter,
        "no_speech_threshold": no_speech_threshold,
        "condition_on_previous_text": False,
        "initial_prompt": WHISPER_INITIAL_PROMPT,
    }

    if log_prob_threshold is not None:
        transcribe_kwargs["log_prob_threshold"] = log_prob_threshold

    if compression_ratio_threshold is not None:
        transcribe_kwargs["compression_ratio_threshold"] = compression_ratio_threshold

    segments, info = model.transcribe(
        file_path,
        **transcribe_kwargs,
    )
    segments = list(segments)
    return segments, info


def transcript_from_segments(segments, max_no_speech_prob):
    accepted_segments = []
    rejected_segments = []

    for segment in segments:
        no_speech_prob = getattr(segment, "no_speech_prob", None)
        if no_speech_prob is not None and no_speech_prob > max_no_speech_prob:
            rejected_segments.append({
                "text": segment.text.strip(),
                "no_speech_prob": round(no_speech_prob, 3),
                "avg_logprob": round(getattr(segment, "avg_logprob", 0), 3),
            })
            continue

        accepted_segments.append(normalize_turkish_text(segment.text.strip()))

    if rejected_segments:
        print("No-speech segmentleri elendi:", rejected_segments)

    transcript = " ".join(accepted_segments).strip()
    return transcript


def segment_average(segments, field_name, default=0):
    values = [
        getattr(segment, field_name)
        for segment in segments
        if getattr(segment, field_name, None) is not None
    ]

    if not values:
        return default

    return sum(values) / len(values)


def build_transcript_candidate(file_path, vad_filter, reference_text, options):
    try:
        segments, info = run_whisper_transcribe(file_path, vad_filter, options)
    except RuntimeError as e:
        if not should_retry_whisper_on_cpu(e):
            raise

        switch_whisper_to_cpu(e)
        segments, info = run_whisper_transcribe(file_path, vad_filter, options)

    transcript = transcript_from_segments(
        segments,
        options.get("max_no_speech_prob", WHISPER_MAX_NO_SPEECH_PROB),
    )
    similarity = text_similarity(reference_text, transcript)
    avg_no_speech_prob = segment_average(segments, "no_speech_prob", 1)
    avg_logprob = segment_average(segments, "avg_logprob", -2)
    hallucination = looks_like_whisper_hallucination(transcript)

    score = (
        (similarity * 3)
        + max(avg_logprob, -2)
        - (avg_no_speech_prob * 0.75)
        - (3 if hallucination else 0)
    )

    candidate = {
        "label": options["label"],
        "transcript": transcript,
        "info": info,
        "score": score,
        "similarity": similarity,
        "avg_no_speech_prob": avg_no_speech_prob,
        "avg_logprob": avg_logprob,
        "hallucination": hallucination,
        "segment_count": len(segments),
    }

    print("Whisper adayi:", {
        "label": candidate["label"],
        "transcript": candidate["transcript"],
        "score": round(candidate["score"], 3),
        "similarity": round(candidate["similarity"], 3),
        "avg_no_speech_prob": round(candidate["avg_no_speech_prob"], 3),
        "avg_logprob": round(candidate["avg_logprob"], 3),
        "hallucination": candidate["hallucination"],
        "segment_count": candidate["segment_count"],
    })

    return candidate


def candidate_is_usable(candidate):
    if not candidate["transcript"]:
        return False

    if candidate["hallucination"]:
        return False

    if candidate["avg_no_speech_prob"] > 0.7 and candidate["similarity"] < 0.25:
        return False

    return True


def transcribe_audio_file(file_path, vad_filter, reference_text=""):
    options_list = [
        {
            "label": "normal",
            "no_speech_threshold": WHISPER_NO_SPEECH_THRESHOLD,
            "max_no_speech_prob": WHISPER_MAX_NO_SPEECH_PROB,
        },
        {
            "label": "sensitive",
            "no_speech_threshold": WHISPER_SENSITIVE_NO_SPEECH_THRESHOLD,
            "max_no_speech_prob": WHISPER_SENSITIVE_MAX_NO_SPEECH_PROB,
            "log_prob_threshold": -2.0,
            "compression_ratio_threshold": 10.0,
        },
    ]

    candidates = [
        build_transcript_candidate(file_path, vad_filter, reference_text, options)
        for options in options_list
    ]

    usable_candidates = [
        candidate for candidate in candidates if candidate_is_usable(candidate)
    ]

    if not usable_candidates:
        return "", candidates[-1]["info"]

    best_candidate = max(usable_candidates, key=lambda candidate: candidate["score"])
    return best_candidate["transcript"], best_candidate["info"]


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
    reference_text: str = Form(...),
    student_id: int = Form(1),
    text_id: int = Form(None)
):
    """
    Flutter'dan gelen ses dosyasını alır.
    Local faster-whisper ile metne çevirir.
    Çıkan metni referans metinle karşılaştırır.
    WAR / WER ve kelime analizini döndürür.
    """

    suffix = os.path.splitext(audio.filename or "reading_audio.wav")[1] or ".wav"
    cleanup_paths = []
    audio_stats = {}

    with tempfile.NamedTemporaryFile(
        delete=False,
        suffix=suffix,
        prefix="reading_audio_",
    ) as temp_file:
        shutil.copyfileobj(audio.file, temp_file)
        file_path = temp_file.name

    cleanup_paths.append(file_path)

    print("Gelen ses dosyası:", file_path)
    print("Dosya boyutu:", os.path.getsize(file_path), "byte")
    audio_stats = calculate_audio_stats(file_path)
    print("Ses istatistikleri:", audio_stats)
    try:
        transcript, info = transcribe_audio_file(
            file_path,
            vad_filter=WHISPER_VAD_FILTER,
            reference_text=reference_text,
        )

        if not transcript:
            normalized_path, normalized_stats = normalize_audio_if_quiet(
                file_path,
                audio_stats,
            )

            if normalized_path != file_path:
                cleanup_paths.append(normalized_path)
                transcript, info = transcribe_audio_file(
                    normalized_path,
                    vad_filter=False,
                    reference_text=reference_text,
                )
                audio_stats = normalized_stats

        print("Whisper transcript:", transcript)

        comparison = compare_texts(reference_text, transcript)

        session_result = save_reading_session(
            student_id=student_id,
            text_id=text_id,
            student_name="Gülhan Test Öğrencisi",
            reference_text=reference_text,
            transcript=transcript,
            war=comparison["war"],
            wer=comparison["wer"],
            correct_count=comparison["correct_count"],
            substitution_count=comparison["substitution_count"],
            deletion_count=comparison["deletion_count"],
            insertion_count=comparison["insertion_count"],
            duration_seconds=audio_stats.get("duration_seconds", 0),
        )

        ml_report = build_student_report(student_id)
        ml_summary = ml_report["summary"]
        ml_recommendation = ml_report["recommendation"]


        return {
            "session_id": session_result["session_id"],
            "stars": session_result["stars"],
            "passed": session_result["passed"],
            "level_progress": session_result["level_progress"],
            "message": "Ses başarıyla analiz edildi",
            "reference_text": reference_text,
            "transcript": transcript,
            "war": comparison["war"],
            "wer": comparison["wer"],
            "correct_count": comparison["correct_count"],
            "substitution_count": comparison["substitution_count"],
            "deletion_count": comparison["deletion_count"],
            "insertion_count": comparison["insertion_count"],
            "word_analysis": comparison["analysis"],
            "ml_prediction": {
                "model_type": ml_report["model"]["type"],
                "trained": ml_report["model"]["trained"],
                "risk": ml_summary["risk"],
                "latest_pass_probability": ml_summary["latest_pass_probability"],
                "progress_label": ml_summary["progress_label"],
                "next_text_difficulty": ml_recommendation["next_text_difficulty"],
                "focus_letters": ml_recommendation["focus_letters"],
            },
            "audio_debug": audio_stats
        }

    except Exception as e:
        print("Analyze audio error:", str(e))
        return {
            "message": "Ses analiz edilirken hata oluştu",
            "error": str(e),
            "audio_debug": audio_stats
    }
    finally:
        for cleanup_path in cleanup_paths:
            try:
                if cleanup_path and os.path.exists(cleanup_path):
                    os.remove(cleanup_path)
            except Exception as cleanup_error:
                print("Gecici ses dosyasi silinemedi:", cleanup_path, cleanup_error)

@app.get("/students")
def students():
    return {
        "students": get_students()
    }


@app.get("/levels")
def levels():
    return {
        "levels": get_levels()
    }


@app.get("/sessions")
def sessions():
    return {
        "sessions": get_all_sessions()
    }


@app.get("/student-progress/{student_id}")
def student_progress(student_id: int):
    return {
        "progress": get_student_progress(student_id)
    }


@app.get("/student-texts/{student_id}")
def student_texts(student_id: int):
    return {
        "texts": get_texts_by_unlocked_levels(student_id)
    }

@app.get("/home-summary/{student_id}")
def home_summary(student_id: int):
    return {
        "summary": get_home_summary(student_id)
    }


@app.get("/student-report/{student_id}")
def student_report(student_id: int):
    return {
        "report": build_student_report(student_id)
    }

@app.post("/auth/register/student")
def register_student(
    full_name: str = Form(...),
    email: str = Form(...),
    identifier: str = Form(...),
    age: int = Form(...),
    grade: str = Form(...),
    password: str = Form(...)
):
    try:
        student = register_student_user(
            full_name=full_name,
            email=email,
            identifier=identifier,
            age=age,
            grade=grade,
            password=password
        )

        return {
            "message": "Öğrenci kaydı oluşturuldu.",
            "role": "student",
            "student": student
        }

    except Exception as e:
        return {
            "error": str(e)
        }


@app.post("/auth/register/teacher")
def register_teacher(
    full_name: str = Form(...),
    email: str = Form(...),
    identifier: str = Form(...),
    branch: str = Form(...),
    password: str = Form(...)
):
    try:
        teacher = register_teacher_user(
            full_name=full_name,
            email=email,
            identifier=identifier,
            branch=branch,
            password=password
        )

        return {
            "message": "Öğretmen kaydı oluşturuldu.",
            "role": "teacher",
            "teacher": teacher
        }

    except Exception as e:
        return {
            "error": str(e)
        }


@app.post("/auth/login")
def auth_login(
    role: str = Form(...),
    login_identifier: str = Form(...),
    password: str = Form(...)
):
    try:
        result = login_user(
            role=role,
            login_identifier=login_identifier,
            password=password
        )

        return {
            "message": "Giriş başarılı.",
            "role": role,
            "user": result["user"],
            "student": result["student"],
            "teacher": result["teacher"]
        }

    except Exception as e:
        return {
            "error": str(e)
        }
