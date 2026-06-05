#!/usr/bin/env python3
"""SevenAI agent runtime contract.

This layer is intentionally small and deterministic. It gives SevenOS a stable
agent registry, permission graph and local action ledger that UI surfaces can
consume without depending on natural-language parsing or cloud models.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
AGENTS_FILE = ROOT_DIR / "ai" / "agents.json"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "sevenos" / "ai"
LEDGER_FILE = STATE_DIR / "ledger.jsonl"

SENSITIVE_PERMISSIONS = {
    "system.write",
    "packages.install",
    "packages.remove",
    "services.restart",
    "network.change",
    "profile.switch",
    "theme.apply",
    "files.delete",
    "security.change",
    "external.web",
    "llm.cloud",
    "personal.index",
    "personal.snippet",
    "personal.fulltext.export",
}


def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def read_json(path: Path, fallback: dict[str, Any]) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return fallback


def load_registry() -> dict[str, Any]:
    return read_json(AGENTS_FILE, {"schema": "sevenos.ai-agent-registry.v1", "policy": {}, "agents": []})


def registry_errors(registry: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    agents = registry.get("agents")
    if not isinstance(agents, list) or not agents:
        return ["agent registry is empty"]
    seen: set[str] = set()
    for index, agent in enumerate(agents):
        if not isinstance(agent, dict):
            errors.append(f"agent[{index}] is not an object")
            continue
        agent_id = str(agent.get("id", "")).strip()
        if not agent_id:
            errors.append(f"agent[{index}] has no id")
        elif agent_id in seen:
            errors.append(f"duplicate agent id: {agent_id}")
        seen.add(agent_id)
        for key in ("name", "profile", "mission", "state", "risk"):
            if not str(agent.get(key, "")).strip():
                errors.append(f"{agent_id or index} missing {key}")
        for key in ("permissions", "requires_confirmation", "denied_by_default", "tools"):
            if not isinstance(agent.get(key), list):
                errors.append(f"{agent_id or index} missing list {key}")
    return errors


def ledger_events(limit: int = 50) -> list[dict[str, Any]]:
    try:
        lines = LEDGER_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    events: list[dict[str, Any]] = []
    for line in lines[-max(limit, 1):]:
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            events.append(item)
    return events


def ledger_count() -> int:
    try:
        return sum(1 for _ in LEDGER_FILE.open("r", encoding="utf-8"))
    except OSError:
        return 0


def write_ledger_event(event: dict[str, Any]) -> dict[str, Any]:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "sevenos.ai-ledger-event.v1",
        "ts": now_iso(),
        "agent": event.get("agent") or "equinox.system",
        "action": event.get("action") or "unknown",
        "risk": event.get("risk") or "low",
        "summary": event.get("summary") or "",
        "approved": bool(event.get("approved")),
        "source": event.get("source") or "seven-ai-runtime",
    }
    for key in (
        "input",
        "intent",
        "target",
        "mode",
        "safety",
        "command",
        "applied",
        "blocked",
        "needs_confirmation",
        "conversation_used",
        "confidence",
        "contract",
    ):
        if key in event:
            payload[key] = event.get(key)
    with LEDGER_FILE.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
    return payload


def agents_payload() -> dict[str, Any]:
    registry = load_registry()
    agents = registry.get("agents") if isinstance(registry.get("agents"), list) else []
    return {
        "schema": "sevenos.ai-agents.v1",
        "state": "ready" if not registry_errors(registry) else "needs-attention",
        "policy": registry.get("policy", {}),
        "agents": agents,
        "summary": {
            "total": len(agents),
            "ready": sum(1 for agent in agents if agent.get("state") == "ready"),
            "high_risk": sum(1 for agent in agents if agent.get("risk") == "high"),
        },
    }


def contracts_payload() -> dict[str, Any]:
    registry = load_registry()
    contracts = registry.get("interaction_contracts") if isinstance(registry.get("interaction_contracts"), dict) else {}
    response_card = contracts.get("response_card") if isinstance(contracts.get("response_card"), dict) else {}
    local_context = contracts.get("local_context") if isinstance(contracts.get("local_context"), dict) else {}
    execution = contracts.get("execution") if isinstance(contracts.get("execution"), dict) else {}
    controls = contracts.get("ui_controls") if isinstance(contracts.get("ui_controls"), dict) else {}
    surfaces = contracts.get("surfaces") if isinstance(contracts.get("surfaces"), list) else []
    required_response_fields = response_card.get("required_fields") if isinstance(response_card.get("required_fields"), list) else []

    checks = [
        {
            "key": "default-surface",
            "ok": str(contracts.get("default_surface") or "") == "spotlight-chat",
            "detail": contracts.get("default_surface") or "",
        },
        {
            "key": "response-card",
            "ok": {"title", "answer", "state", "safety", "controls"}.issubset({str(item) for item in required_response_fields}),
            "detail": required_response_fields,
        },
        {
            "key": "local-context",
            "ok": local_context.get("default_scope") == "metadata" and "credentials.read" in set(local_context.get("denied_by_default") or []),
            "detail": {
                "default_scope": local_context.get("default_scope"),
                "content_scope": local_context.get("content_scope"),
            },
        },
        {
            "key": "execution",
            "ok": execution.get("system_write") == "preview_then_confirm" and execution.get("destructive") == "blocked_by_default",
            "detail": execution,
        },
        {
            "key": "controls",
            "ok": controls.get("submit") == "Enter" and controls.get("close") == "Esc" and controls.get("confirm_action") == "Ctrl+Enter",
            "detail": controls,
        },
        {
            "key": "surfaces",
            "ok": {"Spotlight", "Settings", "Doctor", "Seven Files"}.issubset({str(item) for item in surfaces}),
            "detail": surfaces,
        },
    ]
    score = round(sum(1 for check in checks if check["ok"]) / len(checks) * 100) if checks else 0
    return {
        "schema": "sevenos.ai-interaction-contracts.v1",
        "state": "ready" if score == 100 else "needs-attention",
        "score": score,
        "default_surface": contracts.get("default_surface") or "unknown",
        "checks": checks,
        "summary": {
            "checks": len(checks),
            "ok": sum(1 for check in checks if check["ok"]),
            "surfaces": len(surfaces),
            "controls": len(controls),
        },
        "contracts": contracts,
        "issues": [f"{check['key']} contract needs attention" for check in checks if not check["ok"]],
    }


def coverage_payload() -> dict[str, Any]:
    registry = load_registry()
    errors = registry_errors(registry)
    agents = registry.get("agents") if isinstance(registry.get("agents"), list) else []
    rows: list[dict[str, Any]] = []
    issues: list[dict[str, str]] = []
    for index, agent in enumerate(agents):
        if not isinstance(agent, dict):
            continue
        agent_id = str(agent.get("id") or index)
        surfaces = _agent_list_value(agent, "surfaces")
        tools = _agent_list_value(agent, "tools")
        capabilities = _agent_list_value(agent, "capabilities")
        triggers = _agent_list_value(agent, "handoff_triggers")
        confirms = _agent_list_value(agent, "requires_confirmation")
        denied = _agent_list_value(agent, "denied_by_default")
        status_command = str(agent.get("status_command") or "").strip()
        missing: list[str] = []
        if not surfaces:
            missing.append("surfaces")
        if not tools:
            missing.append("tools")
        if not capabilities:
            missing.append("capabilities")
        if not triggers:
            missing.append("handoff_triggers")
        if not confirms:
            missing.append("requires_confirmation")
        if not denied:
            missing.append("denied_by_default")
        if not status_command:
            missing.append("status_command")
        if str(agent.get("state")) != "ready":
            missing.append("ready_state")
        for key in missing:
            issues.append({"agent": agent_id, "key": key, "message": f"{agent_id} missing {key}"})
        rows.append({
            "agent": agent_id,
            "name": agent.get("name"),
            "profile": agent.get("profile"),
            "risk": agent.get("risk"),
            "state": agent.get("state"),
            "surfaces": len(surfaces),
            "tools": len(tools),
            "capabilities": len(capabilities),
            "handoff_triggers": len(triggers),
            "requires_confirmation": len(confirms),
            "denied_by_default": len(denied),
            "status_command": status_command,
            "missing": missing,
            "coverage": "complete" if not missing else "partial",
        })
    total = len(rows)
    complete = sum(1 for row in rows if row["coverage"] == "complete")
    high_risk = sum(1 for row in rows if row.get("risk") == "high")
    score = round((complete / total) * 100) if total else 0
    return {
        "schema": "sevenos.ai-agent-coverage.v1",
        "state": "ready" if total == 7 and complete == total and not errors else "needs-attention",
        "score": score,
        "summary": {
            "agents": total,
            "complete": complete,
            "partial": total - complete,
            "high_risk": high_risk,
            "registry_errors": len(errors),
        },
        "coverage": rows,
        "issues": [{"agent": "registry", "key": "schema", "message": item} for item in errors] + issues,
        "policy": {
            "local_first": bool(registry.get("policy", {}).get("local_first", True)),
            "execution_default": registry.get("policy", {}).get("execution_default", "preview"),
            "ledger": registry.get("policy", {}).get("ledger", "required"),
        },
    }


def _agent_list_value(agent: dict[str, Any], key: str) -> list[str]:
    value = agent.get(key)
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def handoffs_payload() -> dict[str, Any]:
    registry = load_registry()
    errors = registry_errors(registry)
    agents = registry.get("agents") if isinstance(registry.get("agents"), list) else []
    handoffs: list[dict[str, Any]] = []
    capability_map: dict[str, list[str]] = {}
    trigger_map: dict[str, list[str]] = {}
    for agent in agents:
        agent_id = str(agent.get("id") or "").strip()
        if not agent_id:
            continue
        capabilities = _agent_list_value(agent, "capabilities")
        triggers = _agent_list_value(agent, "handoff_triggers")
        signals = _agent_list_value(agent, "context_signals")
        surfaces = _agent_list_value(agent, "surfaces")
        for capability in capabilities:
            capability_map.setdefault(capability, []).append(agent_id)
        for trigger in triggers:
            trigger_map.setdefault(trigger, []).append(agent_id)
        handoffs.append({
            "agent": agent_id,
            "name": agent.get("name"),
            "profile": agent.get("profile"),
            "risk": agent.get("risk"),
            "mission": agent.get("mission"),
            "capabilities": capabilities,
            "triggers": triggers,
            "context_signals": signals,
            "surfaces": surfaces,
            "status_command": agent.get("status_command") or "",
            "tools": _agent_list_value(agent, "tools")[:6],
        })
    missing = [
        str(agent.get("id") or index)
        for index, agent in enumerate(agents)
        if not _agent_list_value(agent, "capabilities") or not _agent_list_value(agent, "handoff_triggers")
    ]
    return {
        "schema": "sevenos.ai-handoffs.v1",
        "state": "ready" if not errors and not missing else "needs-attention",
        "policy": {
            "execution_default": registry.get("policy", {}).get("execution_default", "preview"),
            "confirmation_required_for": registry.get("policy", {}).get("confirmation_required_for", []),
        },
        "handoffs": handoffs,
        "capability_map": capability_map,
        "trigger_map": trigger_map,
        "summary": {
            "agents": len(handoffs),
            "capabilities": len(capability_map),
            "triggers": len(trigger_map),
            "missing_handoff_metadata": len(missing),
        },
        "issues": errors + [f"{agent_id} missing capabilities or handoff_triggers" for agent_id in missing],
    }


def permissions_payload() -> dict[str, Any]:
    registry = load_registry()
    graph: list[dict[str, Any]] = []
    agents = registry.get("agents") if isinstance(registry.get("agents"), list) else []
    for agent in agents:
        permissions = set(agent.get("permissions") or [])
        confirmations = set(agent.get("requires_confirmation") or [])
        denied = set(agent.get("denied_by_default") or [])
        graph.append({
            "agent": agent.get("id"),
            "profile": agent.get("profile"),
            "risk": agent.get("risk"),
            "allowed": sorted(permissions),
            "confirm": sorted(confirmations),
            "denied": sorted(denied),
            "sensitive_confirmed": sorted(confirmations & SENSITIVE_PERMISSIONS),
            "sensitive_allowed_without_confirmation": sorted((permissions & SENSITIVE_PERMISSIONS) - confirmations),
        })
    leaks = [item for item in graph if item["sensitive_allowed_without_confirmation"]]
    return {
        "schema": "sevenos.ai-permission-graph.v1",
        "state": "ready" if not leaks and not registry_errors(registry) else "needs-attention",
        "default": {
            "execution": registry.get("policy", {}).get("execution_default", "preview"),
            "cloud": registry.get("policy", {}).get("cloud_default", "disabled"),
            "ledger": registry.get("policy", {}).get("ledger", "required"),
        },
        "sensitive_permissions": sorted(SENSITIVE_PERMISSIONS),
        "graph": graph,
        "issues": [
            {
                "agent": item["agent"],
                "permission": permission,
                "message": "Sensitive permission is allowed without explicit confirmation.",
            }
            for item in leaks
            for permission in item["sensitive_allowed_without_confirmation"]
        ],
    }


def runtime_status() -> dict[str, Any]:
    registry = load_registry()
    errors = registry_errors(registry)
    agents = registry.get("agents") if isinstance(registry.get("agents"), list) else []
    permissions = permissions_payload()
    coverage = coverage_payload()
    contracts = contracts_payload()
    state = "ready" if not errors and permissions["state"] == "ready" and contracts["state"] == "ready" else "needs-attention"
    return {
        "schema": "sevenos.ai-runtime.v1",
        "state": state,
        "root": str(ROOT_DIR),
        "registry": {
            "path": str(AGENTS_FILE),
            "exists": AGENTS_FILE.exists(),
            "agents": len(agents),
            "ready": sum(1 for agent in agents if agent.get("state") == "ready"),
        },
        "policy": {
            "local_first": bool(registry.get("policy", {}).get("local_first", True)),
            "cloud_default": registry.get("policy", {}).get("cloud_default", "disabled"),
            "execution_default": registry.get("policy", {}).get("execution_default", "preview"),
            "ledger": registry.get("policy", {}).get("ledger", "required"),
        },
        "ledger": {
            "path": str(LEDGER_FILE),
            "events": ledger_count(),
            "writable": ledger_writable(),
        },
        "coverage": {
            "state": coverage.get("state"),
            "score": coverage.get("score"),
            "summary": coverage.get("summary", {}),
        },
        "contracts": {
            "state": contracts.get("state"),
            "score": contracts.get("score"),
            "default_surface": contracts.get("default_surface"),
            "summary": contracts.get("summary", {}),
        },
        "issues": errors + [issue["message"] for issue in permissions.get("issues", [])],
        "next": [
            "seven ai agents --json",
            "seven ai coverage --json",
            "seven ai contracts --json",
            "seven ai handoffs --json",
            "seven ai permissions --json",
            "seven ai ledger --json",
            "seven ai learning --json",
            "seven ai operate \"<request>\" --json",
        ],
    }


def ledger_writable() -> bool:
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        test_file = STATE_DIR / ".write-test"
        test_file.write_text("ok", encoding="utf-8")
        test_file.unlink(missing_ok=True)
        return True
    except OSError:
        return False


def ledger_payload(limit: int) -> dict[str, Any]:
    events = ledger_events(limit)
    return {
        "schema": "sevenos.ai-ledger.v1",
        "state": "ready" if ledger_writable() else "read-only",
        "path": str(LEDGER_FILE),
        "events_total": ledger_count(),
        "events": events,
        "summary": {
            "shown": len(events),
            "approved": sum(1 for event in events if event.get("approved")),
            "high_risk": sum(1 for event in events if event.get("risk") == "high"),
        },
    }


def doctor_payload() -> dict[str, Any]:
    status = runtime_status()
    coverage = coverage_payload()
    contracts = contracts_payload()
    checks = [
        {"key": "registry", "ok": bool(status["registry"]["exists"] and status["registry"]["agents"] == 7), "detail": status["registry"]},
        {"key": "permissions", "ok": permissions_payload()["state"] == "ready", "detail": permissions_payload()["default"]},
        {"key": "coverage", "ok": coverage["state"] == "ready", "detail": coverage["summary"]},
        {"key": "contracts", "ok": contracts["state"] == "ready", "detail": contracts["summary"]},
        {"key": "handoffs", "ok": handoffs_payload()["state"] == "ready", "detail": handoffs_payload()["summary"]},
        {"key": "ledger", "ok": bool(status["ledger"]["writable"]), "detail": status["ledger"]},
        {"key": "local-first", "ok": bool(status["policy"]["local_first"] and status["policy"]["cloud_default"] == "disabled"), "detail": status["policy"]},
    ]
    score = round(sum(1 for check in checks if check["ok"]) / len(checks) * 100)
    return {
        "schema": "sevenos.ai-runtime-doctor.v1",
        "state": "ready" if score == 100 and status["state"] == "ready" else "needs-attention",
        "score": score,
        "checks": checks,
        "issues": status["issues"],
    }


def print_payload(payload: dict[str, Any], json_flag: bool) -> None:
    if json_flag:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return
    state = payload.get("state", "unknown")
    schema = payload.get("schema", "sevenos.ai")
    print(f"{schema} · {state}")
    summary = payload.get("summary")
    if isinstance(summary, dict):
        print(" · ".join(f"{key}: {value}" for key, value in summary.items()))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="seven-ai-runtime")
    parser.add_argument("command", nargs="?", default="status", choices=("status", "runtime", "agents", "coverage", "contracts", "handoffs", "permissions", "ledger", "record", "doctor"))
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--limit", type=int, default=40)
    parser.add_argument("--agent", default="equinox.system")
    parser.add_argument("--action", default="")
    parser.add_argument("--risk", default="low", choices=("low", "medium", "high"))
    parser.add_argument("--summary", default="")
    parser.add_argument("--approved", action="store_true")
    args = parser.parse_args(argv)

    if args.command in {"status", "runtime"}:
        payload = runtime_status()
    elif args.command == "agents":
        payload = agents_payload()
    elif args.command == "coverage":
        payload = coverage_payload()
    elif args.command == "contracts":
        payload = contracts_payload()
    elif args.command == "handoffs":
        payload = handoffs_payload()
    elif args.command == "permissions":
        payload = permissions_payload()
    elif args.command == "ledger":
        payload = ledger_payload(args.limit)
    elif args.command == "doctor":
        payload = doctor_payload()
    else:
        payload = {
            "schema": "sevenos.ai-record.v1",
            "recorded": write_ledger_event({
                "agent": args.agent,
                "action": args.action,
                "risk": args.risk,
                "summary": args.summary,
                "approved": args.approved,
            }),
        }
    print_payload(payload, args.json)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
