"""
DoseBand Database Module - SQLite Data Logging, Worker Exposure Persistence & Worker Management.

This module provides persistent storage and cumulative dose tracking for industrial
workers exposed to H2S gas using SQLite and Pandas.

Database Schema:
----------------
Table 1: readings
- id:                      INTEGER PRIMARY KEY AUTOINCREMENT
- worker_id:               TEXT
- timestamp:               TEXT (ISO 8601 format)
- intensity:               REAL (0.0 to 1.0)
- dose:                    REAL (ppm * hours)
- risk_level:              TEXT ('Safe', 'Caution', 'Unsafe — seek medical review')
- is_expired:              INTEGER (0 or 1)
- expiry_status_message:   TEXT ('Valid — safe to use', 'EXPIRED...')

Table 2: workers
- id:                      INTEGER PRIMARY KEY AUTOINCREMENT
- worker_id:               TEXT UNIQUE NOT NULL
- name:                    TEXT NOT NULL
- department:              TEXT NOT NULL
- work_zone:               TEXT NOT NULL
- shift:                   TEXT NOT NULL
- badge_id:                TEXT UNIQUE NOT NULL
- badge_issue_date:        TEXT NOT NULL (YYYY-MM-DD)
- badge_expiry_date:       TEXT NOT NULL (YYYY-MM-DD)
- status:                  TEXT NOT NULL ('Active', 'Inactive', 'On Leave', etc.)
"""

from datetime import datetime, date, timedelta
import os
import sqlite3
from typing import Dict, List, Optional, Union
import pandas as pd

DEFAULT_DB_PATH: str = "doseband.db"


def init_db(db_path: str = DEFAULT_DB_PATH) -> None:
    """
    Initializes SQLite database and creates the 'readings' and 'workers' tables if they do not exist.
    Also seeds default demo workers if the workers table is empty.

    Args:
        db_path (str): Filepath for the SQLite database.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Table 1: readings log
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

    # Table 2: worker profiles & dosimeter badge registration
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS workers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            department TEXT NOT NULL,
            work_zone TEXT NOT NULL,
            shift TEXT NOT NULL,
            badge_id TEXT UNIQUE NOT NULL,
            badge_issue_date TEXT NOT NULL,
            badge_expiry_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Active'
        );
        """
    )

    conn.commit()

    # Seed default workers if table is empty
    cursor.execute("SELECT COUNT(*) FROM workers;")
    count = cursor.fetchone()[0]
    if count == 0:
        seed_default_workers_cursor(cursor)
        conn.commit()

    conn.close()


