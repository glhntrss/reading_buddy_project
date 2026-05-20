import sqlite3
from datetime import datetime

DB_NAME = "reading_buddy.db"


def create_tables():
    connection = sqlite3.connect(DB_NAME)
    cursor = connection.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS reading_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_name TEXT,
            reference_text TEXT,
            transcript TEXT,
            war REAL,
            wer REAL,
            correct_count INTEGER,
            substitution_count INTEGER,
            deletion_count INTEGER,
            insertion_count INTEGER,
            created_at TEXT
        )
    """)

    connection.commit()
    connection.close()


def save_reading_session(
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
    connection = sqlite3.connect(DB_NAME)
    cursor = connection.cursor()

    cursor.execute("""
        INSERT INTO reading_sessions (
            student_name,
            reference_text,
            transcript,
            war,
            wer,
            correct_count,
            substitution_count,
            deletion_count,
            insertion_count,
            created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        student_name,
        reference_text,
        transcript,
        war,
        wer,
        correct_count,
        substitution_count,
        deletion_count,
        insertion_count,
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))

    connection.commit()
    connection.close()


def get_all_sessions():
    connection = sqlite3.connect(DB_NAME)
    connection.row_factory = sqlite3.Row
    cursor = connection.cursor()

    cursor.execute("""
        SELECT * FROM reading_sessions
        ORDER BY created_at DESC
    """)

    rows = cursor.fetchall()
    connection.close()

    return [dict(row) for row in rows]