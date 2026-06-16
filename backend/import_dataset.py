import argparse
import csv
from pathlib import Path

from database import (
    create_tables,
    refresh_all_student_progress,
    seed_default_student,
    seed_levels,
)
from database import get_connection


DATASET_PATH = Path(__file__).resolve().parent / "datasets" / "reading_texts.csv"


def parse_int(value, default=0):
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return default


def count_words(text):
    return len([word for word in str(text).replace(".", " ").split() if word.strip()])


def clean_row(row):
    content = (row.get("content") or "").strip()
    word_count = parse_int(row.get("word_count"), count_words(content))

    return {
        "level_id": parse_int(row.get("level_id"), 1),
        "title": (row.get("title") or "").strip(),
        "level": (row.get("level") or "").strip(),
        "content": content,
        "target_letters": (row.get("target_letters") or "").strip(),
        "target_skill": (row.get("target_skill") or "").strip(),
        "word_count": word_count,
    }


def validate_row(row, row_number):
    required_fields = ("level_id", "title", "level", "content")
    missing_fields = [field for field in required_fields if not row.get(field)]

    if missing_fields:
        missing = ", ".join(missing_fields)
        raise ValueError(f"{row_number}. satirda eksik alan var: {missing}")


def upsert_reading_text(cursor, row):
    cursor.execute(
        """
        SELECT id
        FROM reading_texts
        WHERE level_id = ?
          AND (title = ? OR content = ?)
        ORDER BY id ASC
        LIMIT 1
        """,
        (row["level_id"], row["title"], row["content"]),
    )
    existing = cursor.fetchone()

    if existing:
        cursor.execute(
            """
            UPDATE reading_texts
            SET title = ?,
                level = ?,
                content = ?,
                target_letters = ?,
                target_skill = ?,
                word_count = ?
            WHERE id = ?
            """,
            (
                row["title"],
                row["level"],
                row["content"],
                row["target_letters"],
                row["target_skill"],
                row["word_count"],
                existing["id"],
            ),
        )
        return "updated"

    cursor.execute(
        """
        INSERT INTO reading_texts (
            level_id,
            title,
            level,
            content,
            target_letters,
            target_skill,
            word_count
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            row["level_id"],
            row["title"],
            row["level"],
            row["content"],
            row["target_letters"],
            row["target_skill"],
            row["word_count"],
        ),
    )
    return "inserted"


def import_reading_texts(dataset_path):
    create_tables()
    seed_levels()
    seed_default_student()

    inserted_count = 0
    updated_count = 0

    connection = get_connection()
    cursor = connection.cursor()

    with dataset_path.open("r", encoding="utf-8-sig", newline="") as dataset_file:
        reader = csv.DictReader(dataset_file)

        for row_number, raw_row in enumerate(reader, start=2):
            row = clean_row(raw_row)
            validate_row(row, row_number)
            action = upsert_reading_text(cursor, row)

            if action == "inserted":
                inserted_count += 1
            else:
                updated_count += 1

    connection.commit()
    connection.close()

    refresh_all_student_progress()

    return {
        "inserted": inserted_count,
        "updated": updated_count,
        "dataset_path": str(dataset_path),
    }


def main():
    parser = argparse.ArgumentParser(
        description="Okuma metinleri veri setini reading_texts tablosuna aktarir."
    )
    parser.add_argument(
        "--file",
        default=str(DATASET_PATH),
        help="CSV veri seti dosya yolu.",
    )
    args = parser.parse_args()

    dataset_path = Path(args.file).resolve()

    if not dataset_path.exists():
        raise FileNotFoundError(f"Veri seti bulunamadi: {dataset_path}")

    result = import_reading_texts(dataset_path)
    print(
        "Veri seti aktarildi: "
        f"{result['inserted']} yeni, {result['updated']} guncellenen kayit."
    )
    print(f"Kaynak: {result['dataset_path']}")


if __name__ == "__main__":
    main()
