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

TOOL="$(cah_detect_tool_from_env)"
TRANSCRIPT=""
if command -v jq >/dev/null 2>&1; then
  TRANSCRIPT="$(jq -r '.transcript_path // .conversation_path // empty' <<< "$INPUT" 2>/dev/null || true)"
fi

# Claude SessionEnd has short timeout — capture in background
(
  cah_capture_state "$GIT_ROOT" "$TOOL" "$TRANSCRIPT"
  if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    "$SCRIPT_DIR/archive-transcript.sh" "$FORMAT" <<< "$INPUT" || true
  fi
) >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
