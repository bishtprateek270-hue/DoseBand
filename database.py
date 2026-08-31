"""
DoseBand Database Module - SQLite Data Logging & Worker Exposure Persistence.

This module provides persistent storage and cumulative dose tracking for industrial
workers exposed to H2S gas using SQLite and Pandas.

Database Schema (table: readings):
----------------------------------
- id:                      INTEGER PRIMARY KEY AUTOINCREMENT
- worker_id:               TEXT
- timestamp:               TEXT (ISO 8601 format)
- intensity:               REAL (0.0 to 1.0)
- dose:                    REAL (ppm * hours)
- risk_level:              TEXT ('Safe', 'Caution', 'Unsafe — seek medical review')
- is_expired:              INTEGER (0 or 1)
- expiry_status_message:   TEXT ('Valid — safe to use', 'EXPIRED...')
"""

from datetime import datetime
import os
import sqlite3
from typing import Optional, Union
import pandas as pd

DEFAULT_DB_PATH: str = "doseband.db"


def init_db(db_path: str = DEFAULT_DB_PATH) -> None:
    """
    Initializes SQLite database and creates the 'readings' table if it does not exist.

    Args:
        db_path (str): Filepath for the SQLite database.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            intensity REAL NOT NULL,
            dose REAL NOT NULL,
            risk_level TEXT NOT NULL,
            is_expired INTEGER NOT NULL,
            expiry_status_message TEXT NOT NULL
        );
        """
    )

    conn.commit()
    conn.close()


def insert_reading(
    worker_id: str,
    intensity: float,
    dose: float,
    risk_level: str,
    is_expired: Union[bool, int],
    expiry_status_message: str,
    db_path: str = DEFAULT_DB_PATH
) -> int:
    """
    Inserts a new sensor reading log record into the database with ISO timestamp.

    Args:
        worker_id (str): Unique worker identification code.
        intensity (float): Calculated optical staining intensity (0.0 to 1.0).
        dose (float): Predicted cumulative H2S dose (ppm*hr).
        risk_level (str): Safety risk classification.
        is_expired (bool | int): Badge expiry status flag (True/1 if expired).
        expiry_status_message (str): Human-readable badge validity message.
        db_path (str): Database file path.

    Returns:
        int: The inserted record ID.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    timestamp_str = datetime.now().isoformat()
    expired_flag = 1 if is_expired else 0

    cursor.execute(
        """
        INSERT INTO readings (
            worker_id, timestamp, intensity, dose, risk_level, is_expired, expiry_status_message
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
        (
            str(worker_id).strip(),
            timestamp_str,
            float(intensity),
            float(dose),
            str(risk_level),
            expired_flag,
            str(expiry_status_message)
        )
    )

    record_id = cursor.lastrowid
    conn.commit()
    conn.close()
    return record_id


def get_all_readings(db_path: str = DEFAULT_DB_PATH) -> pd.DataFrame:
    """
    Retrieves all logged readings ordered by timestamp descending.

    Args:
        db_path (str): Database file path.

    Returns:
        pd.DataFrame: Pandas DataFrame containing all records.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    query = "SELECT * FROM readings ORDER BY timestamp DESC;"
    df = pd.read_sql_query(query, conn)
    conn.close()
    return df


def get_readings_for_worker(worker_id: str, db_path: str = DEFAULT_DB_PATH) -> pd.DataFrame:
    """
    Retrieves all logged readings for a specific worker_id ordered by timestamp descending.

    Args:
        worker_id (str): Worker ID to filter by.
        db_path (str): Database file path.

    Returns:
        pd.DataFrame: Filtered Pandas DataFrame.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    query = "SELECT * FROM readings WHERE worker_id = ? ORDER BY timestamp DESC;"
    df = pd.read_sql_query(query, conn, params=(str(worker_id).strip(),))
    conn.close()
    return df


def get_cumulative_dose(worker_id: str, db_path: str = DEFAULT_DB_PATH) -> float:
    """
    Calculates the total cumulative dose (sum of dose column) for a given worker.

    Args:
        worker_id (str): Worker ID to calculate total dose for.
        db_path (str): Database file path.

    Returns:
        float: Total cumulative H2S dose (ppm*hr).
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT SUM(dose) FROM readings WHERE worker_id = ?;",
        (str(worker_id).strip(),)
    )
    result = cursor.fetchone()[0]
    conn.close()

    return float(result) if result is not None else 0.0


if __name__ == "__main__":
    test_db = "doseband.db"

    print(f"Initializing database '{test_db}'...")
    init_db(test_db)

    print("Inserting 3 sample worker readings...")
    insert_reading(
        worker_id="W-101",
        intensity=0.15,
        dose=8.5,
        risk_level="Safe",
        is_expired=False,
        expiry_status_message="Valid — safe to use",
        db_path=test_db
    )
    insert_reading(
        worker_id="W-102",
        intensity=0.52,
        dose=42.0,
        risk_level="Caution",
        is_expired=False,
        expiry_status_message="Valid — safe to use",
        db_path=test_db
    )
    insert_reading(
        worker_id="W-101",
        intensity=0.88,
        dose=115.2,
        risk_level="Unsafe — seek medical review",
        is_expired=True,
        expiry_status_message="EXPIRED — do not rely on this badge, replace immediately",
        db_path=test_db
    )

    print("\n--- All Database Logs ---")
    all_logs = get_all_readings(test_db)
    print(all_logs.to_string(index=False))

    print("\n--- Worker Cumulative Dose Check ---")
    cum_w101 = get_cumulative_dose("W-101", test_db)
    print(f"Worker W-101 Cumulative Exposure Dose: {cum_w101:.2f} ppm*hr")
