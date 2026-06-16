import sqlite3
from datetime import datetime

DB_NAME = "reading_buddy.db"


def get_connection():
    connection = sqlite3.connect(DB_NAME)
    connection.row_factory = sqlite3.Row
    return connection


def column_exists(cursor, table_name, column_name):
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = cursor.fetchall()
    return any(column["name"] == column_name for column in columns)


def add_column_if_not_exists(cursor, table_name, column_name, column_type):
    if not column_exists(cursor, table_name, column_name):
        cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}")


def create_tables():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            age INTEGER,
            grade TEXT,
            current_level INTEGER DEFAULT 1,
            created_at TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS levels (
            id INTEGER PRIMARY KEY,
            title TEXT,
            description TEXT,
            required_stars INTEGER
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS reading_texts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level_id INTEGER,
            title TEXT,
            level TEXT,
            content TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS reading_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            text_id INTEGER,
            student_name TEXT,
            reference_text TEXT,
            transcript TEXT,
            war REAL,
            wer REAL,
            stars INTEGER,
            passed INTEGER,
            correct_count INTEGER,
            substitution_count INTEGER,
            deletion_count INTEGER,
            insertion_count INTEGER,
            created_at TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS student_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            level_id INTEGER,
            best_stars INTEGER DEFAULT 0,
            is_unlocked INTEGER DEFAULT 0,
            is_completed INTEGER DEFAULT 0
        )
    """)

    # Eski reading_sessions tablosu varsa eksik kolonları ekler
    add_column_if_not_exists(cursor, "reading_sessions", "student_id", "INTEGER")
    add_column_if_not_exists(cursor, "reading_sessions", "text_id", "INTEGER")
    add_column_if_not_exists(cursor, "reading_sessions", "stars", "INTEGER")
    add_column_if_not_exists(cursor, "reading_sessions", "passed", "INTEGER")

    connection.commit()
    connection.close()


def seed_levels():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT COUNT(*) AS count FROM levels")
    count = cursor.fetchone()["count"]

    if count == 0:
        levels = [
            (1, "Seviye 1", "Kısa ve basit cümleler", 2),
            (2, "Seviye 2", "Günlük yaşam cümleleri", 2),
            (3, "Seviye 3", "Orta uzunlukta okuma parçaları", 2),
            (4, "Seviye 4", "Dikkat ve akıcılık metinleri", 2),
            (5, "Seviye 5", "Daha uzun ve zor metinler", 2),
        ]

        cursor.executemany("""
            INSERT INTO levels (id, title, description, required_stars)
            VALUES (?, ?, ?, ?)
        """, levels)

    connection.commit()
    connection.close()


def seed_reading_texts():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT COUNT(*) AS count FROM reading_texts")
    count = cursor.fetchone()["count"]

    if count == 0:
        texts = [
    (
        1,
        "Seviye 1 - İlk Okuma",
        "Kolay",
        "Ali ata bak."
    ),
    (
        1,
        "Seviye 1 - Kısa Cümle",
        "Kolay",
        "Ayşe top al."
    ),
    (
        2,
        "Seviye 2 - Basit Günlük Cümle",
        "Kolay",
        "Bugün hava çok güzel."
    ),
    (
        2,
        "Seviye 2 - Bahçe",
        "Kolay",
        "Çocuklar bahçede oyun oynuyor."
    ),
    (
        3,
        "Seviye 3 - Okula Hazırlık",
        "Orta",
        "Mert sabah erkenden uyandı ve çantasını hazırladı."
    ),
    (
        4,
        "Seviye 4 - Kitap Okuma",
        "Orta",
        "Zeynep her akşam yatmadan önce birkaç sayfa kitap okurdu."
    ),
    (
        5,
        "Seviye 5 - Dikkat Metni",
        "Zor",
        "Küçük çocuk yerdeki sarı ve kırmızı yaprakları dikkatle topladı."
    ),
]

        cursor.executemany("""
            INSERT INTO reading_texts (level_id, title, level, content)
            VALUES (?, ?, ?, ?)
        """, texts)

    connection.commit()
    connection.close()


def seed_default_student():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT COUNT(*) AS count FROM students")
    count = cursor.fetchone()["count"]

    if count == 0:
        cursor.execute("""
            INSERT INTO students (name, age, grade, current_level, created_at)
            VALUES (?, ?, ?, ?, ?)
        """, (
            "Gülhan Test Öğrencisi",
            8,
            "2. Sınıf",
            1,
            datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        ))

        student_id = cursor.lastrowid

        for level_id in range(1, 6):
            is_unlocked = 1 if level_id == 1 else 0

            cursor.execute("""
                INSERT INTO student_progress (
                    student_id, level_id, best_stars, is_unlocked, is_completed
                )
                VALUES (?, ?, ?, ?, ?)
            """, (
                student_id,
                level_id,
                0,
                is_unlocked,
                0
            ))

    connection.commit()
    connection.close()


def get_students():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT * FROM students ORDER BY id ASC")
    rows = cursor.fetchall()

    connection.close()
    return [dict(row) for row in rows]


def get_levels():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT * FROM levels ORDER BY id ASC")
    rows = cursor.fetchall()

    connection.close()
    return [dict(row) for row in rows]


def get_reading_texts():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT * FROM reading_texts
        ORDER BY level_id ASC, id ASC
    """)

    rows = cursor.fetchall()
    connection.close()

    return [dict(row) for row in rows]


