#!/usr/bin/env bash
set -euo pipefail
TAHOE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
if [[ -z "${TAHOE_PYTHON:-}" && "$(uname -s)" == "Darwin" && -x "$TAHOE_DIR/Tahoe Desktop.app/Contents/MacOS/TahoeDesktop" ]]; then
    exec "$TAHOE_DIR/Tahoe Desktop.app/Contents/MacOS/TahoeDesktop" "$@"
fi
if [[ -n "${TAHOE_PYTHON:-}" ]]; then
    exec "$TAHOE_PYTHON" "$TAHOE_DIR/main.py" "$@"
fi
if [[ -x "$TAHOE_DIR/.venv/bin/python" ]]; then
    exec "$TAHOE_DIR/.venv/bin/python" "$TAHOE_DIR/main.py" "$@"
fi
# Reuse the isolated runtime prepared alongside this checkout, when present.
TAHOE_DEV_PYTHON="$TAHOE_DIR/../../work/qt-env/bin/python"
if [[ -x "$TAHOE_DEV_PYTHON" ]] && "$TAHOE_DEV_PYTHON" -c 'import PySide6, chess, pyte' 2>/dev/null; then
    exec "$TAHOE_DEV_PYTHON" "$TAHOE_DIR/main.py" "$@"
fi
python3 -m venv "$TAHOE_DIR/.venv"
"$TAHOE_DIR/.venv/bin/python" -m pip install -r "$TAHOE_DIR/requirements.txt"
exec "$TAHOE_DIR/.venv/bin/python" "$TAHOE_DIR/main.py" "$@"
