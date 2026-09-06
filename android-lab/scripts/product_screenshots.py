#!/usr/bin/env python3
"""Compatibility entry point for the current iOS-aligned Android UI."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name("product_parity_capture.py")),run_name="__main__")
