import os
import sqlite3
from datetime import datetime, timedelta
import hashlib

DB_NAME = os.path.join(os.path.dirname(__file__), "reading_buddy.db")


def get_connection():
    connection = sqlite3.connect(DB_NAME)
    connection.row_factory = sqlite3.Row
    return connection


def clamp_percentage(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0

    return max(0, min(100, round(number, 2)))

def hash_password(password, salt=None):
    if salt is None:
        salt = os.urandom(16).hex()

    password_hash = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        100000
    ).hex()

    return password_hash, salt


def verify_password(password, password_hash, salt):
    calculated_hash, _ = hash_password(password, salt)
    return calculated_hash == password_hash

def column_exists(cursor, table_name, column_name):
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = cursor.fetchall()
    return any(column["name"] == column_name for column in columns)


def add_column_if_not_exists(cursor, table_name, column_name, column_type):
    if not column_exists(cursor, table_name, column_name):
        cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}")


def register_student_user(full_name, email, identifier, age, grade, password):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT * FROM users
        WHERE email = ? OR identifier = ?
    """, (email, identifier))

    existing_user = cursor.fetchone()

    if existing_user:
        connection.close()
        raise Exception("Bu mail veya ID ile kayıtlı kullanıcı zaten var.")

    password_hash, password_salt = hash_password(password)

    cursor.execute("""
        INSERT INTO users (
            role, full_name, email, identifier,
            password_hash, password_salt, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        "student",
        full_name,
        email,
        identifier,
        password_hash,
        password_salt,
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))

    user_id = cursor.lastrowid

    cursor.execute("""
        INSERT INTO students (
            user_id, name, email, identifier,
            age, grade, current_level, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id,
        full_name,
        email,
        identifier,
        age,
        grade,
        1,
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))

    student_id = cursor.lastrowid

    cursor.execute("SELECT id FROM levels ORDER BY id ASC")
    levels = cursor.fetchall()

    for level in levels:
        level_id = level["id"]
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

    cursor.execute("SELECT * FROM students WHERE id = ?", (student_id,))
    student = cursor.fetchone()

    connection.close()

    return dict(student)

def register_teacher_user(full_name, email, identifier, branch, password):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT * FROM users
        WHERE email = ? OR identifier = ?
    """, (email, identifier))

    existing_user = cursor.fetchone()

    if existing_user:
        connection.close()
        raise Exception("Bu mail veya ID ile kayıtlı kullanıcı zaten var.")

    password_hash, password_salt = hash_password(password)

    cursor.execute("""
        INSERT INTO users (
            role, full_name, email, identifier,
            password_hash, password_salt, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        "teacher",
        full_name,
        email,
        identifier,
        password_hash,
        password_salt,
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))

    user_id = cursor.lastrowid

    cursor.execute("""
        INSERT INTO teachers (
            user_id, name, email, identifier, branch, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?)
    """, (
        user_id,
        full_name,
        email,
        identifier,
        branch,
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))

    teacher_id = cursor.lastrowid

    connection.commit()

    cursor.execute("SELECT * FROM teachers WHERE id = ?", (teacher_id,))
    teacher = cursor.fetchone()

    connection.close()

    return dict(teacher)

def login_user(role, login_identifier, password):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT * FROM users
        WHERE role = ?
          AND (email = ? OR identifier = ?)
    """, (
        role,
        login_identifier,
        login_identifier
    ))

    user = cursor.fetchone()

    if not user:
        connection.close()
        raise Exception("Kullanıcı bulunamadı.")

    is_valid = verify_password(
        password,
        user["password_hash"],
        user["password_salt"]
    )

    if not is_valid:
        connection.close()
        raise Exception("Şifre hatalı.")

    user_dict = dict(user)

    if role == "student":
        cursor.execute("""
            SELECT * FROM students
            WHERE user_id = ?
        """, (user["id"],))

        student = cursor.fetchone()
        connection.close()

        return {
            "user": user_dict,
            "student": dict(student) if student else None,
            "teacher": None
        }

    if role == "teacher":
        cursor.execute("""
            SELECT * FROM teachers
            WHERE user_id = ?
        """, (user["id"],))

        teacher = cursor.fetchone()
        connection.close()

        return {
            "user": user_dict,
            "student": None,
            "teacher": dict(teacher) if teacher else None
        }

    connection.close()
    raise Exception("Geçersiz kullanıcı rolü.")

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
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT,
        full_name TEXT,
        email TEXT UNIQUE,
        identifier TEXT UNIQUE,
        password_hash TEXT,
        password_salt TEXT,
        created_at TEXT
    )
