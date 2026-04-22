#!/usr/bin/env python3
"""Backward-compatible entrypoint: delegates to gen_demo_hub_k8s.py."""
import subprocess
import sys
from pathlib import Path

if __name__ == "__main__":
    p = Path(__file__).with_name("gen_demo_hub_k8s.py")
    raise SystemExit(subprocess.call([sys.executable, str(p)]))
