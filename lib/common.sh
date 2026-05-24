#!/usr/bin/env bash
# Shared helpers for cross-agent-handoff

cah_resolve_root() {
  if [[ -n "${CAH_ROOT:-}" && -d "$CAH_ROOT" ]]; then
    return 0
  fi
  local install="${CAH_INSTALL:-$HOME/.local/share/cross-agent-handoff}"
  if [[ -d "$install" ]]; then
    CAH_ROOT="$install"
    return 0
  fi
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  CAH_ROOT="$script_dir"
}

cah_find_git_root() {
  local start="${1:-$(pwd)}"
  git -C "$start" rev-parse --show-toplevel 2>/dev/null
}

cah_agent_dir() {
  local root="$1"
  echo "$root/.agent"
}

cah_session_file() {
  echo "$(cah_agent_dir "$1")/SESSION.md"
}

cah_state_file() {
  echo "$(cah_agent_dir "$1")/state.json"
}

cah_brief_file() {
  echo "$(cah_agent_dir "$1")/SESSION.brief.md"
}

cah_marker_file() {
  echo "$(cah_agent_dir "$1")/.session-start-ts"
}

cah_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

cah_detect_tool_from_env() {
  if [[ -n "${CAH_TOOL:-}" ]]; then
    echo "$CAH_TOOL"
    return 0
  fi
  if [[ -n "${CLAUDE_CODE_REMOTE:-}" ]]; then
    echo "claude-code-web"
    return 0
  fi
  echo "unknown"
}

cah_read_json_field() {
  local json="$1"
  local field="$2"
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r "$field // empty" 2>/dev/null
  else
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('${field#.*}' if '.' not in '$field' else '$field'.split('.')[-1]) or '')" <<< "$json" 2>/dev/null || true
  fi
}

cah_build_context_blob() {
  local git_root="$1"
  local session state branch dirty
  session="$(cah_session_file "$git_root")"
  state="$(cah_state_file "$git_root")"

  if [[ ! -f "$session" ]]; then
    return 1
  fi

  echo "# Cross-agent handoff"
  echo ""
  echo "Read and continue from \`.agent/SESSION.md\` in this repository. Do not restart from scratch."
  echo ""
  cat "$session"

  if [[ -f "$state" ]]; then
    echo ""
    echo "---"
    echo "Machine state (\`.agent/state.json\`):"
    cat "$state"
  fi

  branch="$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  dirty="$(git -C "$git_root" status --short 2>/dev/null | head -20)"
  echo ""
  echo "---"
  echo "Git branch: $branch"
  if [[ -n "$dirty" ]]; then
    echo "Dirty files:"
    echo "$dirty"
  fi
}

cah_handoff_section() {
  cat <<'EOF'
## Session continuity
- On start: read `.agent/SESSION.md` before doing work.
- On stop or when context is low: update `.agent/SESSION.md` (goal, progress, next steps, decisions, blockers, context digest).
- Keep work on the branch recorded in `.agent/state.json`.
- Do not restart from scratch if SESSION.md exists.
EOF
}

cah_stop_message() {
  cat <<'EOF'
Before stopping, update `.agent/SESSION.md` with: Goal, Progress, Next steps, Decisions, Blockers, and Context digest (conversation-only details not already captured). Then stop again.
EOF
}

cah_session_updated_since_start() {
  local git_root="$1"
  local session marker
  session="$(cah_session_file "$git_root")"
  marker="$(cah_marker_file "$git_root")"

  [[ -f "$session" ]] || return 1

  if [[ ! -f "$marker" ]]; then
    # No marker: require file modified within last 30 minutes as heuristic
    local age
    age=$(( $(date +%s) - $(stat -c %Y "$session" 2>/dev/null || stat -f %m "$session" 2>/dev/null || echo 0) ))
    [[ "$age" -lt 1800 ]]
    return
  fi

  local start_ts file_ts
  start_ts="$(cat "$marker" 2>/dev/null || echo 0)"
  file_ts="$(stat -c %Y "$session" 2>/dev/null || stat -f %m "$session" 2>/dev/null || echo 0)"
  [[ "$file_ts" -ge "$start_ts" ]]
}

cah_write_marker() {
  local git_root="$1"
  local marker
  marker="$(cah_marker_file "$git_root")"
  mkdir -p "$(dirname "$marker")"
  date +%s > "$marker"
}

