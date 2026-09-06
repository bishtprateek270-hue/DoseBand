"""
DoseBand QR Code & Smart Badge Identification Module.

This module provides utilities to:
1. Generate printable QR dosimeter smart badges containing badge_id & worker_id.
2. Decode QR codes from uploaded images, live cameras, or badge scans using OpenCV.
3. Validate badge registration, worker linkage, active status, and shelf-life expiry dates.
"""

from datetime import datetime, date
import io
import json
import os
from typing import Dict, Optional, Tuple, Union
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import qrcode

import database

DEFAULT_DB_PATH: str = "doseband.db"


def generate_qr_payload(worker_id: str, badge_id: str) -> str:
    """
    Creates a standardized JSON payload string for a worker badge.
    """
    payload = {
        "app": "DoseBand",
        "worker_id": str(worker_id).strip(),
        "badge_id": str(badge_id).strip(),
        "version": "1.0"
    }
    return json.dumps(payload, separators=(',', ':'))


def generate_badge_qr_png(
    worker_id: str,
    badge_id: str,
    box_size: int = 10,
    border: int = 2
) -> bytes:
    """
    Generates a raw QR code PNG image as bytes.

    Args:
        worker_id (str): Unique worker identifier (e.g., 'W-101').
        badge_id (str): Unique badge identifier (e.g., 'BDG-101').
        box_size (int): Size of each QR pixel box.
        border (int): Border margin in boxes.

    Returns:
        bytes: PNG encoded image bytes.
    """
    payload = generate_qr_payload(worker_id, badge_id)
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=box_size,
        border=border
    )
    qr.add_data(payload)
    qr.make(fit=True)

    img = qr.make_image(fill_color="#0F172A", back_color="#FFFFFF")
    buf = io.BytesIO()
    img.save(buf)
    return buf.getvalue()


def generate_styled_badge_card(
    worker_profile: Dict[str, Union[str, int]],
    output_size: Tuple[int, int] = (600, 360)
) -> bytes:
    """
    Generates a branded, printable industrial ID badge card with embedded QR code.

    Args:
        worker_profile (dict): Dictionary with worker fields (worker_id, name, department, work_zone, shift, badge_id, badge_expiry_date, status).
        output_size (tuple): Width and height of the badge card in pixels.

    Returns:
        bytes: PNG encoded badge card image.
    """
    w_width, w_height = output_size
    card = Image.new("RGB", (w_width, w_height), color="#0F172A")
    draw = ImageDraw.Draw(card)

    # Top header banner
    draw.rectangle([(0, 0), (w_width, 64)], fill="#1E293B")
    draw.rectangle([(0, 60), (w_width, 64)], fill="#EA580C")

    # Header text
    draw.text((20, 16), "DOSEBAND • INDUSTRIAL SAFETY DOSIMETER BADGE", fill="#F8FAFC")
    draw.text((20, 38), "DGMS / OISD H2S HAZARDOUS GAS COMPLIANCE", fill="#94A3B8")

    # Generate QR Code for badge
    qr_bytes = generate_badge_qr_png(
        worker_id=str(worker_profile["worker_id"]),
        badge_id=str(worker_profile["badge_id"]),
        box_size=7,
        border=1
    )
    qr_img = Image.open(io.BytesIO(qr_bytes)).convert("RGB")
    qr_size = 210
    qr_img = qr_img.resize((qr_size, qr_size), Image.Resampling.LANCZOS)

    # Paste QR Code on right side
    qr_x = w_width - qr_size - 24
    qr_y = 80
    # Background white rounded container for QR
    draw.rectangle([(qr_x - 6, qr_y - 6), (qr_x + qr_size + 6, qr_y + qr_size + 6)], fill="#FFFFFF")
    card.paste(qr_img, (qr_x, qr_y))

    # Badge Info on Left side
    text_x = 24
    curr_y = 82
    draw.text((text_x, curr_y), str(worker_profile.get("name", "Unknown Worker")), fill="#F8FAFC")
    curr_y += 24
    draw.text((text_x, curr_y), f"WORKER ID: {worker_profile.get('worker_id', 'N/A')}", fill="#F97316")
    curr_y += 26

    draw.text((text_x, curr_y), f"DEPT: {worker_profile.get('department', 'N/A')}", fill="#CBD5E1")
    curr_y += 20
    draw.text((text_x, curr_y), f"ZONE: {worker_profile.get('work_zone', 'N/A')}", fill="#CBD5E1")
    curr_y += 20
    draw.text((text_x, curr_y), f"SHIFT: {worker_profile.get('shift', 'N/A')}", fill="#94A3B8")
    curr_y += 24

    draw.text((text_x, curr_y), f"BADGE ID: {worker_profile.get('badge_id', 'N/A')}", fill="#38BDF8")
    curr_y += 20
    draw.text((text_x, curr_y), f"EXPIRES: {worker_profile.get('badge_expiry_date', 'N/A')}", fill="#FCD34D")

    # Bottom status banner
    status_text = str(worker_profile.get("status", "Active")).upper()
    status_bg = "#065F46" if status_text == "ACTIVE" else "#991B1B"
    draw.rectangle([(0, w_height - 36), (w_width, w_height)], fill=status_bg)
    draw.text((20, w_height - 26), f"STATUS: {status_text} • SCAN AT START OF SHIFT", fill="#F8FAFC")

    buf = io.BytesIO()
    card.save(buf, format="PNG")
    return buf.getvalue()


