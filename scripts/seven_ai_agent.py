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
import sqlite3
import time
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from seven_ai_provider import local_answer
from seven_i18n import language_code as sevenos_language_code


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
    AppEntry("SevenOS Settings", "seven-settings.desktop", "seven-settings", "gui", "settings", "seven-settings", "sevenos"),
    AppEntry("Seven Files", "seven-files.desktop", "seven-files", "gui", "files", "seven-files", "sevenos"),
    AppEntry("Seven Hub", "seven-hub.desktop", "seven hub", "gui", "system", "seven-hub", "sevenos"),
    AppEntry("Seven Terminal", "seven-terminal.desktop", "seven-terminal", "gui", "terminal", "utilities-terminal", "sevenos"),
    AppEntry("Seven Spotlight", "seven-spotlight.desktop", "seven-spotlight", "gui", "search", "seven-spotlight", "sevenos"),
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

PROCESS_ALIASES = {
    "blender": ["blender"],
    "firefox": ["firefox"],
    "chrome": ["chrome", "google-chrome", "chromium"],
    "chromium": ["chromium"],
    "vscode": ["code"],
    "vs code": ["code"],
    "visual studio code": ["code"],
    "code": ["code"],
    "terminal": ["kitty", "seven-terminal"],
    "kitty": ["kitty"],
    "files": ["seven-files", "nautilus"],
    "fichiers": ["seven-files", "nautilus"],
    "seven files": ["seven-files", "nautilus"],
    "settings": ["seven-settings"],
    "parametres": ["seven-settings"],
    "paramètres": ["seven-settings"],
}

MESSAGES = {
    "en": {
        "title": "SevenAI",
        "input": "Request",
        "preview": "I understood the request. I am showing the safe preview first.",
        "apply_hint": "To confirm this system action, run the same request with `--apply`.",
        "command": "Planned command",
        "command_done": "Command used",
        "open_ok": "I am opening {target}.",
        "open_missing": "I could not find an installed app matching “{target}”.",
        "stop_preview": "I can stop {target}. This may close unsaved work.",
        "stop_done": "I asked the system to stop {target}.",
        "stop_missing": "I could not resolve a safe process name for “{target}”.",
        "theme_preview": "I can switch SevenOS to {target} mode.",
        "theme_done": "SevenOS theme switch requested: {target}.",
        "workspace": "I am switching to workspace {target}.",
        "wifi_status": "Here is the current Wi-Fi state.",
        "wifi_repair_preview": "I prepared a Wi-Fi repair. It may restart NetworkManager.",
        "wifi_repair_done": "I launched the Wi-Fi repair step.",
        "install_preview": "I can install {target}. This changes system packages.",
        "install_done": "Package installation requested for {target}.",
        "diagnostic": "Here is what I see on this machine.",
        "memory": "Memory used: {value}%",
        "disk": "Home disk used: {value}%",
        "failed_units": "Failed services: {value}",
        "no_failed_units": "No failed systemd services detected.",
        "recommendations": "Recommendations",
        "shortcuts": "Useful shortcuts",
        "workflow": "Workspace and focus tips",
        "sevenos": "SevenOS in plain words",
        "pillars": "Key ideas",
        "web_disabled": "Web access is off by default for privacy.",
        "guidance": "I can help with apps, Wi-Fi, themes, workspaces, shortcuts and diagnostics.",
        "result_error": "The action returned an error: {value}",
        "result_ok": "Done.",
    },
    "fr": {
        "title": "SevenAI",
        "input": "Demande",
        "preview": "J’ai compris la demande. Je te montre d’abord l’aperçu sécurisé.",
        "apply_hint": "Pour confirmer cette action système, relance la même demande avec `--apply`.",
        "command": "Commande prévue",
        "command_done": "Commande utilisée",
        "open_ok": "J’ouvre {target}.",
        "open_missing": "Je n’ai pas trouvé d’application installée correspondant à « {target} ».",
        "stop_preview": "Je peux arrêter {target}. Cela peut fermer du travail non enregistré.",
        "stop_done": "J’ai demandé au système d’arrêter {target}.",
        "stop_missing": "Je n’ai pas pu résoudre un nom de processus sûr pour « {target} ».",
        "theme_preview": "Je peux passer SevenOS en mode {target}.",
        "theme_done": "Changement de thème SevenOS demandé : {target}.",
        "workspace": "Je passe à l’espace de travail {target}.",
        "wifi_status": "Voici l’état actuel du Wi-Fi.",
        "wifi_repair_preview": "J’ai préparé une réparation Wi-Fi. Elle peut redémarrer NetworkManager.",
        "wifi_repair_done": "J’ai lancé l’étape de réparation Wi-Fi.",
        "install_preview": "Je peux installer {target}. Cette action modifie les paquets système.",
        "install_done": "Installation de paquet demandée pour {target}.",
        "diagnostic": "Voici ce que je vois sur cette machine.",
        "memory": "Mémoire utilisée : {value} %",
        "disk": "Disque personnel utilisé : {value} %",
        "failed_units": "Services en erreur : {value}",
        "no_failed_units": "Aucun service systemd en erreur détecté.",
        "recommendations": "Recommandations",
        "shortcuts": "Raccourcis utiles",
        "workflow": "Conseils pour les espaces et le focus",
        "sevenos": "SevenOS simplement",
        "pillars": "Idées clés",
        "web_disabled": "L’accès web est désactivé par défaut pour protéger la confidentialité.",
        "guidance": "Je peux aider avec les apps, le Wi-Fi, les thèmes, les espaces, les raccourcis et les diagnostics.",
        "result_error": "L’action a retourné une erreur : {value}",
        "result_ok": "Terminé.",
    },
}


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.lower().strip())


