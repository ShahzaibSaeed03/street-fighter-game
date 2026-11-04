"""Build all 9 non-Mixamo creatures. Run via Blender --python."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from creatures import BUILDERS  # noqa: E402
from lib_common import log  # noqa: E402

ONLY = [a for a in sys.argv[1:] if a in BUILDERS]


def main():
    names = ONLY or list(BUILDERS.keys())
    ok = 0
    for name in names:
        log(f"\n==== building {name} ====")
        try:
            BUILDERS[name]()
            ok += 1
        except Exception as e:
            log(f"FAIL {name}: {e}")
            import traceback
            traceback.print_exc()
    log(f"\nCREATURES DONE {ok}/{len(names)}")
    if ok < len(names):
        sys.exit(1)


if __name__ == "__main__":
    main()
