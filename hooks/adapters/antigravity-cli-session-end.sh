#!/usr/bin/env bash
set -euo pipefail
export CAH_TOOL=antigravity-cli
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../session-end.sh" antigravity-cli