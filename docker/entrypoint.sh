#!/usr/bin/env bash
set -euo pipefail

export CAH_ROOT="${CAH_ROOT:-/opt/cross-agent-handoff}"
export HOME="${HOME:-/tmp/cah-home}"
mkdir -p "$HOME"

# Personal dev container: allow git in any mounted host path.
git config --global --add safe.directory '*' 2>/dev/null || true

# Daemon mode (docker compose up -d)
if [[ "${1:-}" == "sleep" ]]; then
  shift
  exec sleep "$@"
fi

exec "${CAH_ROOT}/bin/cross-agent-handoff" "$@"