""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT,
        email TEXT,
        identifier TEXT,
        branch TEXT,
        created_at TEXT
    )
""")

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS reading_texts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level_id INTEGER,
            title TEXT,
            level TEXT,
            content TEXT,
            target_letters TEXT,
            target_skill TEXT,
            word_count INTEGER
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
            duration_seconds REAL DEFAULT 0,  
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

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS reading_assignments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teacher_id INTEGER,
            student_id INTEGER,
            text_id INTEGER,
            note TEXT,
            due_date TEXT,
            status TEXT DEFAULT 'assigned',
            completed_at TEXT,
            created_at TEXT
        )
    """)

    # Eski reading_sessions tablosu varsa eksik kolonları ekler
    add_column_if_not_exists(cursor, "reading_sessions", "student_id", "INTEGER")
    add_column_if_not_exists(cursor, "reading_sessions", "text_id", "INTEGER")
    add_column_if_not_exists(cursor, "reading_sessions", "stars", "INTEGER")
    add_column_if_not_exists(cursor, "reading_sessions", "passed", "INTEGER")
    add_column_if_not_exists(cursor, "reading_sessions", "duration_seconds", "REAL DEFAULT 0")
    add_column_if_not_exists(cursor, "reading_texts", "target_letters", "TEXT")
    add_column_if_not_exists(cursor, "reading_texts", "target_skill", "TEXT")
    add_column_if_not_exists(cursor, "reading_texts", "word_count", "INTEGER")
    add_column_if_not_exists(cursor, "students", "user_id", "INTEGER")
    add_column_if_not_exists(cursor, "students", "email", "TEXT")
    add_column_if_not_exists(cursor, "students", "identifier", "TEXT")

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
            ,
            COALESCE((
                SELECT MAX(ra.id)
                FROM reading_assignments ra
                WHERE ra.student_id = ?
                  AND ra.text_id = rt.id
                  AND ra.status = 'assigned'
            ), 0) AS assignment_id,
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM reading_assignments ra
                    WHERE ra.student_id = ?
                      AND ra.text_id = rt.id
                      AND ra.status = 'assigned'
                ) THEN 1
                ELSE 0
            END AS is_assigned
        FROM reading_texts rt
        INNER JOIN student_progress sp
            ON rt.level_id = sp.level_id
        WHERE sp.student_id = ?
          AND (
            sp.is_unlocked = 1
            OR EXISTS (
                SELECT 1
                FROM reading_assignments ra
                WHERE ra.student_id = ?
                  AND ra.text_id = rt.id
                  AND ra.status = 'assigned'
            )
          )
        ORDER BY rt.level_id ASC, rt.id ASC
    """, (student_id, student_id, student_id, student_id, student_id, student_id))

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
    elif war >= 66 and wer <= 50:
        return 2
    elif war >= 33 and wer <= 75:
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
    insertion_count,
    duration_seconds=0

):
    war = clamp_percentage(war)
    wer = clamp_percentage(wer)
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
            duration_seconds,
            created_at
        )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        duration_seconds,
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

            if passed == 1:
                now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                cursor.execute("""
                    UPDATE reading_assignments
                    SET status = 'completed',
                        completed_at = ?
                    WHERE student_id = ?
                      AND text_id = ?
                      AND status != 'completed'
                """, (
                    now,
                    student_id,
                    text_id,
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

    rows = []
    for row in cursor.fetchall():
        item = dict(row)
        item["war"] = clamp_percentage(item.get("war"))
        item["wer"] = clamp_percentage(item.get("wer"))
        rows.append(item)
    connection.close()

    return rows


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


def get_assignment_by_id(assignment_id):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT
            ra.*,
            s.name AS student_name,
            rt.title AS text_title,
            rt.content AS text_content,
            rt.level AS text_level,
            rt.level_id AS level_id,
            t.name AS teacher_name
        FROM reading_assignments ra
        LEFT JOIN students s ON s.id = ra.student_id
        LEFT JOIN reading_texts rt ON rt.id = ra.text_id
        LEFT JOIN teachers t ON t.id = ra.teacher_id
        WHERE ra.id = ?
    """, (assignment_id,))

    row = cursor.fetchone()
    connection.close()
    return dict(row) if row else None


