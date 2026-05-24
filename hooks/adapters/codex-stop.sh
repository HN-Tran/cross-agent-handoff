#!/usr/bin/env bash
set -euo pipefail
export CAH_TOOL=codex
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../stop-enforce-handoff.sh" codex