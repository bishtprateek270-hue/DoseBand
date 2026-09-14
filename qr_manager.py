"""
DoseBand QR Code & Smart Badge Identification Module.

This module provides utilities to:
1. Generate printable QR dosimeter smart badges containing badge_id & worker_id in canonical DoseBand format.
2. Decode QR codes from uploaded images, screenshots, mobile camera photos, and badge scans using high-performance zxing-cpp and multi-pass OpenCV enhancements.
3. Validate badge registration, worker linkage, active status, and shelf-life expiry dates against the workforce database.
"""

from datetime import datetime, date
import io
import json
import os
import re
from typing import Any, Dict, List, Optional, Tuple, Union
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageOps
import qrcode

try:
    import zxingcpp
    HAS_ZXING = True
except ImportError:
    HAS_ZXING = False

import database

DEFAULT_DB_PATH: str = "doseband.db"


def generate_qr_payload(worker_id: str, badge_id: str) -> str:
    """
    Creates a standardized canonical JSON payload string for a worker badge.
    Format:
    {
        "type": "doseband_worker",
        "version": 1,
        "worker_id": "<worker_id>",
        "badge_id": "<badge_id>"
    }
    """
    payload = {
        "type": "doseband_worker",
        "version": 1,
        "worker_id": str(worker_id).strip(),
        "badge_id": str(badge_id).strip()
    }
    return json.dumps(payload, separators=(',', ':'))


def generate_badge_qr_png(
    worker_id: str,
    badge_id: str,
    box_size: int = 10,
    border: int = 2,
    qr_payload: Optional[str] = None
) -> bytes:
    """
    Generates a raw QR code PNG image as bytes using canonical DoseBand format.

    Args:
        worker_id (str): Unique worker identifier (e.g., 'W-101').
        badge_id (str): Unique badge identifier (e.g., 'BDG-101').
        box_size (int): Size of each QR pixel box.
        border (int): Border margin in boxes.
        qr_payload (str, optional): Pre-stored permanent QR payload.

    Returns:
        bytes: PNG encoded image bytes.
    """
    if not qr_payload or not str(qr_payload).strip():
        payload = generate_qr_payload(worker_id, badge_id)
    else:
        payload = str(qr_payload).strip()

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
    img.save(buf, format="PNG")
    return buf.getvalue()