def active_language() -> str:
    requested = os.environ.get("SEVENAI_LANG") or os.environ.get("SEVENOS_LANGUAGE") or ""
    if requested.startswith("fr"):
        return "fr"
    if requested.startswith("en"):
        return "en"
    try:
        return "fr" if sevenos_language_code().startswith("fr") else "en"
    except Exception:
        return "en"


def msg(key: str, language: str | None = None, **values: object) -> str:
    language = language or active_language()
    text = MESSAGES.get(language, MESSAGES["en"]).get(key, MESSAGES["en"].get(key, key))
    return text.format(**values) if values else text


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


def command_process_candidates(command: str) -> list[str]:
    parts = command.split()
    if not parts:
        return []
    while parts and "=" in parts[0] and not parts[0].startswith(("/", "./")):
        parts = parts[1:]
    if len(parts) >= 3 and Path(parts[0]).name == "flatpak" and parts[1] == "run":
        app_id = ""
        for item in parts[2:]:
            if not item.startswith("-"):
                app_id = item
                break
        if not app_id:
            return []
        leaf = app_id.split(".")[-1].lower()
        return [leaf, app_id] if leaf else [app_id]
    first = Path(parts[0]).name
    blocked = {"env", "sh", "bash", "setsid", "gtk-launch", "hyprctl", "sudo"}
    if first in blocked and len(parts) > 1:
        return command_process_candidates(" ".join(parts[1:]))
    return [first] if first else []


def process_names_for_target(target: str, apps: list[AppEntry]) -> list[str]:
    wanted = normalize(target)
    names: list[str] = []
    names.extend(PROCESS_ALIASES.get(wanted, []))
    app = match_app(target, apps)
    if app:
        names.extend(command_process_candidates(app.command))
        names.append(normalize(app.name).replace(" ", "-"))
        names.append(app.desktop_id.removesuffix(".desktop"))
    if wanted and re.fullmatch(r"[a-z0-9._+-]+", wanted):
        names.append(wanted)
    clean: list[str] = []
    seen: set[str] = set()
    for name in names:
        item = Path(name).name.strip()
        if not item or item.startswith("-") or item in seen:
            continue
        seen.add(item)
        clean.append(item)
    return clean


