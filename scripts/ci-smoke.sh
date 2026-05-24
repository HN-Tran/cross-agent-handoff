#!/usr/bin/env bash
# Smoke tests for CI and local dev.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> syntax"
bash -n bin/cross-agent-handoff
while IFS= read -r -d '' f; do
  bash -n "$f"
done < <(find hooks docker lib -name '*.sh' -print0)

echo "==> shellcheck (optional)"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x bin/cross-agent-handoff lib/common.sh docker/entrypoint.sh \
    hooks/session-start.sh hooks/stop-enforce-handoff.sh hooks/session-end.sh \
    || true
fi

echo "==> CLI init in temp repo"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" config user.email "smoke@test.local"
git -C "$TMP" config user.name "Smoke"
echo "# smoke" > "$TMP/README.md"
git -C "$TMP" add README.md
git -C "$TMP" commit -qm "init"

CAH_ROOT="$ROOT" "$ROOT/bin/cross-agent-handoff" init "$TMP"
test -f "$TMP/.agent/SESSION.md"
test -f "$TMP/AGENTS.md"

echo "==> hook session-start (cursor)"
OUT="$(echo '{"cwd":"'"$TMP"'"}' | "$ROOT/hooks/adapters/cursor-session-start.sh")"
echo "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'additional_context' in d and len(d['additional_context'])>10"

echo "==> capture"
(
  cd "$TMP"
  CAH_ROOT="$ROOT" "$ROOT/bin/cross-agent-handoff" capture --tool ci-smoke
)
test -f "$TMP/.agent/state.json"

echo "==> OK"