def get_texts_by_unlocked_levels(student_id):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT
            rt.*,
            COALESCE((
                SELECT MAX(rs.passed)
                FROM reading_sessions rs
                WHERE rs.student_id = ?
                  AND rs.text_id = rt.id
            ), 0) AS is_passed,
            COALESCE((
                SELECT MAX(rs.stars)
                FROM reading_sessions rs
                WHERE rs.student_id = ?
                  AND rs.text_id = rt.id
            ), 0) AS best_stars
        FROM reading_texts rt
        INNER JOIN student_progress sp
            ON rt.level_id = sp.level_id
        WHERE sp.student_id = ?
          AND sp.is_unlocked = 1
        ORDER BY rt.level_id ASC, rt.id ASC
    """, (student_id, student_id, student_id))

    rows = cursor.fetchall()
    connection.close()

    return [dict(row) for row in rows]


def get_level_progress_summary(cursor, student_id, level_id):
    cursor.execute("""
        SELECT COUNT(*) AS total_texts
        FROM reading_texts
        WHERE level_id = ?
    """, (level_id,))
    total_texts = cursor.fetchone()["total_texts"]

    cursor.execute("""
        SELECT COUNT(DISTINCT rt.id) AS completed_texts
        FROM reading_texts rt
        INNER JOIN reading_sessions rs
            ON rs.text_id = rt.id
        WHERE rt.level_id = ?
          AND rs.student_id = ?
          AND rs.passed = 1
    """, (level_id, student_id))
    completed_texts = cursor.fetchone()["completed_texts"]

    progress_percent = 0
    if total_texts > 0:
        progress_percent = round((completed_texts / total_texts) * 100, 2)

    level_completed = 1 if total_texts > 0 and completed_texts >= total_texts else 0
    next_level_id = None

    if level_completed == 1:
        cursor.execute("SELECT id FROM levels WHERE id = ?", (level_id + 1,))
        next_level = cursor.fetchone()
        if next_level:
            next_level_id = next_level["id"]

    return {
        "level_id": level_id,
        "total_texts": total_texts,
        "completed_texts": completed_texts,
        "progress_percent": progress_percent,
        "level_completed": level_completed,
        "can_go_next": next_level_id is not None,
        "next_level_id": next_level_id,
    }


def refresh_all_student_progress():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT id FROM students")
    students = cursor.fetchall()

    cursor.execute("SELECT id FROM levels ORDER BY id ASC")
    levels = cursor.fetchall()

    for student in students:
        previous_level_completed = True

        for level in levels:
            student_id = student["id"]
            level_id = level["id"]
            level_progress = get_level_progress_summary(cursor, student_id, level_id)
            is_unlocked = 1 if level_id == 1 or previous_level_completed else 0
            is_completed = level_progress["level_completed"]

            cursor.execute("""
                SELECT COALESCE(MAX(rs.stars), 0) AS best_stars
                FROM reading_sessions rs
                INNER JOIN reading_texts rt
                    ON rt.id = rs.text_id
                WHERE rs.student_id = ?
                  AND rt.level_id = ?
            """, (student_id, level_id))
            best_stars = cursor.fetchone()["best_stars"]

            cursor.execute("""
                UPDATE student_progress
                SET best_stars = ?,
                    is_unlocked = ?,
                    is_completed = ?
                WHERE student_id = ?
                  AND level_id = ?
            """, (
                best_stars,
                is_unlocked,
                is_completed,
                student_id,
                level_id,
            ))

            previous_level_completed = is_completed == 1

    connection.commit()
    connection.close()


def calculate_stars(war, wer):
    if war >= 90 and wer <= 10:
        return 3
    elif war >= 75 and wer <= 25:
        return 2
    elif war >= 60 and wer <= 40:
        return 1
    else:
        return 0


def save_reading_session(
    student_id,
    text_id,
    student_name,
    reference_text,
    transcript,
    war,
    wer,
    correct_count,
    substitution_count,
    deletion_count,
    insertion_count
):
    stars = calculate_stars(war, wer)
    passed = 1 if stars >= 2 else 0

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        INSERT INTO reading_sessions (
            student_id,
            text_id,
            student_name,
            reference_text,
            transcript,
            war,
            wer,
            stars,
            passed,
            correct_count,
            substitution_count,
            deletion_count,
            insertion_count,
            created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        student_id,
        text_id,
        student_name,
        reference_text,
        transcript,
        war,
        wer,
        stars,
        passed,
        correct_count,
        substitution_count,
        deletion_count,
        insertion_count,
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))
    session_id = cursor.lastrowid
    level_progress = None

    if text_id is not None:
        cursor.execute("SELECT level_id FROM reading_texts WHERE id = ?", (text_id,))
        text_row = cursor.fetchone()

        if text_row:
            level_id = text_row["level_id"]

            cursor.execute("""
                SELECT * FROM student_progress
                WHERE student_id = ? AND level_id = ?
            """, (student_id, level_id))

            progress = cursor.fetchone()

            if progress:
                best_stars = max(progress["best_stars"], stars)
                level_progress = get_level_progress_summary(cursor, student_id, level_id)
                is_completed = level_progress["level_completed"]

                cursor.execute("""
                    UPDATE student_progress
                    SET best_stars = ?, is_completed = ?
                    WHERE student_id = ? AND level_id = ?
                """, (
                    best_stars,
                    is_completed,
                    student_id,
                    level_id
                ))

                if is_completed == 1:
                    next_level = level_progress["next_level_id"]
                    level_progress["can_go_next"] = next_level is not None

                    if next_level is not None:
                        cursor.execute("""
                            UPDATE student_progress
                            SET is_unlocked = 1
                            WHERE student_id = ? AND level_id = ?
                        """, (
                            student_id,
                            next_level
                        ))

                        cursor.execute("""
                            UPDATE students
                            SET current_level = CASE
                                WHEN current_level < ? THEN ?
                                ELSE current_level
                            END
                            WHERE id = ?
                        """, (
                            next_level,
                            next_level,
                            student_id
                        ))

    connection.commit()
    connection.close()

    return {
        "session_id": session_id,
        "stars": stars,
        "passed": passed,
        "level_progress": level_progress
    }


def get_all_sessions():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT *
        FROM reading_sessions
        ORDER BY created_at DESC
    """)

    rows = cursor.fetchall()
    connection.close()

    return [dict(row) for row in rows]


def get_student_progress(student_id):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT 
            sp.id,
            sp.student_id,
            sp.level_id,
            l.title,
            l.description,
            l.required_stars,
            sp.best_stars,
            sp.is_unlocked,
            sp.is_completed
        FROM student_progress sp
        INNER JOIN levels l
            ON sp.level_id = l.id
        WHERE sp.student_id = ?
        ORDER BY sp.level_id ASC
    """, (student_id,))

    rows = cursor.fetchall()
    result = []

    for row in rows:
        item = dict(row)
        level_progress = get_level_progress_summary(
            cursor,
            student_id,
            item["level_id"],
        )
        item.update(level_progress)
        result.append(item)

    connection.close()

    return result
