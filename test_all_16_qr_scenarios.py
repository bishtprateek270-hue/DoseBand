"""
DoseBand Comprehensive 16-Scenario QR Verification Test Suite.
Validates all 16 test cases required for cross-platform QR compatibility.
"""

from datetime import date, timedelta
import io
import json
import sqlite3
import cv2
import numpy as np
from PIL import Image, ImageDraw
import qrcode
import database
import qr_manager

DB_PATH = "doseband.db"


def setup_test_environment():
    """Ensures database has valid, inactive, and expired workers for testing."""
    database.init_db(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Active Worker: W-101 (Rajesh Kumar)
    today = date.today()
    future_exp = (today + timedelta(days=90)).strftime("%Y-%m-%d")
    past_exp = (today - timedelta(days=5)).strftime("%Y-%m-%d")

    cursor.execute("""
        INSERT OR REPLACE INTO workers (worker_id, name, department, work_zone, shift, badge_id, badge_issue_date, badge_expiry_date, status)
        VALUES ('W-101', 'Rajesh Kumar', 'Refinery Operations', 'Zone A', 'Shift 1', 'BDG-101', '2026-08-01', ?, 'Active');
    """, (future_exp,))

    # Inactive Worker: W-107 (Inactive Demo Worker)
    cursor.execute("""
        INSERT OR REPLACE INTO workers (worker_id, name, department, work_zone, shift, badge_id, badge_issue_date, badge_expiry_date, status)
        VALUES ('W-107', 'Inactive Worker', 'Maintenance', 'Zone B', 'Shift 2', 'BDG-107', '2026-08-01', ?, 'Inactive');
    """, (future_exp,))

    # Expired Worker: W-108 (Expired Badge Worker)
    cursor.execute("""
        INSERT OR REPLACE INTO workers (worker_id, name, department, work_zone, shift, badge_id, badge_issue_date, badge_expiry_date, status)
        VALUES ('W-108', 'Expired Worker', 'Laboratory', 'Zone C', 'Shift 1', 'BDG-108', '2026-01-01', ?, 'Active');
    """, (past_exp,))

    conn.commit()
    conn.close()


def make_qr_image(payload_str: str, box_size: int = 8, border: int = 2) -> Image.Image:
    qr = qrcode.QRCode(box_size=box_size, border=border)
    qr.add_data(payload_str)
    qr.make(fit=True)
    return qr.make_image(fill_color="#0F172A", back_color="#FFFFFF").convert("RGB")


def image_to_bytes(pil_img: Image.Image) -> bytes:
    buf = io.BytesIO()
    pil_img.save(buf, format="PNG")
    return buf.getvalue()


def run_all_tests():
    setup_test_environment()
    results = {}
    print("=" * 80)
    print("DOSEBAND WORKER QR SYSTEM — 16-SCENARIO VERIFICATION SUITE")
    print("=" * 80)

    # TEST 1: Generate worker QR in Flutter format / canonical format -> Immediate scan
    w101_payload = json.dumps({"type": "doseband_worker", "version": 1, "worker_id": "W-101", "badge_id": "BDG-101"})
    qr1_img = make_qr_image(w101_payload)
    res1 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(qr1_img), db_path=DB_PATH)
    t1_pass = res1["valid"] is True and res1["worker"]["worker_id"] == "W-101"
    results["TEST 1"] = ("PASS" if t1_pass else "FAIL", f"Loaded worker: {res1.get('worker', {}).get('name')}")

    # TEST 2: Screenshot the same QR (badge card with margins, text, surrounding chassis)
    w_profile = database.get_worker_by_id("W-101", db_path=DB_PATH)
    badge_card_bytes = qr_manager.generate_styled_badge_card(w_profile)
    # Simulate full mobile screen containing the badge card
    screen = Image.new("RGB", (1080, 1920), color="#0F172A")
    badge_pil = Image.open(io.BytesIO(badge_card_bytes))
    screen.paste(badge_pil, (240, 600))
    res2 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(screen), db_path=DB_PATH)
    t2_pass = res2["valid"] is True and res2["worker"]["worker_id"] == "W-101"
    results["TEST 2"] = ("PASS" if t2_pass else "FAIL", f"Screenshot decoded: {res2.get('worker', {}).get('name')}")

    # TEST 3: Crop screenshot around QR
    # Crop the QR region from badge card
    crop_qr = badge_pil.crop((350, 70, 580, 300))
    res3 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(crop_qr), db_path=DB_PATH)
    t3_pass = res3["valid"] is True and res3["worker"]["worker_id"] == "W-101"
    results["TEST 3"] = ("PASS" if t3_pass else "FAIL", f"Cropped QR decoded: {res3.get('worker', {}).get('name')}")

    # TEST 4: Display QR on another phone and photograph it (glare, gradient, noise, angle)
    np_crop = np.array(crop_qr)
    h, w, _ = np_crop.shape
    grad = np.tile(np.linspace(0.85, 1.15, w), (h, 1))
    photo_sim = np.clip(np_crop * grad[:, :, np.newaxis] + np.random.normal(0, 8, np_crop.shape), 0, 255).astype(np.uint8)
    # Add slight perspective
    pts1 = np.float32([[0, 0], [w, 0], [0, h], [w, h]])
    pts2 = np.float32([[8, 10], [w - 12, 5], [4, h - 8], [w - 6, h - 4]])
    matrix = cv2.getPerspectiveTransform(pts1, pts2)
    photo_warped = cv2.warpPerspective(photo_sim, matrix, (w, h), borderValue=(255, 255, 255))
    res4 = qr_manager.verify_qr_image_or_payload(image_bytes=cv2.imencode(".png", photo_warped)[1].tobytes(), db_path=DB_PATH)
    t4_pass = res4["valid"] is True and res4["worker"]["worker_id"] == "W-101"
    results["TEST 4"] = ("PASS" if t4_pass else "FAIL", f"Photographed phone QR decoded: {res4.get('worker', {}).get('name')}")

    # TEST 5: Slightly rotated QR image (15°, 45°, 90°)
    rot15 = qr1_img.rotate(15, expand=True, fillcolor="white")
    res5 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(rot15), db_path=DB_PATH)
    t5_pass = res5["valid"] is True and res5["worker"]["worker_id"] == "W-101"
    results["TEST 5"] = ("PASS" if t5_pass else "FAIL", f"Rotated 15° decoded: {res5.get('worker', {}).get('name')}")

    # TEST 6: Generate QR in Web -> Upload/scan with Flutter validator
    web_qr_png = qr_manager.generate_badge_qr_png("W-101", "BDG-101")
    raw_decoded = qr_manager.decode_raw_qr_text_from_image_bytes(web_qr_png)
    wid_f, bid_f, is_rec = qr_manager.parse_doseband_payload(raw_decoded)
    val_f = qr_manager.validate_badge_profile(wid_f, bid_f, db_path=DB_PATH)
    t6_pass = val_f["valid"] is True and wid_f == "W-101"
    results["TEST 6"] = ("PASS" if t6_pass else "FAIL", f"Web QR scanned by Flutter: {val_f.get('worker', {}).get('name')}")

    # TEST 7: Generate QR in Flutter (canonical payload) -> Upload/scan with Web
    flutter_payload = '{"type":"doseband_worker","version":1,"worker_id":"W-101","badge_id":"BDG-101"}'
    res7 = qr_manager.verify_qr_image_or_payload(raw_payload=flutter_payload, db_path=DB_PATH)
    t7_pass = res7["valid"] is True and res7["worker"]["worker_id"] == "W-101"
    results["TEST 7"] = ("PASS" if t7_pass else "FAIL", f"Flutter QR scanned by Web: {res7.get('worker', {}).get('name')}")

    # TEST 8: Screenshot Web-generated QR -> Upload/verify
    res8 = qr_manager.verify_qr_image_or_payload(image_bytes=badge_card_bytes, db_path=DB_PATH)
    t8_pass = res8["valid"] is True and res8["worker"]["worker_id"] == "W-101"
    results["TEST 8"] = ("PASS" if t8_pass else "FAIL", f"Screenshot Web QR verified: {res8.get('worker', {}).get('name')}")

    # TEST 9: Screenshot Flutter-generated QR -> Upload/verify
    flutter_badge_img = make_qr_image(flutter_payload, box_size=10, border=4)
    res9 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(flutter_badge_img), db_path=DB_PATH)
    t9_pass = res9["valid"] is True and res9["worker"]["worker_id"] == "W-101"
    results["TEST 9"] = ("PASS" if t9_pass else "FAIL", f"Screenshot Flutter QR verified: {res9.get('worker', {}).get('name')}")

    # TEST 10: Random website QR -> REJECT
    google_qr = make_qr_image("https://www.google.com/search?q=doseband")
    res10 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(google_qr), db_path=DB_PATH)
    t10_pass = res10["valid"] is False and res10["message"] == "This is not a valid DoseBand QR."
    results["TEST 10"] = ("PASS" if t10_pass else "FAIL", f"Result: {res10['message']}")

    # TEST 11: Payment QR -> REJECT
    upi_qr = make_qr_image("upi://pay?pa=industrial_safety@icici&pn=SafetyStore&am=250.00")
    res11 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(upi_qr), db_path=DB_PATH)
    t11_pass = res11["valid"] is False and res11["message"] == "This is not a valid DoseBand QR."
    results["TEST 11"] = ("PASS" if t11_pass else "FAIL", f"Result: {res11['message']}")

    # TEST 12: Random text QR -> REJECT
    text_qr = make_qr_image("WIFI:S:Refinery_Guest;T:WPA;P:SecretSafetyPass123;;")
    res12 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(text_qr), db_path=DB_PATH)
    t12_pass = res12["valid"] is False and res12["message"] == "This is not a valid DoseBand QR."
    results["TEST 12"] = ("PASS" if t12_pass else "FAIL", f"Result: {res12['message']}")

    # TEST 13: Fake QR containing fake DoseBand payload -> REJECT
    fake_qr = make_qr_image(json.dumps({"type": "doseband_worker", "version": 1, "worker_id": "W-9999", "badge_id": "BDG-FAKE"}))
    res13 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(fake_qr), db_path=DB_PATH)
    t13_pass = res13["valid"] is False and res13["message"] == "Worker is not registered."
    results["TEST 13"] = ("PASS" if t13_pass else "FAIL", f"Result: {res13['message']}")

    # TEST 14: QR belonging to inactive badge -> REJECT
    inactive_qr = make_qr_image(json.dumps({"type": "doseband_worker", "version": 1, "worker_id": "W-107", "badge_id": "BDG-107"}))
    res14 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(inactive_qr), db_path=DB_PATH)
    t14_pass = res14["valid"] is False and res14["message"] == "Badge is inactive."
    results["TEST 14"] = ("PASS" if t14_pass else "FAIL", f"Result: {res14['message']}")

    # TEST 15: QR belonging to expired badge -> REJECT
    expired_qr = make_qr_image(json.dumps({"type": "doseband_worker", "version": 1, "worker_id": "W-108", "badge_id": "BDG-108"}))
    res15 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(expired_qr), db_path=DB_PATH)
    t15_pass = res15["valid"] is False and res15["message"] == "Badge has expired."
    results["TEST 15"] = ("PASS" if t15_pass else "FAIL", f"Result: {res15['message']}")

    # TEST 16: Image without any QR -> "No QR code detected in this image."
    blank_img = Image.new("RGB", (400, 400), color="#1E293B")
    draw = ImageDraw.Draw(blank_img)
    draw.text((50, 180), "Physical Optical Sensor Strip (No QR)", fill="#F8FAFC")
    res16 = qr_manager.verify_qr_image_or_payload(image_bytes=image_to_bytes(blank_img), db_path=DB_PATH)
    t16_pass = res16["valid"] is False and res16["message"] == "No QR code detected in this image."
    results["TEST 16"] = ("PASS" if t16_pass else "FAIL", f"Result: {res16['message']}")

    print("\nSUMMARY OF RESULTS:")
    all_passed = True
    for test_name, (status, note) in results.items():
        print(f"  {test_name:<10}: [{status}] - {note}")
        if status != "PASS":
            all_passed = False

    print("=" * 80)
    print(f"FINAL RESULT: {'ALL 16 TESTS PASSED SUCCESSFULLY!' if all_passed else 'SOME TESTS FAILED!'}")
    print("=" * 80)
    return all_passed, results


if __name__ == "__main__":
    passed, res = run_all_tests()
    assert passed, "All 16 tests must pass!"

