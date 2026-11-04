from __future__ import annotations
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from creatures import build_vulture
if __name__ == '__main__':
    build_vulture()
