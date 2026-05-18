#!/usr/bin/env python3
"""SevenAI local system agent foundation.

This is intentionally local and provider-neutral. It turns natural language
requests into explicit intents, resolves apps from the desktop registry, and
executes only safe actions by default.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import subprocess
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


ROOT_DIR = Path(os.environ.get("SEVENOS_ROOT", Path(__file__).resolve().parents[1]))
DRY_RUN = os.environ.get("SEVENOS_DRY_RUN") == "1"


@dataclass
class AppEntry:
    name: str
    desktop_id: str
    command: str
    kind: str
    category: str
    icon: str = ""
    source: str = "desktop"


@dataclass
class Intent:
    intent: str
    target: str
    confidence: float
    safety: str
    needs_apply: bool
    reason: str


BUILTIN_APPS = [
    AppEntry("SevenOS Settings", "seven-settings.desktop", "seven-settings", "gui", "settings", "preferences-system", "sevenos"),
    AppEntry("Seven Files", "seven-files.desktop", "seven-files", "gui", "files", "folder", "sevenos"),
    AppEntry("Seven Hub", "seven-hub.desktop", "seven hub", "gui", "system", "sevenos", "sevenos"),
    AppEntry("Seven Terminal", "seven-terminal.desktop", "seven-terminal", "gui", "terminal", "utilities-terminal", "sevenos"),
    AppEntry("Seven Spotlight", "seven-spotlight.desktop", "seven-spotlight", "gui", "search", "system-search", "sevenos"),
]

APP_ALIASES = {
    "settings": "SevenOS Settings",
    "parametres": "SevenOS Settings",
    "paramètres": "SevenOS Settings",
    "files": "Seven Files",
    "fichiers": "Seven Files",
    "file manager": "Seven Files",
    "terminal": "Seven Terminal",
    "hub": "Seven Hub",
    "spotlight": "Seven Spotlight",
    "vscode": "code",
    "vs code": "code",
    "visual studio code": "code",
}


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.lower().strip())


def desktop_dirs() -> list[Path]:
    dirs = []
    home = Path.home()
    dirs.append(home / ".local/share/applications")
    dirs.append(home / ".local/share/flatpak/exports/share/applications")
    for item in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if item:
            dirs.append(Path(item) / "applications")
    dirs.append(Path("/var/lib/flatpak/exports/share/applications"))
    unique: list[Path] = []
    seen: set[str] = set()
    for path in dirs:
        key = str(path)
        if key not in seen:
            seen.add(key)
            unique.append(path)
    return unique


def parse_desktop_file(path: Path) -> AppEntry | None:
    try:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError:
        return None
    data: dict[str, str] = {}
    in_entry = False
    for line in lines:
        line = line.strip()
        if line == "[Desktop Entry]":
            in_entry = True
            continue
        if line.startswith("[") and line.endswith("]") and line != "[Desktop Entry]":
            in_entry = False
        if not in_entry or not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in ("Name", "Exec", "NoDisplay", "Hidden", "Type", "Categories", "Icon"):
            data[key] = value
    if data.get("Type", "Application") != "Application":
        return None
    if data.get("NoDisplay", "false").lower() == "true" or data.get("Hidden", "false").lower() == "true":
        return None
    name = data.get("Name", "").strip()
    command = clean_exec(data.get("Exec", ""))
    if not name or not command:
        return None
    categories = [item for item in data.get("Categories", "").split(";") if item]
    category = categories[0].lower() if categories else "app"
    return AppEntry(name, path.name, command, "gui", category, data.get("Icon", ""), str(path))


def clean_exec(exec_line: str) -> str:
    return re.sub(r"\s+%[fFuUdDnNickvm]", "", exec_line).strip()


def app_registry() -> list[AppEntry]:
    apps = list(BUILTIN_APPS)
    seen = {app.desktop_id for app in apps}
    for directory in desktop_dirs():
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.desktop")):
            if path.name in seen:
                continue
            entry = parse_desktop_file(path)
            if entry:
                apps.append(entry)
                seen.add(entry.desktop_id)
    apps.sort(key=lambda item: (item.source != "sevenos", item.name.lower()))
    return apps


def match_app(target: str, apps: list[AppEntry]) -> AppEntry | None:
    wanted = normalize(APP_ALIASES.get(normalize(target), target))
    if not wanted:
        return None
    names = [(normalize(app.name), app) for app in apps]
    for name, app in names:
        if wanted == name or wanted == normalize(app.desktop_id).removesuffix(".desktop"):
            return app
    for name, app in names:
        if wanted in name or name in wanted:
            return app
    for app in apps:
        command_name = normalize(Path(app.command.split()[0]).name)
        if wanted == command_name:
            return app
    return None


def parse_intent(text: str) -> Intent:
    raw = normalize(text)
    if not raw:
        return Intent("GUIDANCE", "", 0.2, "SAFE", False, "No natural language request was provided.")

    open_match = re.match(r"^(open|launch|start|ouvre|ouvrir|lance|démarre|demarre)\s+(.+)$", raw)
    if open_match:
        return Intent("OPEN_APP", open_match.group(2).strip(), 0.92, "SAFE", False, "User asked to open an application.")

    kill_match = re.match(r"^(close|kill|stop|ferme|quitte|tue|arrête|arrete)\s+(.+)$", raw)
    if kill_match:
        return Intent("KILL_PROCESS", kill_match.group(2).strip(), 0.86, "SYSTEM", True, "Stopping processes can lose work.")

    if any(token in raw for token in ("mon wifi ne marche pas", "wifi ne marche pas", "repare wifi", "répare wifi", "fix wifi", "repair wifi")):
        return Intent("REPAIR_NETWORK", "wifi", 0.9, "SYSTEM", True, "Network repair may restart NetworkManager.")

    if raw in ("wifi status", "network status", "etat wifi", "état wifi", "status wifi"):
        return Intent("CHECK_NETWORK", "wifi", 0.9, "SAFE", False, "User asked for network status.")

    install_match = re.match(r"^(install|installe|installer)\s+(.+)$", raw)
    if install_match:
        target = install_match.group(2).strip()
        if target in ("un outil de dev", "outil de dev", "dev tools", "developer tools"):
            target = "forge"
        return Intent("INSTALL_PACKAGE", target, 0.82, "ROOT", True, "Installing software changes the system.")

    if any(token in raw for token in ("optimise mon système", "optimise mon systeme", "optimize my system", "optimise system", "optimize system")):
        return Intent("OPTIMIZE_SYSTEM", "system", 0.84, "SYSTEM", True, "Optimization may alter services or cleanup state.")

    if raw in ("status", "etat", "état", "system status", "statut"):
        return Intent("SYSTEM_STATUS", "system", 0.78, "SAFE", False, "User asked for SevenOS status.")

    return Intent("GUIDANCE", raw, 0.45, "SAFE", False, "No direct execution intent matched.")


def run(command: list[str], *, apply: bool, cwd: Path | None = None) -> dict[str, Any]:
    command_text = " ".join(command)
    if DRY_RUN or not apply:
        return {"applied": False, "dry_run": DRY_RUN, "command": command_text, "returncode": 0, "stdout": "", "stderr": ""}
    result = subprocess.run(command, cwd=str(cwd) if cwd else None, text=True, capture_output=True, check=False)
    return {
        "applied": True,
        "dry_run": False,
        "command": command_text,
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def launch_app(app: AppEntry, *, apply: bool) -> dict[str, Any]:
    if app.source != "sevenos" and shutil.which("gtk-launch") and app.desktop_id:
        desktop_id = app.desktop_id.removesuffix(".desktop")
        return run(["gtk-launch", desktop_id], apply=apply)
    if shutil.which("hyprctl"):
        return run(["hyprctl", "dispatch", "exec", app.command], apply=apply)
    return run(["sh", "-lc", f"setsid -f {app.command} >/dev/null 2>&1"], apply=apply)


def network_status() -> dict[str, Any]:
    wifi = ROOT_DIR / "bin/seven-wifi"
    if wifi.exists():
        result = subprocess.run([str(wifi), "status-json"], text=True, capture_output=True, check=False)
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            return {"available": False, "detail": result.stderr.strip() or result.stdout.strip()}
    if shutil.which("nmcli"):
        result = subprocess.run(["nmcli", "-t", "-f", "WIFI,STATE", "general"], text=True, capture_output=True, check=False)
        return {"available": result.returncode == 0, "detail": result.stdout.strip()}
    return {"available": False, "detail": "No NetworkManager helper found."}


def system_context() -> dict[str, Any]:
    load = os.getloadavg() if hasattr(os, "getloadavg") else (0.0, 0.0, 0.0)
    processes = []
    for proc in sorted(Path("/proc").glob("[0-9]*"))[:200]:
        try:
            name = (proc / "comm").read_text(encoding="utf-8", errors="ignore").strip()
            processes.append({"pid": int(proc.name), "name": name})
        except (OSError, ValueError):
            continue
    active_window: dict[str, Any] = {}
    if shutil.which("hyprctl"):
        result = subprocess.run(["hyprctl", "activewindow", "-j"], text=True, capture_output=True, check=False)
        try:
            active_window = json.loads(result.stdout) if result.stdout.strip() else {}
        except json.JSONDecodeError:
            active_window = {"detail": result.stderr.strip()}
    return {
        "schema": "sevenos.ai.context.v1",
        "load": {"1m": load[0], "5m": load[1], "15m": load[2]},
        "process_sample": processes[:25],
        "active_window": active_window,
    }


def memory_path() -> Path:
    base = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "sevenos"
    base.mkdir(parents=True, exist_ok=True)
    return base / "ai-memory.jsonl"


def remember(event: dict[str, Any]) -> None:
    try:
        with memory_path().open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
    except OSError:
        pass


def read_memory(limit: int = 12) -> dict[str, Any]:
    path = memory_path()
    if not path.exists():
        return {"schema": "sevenos.ai.memory.v1", "events": []}
    rows = []
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines()[-limit:]:
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return {"schema": "sevenos.ai.memory.v1", "events": rows}


def execute_intent(intent: Intent, text: str, *, apply: bool) -> dict[str, Any]:
    apps = app_registry()
    result: dict[str, Any] = {
        "schema": "sevenos.ai.agent.v1",
        "input": text,
        "intent": asdict(intent),
        "mode": "apply" if apply else "preview",
        "dry_run": DRY_RUN,
        "action": None,
        "result": None,
    }
    effective_apply = apply or not intent.needs_apply

    if intent.intent == "OPEN_APP":
        app = match_app(intent.target, apps)
        result["action"] = {"type": "open_app", "target": intent.target, "app": asdict(app) if app else None}
        result["result"] = launch_app(app, apply=True) if app and (DRY_RUN or effective_apply) else (
            {"returncode": 1, "stderr": f"Application not found: {intent.target}", "applied": False}
        )
    elif intent.intent == "KILL_PROCESS":
        result["action"] = {"type": "kill_process", "target": intent.target, "command": f"pkill -f {intent.target}"}
        result["result"] = run(["pkill", "-f", intent.target], apply=effective_apply)
    elif intent.intent == "CHECK_NETWORK":
        result["action"] = {"type": "check_network", "target": "wifi"}
        result["result"] = network_status()
    elif intent.intent == "REPAIR_NETWORK":
        command = ["systemctl", "restart", "NetworkManager.service"]
        result["action"] = {"type": "repair_network", "target": "wifi", "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply)
    elif intent.intent == "INSTALL_PACKAGE":
        command = ["sevenpkg", "install", intent.target] if intent.target == "forge" else ["sudo", "pacman", "-S", "--needed", intent.target]
        result["action"] = {"type": "install_package", "target": intent.target, "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply, cwd=ROOT_DIR)
    elif intent.intent == "OPTIMIZE_SYSTEM":
        result["action"] = {"type": "optimize_system", "commands": ["seven insights", "seven repair all", "seven scheduler plan"]}
        result["result"] = {"applied": False, "detail": "Preview first. Use SevenAI with --apply once the plan is acceptable."}
    elif intent.intent == "SYSTEM_STATUS":
        result["action"] = {"type": "system_status", "command": "seven state --json"}
        result["result"] = run([str(ROOT_DIR / "bin/seven"), "state", "--json"], apply=True, cwd=ROOT_DIR)
    else:
        result["action"] = {"type": "guidance", "suggestions": [
            "seven ai open settings",
            "seven ai wifi status",
            "seven ai \"mon wifi ne marche pas\"",
            "seven ai install forge",
        ]}
        result["result"] = {"applied": False, "detail": "SevenAI understood this as guidance, not a direct OS action."}

    remember({
        "ts": int(time.time()),
        "input": text,
        "intent": intent.intent,
        "target": intent.target,
        "safety": intent.safety,
        "applied": bool((result.get("result") or {}).get("applied")),
    })
    return result


def print_human(data: dict[str, Any]) -> None:
    intent = data.get("intent", {})
    result = data.get("result") or {}
    action = data.get("action") or {}
    print("SevenAI Agent")
    print("=============")
    print(f"Input: {data.get('input', '')}")
    print(f"Intent: {intent.get('intent')} · target: {intent.get('target') or '-'} · confidence: {intent.get('confidence')}")
    print(f"Safety: {intent.get('safety')} · mode: {data.get('mode')} · dry-run: {str(data.get('dry_run')).lower()}")
    if command := action.get("command") or result.get("command"):
        print(f"Command: {command}")
    if app := action.get("app"):
        print(f"App: {app.get('name')} ({app.get('desktop_id')})")
    if intent.get("needs_apply") and data.get("mode") != "apply":
        print("Next: rerun with --apply when you want SevenAI to execute this system action.")
    stderr = result.get("stderr") if isinstance(result, dict) else ""
    detail = result.get("detail") if isinstance(result, dict) else ""
    if stderr:
        print(f"Result: {stderr}")
    elif detail:
        print(f"Result: {detail}")
    else:
        print(f"Result: returncode={result.get('returncode', 0) if isinstance(result, dict) else 0}")


def main() -> int:
    raw_args = sys.argv[1:]
    json_flag = "--json" in raw_args
    apply_flag = "--apply" in raw_args
    yes_flag = "--yes" in raw_args
    raw_args = [arg for arg in raw_args if arg not in ("--json", "--apply", "--yes")]
    parser = argparse.ArgumentParser(prog="seven-ai-agent")
    parser.add_argument("action", nargs="?", default="ask", choices=("ask", "run", "intent", "apps", "context", "memory"))
    parser.add_argument("text", nargs=argparse.REMAINDER)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args(raw_args)
    args.json = args.json or json_flag
    args.apply = args.apply or apply_flag
    args.yes = args.yes or yes_flag

    if args.action == "apps":
        data = {"schema": "sevenos.ai.apps.v1", "apps": [asdict(app) for app in app_registry()]}
        print(json.dumps(data, indent=2) if args.json else "\n".join(f"{app['name']}\t{app['command']}" for app in data["apps"]))
        return 0
    if args.action == "context":
        data = system_context()
        print(json.dumps(data, indent=2) if args.json else f"Load: {data['load']['1m']:.2f} · processes: {len(data['process_sample'])}")
        return 0
    if args.action == "memory":
        data = read_memory(args.limit)
        print(json.dumps(data, indent=2) if args.json else "\n".join(f"{item.get('intent')} {item.get('target')}" for item in data["events"]))
        return 0

    text = " ".join(args.text).strip()
    intent = parse_intent(text)
    if args.action == "intent":
        data = {"schema": "sevenos.ai.intent.v1", "input": text, "intent": asdict(intent)}
        print(json.dumps(data, indent=2) if args.json else f"{intent.intent}\t{intent.target}\t{intent.safety}")
        return 0

    data = execute_intent(intent, text, apply=args.apply)
    if args.json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print_human(data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