def stop_process(target: str, apps: list[AppEntry], *, apply: bool) -> dict[str, Any]:
    processes = process_names_for_target(target, apps)
    command = " || ".join(f"pkill -x -- {name}" for name in processes) if processes else f"pkill -x -- {target}"
    if DRY_RUN or not apply:
        return {
            "applied": False,
            "dry_run": DRY_RUN,
            "command": command,
            "processes": processes,
            "returncode": 0 if processes else 1,
            "stdout": "",
            "stderr": "" if processes else f"No safe process mapping for {target}",
        }
    results = []
    matched = False
    for process in processes:
        result = subprocess.run(["pkill", "-x", "--", process], text=True, capture_output=True, check=False)
        results.append({"process": process, "returncode": result.returncode, "stderr": result.stderr.strip()})
        if result.returncode == 0:
            matched = True
    return {
        "applied": True,
        "dry_run": False,
        "command": command,
        "processes": processes,
        "returncode": 0 if matched else 1,
        "stdout": "",
        "stderr": "" if matched else f"No running process matched {target}",
        "details": results,
    }


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

    diagnose_match = re.match(r"^(diagnose|diagnostic|check|analyse)\s*(system|système|systeme|network|wifi|disk|disque|services)?", raw)
    if diagnose_match and diagnose_match.group(0).strip():
        target = diagnose_match.group(2) or "system"
        aliases = {"système": "system", "systeme": "system", "wifi": "network", "disque": "disk"}
        return Intent("DIAGNOSE_SYSTEM", aliases.get(target, target), 0.86, "SAFE", False, "User asked SevenAI to diagnose local system state.")

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

    research_match = re.match(r"^(research|recherche profonde|cherche sur internet)\s+(.+)$", raw)
    if research_match:
        return Intent("RESEARCH_QUERY", research_match.group(2).strip(), 0.8, "WEB", False, "User asked SevenAI for cached local research.")

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


def shortcut_catalog(language: str | None = None) -> dict[str, Any]:
    language = language or active_language()
    config = ROOT_DIR / "hyprland/hyprland.conf"
    if language == "fr":
        shortcuts = [
            {"keys": "Super", "action": "Lanceur d’apps"},
            {"keys": "Super+Espace", "action": "Spotlight SevenOS"},
            {"keys": "Super+D", "action": "Afficher ou masquer le Dock SevenOS"},
            {"keys": "Super+H", "action": "Aide SevenOS"},
            {"keys": "Super+Maj+H", "action": "Seven Hub"},
            {"keys": "Super+E", "action": "Seven Files"},
            {"keys": "Super+Entrée", "action": "Terminal classique"},
            {"keys": "Super+Maj+Entrée", "action": "Terminal sombre"},
            {"keys": "Super+Maj+P", "action": "Menu d’alimentation"},
            {"keys": "Super+1..9", "action": "Changer d’espace de travail"},
            {"keys": "Super+Maj+1..9", "action": "Déplacer la fenêtre vers un espace"},
        ]
    else:
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
    return {"schema": "sevenos.ai.shortcuts.v1", "language": language, "shortcuts": shortcuts, "hyprland_binds": parsed[:80]}


def sevenos_knowledge(language: str | None = None) -> dict[str, Any]:
    language = language or active_language()
    if language == "fr":
        summary = (
            "SevenOS est une expérience Linux intelligente de nouvelle génération basée sur Hyprland, "
            "le contrôle système local, les profils contextuels, la cybersécurité, les workflows créatifs "
            "et un langage visuel glass premium."
        )
        pillars = ["fluidité", "sécurité", "profils contextuels", "contrôle assisté par IA", "workflows création/dev/cyber"]
    else:
        summary = (
            "SevenOS is a next-generation intelligent Linux experience based on Hyprland, "
            "local-first system control, contextual profiles, cybersecurity tooling, "
            "creative workflows and a premium glass design language."
        )
        pillars = ["fluidity", "security", "contextual profiles", "AI-assisted control", "creative/dev/cyber workflows"]
    return {
        "schema": "sevenos.ai.knowledge.v1",
        "name": "SevenOS",
        "tagline": "Beyond the Desktop.",
        "language": language,
        "summary": summary,
        "pillars": pillars,
        "primary_surfaces": ["Spotlight", "Seven Hub", "Seven Files", "Waybar cockpit", "SevenAI", "SevenShield"],
        "daily_shortcuts": shortcut_catalog(language)["shortcuts"],
        "workflow_tips": workflow_plan(language)["tips"],
    }


