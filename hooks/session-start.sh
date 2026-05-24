#!/usr/bin/env bash
set -euo pipefail

FORMAT="${1:-plain}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
cah_resolve_root

INPUT="$(cat)"
CWD="$(cah_hook_cwd "$INPUT")"
CWD="${CWD:-$(pwd)}"

GIT_ROOT="$(cah_find_git_root "$CWD" 2>/dev/null || true)"
if [[ -z "$GIT_ROOT" ]]; then
  exit 0
fi

SESSION="$(cah_session_file "$GIT_ROOT")"
if [[ ! -f "$SESSION" ]]; then
  exit 0
fi

cah_write_marker "$GIT_ROOT"
BRANCH="$(git -C "$GIT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
CONTEXT="$(cah_build_context_blob "$GIT_ROOT")"
cah_emit_session_start "$FORMAT" "$CONTEXT" "$BRANCH"
