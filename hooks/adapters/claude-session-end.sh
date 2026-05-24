#!/usr/bin/env bash
set -euo pipefail
export CAH_TOOL=claude-code
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../session-end.sh" claude