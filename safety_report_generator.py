"""
DoseBand Safety Report Generator Module.

Generates formal DGMS/OISD-compliant industrial dosimetry safety audit reports
in PDF (via ReportLab) and CSV formats based on real SQLite database records.
"""

from datetime import datetime, date
import io
from typing import Dict, List, Optional, Any, Tuple
import pandas as pd

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    HRFlowable,
    KeepTogether,
)

import database


def filter_readings(
    worker_id_filter: str = "All Workers",
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db_path: str = database.DEFAULT_DB_PATH
) -> pd.DataFrame:
    """
    Fetches and filters readings from SQLite database by worker and date range.
    """
    if worker_id_filter == "All Workers":
        df = database.get_all_readings(db_path)
    else:
        df = database.get_readings_for_worker(worker_id_filter, db_path)

    if df.empty:
        return df

    df["timestamp_dt"] = pd.to_datetime(df["timestamp"])
    df["scan_date"] = df["timestamp_dt"].dt.date

    if start_date is not None:
        df = df[df["scan_date"] >= start_date]
    if end_date is not None:
        df = df[df["scan_date"] <= end_date]

    return df.sort_values("timestamp_dt", ascending=False)


def generate_safety_report_data(
    worker_id_filter: str = "All Workers",
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db_path: str = database.DEFAULT_DB_PATH
) -> Dict[str, Any]:
    """
    Compiles full audit metrics, worker profiles, and scan logs for reporting.
    """
    df_readings = filter_readings(worker_id_filter, start_date, end_date, db_path)
    df_all_workers = database.get_all_workers(db_path)
    today = date.today()

    # Determine targeted workers list
    if worker_id_filter == "All Workers":
        if not df_all_workers.empty:
            targeted_workers = df_all_workers.to_dict("records")
        else:
            w_ids = df_readings["worker_id"].unique().tolist() if not df_readings.empty else []
            targeted_workers = [{"worker_id": wid, "name": f"Worker {wid}", "department": "Operations", "work_zone": "General", "shift": "General", "badge_id": "N/A", "badge_issue_date": "N/A", "badge_expiry_date": "N/A", "status": "Active"} for wid in w_ids]
    else:
        w_prof = database.get_worker_by_id(worker_id_filter, db_path)
        if w_prof:
            targeted_workers = [w_prof]
        else:
            targeted_workers = [{"worker_id": worker_id_filter, "name": f"Worker {worker_id_filter}", "department": "Operations", "work_zone": "General", "shift": "General", "badge_id": "N/A", "badge_issue_date": "N/A", "badge_expiry_date": "N/A", "status": "Active"}]

    # Compute worker-level status breakdown
    worker_details = []
    for w in targeted_workers:
        wid = w["worker_id"]
        cum_dose = database.get_cumulative_dose(wid, db_path)
        
        # Badge expiry
        is_expired = False
        days_left = 999
        if w.get("badge_expiry_date") and w["badge_expiry_date"] != "N/A":
            try:
                exp_d = datetime.strptime(w["badge_expiry_date"], "%Y-%m-%d").date()
                days_left = (exp_d - today).days
                is_expired = exp_d < today or w.get("status") != "Active"
            except Exception:
                pass

        if cum_dose >= 50.0:
            risk_tier = "CRITICAL (Exceeds Limit)"
        elif cum_dose >= 10.0:
            risk_tier = "CAUTION (Elevated)"
        else:
            risk_tier = "SAFE (Within Limit)"

        worker_details.append({
            "worker_id": wid,
            "name": w.get("name", "Unknown"),
            "department": w.get("department", "Operations"),
            "work_zone": w.get("work_zone", "General"),
            "shift": w.get("shift", "General"),
            "badge_id": w.get("badge_id", "N/A"),
            "badge_issue_date": w.get("badge_issue_date", "N/A"),
            "badge_expiry_date": w.get("badge_expiry_date", "N/A"),
            "badge_status": f"EXPIRED ({abs(days_left)}d ago)" if is_expired else (f"Expiring in {days_left}d" if days_left <= 7 else "Active / Valid"),
            "status": w.get("status", "Active"),
            "cumulative_dose": round(cum_dose, 2),
            "risk_tier": risk_tier
        })

    # Summary analytics across filtered readings
    total_scans = len(df_readings)
    total_dose = float(df_readings["dose"].sum()) if not df_readings.empty else 0.0
    avg_dose = float(df_readings["dose"].mean()) if not df_readings.empty else 0.0
    max_dose = float(df_readings["dose"].max()) if not df_readings.empty else 0.0
    
    avg_temp = float(df_readings["temperature"].mean()) if not df_readings.empty and "temperature" in df_readings.columns else 25.0
    avg_humidity = float(df_readings["humidity"].mean()) if not df_readings.empty and "humidity" in df_readings.columns else 50.0

    # Overall Compliance Status
    if any(w["cumulative_dose"] >= 50.0 for w in worker_details):
        overall_compliance = "CRITICAL NON-COMPLIANCE (Immediate Medical & Safety Review Required)"
        compliance_color = "#DC2626"
    elif any(w["cumulative_dose"] >= 10.0 or "EXPIRED" in w["badge_status"] for w in worker_details):
        overall_compliance = "CAUTION / ACTION REQUIRED (Approaching Exposure Ceiling / Badge Expiry)"
        compliance_color = "#D97706"
    else:
        overall_compliance = "COMPLIANT (All monitored parameters within OSHA / DGMS safe thresholds)"
        compliance_color = "#059669"

    report_id = f"DB-SAR-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    return {
        "report_id": report_id,
        "generated_at": generated_at,
        "worker_filter": worker_id_filter,
        "start_date": str(start_date) if start_date else "Earliest Recorded",
        "end_date": str(end_date) if end_date else "Latest Recorded",
        "total_scans": total_scans,
        "total_dose": round(total_dose, 2),
        "avg_dose": round(avg_dose, 2),
        "max_dose": round(max_dose, 2),
        "avg_temp": round(avg_temp, 1),
        "avg_humidity": round(avg_humidity, 1),
        "overall_compliance": overall_compliance,
        "compliance_color": compliance_color,
        "workers": worker_details,
        "readings_df": df_readings
    }


