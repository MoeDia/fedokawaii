#!/usr/bin/env python3
"""Builds Fedokawaii-Learn.pdf — the learning guide Super+U opens — from docs/fedokawaii-learn.md,
through handbook.py's own machinery: the same pixel faces, seals, stitch, palette, figures and
contents. Only the source, the file name and the chapters' kanji (the guide's front matter) differ.

usage: python3 docs/build/learn.py        builds Fedokawaii-Learn.pdf in FEDOKAWAII_OUT
       python3 docs/build/learn.py --help this text
Every other setting is handbook.py's (FEDOKAWAII_SCRATCH, FEDOKAWAII_OUT, FEDOKAWAII_CHROME …)."""
import os
import runpy
import sys
from pathlib import Path

if len(sys.argv) > 1:
    print(__doc__, file=sys.stdout if sys.argv[1] in ("-h", "--help") else sys.stderr)
    sys.exit(0 if sys.argv[1] in ("-h", "--help") else 2)
sys.dont_write_bytecode = True                 # (no __pycache__ left in the repository)
HERE = Path(__file__).resolve().parent
REPO = os.environ.setdefault("FEDOKAWAII_REPO", str(HERE.parents[1]))
os.environ["FEDOKAWAII_GUIDE"] = f"{REPO}/docs/fedokawaii-learn.md"
os.environ["FEDOKAWAII_PDF"] = "Fedokawaii-Learn.pdf"
sys.argv = [str(HERE / "handbook.py")]
runpy.run_path(str(HERE / "handbook.py"), run_name="__main__")
