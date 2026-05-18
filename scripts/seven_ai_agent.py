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
import urllib.parse
import urllib.request
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

    if ("theme" in raw or "thème" in raw or "mode" in raw) and any(token in raw for token in ("light", "clair", "claire")):
        return Intent("SET_THEME", "light", 0.9, "SYSTEM", True, "Theme changes rewrite user desktop configuration.")

    if ("theme" in raw or "thème" in raw or "mode" in raw) and any(token in raw for token in ("dark", "sombre", "noir")):
        return Intent("SET_THEME", "dark", 0.9, "SYSTEM", True, "Theme changes rewrite user desktop configuration.")

    workspace_match = re.search(r"(workspace|bureau|espace)\s+(next|previous|suivant|precedent|précédent|[1-9])", raw)
    if workspace_match:
        target = workspace_match.group(2)
        aliases = {"suivant": "next", "precedent": "previous", "précédent": "previous"}
        return Intent("SWITCH_WORKSPACE", aliases.get(target, target), 0.88, "SAFE", False, "User asked Hyprland to switch workspace.")

    go_workspace_match = re.search(r"(va|go|switch|change|passe).*(workspace|bureau|espace)\s+([1-9])", raw)
    if go_workspace_match:
        return Intent("SWITCH_WORKSPACE", go_workspace_match.group(3), 0.86, "SAFE", False, "User asked Hyprland to switch workspace.")

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

    if any(token in raw for token in ("optimise mon workspace", "optimise mon travail", "organise mon travail", "optimize my workspace", "optimize my workflow")):
        return Intent("OPTIMIZE_WORKFLOW", "workspace", 0.84, "SAFE", False, "User asked for workspace and workflow guidance.")

    if any(token in raw for token in ("raccourcis", "shortcuts", "keybinds", "clavier", "hotkeys")):
        return Intent("SHOW_SHORTCUTS", "keyboard", 0.86, "SAFE", False, "User asked for SevenOS keyboard shortcuts.")

    if any(token in raw for token in ("c'est quoi sevenos", "qu'est ce que sevenos", "what is sevenos", "parle de sevenos", "explique sevenos")):
        return Intent("EXPLAIN_SEVENOS", "sevenos", 0.88, "SAFE", False, "User asked for an explanation of SevenOS.")

    web_match = re.match(r"^(search|cherche|recherche|web|internet)\s+(.+)$", raw)
    if web_match:
        return Intent("WEB_QUERY", web_match.group(2).strip(), 0.78, "WEB", False, "User asked SevenAI to search the web.")

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


def shortcut_catalog() -> dict[str, Any]:
    config = ROOT_DIR / "hyprland/hyprland.conf"
    shortcuts = [
        {"keys": "Super", "action": "Apps launcher"},
        {"keys": "Super+Space", "action": "SevenOS Spotlight"},
        {"keys": "Super+D", "action": "Toggle SevenOS Dock"},
        {"keys": "Super+H", "action": "SevenOS Help"},
        {"keys": "Super+Shift+H", "action": "Seven Hub"},
        {"keys": "Super+E", "action": "Seven Files"},
        {"keys": "Super+Enter", "action": "Terminal Classic"},
        {"keys": "Super+Shift+Enter", "action": "Terminal Dark"},
        {"keys": "Super+Shift+P", "action": "Power menu"},
        {"keys": "Super+1..9", "action": "Switch workspace"},
        {"keys": "Super+Shift+1..9", "action": "Move window to workspace"},
    ]
    parsed = []
    if config.exists():
        for line in config.read_text(encoding="utf-8", errors="ignore").splitlines():
            if not line.startswith("bind ="):
                continue
            parsed.append(line)
    return {"schema": "sevenos.ai.shortcuts.v1", "shortcuts": shortcuts, "hyprland_binds": parsed[:80]}


