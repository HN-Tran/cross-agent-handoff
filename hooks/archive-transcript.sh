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
[[ -n "$GIT_ROOT" ]] || exit 0

TRANSCRIPT=""
if command -v jq >/dev/null 2>&1; then
  TRANSCRIPT="$(jq -r '.transcript_path // .conversation_path // empty' <<< "$INPUT" 2>/dev/null || true)"
fi

if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
  exit 0
fi

TOOL="$(cah_detect_tool_from_env)"
cah_capture_state "$GIT_ROOT" "$TOOL" "$TRANSCRIPT"
exit 0
