#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

pass() {
    echo "PASS: $1"
}

echo "SevenOS Context Engine Tests"
echo "============================"
echo

# ------------------------------------------------------------
# Syntax
# ------------------------------------------------------------

bash -n contextd.sh || fail "contextd syntax"
pass "contextd syntax"

bash -n contextctl.sh || fail "contextctl syntax"
pass "contextctl syntax"

# ------------------------------------------------------------
# JSON contract
# ------------------------------------------------------------

context="$(./contextd.sh once --json)" \
    || fail "contextd once --json"

echo "$context" | jq -e '
    .schema == "sevenos.contextd.cycle.v1"
    and (.mode | type == "string")
    and (.state | type == "object")
    and (.decisions | type == "object")
    and (.policies | type == "object")
    and (.actions | type == "object")
    and (.execution | type == "object")
' >/dev/null || fail "context contract"

pass "context JSON contract"

# ------------------------------------------------------------
# Execution contract
# ------------------------------------------------------------

echo "$context" | jq -e '
    (.execution.executions | type == "array")
    and (.execution.executions | length > 0)
' >/dev/null || fail "execution contract"

pass "execution contract"

# ------------------------------------------------------------
# Required execution fields
# ------------------------------------------------------------

echo "$context" | jq -e '
    all(
        .execution.executions[];
        (.id | type == "string")
        and (.execution | type == "string")
        and (.mode | type == "string")
        and (.executable | type == "boolean")
    )
' >/dev/null || fail "execution fields"

pass "execution fields"

# ------------------------------------------------------------
# Apply cycle
# ------------------------------------------------------------

before="$(./audit.sh count)"

apply_context="$(./contextd.sh --apply --json)" \
    || fail "apply cycle"

after="$(./audit.sh count)"

[[ "$after" -gt "$before" ]] \
    || fail "audit was not recorded"

pass "apply cycle"

# ------------------------------------------------------------
# Apply JSON contract
# ------------------------------------------------------------

echo "$apply_context" | jq -e '
    .schema == "sevenos.contextd.cycle.v1"
    and .mode == "apply"
    and (.execution.executions | length > 0)
' >/dev/null || fail "apply JSON contract"

pass "apply JSON contract"

echo
echo "All Context Engine tests passed."