def sevenos_knowledge() -> dict[str, Any]:
    return {
        "schema": "sevenos.ai.knowledge.v1",
        "name": "SevenOS",
        "tagline": "Beyond the Desktop.",
        "summary": (
            "SevenOS is a next-generation intelligent Linux experience based on Hyprland, "
            "local-first system control, contextual profiles, cybersecurity tooling, "
            "creative workflows and a premium glass design language."
        ),
        "pillars": ["fluidity", "security", "contextual profiles", "AI-assisted control", "creative/dev/cyber workflows"],
        "primary_surfaces": ["Spotlight", "Seven Hub", "Seven Files", "Waybar cockpit", "SevenAI", "SevenShield"],
        "daily_shortcuts": shortcut_catalog()["shortcuts"],
        "workflow_tips": workflow_plan()["tips"],
    }


def workflow_plan() -> dict[str, Any]:
    return {
        "schema": "sevenos.ai.workflow.v1",
        "tips": [
            "Use Super+Space as the single command surface instead of hunting through menus.",
            "Keep Super+D for pinned daily apps and folders, and leave Spotlight for actions/search.",
            "Use Super+1..9 to separate focus contexts: dev, browser, docs, media, communication.",
            "Use profile workspaces: Forge for development, Shield for cybersecurity, Studio for creation.",
            "Use Super+S as a temporary scratch workspace for transient terminals or notes.",
            "Open Seven Hub with Super+Shift+H when you need settings, repair or profile actions.",
        ],
        "recommended_layout": [
            {"workspace": "1", "role": "Focus app / editor"},
            {"workspace": "2", "role": "Browser and docs"},
            {"workspace": "3", "role": "Terminal, containers and logs"},
            {"workspace": "4", "role": "Creative or communication"},
            {"workspace": "special:seven", "role": "Scratchpad and temporary tools"},
        ],
    }


def llm_contract() -> dict[str, Any]:
    return {
        "schema": "sevenos.ai.llm-contract.v1",
        "default_mode": "local-first",
        "goal": "A provider-neutral OS agent that can parse intents, explain SevenOS, control safe desktop actions, request confirmation for system changes and optionally enrich answers from the web.",
        "layers": [
            "Input Layer: CLI, Spotlight, Waybar AI module and future voice input.",
            "Intent Engine: rules first, then local model adapter and embeddings.",
            "Context & Memory: active window, processes, profile, local event log and user workflow patterns.",
            "System Knowledge Graph: SevenOS docs, actions, packages, apps, profiles and repair plans.",
            "Execution Layer: safe UI actions, system actions with --apply, root actions with explicit confirmation.",
            "Self-Healing & Learning: diagnose, propose, execute, record and improve next suggestions.",
        ],
        "providers": [
            {"key": "rules", "status": "active", "privacy": "local"},
            {"key": "ollama", "status": "planned-adapter", "privacy": "local"},
            {"key": "openai-compatible", "status": "planned-adapter", "privacy": "opt-in remote"},
        ],
        "web_policy": {
            "default": "disabled",
            "enable": "SEVENAI_WEB=1 seven ai web \"query\" --json",
            "storage": "Summaries can be cached locally later under XDG_STATE_HOME/sevenos.",
            "safety": "Do not send system context to the web unless the user explicitly asks.",
        },
    }


