"""
DoseBand REST API Server Launcher.

Usage:
    python api_server.py [--host 0.0.0.0] [--port 8000] [--reload]
"""

import argparse
import uvicorn
from backend.api import app

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="DoseBand REST API Server")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Binding host (default: 0.0.0.0 for LAN & emulator access)")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on (default: 8000)")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload on code change")

    args = parser.parse_args()
    print("=" * 70)
    print(f"Starting DoseBand REST API Server on http://{args.host}:{args.port}")
    print("    Swagger UI available at: http://localhost:8000/docs")
    print("    Android Emulator Access: http://10.0.2.2:8000")
    print("=" * 70)

    uvicorn.run("backend.api:app", host=args.host, port=args.port, reload=args.reload)
