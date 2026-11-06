"""Hace importable la aplicacion aunque pytest se ejecute desde otra carpeta."""

import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
