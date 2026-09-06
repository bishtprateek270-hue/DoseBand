"""
DoseBand Exposure Trend Forecasting Module.

Calculates cumulative H2S exposure accumulation rates from historical scan logs
and projects estimated time-to-threshold (Warning: 10.0 ppm*hr, Critical: 50.0 ppm*hr)
using real SQLite database records.

Status: ESTIMATION / STATISTICAL PROJECTION
"""

from datetime import datetime, date, timedelta
from typing import Dict, List, Optional, Any
import numpy as np
import pandas as pd

import database

# Threshold constants aligned with OSHA / DGMS guidelines
THRESHOLD_WARNING: float = 10.0   # Permissible Exposure Limit (8-hr TWA)
THRESHOLD_CRITICAL: float = 50.0  # Immediately dangerous / Unsafe threshold
MIN_SCANS_REQUIRED: int = 2       # Minimum chronological readings for rate projection


def compute_worker_forecast(
    worker_id: str,
    db_path: str = database.DEFAULT_DB_PATH
) -> Dict[str, Any]:
    """
    Computes exposure accumulation rate and time-to-threshold forecast for a single worker.

    Args:
        worker_id (str): Worker ID code.
        db_path (str): Database file path.

    Returns:
        Dict[str, Any]: Forecast metrics, estimated days, and status messages.
    """
    w_profile = database.get_worker_by_id(worker_id, db_path)
    w_name = w_profile["name"] if w_profile else f"Worker {worker_id}"
    w_zone = w_profile["work_zone"] if w_profile else "Unassigned"
    w_dept = w_profile["department"] if w_profile else "Operations"

    df_readings = database.get_readings_for_worker(worker_id, db_path)
    cum_dose = database.get_cumulative_dose(worker_id, db_path)

    # 1. Check if sufficient historical records exist
    if df_readings.empty or len(df_readings) < MIN_SCANS_REQUIRED:
        return {
            "worker_id": worker_id,
            "name": w_name,
            "work_zone": w_zone,
            "department": w_dept,
            "cumulative_dose": round(cum_dose, 2),
            "total_scans": len(df_readings),
            "status": "insufficient_data",
            "daily_rate": None,
            "days_to_warning": None,
            "days_to_critical": None,
            "forecast_message": "Insufficient data for forecasting (minimum 2 historical scans required).",
            "trend_badge": "⚪ Insufficient Data",
            "priority_score": 999.0
        }

    # 2. Parse timestamps and sort chronologically
    df_sorted = df_readings.copy()
    df_sorted["timestamp_dt"] = pd.to_datetime(df_sorted["timestamp"])
    df_sorted = df_sorted.sort_values("timestamp_dt", ascending=True)

    t_first = df_sorted["timestamp_dt"].iloc[0]
    t_last = df_sorted["timestamp_dt"].iloc[-1]
    
    # Calculate distinct scan days and total time span
    unique_dates = df_sorted["timestamp_dt"].dt.date.nunique()
    time_span_days = max((t_last - t_first).total_seconds() / 86400.0, 0.0)

    total_dose_in_window = float(df_sorted["dose"].sum())

    if time_span_days >= 1.0:
        # Multi-day surveillance: average daily accumulation over the observation span
        daily_rate = total_dose_in_window / time_span_days
    elif unique_dates > 1:
        daily_rate = total_dose_in_window / float(unique_dates)
    else:
        # Single-day observation: daily rate is the accumulated dose for that work shift / day
        daily_rate = total_dose_in_window

    daily_rate = max(0.0, daily_rate)

    # 3. Handle threshold status
    if cum_dose >= THRESHOLD_CRITICAL:
        return {
            "worker_id": worker_id,
            "name": w_name,
            "work_zone": w_zone,
            "department": w_dept,
            "cumulative_dose": round(cum_dose, 2),
            "total_scans": len(df_readings),
            "status": "exceeded_critical",
            "daily_rate": round(daily_rate, 2),
            "days_to_warning": 0.0,
            "days_to_critical": 0.0,
            "forecast_message": f"CRITICAL LIMIT EXCEEDED: Worker {worker_id} has accumulated {cum_dose:.2f} ppm*hr (ceiling: {THRESHOLD_CRITICAL:.1f} ppm*hr). Immediate medical review required.",
            "trend_badge": "🔴 Critical Exceeded",
            "priority_score": -100.0
        }

    if daily_rate <= 0.01:
        return {
            "worker_id": worker_id,
            "name": w_name,
            "work_zone": w_zone,
            "department": w_dept,
            "cumulative_dose": round(cum_dose, 2),
            "total_scans": len(df_readings),
            "status": "stable",
            "daily_rate": round(daily_rate, 2),
            "days_to_warning": None,
            "days_to_critical": None,
            "forecast_message": f"Negligible accumulation rate ({daily_rate:.2f} ppm*hr/day). Worker {worker_id} exposure is stable within safe operating limits.",
            "trend_badge": "🟢 Stable / Low Risk",
            "priority_score": 500.0
        }

    # 4. Compute projected days to reach Warning and Critical thresholds
    days_to_warning = None
    if cum_dose < THRESHOLD_WARNING:
        remaining_warn = THRESHOLD_WARNING - cum_dose
        days_to_warning = max(0.1, remaining_warn / daily_rate)

    remaining_crit = THRESHOLD_CRITICAL - cum_dose
    days_to_critical = max(0.1, remaining_crit / daily_rate)

    # 5. Formulate human-readable message
    if days_to_warning is not None:
        if days_to_warning < 1.0:
            warn_str = f"~{int(days_to_warning * 24)} hours"
        elif days_to_warning < 1.5:
            warn_str = "~1 day"
        else:
            warn_str = f"~{days_to_warning:.1f} days"

        if days_to_critical < 1.5:
            crit_str = "~1 day"
        else:
            crit_str = f"~{days_to_critical:.1f} days"

        msg = (
            f"At the current exposure rate of +{daily_rate:.2f} ppm*hr/day, Worker {worker_id} ({w_name}) "
            f"may reach the warning level ({THRESHOLD_WARNING:.1f} ppm*hr) in {warn_str} "
            f"(critical limit in {crit_str})."
        )
        badge = "🟡 Warning Approaching" if days_to_warning <= 7 else "🟢 Steady Accumulation"
        priority_score = days_to_warning

    else:
        # Already past warning threshold (10.0), approaching Critical (50.0)
        if days_to_critical < 1.0:
            crit_str = f"~{int(days_to_critical * 24)} hours"
        elif days_to_critical < 1.5:
            crit_str = "~1 day"
        else:
            crit_str = f"~{days_to_critical:.1f} days"

        msg = (
            f"At the current exposure rate of +{daily_rate:.2f} ppm*hr/day, Worker {worker_id} ({w_name}) "
            f"is in Caution Tier and may reach the critical threshold ({THRESHOLD_CRITICAL:.1f} ppm*hr) in {crit_str}."
        )
        badge = "🔴 Critical Approaching" if days_to_critical <= 7 else "🟡 Elevated Accumulation"
        priority_score = days_to_critical

    return {
        "worker_id": worker_id,
        "name": w_name,
        "work_zone": w_zone,
        "department": w_dept,
        "cumulative_dose": round(cum_dose, 2),
        "total_scans": len(df_readings),
        "status": "active_forecast",
        "daily_rate": round(daily_rate, 2),
        "days_to_warning": round(days_to_warning, 1) if days_to_warning is not None else None,
        "days_to_critical": round(days_to_critical, 1),
        "forecast_message": msg,
        "trend_badge": badge,
        "priority_score": round(priority_score, 2)
    }


def get_all_workers_forecast_summary(
    db_path: str = database.DEFAULT_DB_PATH
) -> List[Dict[str, Any]]:
    """
    Computes forecasts for all registered workers and ranks them by exposure urgency.

    Returns:
        List[Dict[str, Any]]: Sorted list of worker forecast records (most critical first).
    """
    df_workers = database.get_all_workers(db_path)
    df_readings = database.get_all_readings(db_path)

    worker_ids = set()
    if not df_workers.empty:
        worker_ids.update(df_workers["worker_id"].tolist())
    if not df_readings.empty:
        worker_ids.update(df_readings["worker_id"].tolist())

    forecasts = []
    for wid in sorted(list(worker_ids)):
        f = compute_worker_forecast(wid, db_path)
        forecasts.append(f)

    # Sort: Critical exceeded first, then lowest days_to_warning/critical, then stable, then insufficient data
    forecasts.sort(key=lambda x: x["priority_score"])
    return forecasts