def workflow_plan(language: str | None = None) -> dict[str, Any]:
    language = language or active_language()
    if language == "fr":
        tips = [
            "Utilise Super+Espace comme surface de commande unique au lieu de chercher dans les menus.",
            "Garde Super+D pour les apps et dossiers quotidiens, et Spotlight pour les actions et la recherche.",
            "Utilise Super+1..9 pour séparer les contextes : dev, navigateur, docs, média, communication.",
            "Utilise les profils : Forge pour le développement, Shield pour la cybersécurité, Studio pour la création.",
            "Utilise Super+S comme espace temporaire pour les terminaux ou notes rapides.",
            "Ouvre Seven Hub avec Super+Maj+H pour les réglages, réparations et actions de profil.",
        ]
        layout_roles = [
            {"workspace": "1", "role": "App principale / éditeur"},
            {"workspace": "2", "role": "Navigateur et documentation"},
            {"workspace": "3", "role": "Terminal, conteneurs et logs"},
            {"workspace": "4", "role": "Création ou communication"},
            {"workspace": "special:seven", "role": "Scratchpad et outils temporaires"},
        ]
    else:
        tips = [
            "Use Super+Space as the single command surface instead of hunting through menus.",
            "Keep Super+D for pinned daily apps and folders, and leave Spotlight for actions/search.",
            "Use Super+1..9 to separate focus contexts: dev, browser, docs, media, communication.",
            "Use profile workspaces: Forge for development, Shield for cybersecurity, Studio for creation.",
            "Use Super+S as a temporary scratch workspace for transient terminals or notes.",
            "Open Seven Hub with Super+Shift+H when you need settings, repair or profile actions.",
        ]
        layout_roles = [
            {"workspace": "1", "role": "Focus app / editor"},
            {"workspace": "2", "role": "Browser and docs"},
            {"workspace": "3", "role": "Terminal, containers and logs"},
            {"workspace": "4", "role": "Creative or communication"},
            {"workspace": "special:seven", "role": "Scratchpad and temporary tools"},
        ]
    return {
        "schema": "sevenos.ai.workflow.v1",
        "language": language,
        "tips": tips,
        "recommended_layout": layout_roles,
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
            {"key": "seven-local", "status": "active", "privacy": "local", "cost": "none", "network": "none"},
            {"key": "rules", "status": "active", "privacy": "local", "cost": "none", "network": "none"},
        ],
        "web_policy": {
            "default": "disabled",
            "enable": "SEVENAI_WEB=1 seven ai web \"query\" --json",
            "storage": "Research results are cached locally under XDG_STATE_HOME/sevenos/ai.sqlite3.",
            "safety": "Do not send system context to the web unless the user explicitly asks.",
        },
    }


def web_query(query: str, *, enabled: bool) -> dict[str, Any]:
    language = active_language()
    if not enabled and os.environ.get("SEVENAI_WEB") != "1":
        return {
            "schema": "sevenos.ai.web.v1",
            "enabled": False,
            "language": language,
            "query": query,
            "summary": (
                "L’accès web est désactivé par défaut. Active-le explicitement avec SEVENAI_WEB=1."
                if language == "fr"
                else "Web access is disabled by default. Enable it explicitly with SEVENAI_WEB=1."
            ),
            "next": f"SEVENAI_WEB=1 seven ai web {json.dumps(query)} --json",
        }
    url = "https://duckduckgo.com/html/?" + urllib.parse.urlencode({"q": query})
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "SevenAI/0.1"})
        with urllib.request.urlopen(request, timeout=8) as response:
            html = response.read(200000).decode("utf-8", errors="ignore")
    except Exception as exc:
        return {"schema": "sevenos.ai.web.v1", "enabled": True, "language": language, "query": query, "error": str(exc)}
    snippets = re.findall(r'class="result__a"[^>]*>(.*?)</a>', html, flags=re.S)
    clean = [re.sub(r"<[^>]+>", "", item).strip() for item in snippets[:5]]
    return {"schema": "sevenos.ai.web.v1", "enabled": True, "language": language, "query": query, "source": "duckduckgo-html", "results": clean}


