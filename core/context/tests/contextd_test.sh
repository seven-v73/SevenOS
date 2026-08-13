#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONTEXT_STATE_DIR="$ROOT/.context"
CONTEXT_STATE_FILE="$CONTEXT_STATE_DIR/context.json"
AUDIT_FILE="$ROOT/audit/events.jsonl"

TEST_STATE_BACKUP=""
TEST_AUDIT_COUNT_BEFORE=0

# ============================================================
# Helpers
# ============================================================

fail() {
    echo "FAIL: $1" >&2
    cleanup
    exit 1
}

pass() {
    echo "PASS: $1"
}

cleanup() {
    # Restore previous context state if we backed it up.
    if [[ -n "$TEST_STATE_BACKUP" && -f "$TEST_STATE_BACKUP" ]]; then
        mkdir -p "$CONTEXT_STATE_DIR"
        mv "$TEST_STATE_BACKUP" "$CONTEXT_STATE_FILE"
        TEST_STATE_BACKUP=""
    fi
}

trap cleanup EXIT

# ============================================================
# Header
# ============================================================

echo "SevenOS Context Engine Tests"
echo "============================"
echo

# ============================================================
# Environment
# ============================================================

command -v jq >/dev/null 2>&1 \
    || fail "jq unavailable"

[[ -x "./contextd.sh" ]] \
    || fail "contextd.sh unavailable"

[[ -x "./contextctl.sh" ]] \
    || fail "contextctl.sh unavailable"

[[ -x "./audit.sh" ]] \
    || fail "audit.sh unavailable"

# ============================================================
# Syntax
# ============================================================

bash -n contextd.sh \
    || fail "contextd syntax"

pass "contextd syntax"

bash -n contextctl.sh \
    || fail "contextctl syntax"

pass "contextctl syntax"

bash -n executor.sh \
    || fail "executor syntax"

pass "executor syntax"

bash -n audit.sh \
    || fail "audit syntax"

pass "audit syntax"

bash -n history.sh \
    || fail "history syntax"

pass "history syntax"

# ============================================================
# JSON contract — dry-run cycle
# ============================================================

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
' >/dev/null \
    || fail "context JSON contract"

pass "context JSON contract"

# ============================================================
# Execution contract
# ============================================================

echo "$context" | jq -e '
    (.execution.schema == "sevenos.execution.v1")
    and (.execution.mode == "dry-run")
    and (.execution.executions | type == "array")
    and (.execution.executions | length > 0)
' >/dev/null \
    || fail "execution contract"

pass "execution contract"

# ============================================================
# Required execution fields
# ============================================================

echo "$context" | jq -e '
    all(
        .execution.executions[];
        (.id | type == "string")
        and (.source | type == "string")
        and (.category | type == "string")
        and (.priority | IN("high", "medium", "low"))
        and (.mode | IN("automatic", "notify", "confirmation", "blocked"))
        and (.risk | IN("low", "medium", "high"))
        and (.executable | type == "boolean")
        and (.execution | type == "string")
        and (.execution_id | type == "string")
    )
' >/dev/null \
    || fail "execution fields"

pass "execution fields"

# ============================================================
# Context CLI JSON contract
# ============================================================

status_json="$(./contextctl.sh status --json)" \
    || fail "contextctl status --json"

echo "$status_json" | jq -e '
    .schema == "sevenos.contextctl.status.v1"
    and (.state | type == "object")
    and (.decisions | type == "object")
    and (.policies | type == "object")
    and (.actions | type == "object")
    and (.execution | type == "object")
    and (.history | type == "object")
' >/dev/null \
    || fail "contextctl status JSON contract"

pass "contextctl JSON contract"

# ============================================================
# Audit baseline
# ============================================================

mkdir -p "$CONTEXT_STATE_DIR"

if [[ -f "$CONTEXT_STATE_FILE" ]]; then
    TEST_STATE_BACKUP="$(mktemp)"
    cp "$CONTEXT_STATE_FILE" "$TEST_STATE_BACKUP"
fi

if [[ -f "$AUDIT_FILE" ]]; then
    TEST_AUDIT_COUNT_BEFORE="$(wc -l < "$AUDIT_FILE")"
else
    TEST_AUDIT_COUNT_BEFORE=0
fi

# ============================================================
# Deterministic apply cycle
# ============================================================
#
# The Context Engine persists its previous fingerprint.
# For the integration test we deliberately remove only the
# persistent context state so the next apply cycle is a real
# first cycle.
#
# We DO NOT clear the audit log.
#
# ============================================================

rm -f "$CONTEXT_STATE_FILE"

apply_context="$(./contextd.sh --apply --json)" \
    || fail "apply cycle"

# ============================================================
# Apply JSON contract
# ============================================================