def generate_styled_badge_card(
    worker_profile: Dict[str, Union[str, int]],
    output_size: Tuple[int, int] = (600, 360)
) -> bytes:
    """
    Generates a branded, printable industrial ID badge card with embedded QR code.

    Args:
        worker_profile (dict): Dictionary with worker fields (worker_id, name, department, work_zone, shift, badge_id, badge_expiry_date, status, qr_payload).
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
        worker_id=str(worker_profile.get("worker_id", "")),
        badge_id=str(worker_profile.get("badge_id", "")),
        box_size=7,
        border=1,
        qr_payload=str(worker_profile.get("qr_payload", "")) if worker_profile.get("qr_payload") else None
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


def parse_doseband_payload(raw_text: Optional[str]) -> Tuple[Optional[str], Optional[str], bool]:
    """
    Parses decoded raw QR text.
    Returns (worker_id, badge_id, is_doseband_recognized).

    Supports:
    1. Canonical format: {"type": "doseband_worker", "version": 1, "worker_id": "...", "badge_id": "..."}
    2. Previous format: {"app": "DoseBand", "worker_id": "...", "badge_id": "...", "version": "1.0"}
    3. Generic JSON containing worker_id and/or badge_id
    4. Legacy plain text formats: "BDG-101", "W-101", "DOSEBAND:W-101:BDG-101", etc.
    """
    if not raw_text:
        return None, None, False

    text = str(raw_text).strip()
    if not text:
        return None, None, False

    # 1. Try parsing JSON
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            # Check for DoseBand indicators or worker/badge fields
            is_explicit_doseband = (
                data.get("type") == "doseband_worker" or
                data.get("app") == "DoseBand" or
                data.get("system") == "DoseBand"
            )
            wid = data.get("worker_id") or data.get("workerId") or data.get("id")
            bid = data.get("badge_id") or data.get("badgeId") or data.get("badge")

            if wid or bid:
                w_str = str(wid).strip() if wid is not None else None
                b_str = str(bid).strip() if bid is not None else None
                return w_str, b_str, True
            elif is_explicit_doseband:
                return None, None, True
            else:
                # Other JSON format (e.g. wifi, config, third-party) -> not DoseBand
                return None, None, False
    except (json.JSONDecodeError, ValueError):
        pass

    # 2. Check for third-party non-DoseBand QR patterns (URLs, UPI payments, WiFi, etc.)
    lower = text.lower()
    if lower.startswith(("http://", "https://", "upi://", "wifi:", "smsto:", "tel:", "mailto:", "otpauth:")):
        return None, None, False

    # 3. Check for structured plain text: DOSEBAND:W-101:BDG-101 or W-101/BDG-101
    doseband_prefix_match = re.search(r'DOSEBAND[:\-_/]([A-Za-z0-9\-_]+)[:\-_/]([A-Za-z0-9\-_]+)', text, re.IGNORECASE)
    if doseband_prefix_match:
        return doseband_prefix_match.group(1).strip(), doseband_prefix_match.group(2).strip(), True

    # 4. Check for legacy Badge ID (e.g., BDG-101, BDG_102, BDG101)
    badge_match = re.fullmatch(r'BDG[-_]?[A-Za-z0-9]+', text, re.IGNORECASE)
    if badge_match:
        return None, text.strip(), True

    # 5. Check for legacy Worker ID (e.g., W-101, W_102, W101)
    worker_match = re.fullmatch(r'W[-_]?[0-9]+', text, re.IGNORECASE)
    if worker_match:
        return text.strip(), None, True

    # Random text without any DoseBand identifier
    return None, None, False


def _decode_with_zxing(image_obj: Any) -> Optional[str]:
    """Helper to decode barcode using zxing-cpp if installed."""
    if not HAS_ZXING or image_obj is None:
        return None
    try:
        # Pass with all orientations, downscaling and inversion enabled
        res = zxingcpp.read_barcode(
            image_obj,
            try_rotate=True,
            try_downscale=True,
            try_invert=True,
            binarizer=zxingcpp.Binarizer.LocalAverage
        )
        if res and res.text:
            return res.text.strip()

        # Fallback with GlobalHistogram binarizer
        res2 = zxingcpp.read_barcode(
            image_obj,
            try_rotate=True,
            try_downscale=True,
            try_invert=True,
            binarizer=zxingcpp.Binarizer.GlobalHistogram
        )
        if res2 and res2.text:
            return res2.text.strip()
    except Exception:
        pass
    return None


def _decode_with_opencv(img_bgr: np.ndarray) -> Optional[str]:
    """Helper to decode barcode using OpenCV QRCodeDetector."""
    if img_bgr is None or img_bgr.size == 0:
        return None
    try:
        detector = cv2.QRCodeDetector()
        text, _, _ = detector.detectAndDecode(img_bgr)
        if text and text.strip():
            return text.strip()
    except Exception:
        pass

    try:
        if hasattr(cv2, "QRCodeDetectorAruco"):
            detector_aruco = cv2.QRCodeDetectorAruco()
            text, _, _ = detector_aruco.detectAndDecode(img_bgr)
            if text and text.strip():
                return text.strip()
    except Exception:
        pass
    return None


def decode_raw_qr_text_from_image_bytes(image_bytes: bytes) -> Optional[str]:
    """
    Decodes raw text from any QR code image bytes using a multi-pass, robust engine.
    Handles:
    - Screenshots (including cropped and high/low DPI)
    - Photos of mobile screens (glare, moire, perspective, exposure)
    - Rotated images (90, 180, 270 degrees)
    - Contrast/brightness variations

    Returns:
        Optional[str]: Raw decoded string if any QR code is found, else None.
    """
    if not image_bytes or len(image_bytes) == 0:
        return None

    # Step 1: Open with PIL and handle EXIF camera orientation
    pil_img: Optional[Image.Image] = None
    try:
        raw_pil = Image.open(io.BytesIO(image_bytes))
        pil_img = ImageOps.exif_transpose(raw_pil).convert("RGB")
    except Exception:
        pass

    # Step 2: Convert to OpenCV BGR numpy array
    np_arr = np.frombuffer(image_bytes, np.uint8)
    bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if pil_img is None and bgr is None:
        return None

    # Pass 1: Direct decode on original full-resolution image
    if pil_img is not None:
        text = _decode_with_zxing(pil_img)
        if text:
            return text

    if bgr is not None:
        text = _decode_with_zxing(bgr) or _decode_with_opencv(bgr)
        if text:
            return text

    # If OpenCV array is missing but PIL succeeded, convert PIL to OpenCV array
    if bgr is None and pil_img is not None:
        bgr = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)

    if bgr is None:
        return None

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

    # Pass 2: Grayscale decode
    text = _decode_with_zxing(gray) or _decode_with_opencv(gray)
    if text:
        return text

    # Pass 3: Multi-scale resizing (upscale for small badge QR, downscale for huge 48MP photos)
    h, w = gray.shape[:2]
    scale_factors = [1.5, 2.0, 0.75, 0.5] if max(h, w) < 2500 else [0.5, 0.25, 1.5]
    for scale in scale_factors:
        nw, nh = int(w * scale), int(h * scale)
        if nw > 10 and nh > 10:
            resized = cv2.resize(gray, (nw, nh), interpolation=cv2.INTER_CUBIC if scale > 1.0 else cv2.INTER_AREA)
            text = _decode_with_zxing(resized) or _decode_with_opencv(resized)
            if text:
                return text

    # Pass 4: Contrast enhancement (CLAHE + Sharpening)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    cl = clahe.apply(gray)
    text = _decode_with_zxing(cl) or _decode_with_opencv(cl)
    if text:
        return text

    # Pass 5: Thresholding variations (Otsu & Adaptive)
    _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    text = _decode_with_zxing(otsu) or _decode_with_opencv(otsu)
    if text:
        return text

    adapt = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 21, 5)
    text = _decode_with_zxing(adapt) or _decode_with_opencv(adapt)
    if text:
        return text

    # Pass 6: Rotations (90, 180, 270)
    for rot in [cv2.ROTATE_90_CLOCKWISE, cv2.ROTATE_180, cv2.ROTATE_90_COUNTERCLOCKWISE]:
        rotated_gray = cv2.rotate(gray, rot)
        text = _decode_with_zxing(rotated_gray) or _decode_with_opencv(rotated_gray)
        if text:
            return text

    # Pass 7: Contour / Region of Interest cropping
    # Find bounding boxes that resemble cards or QR squares
    try:
        contours, _ = cv2.findContours(otsu, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        for cnt in sorted(contours, key=cv2.contourArea, reverse=True)[:5]:
            x, y, cw, ch = cv2.boundingRect(cnt)
            if cw > 50 and ch > 50 and (cw < w or ch < h):
                crop = gray[max(0, y-10):min(h, y+ch+10), max(0, x-10):min(w, x+cw+10)]
                if crop.size > 0:
                    text = _decode_with_zxing(crop) or _decode_with_opencv(crop)
                    if text:
                        return text
    except Exception:
        pass

    return None


def decode_qr_from_image_bytes(
    image_bytes: bytes,
    db_path: str = DEFAULT_DB_PATH
) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """
    Decodes QR code from raw image bytes and parses DoseBand worker & badge identifiers.

    Returns:
        tuple: (worker_id, badge_id, raw_payload)
               - If no QR detected: (None, None, None)
               - If QR detected but foreign: (None, None, raw_payload)
               - If DoseBand QR detected: (worker_id, badge_id, raw_payload)
    """
    raw_payload = decode_raw_qr_text_from_image_bytes(image_bytes)
    if raw_payload is None:
        return None, None, None

    wid, bid, is_doseband = parse_doseband_payload(raw_payload)
    if is_doseband and (wid or bid):
        return wid, bid, raw_payload
    else:
        return None, None, raw_payload


def validate_badge_profile(
    worker_id: Optional[str],
    badge_id: Optional[str],
    db_path: str = DEFAULT_DB_PATH
) -> Dict[str, Any]:
    """
    Validates that the scanned badge exists, belongs to that worker, is active, and is not expired.
    Authoritative database lookup.

    Returns:
        dict: {
            "valid": bool,
            "status": "VALID" | "WORKER_NOT_FOUND" | "BADGE_NOT_REGISTERED" | "INACTIVE" | "EXPIRED" | "INVALID_QR",
            "worker": Optional[dict],
            "message": str
        }
    """
    if not worker_id and not badge_id:
        return {
            "valid": False,
            "status": "INVALID_QR",
            "worker": None,
            "message": "This is not a valid DoseBand QR."
        }

    # Lookup worker profile (first by worker_id, fallback by badge_id)
    worker_profile = None
    if worker_id:
        worker_profile = database.get_worker_by_id(worker_id, db_path=db_path)
    if not worker_profile and badge_id:
        worker_profile = database.get_worker_by_badge_id(badge_id, db_path=db_path)

    if not worker_profile:
        return {
            "valid": False,
            "status": "WORKER_NOT_FOUND",
            "worker": None,
            "message": "Worker is not registered."
        }

    # 1. Validate badge-worker linkage if badge_id was supplied
    if badge_id and worker_profile.get("badge_id"):
        db_badge = str(worker_profile.get("badge_id", "")).strip().upper()
        scanned_badge = str(badge_id).strip().upper()
        if db_badge != scanned_badge:
            return {
                "valid": False,
                "status": "BADGE_NOT_REGISTERED",
                "worker": worker_profile,
                "message": "Badge is not registered."
            }

    # 2. Validate worker / badge active status
    status_str = str(worker_profile.get("status", "Active")).strip().capitalize()
    if status_str != "Active":
        return {
            "valid": False,
            "status": "INACTIVE",
            "worker": worker_profile,
            "message": "Badge is inactive."
        }

    # 3. Validate badge shelf-life expiry date
    exp_date_str = str(worker_profile.get("badge_expiry_date", "")).strip()
    if exp_date_str:
        try:
            exp_date = datetime.strptime(exp_date_str, "%Y-%m-%d").date()
            if exp_date < date.today():
                return {
                    "valid": False,
                    "status": "EXPIRED",
                    "worker": worker_profile,
                    "message": "Badge has expired."
                }
        except Exception:
            pass

    return {
        "valid": True,
        "status": "VALID",
        "worker": worker_profile,
        "message": "Worker verified successfully."
    }


def verify_qr_image_or_payload(
    image_bytes: Optional[bytes] = None,
    raw_payload: Optional[str] = None,
    db_path: str = DEFAULT_DB_PATH
) -> Dict[str, Any]:
    """
    Unified end-to-end QR verification function used across API, Web, and Tests.
    Decodes QR if image provided, parses payload, and validates against database.
    """
    decoded_text = raw_payload

    if image_bytes is not None and len(image_bytes) > 0:
        decoded_text = decode_raw_qr_text_from_image_bytes(image_bytes)
        if decoded_text is None:
            return {
                "valid": False,
                "status": "NO_QR_DETECTED",
                "message": "No QR code detected in this image.",
                "worker": None,
                "raw_payload": None
            }

    if not decoded_text or not decoded_text.strip():
        return {
            "valid": False,
            "status": "NO_QR_DETECTED",
            "message": "No QR code detected in this image.",
            "worker": None,
            "raw_payload": None
        }

    wid, bid, is_recognized = parse_doseband_payload(decoded_text)
    if not is_recognized:
        return {
            "valid": False,
            "status": "INVALID_QR",
            "message": "This is not a valid DoseBand QR.",
            "worker": None,
            "raw_payload": decoded_text
        }

    val_res = validate_badge_profile(wid, bid, db_path=db_path)
    return {
        "valid": val_res["valid"],
        "status": val_res["status"],
        "message": val_res["message"],
        "worker": val_res.get("worker"),
        "raw_payload": decoded_text
    }


if __name__ == "__main__":
    database.init_db()
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
    res = verify_qr_image_or_payload(image_bytes=badge_card)
    print("Verification Result:", res)
    assert res["valid"] is True, "Validation should pass for registered W-101"
    print("\nAll QR Manager unit tests passed!")