def cached_research(query: str, *, enabled: bool) -> dict[str, Any]:
    key = normalize(query)
    try:
        with db() as conn:
            row = conn.execute("select payload from research_cache where query = ?", (key,)).fetchone()
            if row:
                payload = json.loads(row["payload"])
                payload["cached"] = True
                return payload
    except (sqlite3.Error, json.JSONDecodeError):
        pass

    payload = web_query(query, enabled=enabled)
    answer = local_answer(query, {"web": payload})
    payload = {
        "schema": "sevenos.ai.research.v1",
        "query": query,
        "web": payload,
        "local_provider": answer,
        "cached": False,
    }
    if payload["web"].get("enabled"):
        try:
            with db() as conn:
                conn.execute(
                    "insert or replace into research_cache (query, ts, payload) values (?, ?, ?)",
                    (key, int(time.time()), json.dumps(payload, ensure_ascii=False)),
                )
        except sqlite3.Error:
            pass
    return payload


def read_meminfo() -> dict[str, int]:
    data = {}
    try:
        for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
            key, value = line.split(":", 1)
            data[key] = int(value.strip().split()[0])
    except (OSError, ValueError):
        pass
    return data


def top_processes(limit: int = 8) -> list[dict[str, Any]]:
    processes = []
    uptime_ticks = os.sysconf(os.sysconf_names.get("SC_CLK_TCK", "SC_CLK_TCK"))
    for proc in Path("/proc").glob("[0-9]*"):
        try:
            stat = (proc / "stat").read_text(encoding="utf-8", errors="ignore")
            parts = stat.split()
            utime = int(parts[13])
            stime = int(parts[14])
            rss_pages = int(parts[23])
            name = (proc / "comm").read_text(encoding="utf-8", errors="ignore").strip()
            processes.append({
                "pid": int(proc.name),
                "name": name,
                "cpu_ticks": utime + stime,
                "rss_mb": round(rss_pages * os.sysconf("SC_PAGE_SIZE") / 1024 / 1024, 1),
            })
        except (OSError, ValueError, IndexError):
            continue
    return sorted(processes, key=lambda item: (item["cpu_ticks"], item["rss_mb"]), reverse=True)[:limit]


def service_state(name: str) -> str:
    if not shutil.which("systemctl"):
        return "unknown"
    result = subprocess.run(["systemctl", "is-active", name], text=True, capture_output=True, check=False)
    return result.stdout.strip() or "unknown"


def failed_units() -> list[str]:
    if not shutil.which("systemctl"):
        return []
    result = subprocess.run(["systemctl", "--failed", "--plain", "--no-legend"], text=True, capture_output=True, check=False)
    units = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if parts:
            units.append(parts[0])
    return units[:12]


def diagnostics(area: str = "system") -> dict[str, Any]:
    mem = read_meminfo()
    total = mem.get("MemTotal", 0)
    available = mem.get("MemAvailable", 0)
    memory = {
        "total_mb": round(total / 1024, 1) if total else 0,
        "available_mb": round(available / 1024, 1) if available else 0,
        "used_percent": round((1 - available / total) * 100, 1) if total else 0,
    }
    disk = shutil.disk_usage(str(Path.home()))
    payload = {
        "schema": "sevenos.ai.diagnostics.v1",
        "area": area,
        "load": system_context()["load"],
        "memory": memory,
        "disk_home": {
            "total_gb": round(disk.total / 1024**3, 1),
            "free_gb": round(disk.free / 1024**3, 1),
            "used_percent": round(disk.used / disk.total * 100, 1),
        },
        "top_processes": top_processes(),
        "failed_units": failed_units(),
        "network": {
            "networkmanager": service_state("NetworkManager.service"),
            "wifi": network_status(),
        },
        "recommendations": [],
    }
    if payload["memory"]["used_percent"] > 85:
        payload["recommendations"].append("High memory use: inspect top processes before killing anything.")
    if payload["disk_home"]["used_percent"] > 85:
        payload["recommendations"].append("Home disk is getting full: run a cleanup playbook preview.")
    if payload["failed_units"]:
        payload["recommendations"].append("Failed systemd units detected: inspect logs before restart.")
    if payload["network"]["networkmanager"] != "active":
        payload["recommendations"].append("NetworkManager is not active: Wi-Fi repair playbook can restart it.")
    return payload


