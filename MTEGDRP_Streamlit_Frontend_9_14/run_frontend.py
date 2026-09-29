# -*- coding: utf-8 -*-
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


if __name__ == "__main__":
    root = Path(__file__).resolve().parent
    port = os.getenv("STREAMLIT_PORT", "8501")
    command = [
        sys.executable,
        "-m",
        "streamlit",
        "run",
        str(root / "streamlit_app.py"),
        "--server.port",
        port,
    ]
    raise SystemExit(subprocess.call(command, cwd=str(root)))