def generate_pdf_report(report_data: Dict[str, Any]) -> bytes:
    """
    Generates a professional PDF industrial safety report using ReportLab.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()
    
    # Custom Palette
    navy = colors.HexColor("#0F172A")
    slate = colors.HexColor("#1E293B")
    orange = colors.HexColor("#EA580C")
    muted_grey = colors.HexColor("#64748B")
    light_bg = colors.HexColor("#F8FAFC")
    border_grey = colors.HexColor("#E2E8F0")

    # Typography styles
    style_title = ParagraphStyle(
        "DocTitle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=18,
        leading=22,
        textColor=navy,
        spaceAfter=4
    )
    style_subtitle = ParagraphStyle(
        "DocSubTitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=muted_grey,
        spaceAfter=10
    )
    style_section = ParagraphStyle(
        "DocSection",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=12,
        leading=15,
        textColor=navy,
        spaceBefore=10,
        spaceAfter=6
    )
    style_body = ParagraphStyle(
        "DocBody",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8.5,
        leading=11,
        textColor=slate
    )
    style_disclaimer = ParagraphStyle(
        "DocDisclaimer",
        parent=styles["Normal"],
        fontName="Helvetica-Oblique",
        fontSize=7.5,
        leading=10,
        textColor=muted_grey
    )

    story = []

    # 1. Header Banner Table
    header_data = [
        [
            Paragraph("<b>🛡️ DOSEBAND OCCUPATIONAL SAFETY DOSIMETRY</b><br/><font color='#64748B' size=8>Hazardous Gas Exposure Monitoring & Health Audit Report</font>", style_body),
            Paragraph(f"<b>REPORT ID:</b> {report_data['report_id']}<br/><b>DATE:</b> {report_data['generated_at']}<br/><b>STANDARD:</b> DGMS / OISD / OSHA PEL", style_body)
        ]
    ]
    t_header = Table(header_data, colWidths=[340, 180])
    t_header.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), light_bg),
        ('BOX', (0,0), (-1,-1), 1, border_grey),
        ('PADDING', (0,0), (-1,-1), 8),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(t_header)
    story.append(Spacer(1, 10))

    # 2. Scope & Compliance Banner
    comp_color = colors.HexColor(report_data["compliance_color"])
    scope_text = f"<b>Audit Scope:</b> {report_data['worker_filter']} &nbsp;|&nbsp; <b>Time Window:</b> {report_data['start_date']} to {report_data['end_date']}"
    comp_text = f"<b>Compliance Audit Status:</b> {report_data['overall_compliance']}"
    
    scope_data = [
        [Paragraph(scope_text, style_body)],
        [Paragraph(comp_text, ParagraphStyle("Comp", parent=style_body, fontName="Helvetica-Bold", textColor=comp_color))]
    ]
    t_scope = Table(scope_data, colWidths=[520])
    t_scope.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), light_bg),
        ('LINELEFT', (0,0), (0,-1), 3, comp_color),
        ('BOX', (0,0), (-1,-1), 0.5, border_grey),
        ('PADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_scope)
    story.append(Spacer(1, 10))

    # 3. KPI Summary Table
    story.append(Paragraph("<b>1. Exposure & Environmental Key Metrics</b>", style_section))
    kpi_data = [
        ["Total Scans Logged", "Total Dose (ppm*hr)", "Mean Scan Dose", "Peak Single Dose", "Mean Temp (°C)", "Mean RH (%)"],
        [
            str(report_data["total_scans"]),
            f"{report_data['total_dose']:.2f}",
            f"{report_data['avg_dose']:.2f}",
            f"{report_data['max_dose']:.2f}",
            f"{report_data['avg_temp']:.1f}°C",
            f"{report_data['avg_humidity']:.1f}%"
        ]
    ]
    t_kpi = Table(kpi_data, colWidths=[86, 86, 86, 86, 88, 88])
    t_kpi.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), slate),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,0), 8),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('BACKGROUND', (0,1), (-1,1), light_bg),
        ('FONTNAME', (0,1), (-1,1), 'Helvetica-Bold'),
        ('FONTSIZE', (0,1), (-1,1), 9),
        ('TEXTCOLOR', (0,1), (-1,1), navy),
        ('GRID', (0,0), (-1,-1), 0.5, border_grey),
        ('PADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_kpi)
    story.append(Spacer(1, 10))

    # 4. Worker Profiles Table
    story.append(Paragraph("<b>2. Monitored Personnel & Dosimeter Badge Status</b>", style_section))
    w_rows = [["Worker ID", "Name", "Department", "Work Zone", "Badge ID", "Expiry Date", "Cum. Dose", "Risk Status"]]
    for w in report_data["workers"]:
        w_rows.append([
            w["worker_id"],
            w["name"],
            w["department"],
            w["work_zone"],
            w["badge_id"],
            w["badge_expiry_date"],
            f"{w['cumulative_dose']:.2f} ppm*hr",
            w["risk_tier"]
        ])

    t_workers = Table(w_rows, colWidths=[55, 80, 85, 95, 55, 60, 50, 40])
    t_workers.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), navy),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,0), 7.5),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('GRID', (0,0), (-1,-1), 0.5, border_grey),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, light_bg]),
        ('FONTSIZE', (0,1), (-1,-1), 7.5),
        ('PADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(t_workers)
    story.append(Spacer(1, 10))

    # 5. Prototype Environmental Compensation Notice
    story.append(Paragraph("<b>3. Prototype Environmental Compensation Notice</b>", style_section))
    proto_text = (
        "⚠️ <b>EXPERIMENTAL PROTOTYPE NOTICE:</b> Ambient temperature (°C) and relative humidity (%) compensation "
        "factors (CF) reflect a theoretical kinetic adjustment model normalized against standard reference baseline "
        "(T_ref = 25.0°C, RH_ref = 50.0%). <i>Official regulatory dose compliance continues to rely upon uncompensated "
        "optical ML calibration curves until empirical multi-chamber environmental validation is complete.</i>"
    )
    t_proto = Table([[Paragraph(proto_text, style_disclaimer)]], colWidths=[520])
    t_proto.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#FEF3C7")),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor("#F59E0B")),
        ('PADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_proto)
    story.append(Spacer(1, 10))

    # 6. Recent Scan History Table (up to 15 entries)
    story.append(Paragraph("<b>4. Logged Scan History & Sensor Staining Analysis</b>", style_section))
    df_r = report_data["readings_df"]
    if df_r.empty:
        story.append(Paragraph("<i>No scan records logged in the selected time window.</i>", style_disclaimer))
    else:
        scan_rows = [["ID", "Worker", "Timestamp", "Dose (ppm*hr)", "Raw Int", "T (°C)", "RH (%)", "CF*", "Corr Int*", "Risk Level"]]
        # Limit to last 15 scans in PDF to prevent multi-page overflow
        for _, r in df_r.head(15).iterrows():
            ts_str = str(r["timestamp"])[:16].replace("T", " ")
            r_int = f"{float(r.get('raw_intensity', r['intensity'])):.3f}"
            c_int = f"{float(r.get('corrected_intensity', r['intensity'])):.3f}"
            cf_val = f"{float(r.get('compensation_factor', 1.0)):.3f}"
            temp_val = f"{float(r.get('temperature', 25.0)):.1f}"
            rh_val = f"{float(r.get('humidity', 50.0)):.0f}%"

            scan_rows.append([
                str(r["id"]),
                str(r["worker_id"]),
                ts_str,
                f"{float(r['dose']):.2f}",
                r_int,
                temp_val,
                rh_val,
                cf_val,
                c_int,
                str(r["risk_level"]).split(" ")[0]
            ])

        t_scans = Table(scan_rows, colWidths=[25, 45, 80, 60, 42, 38, 38, 38, 44, 50])
        t_scans.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), slate),
            ('TEXTCOLOR', (0,0), (-1,0), colors.white),
            ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
            ('FONTSIZE', (0,0), (-1,0), 7),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('GRID', (0,0), (-1,-1), 0.5, border_grey),
            ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, light_bg]),
            ('FONTSIZE', (0,1), (-1,-1), 7),
            ('PADDING', (0,0), (-1,-1), 3.5),
        ]))
        story.append(t_scans)
        if len(df_r) > 15:
            story.append(Paragraph(f"<i>*Showing 15 most recent scans of {len(df_r)} total matching records. Download CSV for complete dataset.</i>", style_disclaimer))

    story.append(Spacer(1, 14))

    # 7. Sign-off Footer
    sign_data = [
        [
            Paragraph("<b>Generated By:</b> DoseBand Industrial Safety Console<br/><b>Verified Safety Officer:</b> ___________________________", style_disclaimer),
            Paragraph("<b>Safety Officer Signature:</b> ___________________________<br/><b>Seal & Date:</b> ___________________________", style_disclaimer)
        ]
    ]
    t_sign = Table(sign_data, colWidths=[260, 260])
    t_sign.setStyle(TableStyle([
        ('PADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
    ]))
    story.append(t_sign)

    doc.build(story)
    buffer.seek(0)
    return buffer.getvalue()


def generate_csv_report(report_data: Dict[str, Any]) -> str:
    """
    Generates a structured CSV compliance report.
    """
    df_r = report_data["readings_df"].copy()
    if df_r.empty:
        return "No readings logged for selected filter criteria."

    if "temperature" not in df_r.columns:
        df_r["temperature"] = 25.0
    if "humidity" not in df_r.columns:
        df_r["humidity"] = 50.0
    if "compensation_factor" not in df_r.columns:
        df_r["compensation_factor"] = 1.0
    if "corrected_intensity" not in df_r.columns:
        df_r["corrected_intensity"] = df_r["intensity"]
    if "raw_intensity" not in df_r.columns:
        df_r["raw_intensity"] = df_r["intensity"]

    df_export = df_r[[
        "id",
        "worker_id",
        "timestamp",
        "dose",
        "raw_intensity",
        "temperature",
        "humidity",
        "compensation_factor",
        "corrected_intensity",
        "risk_level",
        "is_expired",
        "expiry_status_message"
    ]].rename(columns={
        "id": "Scan Record ID",
        "worker_id": "Worker ID",
        "timestamp": "Scan Timestamp",
        "dose": "Dose (ppm*hr)",
        "raw_intensity": "Raw Optical Intensity",
        "temperature": "Ambient Temp (deg C)",
        "humidity": "Ambient RH (%)",
        "compensation_factor": "Prototype Comp Factor (CF)",
        "corrected_intensity": "Prototype Corrected Intensity",
        "risk_level": "Safety Risk Classification",
        "is_expired": "Badge Expired Flag",
        "expiry_status_message": "Badge Status Message"
    })

    return df_export.to_csv(index=False)
