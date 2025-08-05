#!/usr/bin/env python3

import typing as t
import sqlite3
import json
import csv
import sys
from pathlib import Path


def convert_csv_to_formats(csv_input_path: str, output_dir: str) -> None:
    """Convert CSV to JSON and SQLite formats"""
    csv_path = Path(csv_input_path)
    output_path = Path(output_dir)
    
    # Ensure output directories exist
    (output_path / "json").mkdir(parents=True, exist_ok=True)
    (output_path / "sqlite").mkdir(parents=True, exist_ok=True)
    
    json_outfile = output_path / "json" / "toxic-repos.json"
    sqlite_outfile = output_path / "sqlite" / "toxic-repos.sqlite3"
    
    print(f"Converting {csv_path} to JSON and SQLite formats...")
    
    # Read CSV data
    csv_data = []
    with open(csv_path, "r", encoding="utf-8") as fp:
        csv_reader = csv.DictReader(fp)
        row_names = csv_reader.fieldnames
        for row in csv_reader:
            csv_data.append(row)
    
    print(f"Read {len(csv_data)} records from CSV")
    
    # Convert to JSON
    with open(json_outfile, "w", encoding="utf-8") as fp:
        json.dump(csv_data, fp, ensure_ascii=False, indent=4)
    print(f"Created JSON: {json_outfile}")
    
    # Convert to SQLite
    # Remove existing database if it exists
    if sqlite_outfile.exists():
        sqlite_outfile.unlink()
    
    connection = sqlite3.connect(sqlite_outfile)
    cursor = connection.cursor()
    
    # Create table with appropriate columns
    if row_names:
        safe_columns = []
        for col in row_names:
            # Only allow alphanumeric characters, underscores, and hyphens
            if col and all(c.isalnum() or c in '_-' for c in col):
                safe_columns.append(f'"{col}" TEXT')
            else:
                raise ValueError(f"Invalid column name: {col}")
        
        columns = ", ".join(safe_columns)
        create_table_sql = "CREATE TABLE repos (" + columns + ")"
        cursor.execute(create_table_sql)
        
        # Insert data using parameterized query
        placeholders = ", ".join(["?" for _ in row_names])
        insert_sql = "INSERT INTO repos VALUES (" + placeholders + ")"
        
        for row_data in csv_data:
            values = [row_data.get(col, "") for col in row_names]
            cursor.execute(insert_sql, values)
        
        connection.commit()
    
    connection.close()
    print(f"Created SQLite: {sqlite_outfile}")


def convert_sqlite_to_formats() -> None:
    """Original function to convert from SQLite to CSV and JSON"""
    DATABASE_PATH = Path("data/sqlite/toxic-repos.sqlite3")
    JSON_OUTFILE_PATH = Path("data/json/toxic-repos.json")
    CSV_OUTFILE_PATH = Path("data/csv/toxic-repos.csv")
    
    connection = sqlite3.connect(DATABASE_PATH)
    cursor = connection.cursor()

    execute_result = cursor.execute("SELECT * FROM repos ORDER BY problem_type")

    column_datas: t.List[t.Tuple[t.Any, ...]] = list(execute_result)  # type: ignore
    row_names = list(map(lambda x: x[0], cursor.description))

    # To json
    json_data = [
        {
            row_names[index]: data
            for index, data in enumerate(column_data)
        }
        for column_data in column_datas
    ]
    with open(JSON_OUTFILE_PATH, "w", encoding="utf-8") as fp:
        json.dump(json_data, fp, ensure_ascii=False, indent=4)

    # To csv
    with open(CSV_OUTFILE_PATH, "w", newline='', encoding="utf-8") as fp:
        csv_writer = csv.writer(fp)
        csv_writer.writerow(row_names)
        for column_data in column_datas:
            csv_writer.writerow(column_data)


def main() -> None:
    if len(sys.argv) == 3:
        # New mode: convert CSV to other formats
        csv_input_path = sys.argv[1]
        output_dir = sys.argv[2]
        convert_csv_to_formats(csv_input_path, output_dir)
    elif len(sys.argv) == 1:
        # Original mode: convert SQLite to CSV and JSON
        convert_sqlite_to_formats()
    else:
        print("Usage:")
        print("  python3 convert_database_to_other_formats.py <csv_input> <output_dir>")
        print("  python3 convert_database_to_other_formats.py  # (original SQLite mode)")
        sys.exit(1)


if __name__ == "__main__":
    main()