def decode_qr_from_image_bytes(image_bytes: bytes) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """
    Decodes QR code from raw image bytes using OpenCV QRCodeDetector.

    Args:
        image_bytes (bytes): Image file bytes.

    Returns:
        tuple: (worker_id, badge_id, raw_payload) if found, else (None, None, None).
    """
    try:
        np_arr = np.frombuffer(image_bytes, np.uint8)
        bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if bgr is None:
            return None, None, None

        detector = cv2.QRCodeDetector()
        
        # Primary detection
        decoded_text, points, _ = detector.detectAndDecode(bgr)
        
        # Fallback: if not detected, try grayscale + contrast equalization
        if not decoded_text:
            gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
            decoded_text, points, _ = detector.detectAndDecode(gray)

        # Fallback 2: Otsu binary thresholding
        if not decoded_text:
            gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
            _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            decoded_text, points, _ = detector.detectAndDecode(thresh)

        if not decoded_text:
            return None, None, None

        raw_payload = decoded_text.strip()

        # Attempt to parse as JSON payload
        try:
            parsed = json.loads(raw_payload)
            if isinstance(parsed, dict):
                w_id = parsed.get("worker_id") or parsed.get("worker") or parsed.get("id")
                b_id = parsed.get("badge_id") or parsed.get("badge")
                if w_id or b_id:
                    return str(w_id).strip() if w_id else None, str(b_id).strip() if b_id else None, raw_payload
        except Exception:
            pass

        # Attempt to parse delimiter string e.g. "W-101:BDG-101" or "W-101|BDG-101"
        for delimiter in [":", "|", ",", "-", "_"]:
            if delimiter in raw_payload:
                parts = raw_payload.split(delimiter, 1)
                if len(parts) == 2:
                    p0, p1 = parts[0].strip(), parts[1].strip()
                    if p0.startswith("W") and (p1.startswith("BDG") or p1.startswith("B")):
                        return p0, p1, raw_payload
                    elif (p0.startswith("BDG") or p0.startswith("B")) and p1.startswith("W"):
                        return p1, p0, raw_payload

        # Single ID fallback (if raw text looks like Worker ID or Badge ID)
        if raw_payload.startswith("W-") or raw_payload.startswith("W"):
            return raw_payload, None, raw_payload
        elif raw_payload.startswith("BDG-") or raw_payload.startswith("BDG"):
            return None, raw_payload, raw_payload

        return None, None, raw_payload

    except Exception:
        return None, None, None