def create_reading_assignment(teacher_id, student_id, text_id, due_date="", note=""):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT id FROM students WHERE id = ?", (student_id,))
    if cursor.fetchone() is None:
        connection.close()
        raise Exception("Öğrenci bulunamadı.")

    cursor.execute("SELECT id FROM reading_texts WHERE id = ?", (text_id,))
    if cursor.fetchone() is None:
        connection.close()
        raise Exception("Okuma metni bulunamadı.")

    cursor.execute("""
        INSERT INTO reading_assignments (
            teacher_id,
            student_id,
            text_id,
            note,
            due_date,
            status,
            created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        teacher_id,
        student_id,
        text_id,
        note,
        due_date,
        "assigned",
        datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    ))

    assignment_id = cursor.lastrowid
    connection.commit()
    connection.close()

    return get_assignment_by_id(assignment_id)


def get_reading_assignments(teacher_id=None, student_id=None):
    connection = get_connection()
    cursor = connection.cursor()

    conditions = []
    params = []

    if teacher_id is not None:
        conditions.append("ra.teacher_id = ?")
        params.append(teacher_id)

    if student_id is not None:
        conditions.append("ra.student_id = ?")
        params.append(student_id)

    where_clause = ""
    if conditions:
        where_clause = "WHERE " + " AND ".join(conditions)

    cursor.execute(f"""
        SELECT
            ra.*,
            s.name AS student_name,
            rt.title AS text_title,
            rt.content AS text_content,
            rt.level AS text_level,
            rt.level_id AS level_id,
            t.name AS teacher_name
        FROM reading_assignments ra
        LEFT JOIN students s ON s.id = ra.student_id
        LEFT JOIN reading_texts rt ON rt.id = ra.text_id
        LEFT JOIN teachers t ON t.id = ra.teacher_id
        {where_clause}
        ORDER BY
            CASE ra.status WHEN 'assigned' THEN 0 ELSE 1 END,
            COALESCE(ra.due_date, '') ASC,
            ra.created_at DESC
    """, params)

    rows = [dict(row) for row in cursor.fetchall()]
    connection.close()
    return rows

def get_home_summary(student_id):
    daily_goal_minutes = 5

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT * FROM students WHERE id = ?", (student_id,))
    student = cursor.fetchone()

    if not student:
        connection.close()
        return {
            "daily_goal_minutes": daily_goal_minutes,
            "today_completed_minutes": 0,
            "daily_goal_completed": False,
            "streak_days": 0,
            "current_level": 1,
            "level_progress": 0.0,
        }

    today = datetime.now().strftime("%Y-%m-%d")

    cursor.execute("""
        SELECT duration_seconds
        FROM reading_sessions
        WHERE student_id = ?
          AND substr(created_at, 1, 10) = ?
    """, (student_id, today))

    today_sessions = cursor.fetchall()

    today_completed_minutes = 0

    for session in today_sessions:
        seconds = session["duration_seconds"] or 0

        if seconds > 0:
            # Demo için kısa okumaları da 1 dk sayıyoruz.
            today_completed_minutes += max(1, round(seconds / 60))

    today_completed_minutes = min(today_completed_minutes, daily_goal_minutes)
    daily_goal_completed = today_completed_minutes >= daily_goal_minutes

    cursor.execute("""
        SELECT DISTINCT substr(created_at, 1, 10) AS day
        FROM reading_sessions
        WHERE student_id = ?
        ORDER BY day DESC
    """, (student_id,))

    active_days = {
        row["day"]
        for row in cursor.fetchall()
        if row["day"]
    }

    streak_days = 0
    check_day = datetime.now().date()

    while check_day.strftime("%Y-%m-%d") in active_days:
        streak_days += 1
        check_day -= timedelta(days=1)

    current_level = student["current_level"] or 1
    level_summary = get_level_progress_summary(cursor, student_id, current_level)

    level_progress = 0.0
    if level_summary:
        level_progress = (level_summary["progress_percent"] or 0) / 100

    connection.close()

    return {
        "daily_goal_minutes": daily_goal_minutes,
        "today_completed_minutes": today_completed_minutes,
        "daily_goal_completed": daily_goal_completed,
        "streak_days": streak_days,
        "current_level": current_level,
        "level_progress": level_progress,
    }