def web_query(query: str, *, enabled: bool) -> dict[str, Any]:
    if not enabled and os.environ.get("SEVENAI_WEB") != "1":
        return {
            "schema": "sevenos.ai.web.v1",
            "enabled": False,
            "query": query,
            "summary": "Web access is disabled by default. Enable it explicitly with SEVENAI_WEB=1.",
            "next": f"SEVENAI_WEB=1 seven ai web {json.dumps(query)} --json",
        }
    url = "https://duckduckgo.com/html/?" + urllib.parse.urlencode({"q": query})
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "SevenAI/0.1"})
        with urllib.request.urlopen(request, timeout=8) as response:
            html = response.read(200000).decode("utf-8", errors="ignore")
    except Exception as exc:
        return {"schema": "sevenos.ai.web.v1", "enabled": True, "query": query, "error": str(exc)}
    snippets = re.findall(r'class="result__a"[^>]*>(.*?)</a>', html, flags=re.S)
    clean = [re.sub(r"<[^>]+>", "", item).strip() for item in snippets[:5]]
    return {"schema": "sevenos.ai.web.v1", "enabled": True, "query": query, "source": "duckduckgo-html", "results": clean}


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
    elif intent.intent == "SET_THEME":
        command = [str(ROOT_DIR / "install.sh"), "theme", intent.target]
        result["action"] = {"type": "set_theme", "target": intent.target, "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply, cwd=ROOT_DIR)
    elif intent.intent == "SWITCH_WORKSPACE":
        dispatch_target = {"next": "r+1", "previous": "r-1"}.get(intent.target, intent.target)
        command = ["hyprctl", "dispatch", "workspace", dispatch_target]
        result["action"] = {"type": "switch_workspace", "target": intent.target, "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply)
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
    elif intent.intent == "EXPLAIN_SEVENOS":
        result["action"] = {"type": "explain_sevenos", "target": "sevenos"}
        result["result"] = {"applied": False, "knowledge": sevenos_knowledge()}
    elif intent.intent == "SHOW_SHORTCUTS":
        result["action"] = {"type": "show_shortcuts", "target": "keyboard"}
        result["result"] = {"applied": False, "shortcuts": shortcut_catalog()}
    elif intent.intent == "OPTIMIZE_WORKFLOW":
        result["action"] = {"type": "optimize_workflow", "target": "workspace"}
        result["result"] = {"applied": False, "workflow": workflow_plan()}
    elif intent.intent == "WEB_QUERY":
        result["action"] = {"type": "web_query", "target": intent.target}
        result["result"] = web_query(intent.target, enabled=False)
    else:
        result["action"] = {"type": "guidance", "suggestions": [
            "seven ai open settings",
            "seven ai 'mets le thème light'",
            "seven ai 'workspace 2'",
            "seven ai 'raccourcis clavier'",
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
    elif isinstance(result, dict) and result.get("knowledge"):
        knowledge = result["knowledge"]
        print(f"Result: {knowledge.get('summary')}")
        print("Pillars: " + ", ".join(knowledge.get("pillars", [])[:5]))
    elif isinstance(result, dict) and result.get("shortcuts"):
        for item in result["shortcuts"].get("shortcuts", [])[:8]:
            print(f"- {item.get('keys')}: {item.get('action')}")
    elif isinstance(result, dict) and result.get("workflow"):
        for item in result["workflow"].get("tips", [])[:6]:
            print(f"- {item}")
    elif isinstance(result, dict) and result.get("summary"):
        print(f"Result: {result.get('summary')}")
    else:
        print(f"Result: returncode={result.get('returncode', 0) if isinstance(result, dict) else 0}")


def main() -> int:
    raw_args = sys.argv[1:]
    json_flag = "--json" in raw_args
    apply_flag = "--apply" in raw_args
    yes_flag = "--yes" in raw_args
    web_flag = "--web" in raw_args
    raw_args = [arg for arg in raw_args if arg not in ("--json", "--apply", "--yes", "--web")]
    parser = argparse.ArgumentParser(prog="seven-ai-agent")
    parser.add_argument("action", nargs="?", default="ask", choices=("ask", "run", "intent", "apps", "context", "memory", "knowledge", "shortcuts", "workflow", "llm", "web"))
    parser.add_argument("text", nargs=argparse.REMAINDER)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--web", action="store_true")
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args(raw_args)
    args.json = args.json or json_flag
    args.apply = args.apply or apply_flag
    args.yes = args.yes or yes_flag
    args.web = args.web or web_flag

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
    if args.action == "knowledge":
        data = sevenos_knowledge()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data["summary"])
        return 0
    if args.action == "shortcuts":
        data = shortcut_catalog()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else "\n".join(f"{item['keys']}\t{item['action']}" for item in data["shortcuts"]))
        return 0
    if args.action == "workflow":
        data = workflow_plan()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else "\n".join(data["tips"]))
        return 0
    if args.action == "llm":
        data = llm_contract()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data["goal"])
        return 0
    if args.action == "web":
        query = " ".join(args.text).strip()
        data = web_query(query, enabled=args.web)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data.get("summary") or "\n".join(data.get("results", [])))
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
