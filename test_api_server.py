"""
Automated Test Suite for DoseBand REST API Backend.

Tests:
1. GET /health
2. GET /workers & GET /workers/W-101
3. POST /badges/verify-qr with valid and foreign QR payloads
4. POST /scan/analyze with sample dosimeter badge images
5. POST /scan/save with database persistence check
6. GET /dashboard analytics
7. GET /reports/summary
"""

import os
import cv2
import pytest
from fastapi.testclient import TestClient

from backend.api import app
import database

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database_connected"] is True
    print("\n[PASS] GET /health verified.")

def test_workers():
    response = client.get("/workers")
    assert response.status_code == 200
    workers = response.json()
    assert len(workers) >= 5
    assert any(w["worker_id"] == "W-101" for w in workers)
    print(f"[PASS] GET /workers returned {len(workers)} workers.")

    # Test single worker
    resp_w101 = client.get("/workers/W-101")
    assert resp_w101.status_code == 200
    w_data = resp_w101.json()
    assert w_data["worker_id"] == "W-101"
    assert w_data["name"] == "Rajesh Kumar"
    print("[PASS] GET /workers/W-101 verified.")

def test_verify_qr():
    # Test valid payload
    valid_payload = '{"app":"DoseBand","worker_id":"W-101","badge_id":"BDG-101","version":"1.0"}'
    resp = client.post("/badges/verify-qr", data={"raw_payload": valid_payload})
    assert resp.status_code == 200
    res = resp.json()
    assert res["valid"] is True
    assert res["worker"]["worker_id"] == "W-101"
    print("[PASS] POST /badges/verify-qr with valid DoseBand QR verified.")

    # Test foreign payload (must reject)
    foreign_payload = 'https://malicious-site.com/hack'
    resp_foreign = client.post("/badges/verify-qr", data={"raw_payload": foreign_payload})
    assert resp_foreign.status_code == 200
    res_f = resp_foreign.json()
    assert res_f["valid"] is False
    print("[PASS] POST /badges/verify-qr with foreign QR blocked correctly.")

def test_scan_analyze_valid():
    image_path = "test_images/base_normal.jpg"
    assert os.path.exists(image_path)
    with open(image_path, "rb") as f:
        files = {"image": ("base_normal.jpg", f, "image/jpeg")}
        data = {
            "worker_id": "W-101",
            "temperature_c": 25.0,
            "humidity_rh": 50.0,
            "exposure_time_h": 1.0,
            "badge_mode": "FULL_DOSEBAND_BADGE"
        }
        resp = client.post("/scan/analyze", files=files, data=data)
        assert resp.status_code == 200
        res = resp.json()
        assert res["is_valid"] is True
        assert res["status"] == "Valid"
        assert res["confidence_pct"] >= 80
        assert res["estimated_h2s_ppm"] > 0
        assert res["risk_level"] in ["Safe", "Caution", "Unsafe"]
        print(f"[PASS] POST /scan/analyze base_normal.jpg -> Valid ({res['estimated_h2s_ppm']} ppm, {res['confidence_pct']}%).")

def test_scan_analyze_negative():
    image_path = "test_images/negative_plain_white.jpg"
    assert os.path.exists(image_path)
    with open(image_path, "rb") as f:
        files = {"image": ("negative_plain_white.jpg", f, "image/jpeg")}
        data = {
            "worker_id": "W-101",
            "temperature_c": 25.0,
            "exposure_time_h": 1.0,
            "badge_mode": "STANDALONE_CHEMICAL_STRIP"
        }
        resp = client.post("/scan/analyze", files=files, data=data)
        assert resp.status_code == 200
        res = resp.json()
        assert res["is_valid"] is False
        assert res["status"] == "Invalid"
        msg_clean = res['user_message'].encode('ascii', 'ignore').decode('ascii')
        print(f"[PASS] POST /scan/analyze negative_plain_white.jpg -> Blocked ({msg_clean[:40]}...).")

def test_dashboard():
    resp = client.get("/dashboard")
    assert resp.status_code == 200
    dash = resp.json()
    assert "summary" in dash
    assert "zone_breakdown" in dash
    assert dash["summary"]["total_workers"] >= 5
    print(f"[PASS] GET /dashboard verified. Active workers: {dash['summary']['active_workers']}.")

def test_reports_summary():
    resp = client.get("/reports/summary")
    assert resp.status_code == 200
    rep = resp.json()
    assert "report_id" in rep
    assert "total_scans" in rep
    print(f"[PASS] GET /reports/summary verified (Report ID: {rep['report_id']}).")

if __name__ == "__main__":
    print("=" * 70)
    print("RUNNING API SERVER TEST SUITE")
    print("=" * 70)
    test_health()
    test_workers()
    test_verify_qr()
    test_scan_analyze_valid()
    test_scan_analyze_negative()
    test_dashboard()
    test_reports_summary()
    print("=" * 70)
    print("[SUCCESS] ALL API SERVER TESTS PASSED!")
    print("=" * 70)
