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
  cah_emit_stop_allow "$FORMAT"
  exit 0
fi

SESSION="$(cah_session_file "$GIT_ROOT")"
if [[ ! -f "$SESSION" ]]; then
  cah_emit_stop_allow "$FORMAT"
  exit 0
fi

TOOL="$(cah_detect_tool_from_env)"
LOOP_COUNT=0
STOP_HOOK_ACTIVE=false
if command -v jq >/dev/null 2>&1; then
  LOOP_COUNT="$(jq -r '.loop_count // 0' <<< "$INPUT" 2>/dev/null || echo 0)"
  STOP_HOOK_ACTIVE="$(jq -r '.stop_hook_active // false' <<< "$INPUT" 2>/dev/null || echo false)"
fi

if cah_session_updated_since_start "$GIT_ROOT"; then
  cah_capture_state "$GIT_ROOT" "$TOOL" ""
  cah_emit_stop_allow "$FORMAT"
  exit 0
fi

# Second pass: platform loop guard fired — allow stop and capture best-effort
if [[ "$STOP_HOOK_ACTIVE" == "true" ]] || [[ "${LOOP_COUNT:-0}" -ge 1 ]]; then
  cah_capture_state "$GIT_ROOT" "$TOOL" ""
  cah_emit_stop_allow "$FORMAT"
  exit 0
fi

MSG="$(cah_stop_message)"
cah_emit_stop_block "$FORMAT" "$MSG"
exit 0