echo "$apply_context" | jq -e '
    .schema == "sevenos.contextd.cycle.v1"
    and .mode == "apply"
    and (.state | type == "object")
    and (.decisions | type == "object")
    and (.policies | type == "object")
    and (.actions | type == "object")
    and (.execution | type == "object")
    and (.execution.schema == "sevenos.execution.v1")
    and (.execution.mode == "apply")
    and (.execution.executions | type == "array")
    and (.execution.executions | length > 0)
' >/dev/null \
    || fail "apply JSON contract"

pass "apply JSON contract"

# ============================================================
# Execution ID contract
# ============================================================

execution_ids="$(
    echo "$apply_context" |
        jq -r '
            .execution.executions[]
            | .execution_id
        ' |
        sort -u
)"

[[ -n "$execution_ids" ]] \
    || fail "execution id missing"

execution_id_count="$(printf '%s\n' "$execution_ids" | wc -l)"

[[ "$execution_id_count" -eq 1 ]] \
    || fail "multiple execution ids in one cycle"

execution_id="$(printf '%s\n' "$execution_ids")"

pass "execution id contract"

# ============================================================
# Audit recording
# ============================================================

after="$(./audit.sh count)"

[[ "$after" -gt "$TEST_AUDIT_COUNT_BEFORE" ]] \
    || fail "audit was not recorded"

pass "audit recorded"

# ============================================================
# Audit ↔ execution correlation
# ============================================================

audit_events="$(
    ./audit.sh events |
        jq -s \
            --arg execution_id "$execution_id" '
                map(
                    select(
                        .execution_id == $execution_id
                    )
                )
            '
)"

audit_event_count="$(echo "$audit_events" | jq 'length')"

expected_execution_count="$(
    echo "$apply_context" |
        jq '.execution.executions | length'
)"

[[ "$audit_event_count" -eq "$expected_execution_count" ]] \
    || fail "audit/execution event count mismatch"

pass "audit correlation"

# ============================================================
# Audit event fields
# ============================================================

echo "$audit_events" | jq -e '
    all(
        .[];
        (.schema == "sevenos.audit.event.v1")
        and (.timestamp | type == "string")
        and (.execution_id | type == "string")
        and (.execution_mode == "apply")
        and (.action | type == "string")
        and (.source | type == "string")
        and (.category | type == "string")
        and (.priority | IN("high", "medium", "low"))
        and (.mode | IN("automatic", "notify", "confirmation", "blocked"))
        and (.risk | IN("low", "medium", "high"))
        and (.executable | type == "boolean")
        and (.execution | type == "string")
    )
' >/dev/null \
    || fail "audit event fields"

pass "audit event contract"

# ============================================================
# Executed action verification
# ============================================================

executed_count="$(
    echo "$apply_context" |
        jq '
            [
                .execution.executions[]
                | select(.execution == "executed")
            ]
            | length
        '
)"

if [[ "$executed_count" -gt 0 ]]; then

    echo "$apply_context" | jq -e '
        all(
            .execution.executions[];
            if .execution == "executed"
            then
                .executable == true
                and (.result | type == "object")
                and (.result.schema == "sevenos.execution.result.v1")
                and (.result.status == "success")
            else
                true
            end
        )
    ' >/dev/null \
        || fail "execution result contract"

    pass "execution result contract"

else
    echo "INFO: no executable action in current environment"
fi

# ============================================================
# Audit action matching
# ============================================================

echo "$apply_context" | jq -e --argjson audit "$audit_events" '
    [
        .execution.executions[]
        | .id
    ]
    | sort
    ==
    (
        [
            $audit[]
            | .action
        ]
        | sort
    )
' >/dev/null \
    || fail "audit action mismatch"

pass "audit action matching"

# ============================================================
# Context fingerprint
# ============================================================

echo "$apply_context" | jq -e '
    (.context_changed | type == "boolean")
' >/dev/null \
    || fail "context_changed field"

pass "context change contract"

# ============================================================
# History JSON
# ============================================================

history_json="$(./history.sh status --json)" \
    || fail "history status --json"

echo "$history_json" | jq -e '
    (.schema == "sevenos.history.v1")
    and (.state_schema == "sevenos.context.state.v1")
    and (.updated_at | type == "string")
    and (.fingerprint | type == "object")
    and (.actions | type == "array")
    and (.audit_events | type == "number")
' >/dev/null \
    || fail "history JSON contract"

pass "history JSON contract"

# ============================================================
# History recent
# ============================================================

history_recent="$(./history.sh recent 5 --json)" \
    || fail "history recent"

echo "$history_recent" | jq -e '
    type == "array"
    and length <= 5
    and all(
        .[];
        .schema == "sevenos.audit.event.v1"
    )
' >/dev/null \
    || fail "history recent contract"

pass "history recent contract"

# ============================================================
# Audit count consistency
# ============================================================

final_audit_count="$(./audit.sh count)"

[[ "$final_audit_count" -ge "$after" ]] \
    || fail "audit count regression"

pass "audit count consistency"

# ============================================================
# Final
# ============================================================

echo
echo "All Context Engine tests passed."