PLAYBOOKS = {
    "wifi_repair": {
        "title": "Wi-Fi Repair",
        "safety": "SYSTEM",
        "steps": [
            {"explain": "Check current network state.", "command": "seven ai diagnose network --json", "apply": False},
            {"explain": "Restart NetworkManager if needed.", "command": "systemctl restart NetworkManager.service", "apply": True},
            {"explain": "Open Wi-Fi connector.", "command": "seven-wifi connect", "apply": True},
        ],
    },
    "slow_system": {
        "title": "Slow System",
        "safety": "SYSTEM",
        "steps": [
            {"explain": "Inspect load, memory and top processes.", "command": "seven ai diagnose system --json", "apply": False},
            {"explain": "Show scheduler recommendations.", "command": "seven scheduler plan", "apply": False},
            {"explain": "Open system monitor for manual confirmation.", "command": "btop", "apply": True},
        ],
    },
    "failed_services": {
        "title": "Failed Services",
        "safety": "SYSTEM",
        "steps": [
            {"explain": "List failed units.", "command": "systemctl --failed", "apply": False},
            {"explain": "Show SevenOS repair plan.", "command": "seven repair all", "apply": False},
        ],
    },
    "disk_cleanup": {
        "title": "Disk Cleanup",
        "safety": "SYSTEM",
        "steps": [
            {"explain": "Inspect disk state.", "command": "seven ai diagnose disk --json", "apply": False},
            {"explain": "Show package cache size.", "command": "du -sh /var/cache/pacman/pkg 2>/dev/null || true", "apply": False},
        ],
    },
}


def playbook(name: str) -> dict[str, Any]:
    key = normalize(name).replace(" ", "_") or "slow_system"
    item = PLAYBOOKS.get(key)
    if not item:
        return {"schema": "sevenos.ai.playbook.v1", "available": sorted(PLAYBOOKS), "error": f"Unknown playbook: {name}"}
    return {"schema": "sevenos.ai.playbook.v1", "key": key, **item, "requires_apply": any(step["apply"] for step in item["steps"])}


def state_dir() -> Path:
    base = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "sevenos"
    base.mkdir(parents=True, exist_ok=True)
    return base


def db_path() -> Path:
    return state_dir() / "ai.sqlite3"


def db() -> sqlite3.Connection:
    conn = sqlite3.connect(db_path())
    conn.row_factory = sqlite3.Row
    conn.execute(
        "create table if not exists events ("
        "id integer primary key autoincrement, ts integer not null, input text, intent text, "
        "target text, safety text, applied integer, source text default 'user')"
    )
    conn.execute(
        "create table if not exists research_cache ("
        "query text primary key, ts integer not null, payload text not null)"
    )
    conn.execute(
        "create table if not exists preferences ("
        "key text primary key, value text not null, ts integer not null)"
    )
    migrate_jsonl_memory(conn)
    return conn


def migrate_jsonl_memory(conn: sqlite3.Connection) -> None:
    legacy = state_dir() / "ai-memory.jsonl"
    marker = conn.execute("select value from preferences where key = 'jsonl_migrated'").fetchone()
    if marker or not legacy.exists():
        return
    for line in legacy.read_text(encoding="utf-8", errors="ignore").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        conn.execute(
            "insert into events (ts, input, intent, target, safety, applied, source) values (?, ?, ?, ?, ?, ?, ?)",
            (
                int(event.get("ts", time.time())),
                event.get("input", ""),
                event.get("intent", ""),
                event.get("target", ""),
                event.get("safety", ""),
                1 if event.get("applied") else 0,
                "legacy-jsonl",
            ),
        )
    conn.execute("insert or replace into preferences (key, value, ts) values ('jsonl_migrated', '1', ?)", (int(time.time()),))


def remember(event: dict[str, Any]) -> None:
    try:
        with db() as conn:
            conn.execute(
                "insert into events (ts, input, intent, target, safety, applied, source) values (?, ?, ?, ?, ?, ?, ?)",
                (
                    int(event.get("ts", time.time())),
                    event.get("input", ""),
                    event.get("intent", ""),
                    event.get("target", ""),
                    event.get("safety", ""),
                    1 if event.get("applied") else 0,
                    event.get("source", "user"),
                ),
            )
    except sqlite3.Error:
        pass


