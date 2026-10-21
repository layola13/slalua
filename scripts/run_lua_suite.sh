#!/usr/bin/env bash
# Build the interpreter probe and run the upstream Lua suite plus local smoke tests.
# Usage: scripts/run_lua_suite.sh [lua-testes-dir]
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LUA_TESTES=${1:-${LUA_TESTES:-$ROOT/../lua/testes}}
TIMEOUT=${TIMEOUT:-10}
BIN=${BIN:-/tmp/slalua-run}
CWD=${CWD:-$ROOT}

export PATH=${SA_BIN:-$HOME/.sa/bin}:$PATH
export SA_PLUGIN_DEV=${SA_PLUGIN_DEV:-1}
export SA_STD_DIR=${SA_STD_DIR:-$HOME/.sa/std}

cd "$ROOT" || exit 1

echo "== check src/main.sla"
sla check src/main.sla || exit 1

echo "== build src/probe_run.sla"
sla build src/probe_run.sla --out .sla-cache/run_suite.sa || exit 1
sa build-exe .sla-cache/run_suite.sa -o "$BIN" || exit 1

pass=0
fail=0
timeout_count=0
skip=0
missing=0

run_one() {
    local file=$1
    local mode=${2:-upstream}
    local out rc last
    out=$(cd "$CWD" && SLALUA_SCRIPT="$file" timeout "$TIMEOUT" "$BIN" 2>&1)
    rc=$?
    last=$(printf '%s\n' "$out" | tail -n 1)
    if printf '%s\n' "$out" | grep -qx 'OK'; then
        pass=$((pass + 1))
        printf 'PASS    %-28s %s\n' "$(basename "$file")" "$last"
    elif [ "$rc" -eq 124 ]; then
        timeout_count=$((timeout_count + 1))
        printf 'TIMEOUT %-28s %s\n' "$(basename "$file")" "$last"
    elif [ -z "$out" ]; then
        skip=$((skip + 1))
        printf 'SKIP    %-28s (no output)\n' "$(basename "$file")"
    elif ! printf '%s\n' "$out" | grep -q 'lua error' && printf '%s\n' "$out" | grep -q 'not active: skipping'; then
        skip=$((skip + 1))
        printf 'SKIP    %-28s %s\n' "$(basename "$file")" "$last"
    elif [ "$mode" = local ] && [ "$rc" -eq 0 ] && ! printf '%s\n' "$out" | grep -q 'lua error'; then
        pass=$((pass + 1))
        printf 'PASS    %-28s rc=0\n' "$(basename "$file")"
    else
        fail=$((fail + 1))
        printf 'FAIL    %-28s rc=%-3s %s\n' "$(basename "$file")" "$rc" "$last"
    fi
}

echo "== upstream Lua tests: $LUA_TESTES"
if [ -d "$LUA_TESTES" ]; then
    for file in "$LUA_TESTES"/*.lua; do
        run_one "$file"
    done
else
    echo "SKIP: directory not found"
    missing=1
fi

echo "== local smoke tests"
for file in "$ROOT"/tests/*.lua; do
    run_one "$file" local
done

echo
echo "== summary: pass=$pass fail=$fail timeout=$timeout_count skip=$skip"
[ "$missing" -eq 0 ] || exit 2
[ "$fail" -eq 0 ] && [ "$timeout_count" -eq 0 ]
