import math
import string
import unicodedata
from collections import Counter, defaultdict

try:
    from database import get_connection
except ModuleNotFoundError:
    from .database import get_connection


FEATURES = [
    "war",
    "wer",
    "correct_count",
    "mispronunciation_count",
    "skipped_word_count",
    "extra_word_count",
    "level_id",
    "word_count",
    "duration_seconds",
    "fluency_wpm",
]

MODEL_FEATURES = [
    "correct_count",
    "mispronunciation_count",
    "skipped_word_count",
    "extra_word_count",
    "level_id",
    "word_count",
    "duration_seconds",
    "fluency_wpm",
]

FEATURE_LABELS = {
    "war": "Okuma başarısı",
    "wer": "Hata oranı",
    "correct_count": "Doğru okuma",
    "mispronunciation_count": "Yanlış telaffuz",
    "skipped_word_count": "Atlanan kelime",
    "extra_word_count": "Fazladan okuma",
    "level_id": "Seviye",
    "word_count": "Metin kelime sayısı",
    "duration_seconds": "Okuma süresi",
    "fluency_wpm": "Akıcılık",
}


def normalize_turkish_text(text):
    replacements = {
        "Å£": "ş",
        "Å¢": "Ş",
        "Ã¾": "ş",
        "Ã": "Ş",
        "Ã°": "ğ",
        "Ã": "Ğ",
        "Ã½": "ı",
        "Ã": "İ",
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    return unicodedata.normalize("NFKC", text).strip()


def clean_text(text):
    text = normalize_turkish_text(str(text or "")).lower()
    text = unicodedata.normalize("NFKD", text).replace("\u0307", "")
    text = unicodedata.normalize("NFC", text)
    text = text.translate(str.maketrans("", "", string.punctuation))
    return text.strip()


def safe_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def clamp_percentage(value):
    return max(0, min(100, round(safe_float(value, 0), 2)))


def safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def estimate_word_count(row):
    word_count = safe_int(row.get("word_count"), 0)
    if word_count > 0:
        return word_count

    return len(clean_text(row.get("reference_text", "")).split())


def session_to_features(row):
    word_count = max(estimate_word_count(row), 1)
    duration_seconds = safe_float(row.get("duration_seconds"), 0)
    fluency_wpm = 0

    if duration_seconds > 0:
        fluency_wpm = round((word_count / duration_seconds) * 60, 2)

    return {
        "war": clamp_percentage(row.get("war")),
        "wer": clamp_percentage(row.get("wer")),
        "correct_count": safe_float(row.get("correct_count"), 0),
        "mispronunciation_count": safe_float(row.get("substitution_count"), 0),
        "skipped_word_count": safe_float(row.get("deletion_count"), 0),
        "extra_word_count": safe_float(row.get("insertion_count"), 0),
        "level_id": safe_float(row.get("level_id"), 1),
        "word_count": safe_float(word_count, 0),
        "duration_seconds": duration_seconds,
        "fluency_wpm": fluency_wpm,
    }


def gini(rows):
    if not rows:
        return 0

    positives = sum(row["target"] for row in rows)
    p_positive = positives / len(rows)
    p_negative = 1 - p_positive
    return 1 - (p_positive * p_positive) - (p_negative * p_negative)


def class_probability(rows):
    if not rows:
        return 0.0

    return sum(row["target"] for row in rows) / len(rows)


def build_decision_tree(rows, depth=0, max_depth=4, min_samples_split=4):
    probability = class_probability(rows)
    prediction = 1 if probability >= 0.5 else 0

    node = {
        "samples": len(rows),
        "probability": round(probability, 4),
        "prediction": prediction,
        "feature": None,
        "threshold": None,
        "left": None,
        "right": None,
    }

    if (
        depth >= max_depth
        or len(rows) < min_samples_split
        or probability in (0, 1)
    ):
        return node

    parent_impurity = gini(rows)
    best = None

    for feature in MODEL_FEATURES:
        values = sorted({row["features"][feature] for row in rows})
        if len(values) <= 1:
            continue

        thresholds = [
            (values[index] + values[index + 1]) / 2
            for index in range(len(values) - 1)
        ]

        for threshold in thresholds:
            left = [row for row in rows if row["features"][feature] <= threshold]
            right = [row for row in rows if row["features"][feature] > threshold]

            if not left or not right:
                continue

            weighted_impurity = (
                (len(left) / len(rows)) * gini(left)
                + (len(right) / len(rows)) * gini(right)
            )
            gain = parent_impurity - weighted_impurity

            if best is None or gain > best["gain"]:
                best = {
                    "feature": feature,
                    "threshold": threshold,
                    "gain": gain,
                    "left": left,
                    "right": right,
                }

    if best is None or best["gain"] <= 0:
        return node

    node["feature"] = best["feature"]
    node["threshold"] = round(best["threshold"], 4)
    node["gain"] = round(best["gain"], 4)
    node["left"] = build_decision_tree(
        best["left"],
        depth=depth + 1,
        max_depth=max_depth,
        min_samples_split=min_samples_split,
    )
    node["right"] = build_decision_tree(
        best["right"],
        depth=depth + 1,
        max_depth=max_depth,
        min_samples_split=min_samples_split,
    )
    return node


def predict_with_tree(tree, features):
    node = tree
    path = []

    while node.get("feature"):
        feature = node["feature"]
        threshold = node["threshold"]
        value = features.get(feature, 0)
        go_left = value <= threshold
        path.append({
            "feature": feature,
            "label": FEATURE_LABELS.get(feature, feature),
            "threshold": threshold,
            "value": round(value, 2),
            "direction": "<=" if go_left else ">",
        })
        node = node["left"] if go_left else node["right"]

    probability = node.get("probability", 0)
    return {
        "passed_probability": round(probability, 3),
        "predicted_passed": 1 if probability >= 0.5 else 0,
        "path": path,
        "leaf_samples": node.get("samples", 0),
    }


def collect_split_importance(tree, counter=None):
    if counter is None:
        counter = Counter()

    feature = tree.get("feature")
    if not feature:
        return counter

    counter[feature] += tree.get("gain", 0.001)
    collect_split_importance(tree.get("left") or {}, counter)
    collect_split_importance(tree.get("right") or {}, counter)
    return counter


def tree_to_rules(tree, prefix=None):
    prefix = prefix or []

    if not tree.get("feature"):
        status = "başarılı okuma" if tree.get("prediction") == 1 else "destek gerekli"
        probability = round(tree.get("probability", 0) * 100, 1)
        return [
            {
                "conditions": prefix,
                "result": f"{status} - başarı yüzdesi %{probability}",
                "samples": tree.get("samples", 0),
            }
        ]

    feature = tree["feature"]
    label = FEATURE_LABELS.get(feature, feature)
    threshold = tree["threshold"]
    left_rules = tree_to_rules(
        tree["left"],
        prefix + [f"{label} <= {threshold}"],
    )
    right_rules = tree_to_rules(
        tree["right"],
        prefix + [f"{label} > {threshold}"],
    )
    return left_rules + right_rules


def risk_from_probability(probability):
    if probability < 0.45:
        return {
            "level": "high",
            "label": "Yoğun destek gerekli",
            "color": "purple",
            "score": round(probability * 100, 1),
        }

    if probability < 0.7:
        return {
            "level": "medium",
            "label": "Düzenli destekle gelişiyor",
            "color": "purple",
            "score": round(probability * 100, 1),
        }

    return {
        "level": "low",
        "label": "Bağımsız okumaya yakın",
        "color": "purple",
        "score": round(probability * 100, 1),
    }


def recommendation_from_risk(risk_level, average_war, recent_pass_rate):
    if risk_level == "high":
        return {
            "next_text_difficulty": "Kolay",
            "message": "Bir sonraki metin daha kısa ve daha az kelimeli olmalı.",
        }

    if risk_level == "medium" or average_war < 75 or recent_pass_rate < 0.6:
        return {
            "next_text_difficulty": "Aynı seviye",
            "message": "Öğrenci aynı zorlukta birkaç metin daha okuyarak pekiştirme yapmalı.",
        }

    return {
        "next_text_difficulty": "Biraz daha zor",
        "message": "Öğrenci kontrollü biçimde daha uzun veya daha zor metne geçebilir.",
    }


def progress_label(sessions):
    if not sessions:
        return "Yeterli veri yok"

    ordered = list(reversed(sessions))
    if len(ordered) < 4:
        return "Başlangıç düzeyi izleniyor"

    first_half = ordered[: max(1, len(ordered) // 2)]
    second_half = ordered[max(1, len(ordered) // 2):]
    first_avg = sum(safe_float(row.get("war"), 0) for row in first_half) / len(first_half)
    second_avg = sum(safe_float(row.get("war"), 0) for row in second_half) / len(second_half)

    if second_avg >= first_avg + 10:
        return "İlerleme iyi"
    if second_avg <= first_avg - 10:
        return "İlerleme zayıflıyor"
    return "İlerleme dengeli"


def align_words(reference_words, transcript_words):
    n = len(reference_words)
    m = len(transcript_words)
    dp = [[0] * (m + 1) for _ in range(n + 1)]

    for i in range(1, n + 1):
        dp[i][0] = i

    for j in range(1, m + 1):
        dp[0][j] = j

    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if reference_words[i - 1] == transcript_words[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + cost,
            )

    i = n
    j = m
    pairs = []

    while i > 0 or j > 0:
        if i > 0 and j > 0 and reference_words[i - 1] == transcript_words[j - 1]:
            pairs.append((reference_words[i - 1], transcript_words[j - 1], "correct"))
            i -= 1
            j -= 1
        elif i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + 1:
            pairs.append((reference_words[i - 1], transcript_words[j - 1], "wrong"))
            i -= 1
            j -= 1
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            pairs.append((reference_words[i - 1], "", "missing"))
            i -= 1
        else:
            pairs.append(("", transcript_words[j - 1], "extra"))
            j -= 1

    pairs.reverse()
    return pairs


def collect_weak_letters(sessions, limit=5):
    counter = Counter()

    for row in sessions:
        reference_words = clean_text(row.get("reference_text", "")).split()
        transcript_words = clean_text(row.get("transcript", "")).split()

        for reference_word, transcript_word, status in align_words(reference_words, transcript_words):
            if status == "correct":
                continue

            if status == "missing":
                counter.update(reference_word)
                continue

            if status == "wrong":
                max_len = max(len(reference_word), len(transcript_word))
                for index in range(max_len):
                    reference_letter = reference_word[index] if index < len(reference_word) else ""
                    transcript_letter = transcript_word[index] if index < len(transcript_word) else ""

                    if reference_letter and reference_letter != transcript_letter:
                        counter[reference_letter] += 1

    return [
        {
            "letter": letter,
            "count": count,
        }
        for letter, count in counter.most_common(limit)
        if letter.strip()
    ]


def get_training_rows():
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT
            rs.*,
            rt.level_id,
            rt.word_count,
            rt.target_letters,
            rt.target_skill,
            rt.level AS text_level,
            rt.title AS text_title
        FROM reading_sessions rs
        LEFT JOIN reading_texts rt
            ON rt.id = rs.text_id
        WHERE rs.passed IS NOT NULL
        ORDER BY rs.created_at ASC, rs.id ASC
        """
    )
    rows = [dict(row) for row in cursor.fetchall()]
    connection.close()
    return rows


def get_student_sessions(student_id):
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT
            rs.*,
            rt.level_id,
            rt.word_count,
            rt.target_letters,
            rt.target_skill,
            rt.level AS text_level,
            rt.title AS text_title
        FROM reading_sessions rs
        LEFT JOIN reading_texts rt
            ON rt.id = rs.text_id
        WHERE rs.student_id = ?
        ORDER BY rs.created_at DESC, rs.id DESC
        """,
        (student_id,),
    )
    rows = [dict(row) for row in cursor.fetchall()]
    connection.close()
    return rows


def get_student(student_id):
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM students WHERE id = ?", (student_id,))
    row = cursor.fetchone()
    connection.close()
    return dict(row) if row else None


def train_decision_tree():
    rows = get_training_rows()
    training_rows = [
        {
            "features": session_to_features(row),
            "target": 1 if safe_int(row.get("passed"), 0) == 1 else 0,
        }
        for row in rows
    ]

    if len(training_rows) < 4 or len({row["target"] for row in training_rows}) < 2:
        return {
            "trained": False,
            "training_count": len(training_rows),
            "tree": None,
            "accuracy": None,
            "feature_importance": [],
            "rules": [],
            "reason": "Karar ağacı için en az iki sınıftan yeterli oturum kaydı gerekir.",
        }

    tree = build_decision_tree(training_rows)
    correct = 0

    for row in training_rows:
        prediction = predict_with_tree(tree, row["features"])
        if prediction["predicted_passed"] == row["target"]:
            correct += 1

    importance_counter = collect_split_importance(tree)
    total_importance = sum(importance_counter.values()) or 1
    importance = [
        {
            "feature": feature,
            "label": FEATURE_LABELS.get(feature, feature),
            "value": round(value / total_importance, 3),
        }
        for feature, value in importance_counter.most_common()
    ]

    return {
        "trained": True,
        "training_count": len(training_rows),
        "tree": tree,
        "accuracy": round(correct / len(training_rows), 3),
        "feature_importance": importance,
        "rules": tree_to_rules(tree)[:8],
        "reason": None,
    }


def prediction_for_session(row, model=None):
    model = model or train_decision_tree()
    features = session_to_features(row)

    if model["trained"]:
        prediction = predict_with_tree(model["tree"], features)
    else:
        probability = max(0, min(1, safe_float(row.get("war"), 0) / 100))
        prediction = {
            "passed_probability": round(probability, 3),
            "predicted_passed": 1 if probability >= 0.66 else 0,
            "path": [],
            "leaf_samples": 0,
        }

    risk = risk_from_probability(prediction["passed_probability"])
    prediction["risk"] = risk
    prediction["features"] = features
    return prediction


def error_breakdown(sessions):
    totals = {
        "Yanlış Telaffuz": 0,
        "Atlanan Kelime": 0,
        "Fazladan Okuma": 0,
        "Doğru Okuma": 0,
    }

    for row in sessions:
        totals["Yanlış Telaffuz"] += safe_int(row.get("substitution_count"), 0)
        totals["Atlanan Kelime"] += safe_int(row.get("deletion_count"), 0)
        totals["Fazladan Okuma"] += safe_int(row.get("insertion_count"), 0)
        totals["Doğru Okuma"] += safe_int(row.get("correct_count"), 0)

    return [
        {"label": label, "value": value}
        for label, value in totals.items()
    ]


def star_distribution(sessions):
    counter = Counter(safe_int(row.get("stars"), 0) for row in sessions)
    return [
        {"label": f"{star} yıldız", "value": counter.get(star, 0)}
        for star in range(4)
    ]


def trend_rows(sessions, field_name):
    ordered = list(reversed(sessions[:10]))
    return [
        {
            "label": str(index + 1),
            "value": (
                clamp_percentage(row.get(field_name))
                if field_name in ("war", "wer")
                else round(safe_float(row.get(field_name), 0), 2)
            ),
        }
        for index, row in enumerate(ordered)
    ]


def build_student_report(student_id):
    student = get_student(student_id)
    sessions = get_student_sessions(student_id)
    model = train_decision_tree()

    predictions = [
        prediction_for_session(row, model)
        for row in sessions
    ]

    total_sessions = len(sessions)
    passed_sessions = sum(1 for row in sessions if safe_int(row.get("passed"), 0) == 1)
    average_war = (
        sum(clamp_percentage(row.get("war")) for row in sessions) / total_sessions
        if total_sessions
        else 0
    )
    average_wer = (
        sum(clamp_percentage(row.get("wer")) for row in sessions) / total_sessions
        if total_sessions
        else 0
    )
    average_fluency = (
        sum(prediction["features"]["fluency_wpm"] for prediction in predictions) / total_sessions
        if total_sessions
        else 0
    )
    pass_rate = passed_sessions / total_sessions if total_sessions else 0

    latest_prediction = predictions[0] if predictions else None
    latest_probability = latest_prediction["passed_probability"] if latest_prediction else 0
    latest_risk = latest_prediction["risk"] if latest_prediction else risk_from_probability(0)

    weak_letters = collect_weak_letters(sessions)
    recommendation = recommendation_from_risk(
        latest_risk["level"],
        average_war,
        pass_rate,
    )
    progress = progress_label(sessions)

    question_answers = [
        {
            "question": "Öğrenci bu okumadan geçti mi?",
            "answer": (
                "Evet, son okuma başarılı."
                if sessions and safe_int(sessions[0].get("passed"), 0) == 1
                else "Hayır, son okuma tekrar edilmeli."
                if sessions
                else "Henüz okuma kaydı yok."
            ),
        },
        {
            "question": "Öğrencinin başarı yüzdesi nasıl?",
            "answer": f"Başarı yüzdesi %{latest_risk['score']}. {latest_risk['label']}.",
        },
        {
            "question": "Öğrenci hangi harf/seslerde zorlanıyor?",
            "answer": (
                ", ".join(item["letter"] for item in weak_letters)
                if weak_letters
                else "Belirgin bir harf/ses zorlanması tespit edilmedi."
            ),
        },
        {
            "question": "Bir sonraki metin kolay mı olmalı zor mu?",
            "answer": recommendation["next_text_difficulty"],
        },
        {
            "question": "Öğrencinin genel ilerlemesi iyi mi kötü mü?",
            "answer": progress,
        },
    ]

    session_reports = []
    for row, prediction in zip(sessions[:20], predictions[:20]):
        session_reports.append({
            "id": row.get("id"),
            "created_at": row.get("created_at"),
            "reference_text": row.get("reference_text"),
            "transcript": row.get("transcript"),
            "war": clamp_percentage(row.get("war")),
            "wer": clamp_percentage(row.get("wer")),
            "stars": safe_int(row.get("stars"), 0),
            "passed": safe_int(row.get("passed"), 0),
            "correct_count": safe_int(row.get("correct_count"), 0),
            "mispronunciation_count": safe_int(row.get("substitution_count"), 0),
            "skipped_word_count": safe_int(row.get("deletion_count"), 0),
            "extra_word_count": safe_int(row.get("insertion_count"), 0),
            "fluency_wpm": prediction["features"]["fluency_wpm"],
            "prediction": prediction,
        })

    return {
        "student": student,
        "model": {
            "type": "Başarı Tahmin Modeli",
            "trained": model["trained"],
            "training_count": model["training_count"],
            "training_accuracy": model["accuracy"],
            "feature_importance": model["feature_importance"],
            "rules": model["rules"],
            "note": model["reason"],
        },
        "summary": {
            "total_sessions": total_sessions,
            "passed_sessions": passed_sessions,
            "pass_rate": round(pass_rate, 3),
            "average_war": round(average_war, 2),
            "average_wer": round(average_wer, 2),
            "average_fluency_wpm": round(average_fluency, 2),
            "latest_pass_probability": round(latest_probability, 3),
            "risk": latest_risk,
            "progress_label": progress,
        },
        "recommendation": {
            **recommendation,
            "focus_letters": weak_letters,
        },
        "question_answers": question_answers,
        "charts": {
            "war_trend": trend_rows(sessions, "war"),
            "wer_trend": trend_rows(sessions, "wer"),
            "error_breakdown": error_breakdown(sessions),
            "star_distribution": star_distribution(sessions),
        },
        "sessions": session_reports,
    }