def seed_default_workers_cursor(cursor: sqlite3.Cursor) -> None:
    """
    Helper function to insert initial sample workers when table is freshly created.
    """
    today = date.today()
    issue_date_str = (today - timedelta(days=30)).isoformat()
    expiry_date_str = (today + timedelta(days=60)).isoformat()
    expiring_soon_str = (today + timedelta(days=5)).isoformat()

    sample_workers = [
        (
            "W-101",
            "Rajesh Kumar",
            "Refinery Operations",
            "Zone A - Crude Distillation Unit",
            "Shift 1 (06:00 - 14:00)",
            "BDG-101",
            issue_date_str,
            expiry_date_str,
            "Active"
        ),
        (
            "W-102",
            "Vikram Singh",
            "Pipeline Maintenance",
            "Zone B - Desulfurization Plant",
            "Shift 2 (14:00 - 22:00)",
            "BDG-102",
            issue_date_str,
            expiry_date_str,
            "Active"
        ),
        (
            "W-103",
            "Amit Sharma",
            "Safety & Inspection",
            "Zone C - Storage & Flare Area",
            "Shift 1 (06:00 - 14:00)",
            "BDG-103",
            issue_date_str,
            expiring_soon_str,
            "Active"
        ),
        (
            "W-104",
            "Priya Patel",
            "Chemical Laboratory",
            "Zone D - Quality Control Lab",
            "General Shift (09:00 - 17:00)",
            "BDG-104",
            issue_date_str,
            expiry_date_str,
            "Active"
        ),
        (
            "W-105",
            "Sunil Verma",
            "Drilling & Extraction",
            "Zone E - Wellhead Platform",
            "Shift 3 (22:00 - 06:00)",
            "BDG-105",
            issue_date_str,
            expiry_date_str,
            "Active"
        ),
    ]

    cursor.executemany(
        """
        INSERT OR IGNORE INTO workers (
            worker_id, name, department, work_zone, shift, badge_id, badge_issue_date, badge_expiry_date, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        sample_workers
    )


def reset_db(db_path: str = DEFAULT_DB_PATH) -> None:
    """
    Drops the 'readings' table and recreates an empty schema to clear demo scan logs.
    Preserves workers table if it exists.

    Args:
        db_path (str): Filepath for the SQLite database.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("DROP TABLE IF EXISTS readings;")
    conn.commit()
    conn.close()
    init_db(db_path)


def reset_all_data(db_path: str = DEFAULT_DB_PATH) -> None:
    """
    Drops both 'readings' and 'workers' tables and re-initializes.

    Args:
        db_path (str): Filepath for the SQLite database.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("DROP TABLE IF EXISTS readings;")
    cursor.execute("DROP TABLE IF EXISTS workers;")
    conn.commit()
    conn.close()
    init_db(db_path)


# -----------------------------------------------------------------------------
# WORKER MANAGEMENT CRUD OPERATIONS
# -----------------------------------------------------------------------------

def insert_worker(
    worker_id: str,
    name: str,
    department: str,
    work_zone: str,
    shift: str,
    badge_id: str,
    badge_issue_date: str,
    badge_expiry_date: str,
    status: str = "Active",
    db_path: str = DEFAULT_DB_PATH
) -> int:
    """
    Inserts a new worker into the database.

    Args:
        worker_id (str): Unique worker identification code (e.g., 'W-106').
        name (str): Full name of the worker.
        department (str): Department name (e.g., 'Refinery Operations').
        work_zone (str): Industrial work zone / plant unit.
        shift (str): Shift timing (e.g., 'Shift 1 (06:00 - 14:00)').
        badge_id (str): Unique dosimeter badge identifier (e.g., 'BDG-106').
        badge_issue_date (str): Date badge was issued (YYYY-MM-DD).
        badge_expiry_date (str): Date badge expires (YYYY-MM-DD).
        status (str): Current worker status ('Active', 'Inactive', 'On Leave').
        db_path (str): Database file path.

    Returns:
        int: The inserted record primary key ID.

    Raises:
        sqlite3.IntegrityError: If worker_id or badge_id already exists.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(
        """
        INSERT INTO workers (
            worker_id, name, department, work_zone, shift, badge_id, badge_issue_date, badge_expiry_date, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        (
            str(worker_id).strip(),
            str(name).strip(),
            str(department).strip(),
            str(work_zone).strip(),
            str(shift).strip(),
            str(badge_id).strip(),
            str(badge_issue_date).strip(),
            str(badge_expiry_date).strip(),
            str(status).strip()
        )
    )

    record_id = cursor.lastrowid
    conn.commit()
    conn.close()
    return record_id


def update_worker(
    worker_id: str,
    name: str,
    department: str,
    work_zone: str,
    shift: str,
    badge_id: str,
    badge_issue_date: str,
    badge_expiry_date: str,
    status: str,
    db_path: str = DEFAULT_DB_PATH
) -> bool:
    """
    Updates an existing worker profile by worker_id.

    Args:
        worker_id (str): Unique worker identifier.
        name (str): Full name.
        department (str): Department.
        work_zone (str): Industrial work zone.
        shift (str): Shift details.
        badge_id (str): Dosimeter badge ID.
        badge_issue_date (str): Badge issue date.
        badge_expiry_date (str): Badge expiry date.
        status (str): Status ('Active', 'Inactive', 'On Leave').
        db_path (str): Database file path.

    Returns:
        bool: True if updated successfully, False if worker_id was not found.

    Raises:
        sqlite3.IntegrityError: If badge_id belongs to another worker.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(
        """
        UPDATE workers
        SET name = ?,
            department = ?,
            work_zone = ?,
            shift = ?,
            badge_id = ?,
            badge_issue_date = ?,
            badge_expiry_date = ?,
            status = ?
        WHERE worker_id = ?;
        """,
        (
            str(name).strip(),
            str(department).strip(),
            str(work_zone).strip(),
            str(shift).strip(),
            str(badge_id).strip(),
            str(badge_issue_date).strip(),
            str(badge_expiry_date).strip(),
            str(status).strip(),
            str(worker_id).strip()
        )
    )

    rows_affected = cursor.rowcount
    conn.commit()
    conn.close()
    return rows_affected > 0


def delete_worker(worker_id: str, db_path: str = DEFAULT_DB_PATH) -> bool:
    """
    Deletes a worker record by worker_id.

    Args:
        worker_id (str): Worker ID to delete.
        db_path (str): Database file path.

    Returns:
        bool: True if deleted successfully, False otherwise.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(
        "DELETE FROM workers WHERE worker_id = ?;",
        (str(worker_id).strip(),)
    )

    rows_affected = cursor.rowcount
    conn.commit()
    conn.close()
    return rows_affected > 0


def get_all_workers(db_path: str = DEFAULT_DB_PATH) -> pd.DataFrame:
    """
    Retrieves all registered workers ordered by worker_id ascending.

    Args:
        db_path (str): Database file path.

    Returns:
        pd.DataFrame: Pandas DataFrame containing all worker profiles.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    query = "SELECT * FROM workers ORDER BY worker_id ASC;"
    df = pd.read_sql_query(query, conn)
    conn.close()
    return df


def get_worker_by_id(worker_id: str, db_path: str = DEFAULT_DB_PATH) -> Optional[Dict[str, Union[int, str]]]:
    """
    Retrieves a single worker profile dictionary by worker_id.

    Args:
        worker_id (str): Worker identification code.
        db_path (str): Database file path.

    Returns:
        Optional[dict]: Dictionary of worker attributes, or None if not found.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute(
        "SELECT * FROM workers WHERE worker_id = ?;",
        (str(worker_id).strip(),)
    )
    row = cursor.fetchone()
    conn.close()

    return dict(row) if row else None


def get_worker_by_badge_id(badge_id: str, db_path: str = DEFAULT_DB_PATH) -> Optional[Dict[str, Union[int, str]]]:
    """
    Retrieves a worker profile dictionary by badge_id.

    Args:
        badge_id (str): Dosimeter badge ID.
        db_path (str): Database file path.

    Returns:
        Optional[dict]: Dictionary of worker attributes, or None if not found.
    """
    if not os.path.exists(db_path):
        init_db(db_path)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute(
        "SELECT * FROM workers WHERE badge_id = ?;",
        (str(badge_id).strip(),)
    )
    row = cursor.fetchone()
    conn.close()

    return dict(row) if row else None


# -----------------------------------------------------------------------------
# SENSOR READINGS OPERATIONS
# -----------------------------------------------------------------------------

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
    if not os.path.exists(db_path):
        init_db(db_path)

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
    test_db = "doseband_test.db"
    if os.path.exists(test_db):
        os.remove(test_db)

    print(f"Initializing database '{test_db}'...")
    init_db(test_db)

    print("\n--- Testing Workers CRUD ---")
    workers_df = get_all_workers(test_db)
    print("Initial Seeded Workers:")
    print(workers_df[["worker_id", "name", "department", "badge_id", "status"]].to_string(index=False))

    print("\nInserting new worker W-106...")
    insert_worker(
        worker_id="W-106",
        name="Kavita Sharma",
        department="Safety & Quality",
        work_zone="Zone A - Crude Unit",
        shift="Shift 1 (06:00 - 14:00)",
        badge_id="BDG-106",
        badge_issue_date="2026-08-01",
        badge_expiry_date="2026-11-01",
        status="Active",
        db_path=test_db
    )
    print("Worker W-106 retrieved:", get_worker_by_id("W-106", test_db))

    print("\nUpdating worker W-106 status to On Leave...")
    update_worker(
        worker_id="W-106",
        name="Kavita Sharma",
        department="Safety & Quality",
        work_zone="Zone A - Crude Unit",
        shift="Shift 1 (06:00 - 14:00)",
        badge_id="BDG-106",
        badge_issue_date="2026-08-01",
        badge_expiry_date="2026-11-01",
        status="On Leave",
        db_path=test_db
    )
    print("Updated W-106:", get_worker_by_id("W-106", test_db))

    print("\nInserting sample readings...")
    insert_reading(
        worker_id="W-101",
        intensity=0.15,
        dose=8.5,
        risk_level="Safe",
        is_expired=False,
        expiry_status_message="Valid — safe to use",
        db_path=test_db
    )

    print("\nDeleting worker W-106...")
    delete_worker("W-106", test_db)
    print("W-106 after deletion:", get_worker_by_id("W-106", test_db))

    if os.path.exists(test_db):
        os.remove(test_db)
    print("\nAll database tests passed successfully!")