cah_capture_state() {
  local git_root="$1"
  local tool="${2:-unknown}"
  local transcript_path="${3:-}"
  local agent_dir state_file branch

  agent_dir="$(cah_agent_dir "$git_root")"
  state_file="$(cah_state_file "$git_root")"
  mkdir -p "$agent_dir/archive"
  branch="$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

  local dirty_json commits_json archive_path=""
  dirty_json="$(git -C "$git_root" status --short 2>/dev/null | jq -R -s 'split("\n") | map(select(length>0))' 2>/dev/null || echo '[]')"
  commits_json="$(git -C "$git_root" log --oneline -5 2>/dev/null | jq -R -s 'split("\n") | map(select(length>0))' 2>/dev/null || echo '[]')"

  if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    local base id
    id="$(basename "$transcript_path" .jsonl)"
    archive_path=".agent/archive/$(date +%Y-%m-%d)-${tool}-${id}.jsonl"
    cp "$transcript_path" "$git_root/$archive_path" 2>/dev/null || true
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg branch "$branch" \
      --arg updated_at "$(cah_now_iso)" \
      --arg tool "$tool" \
      --argjson dirty_files "$dirty_json" \
      --argjson recent_commits "$commits_json" \
      --arg transcript_path "${transcript_path:-}" \
      --arg archive_path "${archive_path:-}" \
      '{
        branch: $branch,
        updated_at: $updated_at,
        tool: $tool,
        dirty_files: $dirty_files,
        recent_commits: $recent_commits,
        transcript_path: (if $transcript_path == "" then null else $transcript_path end),
        archive_path: (if $archive_path == "" then null else $archive_path end)
      }' > "$state_file"
  else
    cat > "$state_file" <<EOF
{
  "branch": "$branch",
  "updated_at": "$(cah_now_iso)",
  "tool": "$tool",
  "transcript_path": "${transcript_path:-null}",
  "archive_path": "${archive_path:-null}"
}
EOF
  fi

  local session diff_stat footer
  session="$(cah_session_file "$git_root")"
  if [[ -f "$session" ]]; then
    diff_stat="$(git -C "$git_root" diff --stat 2>/dev/null | tail -1 || true)"
    footer="<!-- auto: branch=$branch updated=$(cah_now_iso) diff=${diff_stat:-none} -->"
    if ! grep -q '<!-- auto:' "$session" 2>/dev/null; then
      printf '\n%s\n' "$footer" >> "$session"
    else
      sed -i "s|<!-- auto:.* -->|$footer|" "$session" 2>/dev/null || \
        sed -i '' "s|<!-- auto:.* -->|$footer|" "$session" 2>/dev/null || true
    fi
  fi
}

cah_strip_brief() {
  local git_root="$1"
  local session brief
  session="$(cah_session_file "$git_root")"
  brief="$(cah_brief_file "$git_root")"
  [[ -f "$session" ]] || return 1

  local branch repo
  branch="$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  repo="$(git -C "$git_root" remote get-url origin 2>/dev/null | sed 's|.git$||; s|git@github.com:|https://github.com/|' || basename "$git_root")"

  {
    echo "# Task handoff (brief)"
    echo "Repo: $repo  Branch: $branch"
    echo "Updated: $(cah_now_iso)"
    echo ""
    awk '
      /^<!-- auto:/ { exit }
      /^# Task:/ { print; next }
      { print }
    ' "$session" | head -n 80
  } > "$brief"
}

cah_parse_handoff_from_text() {
  local text="$1"
  local session="$2"
  mkdir -p "$(dirname "$session")"
  if [[ -f "$session" ]]; then
    cp "$session" "${session}.bak"
  fi
  printf '%s\n' "$text" > "$session"
}

cah_hook_cwd() {
  local input="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '
      .cwd //
      .workspace_root //
      .workspace_roots[0] //
      .root //
      .project_path //
      empty
    ' <<< "$input" 2>/dev/null || true
  fi
}

cah_json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

cah_emit_session_start() {
  local format="$1"
  local context="$2"
  local branch="${3:-unknown}"
  local one_liner="Resuming from .agent/SESSION.md on branch ${branch}"

  case "$format" in
    cursor)
      printf '{"additional_context":%s}\n' "$(printf '%s' "$context" | cah_json_escape)"
      ;;
    claude)
      printf '{"hookSpecificOutput":{"additionalContext":%s}}\n' "$(printf '%s' "$context" | cah_json_escape)"
      ;;
    codex|antigravity-cli|plain)
      printf '{"additionalContext":%s}\n' "$(printf '%s' "$context" | cah_json_escape)"
      ;;
    antigravity-desktop)
      printf '{"injectSteps":[{"ephemeralMessage":%s}]}\n' "$(printf '%s\n\n%s' "$one_liner" "$context" | cah_json_escape)"
      ;;
    *)
      printf '%s\n' "$context"
      ;;
  esac
}

cah_emit_stop_block() {
  local format="$1"
  local message="$2"
  case "$format" in
    cursor)
      printf '{"followup_message":%s}\n' "$(printf '%s' "$message" | cah_json_escape)"
      ;;
    claude|codex)
      printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$message" | cah_json_escape)"
      ;;
    antigravity-cli)
      printf '{"decision":"halt","reason":%s}\n' "$(printf '%s' "$message" | cah_json_escape)"
      ;;
    antigravity-desktop)
      printf '{"decision":"continue","reason":%s}\n' "$(printf '%s' "$message" | cah_json_escape)"
      ;;
    plain)
      printf '%s\n' "$message"
      exit 2
      ;;
  esac
}

cah_emit_stop_allow() {
  local format="$1"
  case "$format" in
    cursor|plain) echo '{}' ;;
    claude) echo '{}' ;;
    codex) echo '{"decision":"allow"}' ;;
    antigravity-cli) echo '{"decision":"continue"}' ;;
    antigravity-desktop) echo '{"decision":"stop"}' ;;
  esac
}