def read_memory(limit: int = 12) -> dict[str, Any]:
    try:
        with db() as conn:
            events = [
                dict(row)
                for row in conn.execute(
                    "select ts, input, intent, target, safety, applied, source from events order by id desc limit ?",
                    (limit,),
                ).fetchall()
            ]
            top_intents = [
                dict(row)
                for row in conn.execute(
                    "select intent, count(*) as count from events group by intent order by count desc limit 8"
                ).fetchall()
            ]
    except sqlite3.Error:
        events, top_intents = [], []
    return {"schema": "sevenos.ai.memory.v2", "store": str(db_path()), "events": list(reversed(events)), "summary": {"top_intents": top_intents}}


def execute_intent(intent: Intent, text: str, *, apply: bool) -> dict[str, Any]:
    apps = app_registry()
    result: dict[str, Any] = {
        "schema": "sevenos.ai.agent.v1",
        "input": text,
        "language": active_language(),
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
        processes = process_names_for_target(intent.target, apps)
        command = " || ".join(f"pkill -x -- {name}" for name in processes) if processes else f"pkill -x -- {intent.target}"
        result["action"] = {"type": "kill_process", "target": intent.target, "processes": processes, "command": command}
        result["result"] = stop_process(intent.target, apps, apply=effective_apply)
    elif intent.intent == "CHECK_NETWORK":
        result["action"] = {"type": "check_network", "target": "wifi"}
        result["result"] = network_status()
    elif intent.intent == "REPAIR_NETWORK":
        command = ["systemctl", "restart", "NetworkManager.service"]
        result["action"] = {"type": "repair_network", "target": "wifi", "command": " ".join(command), "playbook": playbook("wifi_repair")}
        result["result"] = run(command, apply=effective_apply)
    elif intent.intent == "DIAGNOSE_SYSTEM":
        result["action"] = {"type": "diagnose_system", "target": intent.target}
        diag = diagnostics(intent.target)
        result["result"] = {"applied": False, "diagnostics": diag, "provider": local_answer(text, {"diagnostics": diag, "language": active_language()})}
    elif intent.intent == "INSTALL_PACKAGE":
        command = ["sevenpkg", "install", intent.target] if intent.target == "forge" else ["sudo", "pacman", "-S", "--needed", intent.target]
        result["action"] = {"type": "install_package", "target": intent.target, "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply, cwd=ROOT_DIR)
    elif intent.intent == "OPTIMIZE_SYSTEM":
        result["action"] = {"type": "optimize_system", "commands": ["seven insights", "seven repair all", "seven scheduler plan"], "playbook": playbook("slow_system")}
        result["result"] = {"applied": False, "diagnostics": diagnostics("system"), "detail": "Preview first. Use SevenAI with --apply once the plan is acceptable."}
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
    elif intent.intent == "RESEARCH_QUERY":
        result["action"] = {"type": "research_query", "target": intent.target}
        result["result"] = cached_research(intent.target, enabled=False)
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
    language = active_language()
    action_type = action.get("type", "")
    target = action.get("target") or intent.get("target") or ""
    print(msg("title", language))
    print("=======")
    print(f"{msg('input', language)} : {data.get('input', '')}")

    if action_type == "open_app":
        app = action.get("app")
        if app and not result.get("stderr"):
            print(msg("open_ok", language, target=app.get("name") or target))
        else:
            print(msg("open_missing", language, target=target))
    elif action_type == "kill_process":
        if data.get("mode") == "apply":
            print(msg("stop_done", language, target=target))
        elif action.get("processes"):
            print(msg("stop_preview", language, target=target))
        else:
            print(msg("stop_missing", language, target=target))
    elif action_type == "set_theme":
        key = "theme_done" if data.get("mode") == "apply" else "theme_preview"
        print(msg(key, language, target=target))
    elif action_type == "switch_workspace":
        print(msg("workspace", language, target=target))
    elif action_type == "check_network":
        print(msg("wifi_status", language))
    elif action_type == "repair_network":
        key = "wifi_repair_done" if data.get("mode") == "apply" else "wifi_repair_preview"
        print(msg(key, language))
    elif action_type == "install_package":
        key = "install_done" if data.get("mode") == "apply" else "install_preview"
        print(msg(key, language, target=target))
    elif action_type == "diagnose_system":
        print(msg("diagnostic", language))
    elif action_type == "explain_sevenos":
        print(msg("sevenos", language))
    elif action_type == "show_shortcuts":
        print(msg("shortcuts", language))
    elif action_type == "optimize_workflow":
        print(msg("workflow", language))
    else:
        print(msg("guidance", language))

    if command := action.get("command") or (result.get("command") if isinstance(result, dict) else ""):
        label = "command_done" if data.get("mode") == "apply" else "command"
        print(f"{msg(label, language)} : {command}")

    if intent.get("needs_apply") and data.get("mode") != "apply":
        print(msg("apply_hint", language))

    stderr = result.get("stderr") if isinstance(result, dict) else ""
    detail = result.get("detail") if isinstance(result, dict) else ""
    if stderr and action_type != "kill_process":
        print(msg("result_error", language, value=stderr))
    elif detail:
        print(detail)
    elif isinstance(result, dict) and result.get("knowledge"):
        knowledge = result["knowledge"]
        print(knowledge.get("summary", ""))
        print(f"{msg('pillars', language)} : " + ", ".join(knowledge.get("pillars", [])[:5]))
    elif isinstance(result, dict) and result.get("shortcuts"):
        for item in result["shortcuts"].get("shortcuts", [])[:8]:
            print(f"- {item.get('keys')}: {item.get('action')}")
    elif isinstance(result, dict) and result.get("workflow"):
        for item in result["workflow"].get("tips", [])[:6]:
            print(f"- {item}")
    elif isinstance(result, dict) and result.get("diagnostics"):
        diag = result["diagnostics"]
        print(msg("memory", language, value=diag.get("memory", {}).get("used_percent")))
        print(msg("disk", language, value=diag.get("disk_home", {}).get("used_percent")))
        failed = diag.get("failed_units", [])
        print(msg("failed_units", language, value=", ".join(failed)) if failed else msg("no_failed_units", language))
        for item in diag.get("recommendations", [])[:4]:
            print(f"- {item}")
    elif isinstance(result, dict) and result.get("web"):
        web = result["web"]
        if not web.get("enabled"):
            print(web.get("summary") or msg("web_disabled", language))
        else:
            for item in web.get("results", [])[:5]:
                print(f"- {item}")
    elif isinstance(result, dict) and result.get("summary"):
        print(result.get("summary"))
    elif isinstance(result, dict) and result.get("returncode", 0) not in (0, None) and stderr:
        print(msg("result_error", language, value=stderr))


def main() -> int:
    raw_args = sys.argv[1:]
    json_flag = "--json" in raw_args
    apply_flag = "--apply" in raw_args
    yes_flag = "--yes" in raw_args
    web_flag = "--web" in raw_args
    raw_args = [arg for arg in raw_args if arg not in ("--json", "--apply", "--yes", "--web")]
    parser = argparse.ArgumentParser(prog="seven-ai-agent")
    parser.add_argument("action", nargs="?", default="ask", choices=("ask", "run", "intent", "apps", "context", "memory", "knowledge", "shortcuts", "workflow", "llm", "web", "research", "diagnose", "playbook", "provider"))
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
    if args.action == "provider":
        prompt = " ".join(args.text).strip()
        data = local_answer(prompt, {"diagnostics": diagnostics("system"), "memory": read_memory(8), "language": active_language()})
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data["answer"])
        return 0
    if args.action == "diagnose":
        area = " ".join(args.text).strip() or "system"
        data = diagnostics(area)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else "\n".join(data.get("recommendations") or ["No urgent diagnostic issue found."]))
        return 0
    if args.action == "playbook":
        name = " ".join(args.text).strip() or "slow_system"
        data = playbook(name)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else "\n".join(f"{step['explain']}: {step['command']}" for step in data.get("steps", [])))
        return 0
    if args.action == "web":
        query = " ".join(args.text).strip()
        data = web_query(query, enabled=args.web)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data.get("summary") or "\n".join(data.get("results", [])))
        return 0
    if args.action == "research":
        query = " ".join(args.text).strip()
        data = cached_research(query, enabled=args.web)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data.get("web", {}).get("summary") or data.get("local_provider", {}).get("answer", "No research result."))
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