def validate_badge_profile(
    worker_id: Optional[str],
    badge_id: Optional[str],
    db_path: str = DEFAULT_DB_PATH
) -> Dict[str, Union[bool, str, Optional[dict]]]:
    """
    Validates that the scanned badge exists, belongs to that worker, is active, and is not expired.

    Args:
        worker_id (Optional[str]): Worker ID from QR scan.
        badge_id (Optional[str]): Badge ID from QR scan.
        db_path (str): Path to SQLite database.

    Returns:
        dict: Validation results with status, message, and worker dictionary if found.
    """
    if not worker_id and not badge_id:
        return {
            "valid": False,
            "status": "UNRECOGNIZED",
            "worker": None,
            "message": "Scanned QR code does not contain recognized DoseBand badge credentials."
        }

    # Lookup worker profile
    worker_profile = None
    if worker_id:
        worker_profile = database.get_worker_by_id(worker_id, db_path=db_path)
    elif badge_id:
        worker_profile = database.get_worker_by_badge_id(badge_id, db_path=db_path)

    if not worker_profile:
        return {
            "valid": False,
            "status": "NOT_FOUND",
            "worker": None,
            "message": f"Worker/Badge identifier ('{worker_id or badge_id}') is not registered in the database."
        }

    # 1. Validate badge-worker linkage
    if badge_id and worker_profile.get("badge_id") != badge_id:
        return {
            "valid": False,
            "status": "MISMATCH",
            "worker": worker_profile,
            "message": f"Badge mismatch! Scanned badge `{badge_id}` does not match worker {worker_profile['worker_id']}'s registered badge `{worker_profile['badge_id']}`."
        }

    # 2. Validate worker status
    if worker_profile.get("status") != "Active":
        return {
            "valid": False,
            "status": "INACTIVE",
            "worker": worker_profile,
            "message": f"Worker status is '{worker_profile.get('status')}' (Not Active). Cannot proceed with scan logging."
        }

    # 3. Validate badge shelf-life expiry date
    try:
        exp_date_str = worker_profile.get("badge_expiry_date", "")
        exp_date = datetime.strptime(exp_date_str, "%Y-%m-%d").date()
        today_date = date.today()
        if exp_date < today_date:
            return {
                "valid": False,
                "status": "EXPIRED",
                "worker": worker_profile,
                "message": f"Dosimeter Badge `{worker_profile.get('badge_id')}` expired on {exp_date_str}. Immediate replacement required!"
            }
    except Exception:
        pass

    return {
        "valid": True,
        "status": "VALID",
        "worker": worker_profile,
        "message": f"Badge `{worker_profile.get('badge_id')}` is VALID & active for worker {worker_profile.get('name')} ({worker_profile.get('worker_id')})."
    }


if __name__ == "__main__":
    test_worker = {
        "worker_id": "W-101",
        "name": "Rajesh Kumar",
        "department": "Refinery Operations",
        "work_zone": "Zone A - Crude Distillation Unit",
        "shift": "Shift 1 (06:00 - 14:00)",
        "badge_id": "BDG-101",
        "badge_issue_date": "2026-08-01",
        "badge_expiry_date": "2026-11-01",
        "status": "Active"
    }

    print("Generating raw QR PNG...")
    qr_png = generate_badge_qr_png("W-101", "BDG-101")
    print(f"QR PNG Size: {len(qr_png)} bytes")

    print("\nGenerating styled badge card...")
    badge_card = generate_styled_badge_card(test_worker)
    print(f"Badge Card Size: {len(badge_card)} bytes")

    print("\nDecoding QR from generated badge card...")
    w_id, b_id, raw = decode_qr_from_image_bytes(badge_card)
    print(f"Decoded Worker ID: {w_id}, Badge ID: {b_id}")

    print("\nValidating against database...")
    res = validate_badge_profile(w_id, b_id)
    print("Validation Result:", res)
    assert res["valid"] is True, "Validation should pass for registered W-101"
    print("\nAll QR Manager unit tests passed!")
