#!/usr/bin/env bash
set -euo pipefail
TAHOE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
exec "$TAHOE_DIR/run.sh" "$@"
