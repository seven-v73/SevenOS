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
import shlex
import shutil
import sys
import subprocess
import sqlite3
import time
import unicodedata
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from seven_ai_provider import answer as provider_answer
from seven_ai_provider import local_answer, model_runtime_status
from seven_i18n import language_code as sevenos_language_code

try:
    from seven_ai_runtime import ledger_events, write_ledger_event
except Exception:  # pragma: no cover - ledger must never block the assistant.
    ledger_events = None
    write_ledger_event = None


ROOT_DIR = Path(__file__).resolve().parents[1]
DRY_RUN = os.environ.get("SEVENOS_DRY_RUN") == "1"
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "sevenos"
WAYBAR_CONTEXT_FILE = RUNTIME_DIR / "waybar-context.json"
AI_CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "sevenos"
AI_MANAGER_CACHE = AI_CACHE_DIR / "ai-manager.json"
AI_BRAIN_CACHE = AI_CACHE_DIR / "ai-brain.json"
AI_FOOTPRINT_CACHE = AI_CACHE_DIR / "ai-footprint.json"
AI_CONFIG_FILE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "sevenos" / "ai.env"
AI_STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "sevenos" / "ai"
AI_MISSIONS_FILE = AI_STATE_DIR / "missions.json"
AI_PREFERENCES_FILE = AI_STATE_DIR / "preferences.json"


def run_json(command: list[str], fallback: Any, timeout: float = 8.0) -> Any:
    try:
        result = subprocess.run(
            command,
            cwd=str(ROOT_DIR),
            env={**os.environ, "SEVENOS_ROOT": str(ROOT_DIR)},
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
        if result.returncode != 0 or not result.stdout.strip():
            return fallback
        return json.loads(result.stdout)
    except Exception:
        return fallback


@dataclass
class AppEntry:
    name: str
    desktop_id: str
    command: str
    kind: str
    category: str
    icon: str = ""
    source: str = "desktop"
    aliases: list[str] = field(default_factory=list)


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
    AppEntry("Seven Store", "seven-store.desktop", "seven-store", "gui", "store", "seven-store", "sevenos"),
    AppEntry("Seven Doctor", "seven-doctor.desktop", "seven doctor", "gui", "system", "seven-doctor", "sevenos"),
    AppEntry("Seven Reader", "seven-reader.desktop", "seven-reader", "gui", "reader", "seven-reader", "sevenos"),
    AppEntry("Seven Notes", "seven-notes.desktop", "seven-notes", "gui", "notes", "seven-notes", "sevenos"),
    AppEntry("Seven Tools", "seven-tools.desktop", "seven-tools", "gui", "tools", "seven-tools", "sevenos"),
    AppEntry("SevenAI", "seven-ai.desktop", "seven-spotlight ai", "gui", "assistant", "seven-ai", "sevenos"),
]

APP_ALIASES = {
    "settings": "SevenOS Settings",
    "setting": "SevenOS Settings",
    "reglages": "SevenOS Settings",
    "réglages": "SevenOS Settings",
    "parametre": "SevenOS Settings",
    "paramètre": "SevenOS Settings",
    "parametres": "SevenOS Settings",
    "paramètres": "SevenOS Settings",
    "general settings": "SevenOS Settings",
    "réglages généraux": "SevenOS Settings",
    "reglages generaux": "SevenOS Settings",
    "files": "Seven Files",
    "file": "Seven Files",
    "fichiers": "Seven Files",
    "fichier": "Seven Files",
    "file manager": "Seven Files",
    "gestionnaire de fichiers": "Seven Files",
    "explorateur": "Seven Files",
    "explorateur de fichiers": "Seven Files",
    "terminal": "Seven Terminal",
    "console": "Seven Terminal",
    "hub": "Seven Hub",
    "spotlight": "Seven Spotlight",
    "search": "Seven Spotlight",
    "recherche": "Seven Spotlight",
    "store": "Seven Store",
    "boutique": "Seven Store",
    "app store": "Seven Store",
    "applications": "Seven Store",
    "doctor": "Seven Doctor",
    "docteur": "Seven Doctor",
    "task manager": "Seven Doctor",
    "gestionnaire de taches": "Seven Doctor",
    "gestionnaire de tâches": "Seven Doctor",
    "reader": "Seven Reader",
    "lecteur": "Seven Reader",
    "lecteur pdf": "Seven Reader",
    "pdf": "Seven Reader",
    "notes": "Seven Notes",
    "note": "Seven Notes",
    "bloc notes": "Seven Notes",
    "bloc-notes": "Seven Notes",
    "tools": "Seven Tools",
    "outils": "Seven Tools",
    "ai": "SevenAI",
    "seven ai": "SevenAI",
    "sevenai": "SevenAI",
    "assistant": "SevenAI",
    "navigateur": "firefox",
    "browser": "firefox",
    "web": "firefox",
    "imprimante": "Print Settings",
    "imprimantes": "Print Settings",
    "printer": "Print Settings",
    "printers": "Print Settings",
    "bluetooth": "Bluetooth Manager",
    "wifi": "SevenOS Settings",
    "wi fi": "SevenOS Settings",
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
        "mission": "Equinox mission plan",
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
        "mission": "Mission Equinox",
        "sevenos": "SevenOS simplement",
        "pillars": "Idées clés",
        "web_disabled": "L’accès web est désactivé par défaut pour protéger la confidentialité.",
        "guidance": "Je peux aider avec les apps, le Wi-Fi, les thèmes, les espaces, les raccourcis et les diagnostics.",
        "result_error": "L’action a retourné une erreur : {value}",
        "result_ok": "Terminé.",
    },
}


def normalize(value: str) -> str:
    folded = unicodedata.normalize("NFKD", value)
    ascii_value = "".join(ch for ch in folded if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", ascii_value.lower().strip())


def normalize_app_target(target: str) -> str:
    value = normalize(target)
    value = re.sub(r"^(lance|ouvre|ouvrir|open|launch|start|demarre|démarre)\s+", "", value).strip()
    value = re.sub(r"\b(s'il te plait|s'il te plaît|stp|svp|please)\b", "", value).strip()
    for _ in range(3):
        before = value
        value = re.sub(r"^(l'|l’|le|la|les|un|une|des|the|a|an)\s+", "", value).strip()
        value = re.sub(r"^(app|apps|application|applications|logiciel|programme)\s+", "", value).strip()
        value = re.sub(r"\s+(app|apps|application|applications|logiciel|programme)$", "", value).strip()
        if value == before:
            break
    value = normalize(value)
    return value


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


def language_for_text(text: str) -> str:
    raw = normalize(text)
    if raw.startswith(("et ", "la ", "le ", "les ", "ce ", "cet ", "cette ", "ces ", "mon ", "ma ", "mes ", "ton ", "ta ", "tes ", "que ", "quoi ", "point ", "statut ", "active ", "desactive ", "désactive ", "scanne ", "indexe ", "efface ", "supprime ", "oublie ", "vide ", "demarre ", "démarre ")):
        return "fr"
    french_tokens = (
        "quel", "quelle", "combien", "taille", "disque", "memoire", "mémoire",
        "batterie", "reseau", "réseau", "connexion", "wifi", "wi-fi", "etat", "état", "status", "statut",
        "machine", "modele", "modèle", "ollama", "provider", "sais", "retiens", "apprends", "infos", "informations", "mon", "ma", "mes",
        "processeur", "stockage", "espace", "restant", "libre",
        "ouvre", "ouvrir", "lance", "ferme", "quitte", "installe", "installer",
        "mets", "met", "passe", "theme", "thème", "repare", "répare", "diagnostic",
        "pourquoi", "historique", "derniere", "dernière", "action", "fait", "explique",
        "contexte", "fenetre", "fenêtre", "actuel", "actuelle",
        "aide", "ici", "application",
        "fais", "plan", "sante", "santé", "systeme", "système", "stabilite", "stabilité",
        "maintenance", "ameliorer", "améliorer", "recent", "récent", "activite", "activité",
        "bonjour", "briefing", "jour", "journee", "journée", "quotidien", "quotidienne", "resume", "résume",
        "peux", "peut", "faire", "quoi", "aider",
        "souviens", "retiens", "retient", "memorise", "mémorise", "preference", "préférence",
        "preferences", "préférences", "prefere", "préfère", "reponse", "réponse", "reponses", "réponses",
        "apprentissage", "memoire locale", "mémoire locale", "sources approuvees", "sources approuvées",
        "scanne", "scanner", "indexe", "indexer", "extrait", "extraits", "desactive", "désactive",
        "efface", "effacer", "supprime", "supprimer", "oublie", "oublier", "vide", "vider",
        "coder", "developper", "développer", "creer", "créer", "monter", "video", "vidéo",
        "musique", "reseau", "audit", "securite", "sécurité", "document", "pdf", "culture",
        "africaine", "jouer", "jeu", "regler", "régler", "reparer", "réparer", "analyse", "analyser",
        "compare", "comparer", "comparaison", "poids", "empreinte", "avant apres", "avant après",
        "tendance", "evolution", "évolution", "garde", "garde-fou", "verdict", "gel",
    )
    if any(token in raw for token in french_tokens):
        return "fr"
    return active_language()


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
        if (
            key in ("Name", "Exec", "NoDisplay", "Hidden", "Type", "Categories", "Icon", "GenericName", "Comment", "Keywords")
            or key.startswith("Name[")
            or key.startswith("X-GNOME-FullName")
            or key.startswith("GenericName[")
            or key.startswith("Comment[")
            or key.startswith("Keywords[")
        ):
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
    aliases: list[str] = []
    for key, value in data.items():
        if key.startswith(("Name[", "X-GNOME-FullName", "GenericName", "GenericName[", "Comment", "Comment[")):
            aliases.append(value)
        elif key.startswith(("Keywords", "Keywords[")):
            aliases.extend(item for item in re.split(r"[;,]", value) if item.strip())
    aliases.extend(categories)
    aliases.append(path.stem)
    aliases.append(Path(command.split()[0]).name if command else "")
    deduped_aliases: list[str] = []
    seen_aliases: set[str] = set()
    for alias in aliases:
        clean = normalize_app_target(alias)
        if clean and clean not in seen_aliases and clean != normalize_app_target(name):
            seen_aliases.add(clean)
            deduped_aliases.append(alias.strip())
    return AppEntry(name, path.name, command, "gui", category, data.get("Icon", ""), str(path), deduped_aliases[:32])


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


def app_match_score(wanted: str, app: AppEntry) -> int:
    name = normalize(app.name)
    clean_name = normalize_app_target(name)
    desktop_key = normalize(app.desktop_id).removesuffix(".desktop")
    try:
        command_name = normalize(Path(shlex.split(app.command)[0]).name if app.command else "")
    except ValueError:
        command_name = normalize(app.command.split()[0] if app.command else "")
    category = normalize(app.category)
    alias_values = [normalize_app_target(alias) for alias in app.aliases]
    alias_values = [alias for alias in alias_values if alias]
    searchable = " ".join([name, clean_name, desktop_key, command_name, category, *alias_values])
    tokens = {token for token in re.split(r"[^a-z0-9]+", wanted) if len(token) >= 3}
    name_tokens = {token for token in re.split(r"[^a-z0-9]+", searchable) if token}

    if wanted in {name, clean_name, desktop_key, command_name}:
        return 100
    if wanted in alias_values:
        return 94
    if wanted == normalize(APP_ALIASES.get(name, "")):
        return 98
    if wanted.startswith(name) or name.startswith(wanted) or wanted.startswith(clean_name) or clean_name.startswith(wanted):
        return 86
    long_aliases = [alias for alias in alias_values if len(alias) >= 4]
    if any(wanted.startswith(alias) or alias.startswith(wanted) for alias in long_aliases):
        return 82
    if wanted in searchable:
        return 72
    if name in wanted or clean_name in wanted or any(alias in wanted for alias in long_aliases):
        return 68
    overlap = len(tokens & name_tokens)
    if overlap:
        return 45 + min(overlap * 8, 24)
    return 0


def similar_apps(target: str, apps: list[AppEntry], *, limit: int = 5) -> list[dict[str, str]]:
    wanted = normalize_app_target(target)
    alias = normalize(APP_ALIASES.get(wanted, wanted))
    scored = sorted(
        ((max(app_match_score(wanted, app), app_match_score(alias, app)), app) for app in apps),
        key=lambda item: (-item[0], item[1].source != "sevenos", item[1].name.lower()),
    )
    return [
        {"name": app.name, "desktop_id": app.desktop_id, "command": app.command}
        for score, app in scored
        if score >= 35
    ][:limit]


def match_app(target: str, apps: list[AppEntry]) -> AppEntry | None:
    cleaned = normalize_app_target(target)
    wanted = normalize(APP_ALIASES.get(cleaned, cleaned))
    wanted = normalize(APP_ALIASES.get(wanted, wanted))
    if not wanted:
        return None
    scored = sorted(
        ((max(app_match_score(cleaned, app), app_match_score(wanted, app)), app) for app in apps),
        key=lambda item: (-item[0], item[1].source != "sevenos", item[1].name.lower()),
    )
    best_score, best_app = scored[0] if scored else (0, None)
    return best_app if best_app and best_score >= 60 else None


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

    search_words = ("cherche", "recherche", "retrouve", "trouve", "find", "search")
    local_scopes = ("fichiers", "documents", "notes", "contexte local", "local files", "local documents", "local notes")
    if any(word in raw for word in search_words) and any(scope in raw for scope in local_scopes):
        patterns = (
            r"^(?:cherche|recherche|retrouve|trouve|find|search)\s+(.+?)\s+dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local|local files|local documents|local notes)$",
            r"^(?:cherche|recherche|retrouve|trouve|find|search)\s+(?:dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local|local files|local documents|local notes)\s+)?(.+)$",
            r"(?:dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local|local files|local documents|local notes))\s+(.+)$",
        )
        for pattern in patterns:
            match = re.search(pattern, raw)
            if not match:
                continue
            query = match.group(1).strip()
            query = re.sub(r"^(?:sur internet|web|internet)\s+", "", query).strip()
            if query and query not in local_scopes:
                return Intent("LOCAL_SEARCH", query, 0.91, "SAFE", False, "User asked SevenAI to search the approved local index.")

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

    if any(token in raw for token in ("mon wifi ne marche pas", "wifi ne marche pas", "repare wifi", "répare wifi", "repare le wifi", "répare le wifi", "fix wifi", "repair wifi")):
        return Intent("REPAIR_NETWORK", "wifi", 0.9, "SYSTEM", True, "Network repair may restart NetworkManager.")

    if any(token in raw for token in (
        "insights memoire", "insights mémoire", "analyse ta memoire", "analyse ta mémoire",
        "analyse memoire", "analyse mémoire", "memoire proactive", "mémoire proactive",
        "suggestions memoire", "suggestions mémoire", "memory insights", "memory recommendations",
    )):
        return Intent("MEMORY_INSIGHTS", "memory", 0.9, "SAFE", False, "User asked SevenAI for local memory insights and recommendations.")

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

    if any(token in raw for token in (
        "plan santé", "plan sante", "santé système", "sante systeme", "état complet", "etat complet",
        "stabilité", "stabilite", "rendre stable", "rendre plus stable", "améliorer la stabilité",
        "ameliorer la stabilite", "plan de maintenance", "maintenance sevenos",
        "health plan", "system health plan", "stability plan", "maintenance plan",
    )):
        return Intent("HEALTH_PLAN", "system", 0.86, "SAFE", False, "User asked SevenAI for a prioritized system health plan.")

    if (
        any(token in raw for token in (
            "briefing", "briefing sevenai", "briefing sevenos", "resume ma journee", "résume ma journée",
            "resume la journee", "résume la journée", "bonjour sevenai", "bonjour seven",
            "point du jour", "point quotidien", "etat du jour", "état du jour",
            "daily briefing", "morning briefing", "today briefing", "system briefing",
        ))
        and not any(token in raw for token in ("memoire", "mémoire", "contexte", "local", "mini os", "mini-os"))
    ):
        return Intent("DAILY_BRIEFING", "day", 0.88, "SAFE", False, "User asked SevenAI for a contextual daily briefing.")

    if re.match(r"^(?:souviens[- ]toi que|souviens toi que|retient que|retiens que|memorise que|mémorise que|remember that|remember i|remember my)\s+.+", raw):
        return Intent("REMEMBER_PREFERENCE", raw, 0.9, "SAFE", False, "User asked SevenAI to remember an explicit local preference.")

    if any(token in raw for token in (
        "ce que tu sais de moi", "ce que tu retiens", "qu'est-ce que tu sais de moi",
        "qu’est ce que tu sais de moi", "comment tu apprends", "comment tu me connais",
        "d'où viennent tes infos", "d’ou viennent tes infos", "d'où viennent tes informations",
        "d’ou viennent tes informations", "profil mémoire", "profil memoire",
        "what do you know about me", "what do you remember", "how do you learn",
        "where does your memory come from", "memory profile",
    )):
        return Intent("MEMORY_PROFILE", "memory", 0.9, "SAFE", False, "User asked SevenAI to explain what it knows and where local memory comes from.")

    if any(token in raw for token in (
        "audit mémoire sevenai", "audit memoire sevenai", "audit de ta mémoire",
        "audit de ta memoire", "rapport mémoire sevenai", "rapport memoire sevenai",
        "rapport confidentialité sevenai", "rapport confidentialite sevenai",
        "controle ta mémoire", "contrôle ta mémoire", "verifie ta mémoire",
        "vérifie ta mémoire", "memory audit", "privacy report", "sevenai memory audit",
    )):
        return Intent("MEMORY_AUDIT", "memory", 0.9, "SAFE", False, "User asked SevenAI for a privacy and memory audit.")

    if any(token in raw for token in (
        "plan mémoire sevenai", "plan memoire sevenai", "plan d'apprentissage",
        "plan apprentissage", "améliore ta mémoire", "ameliore ta memoire",
        "rends ta mémoire utile", "rends ta memoire utile", "que peux-tu apprendre",
        "que peux tu apprendre", "quoi apprendre maintenant", "comment améliorer ta mémoire",
        "comment ameliorer ta memoire", "memory plan", "learning plan",
        "improve your memory", "what can you learn",
    )):
        return Intent("MEMORY_PLAN", "memory", 0.9, "SAFE", False, "User asked SevenAI for a safe local learning plan.")

    if any(token in raw for token in (
        "historique mémoire sevenai", "historique memoire sevenai",
        "historique de ta mémoire", "historique de ta memoire",
        "activité mémoire sevenai", "activite memoire sevenai",
        "timeline mémoire", "timeline memoire", "journal mémoire", "journal memoire",
        "qu'est-ce qui a changé dans ta mémoire", "qu’est-ce qui a changé dans ta mémoire",
        "qu'est ce qui a change dans ta memoire", "qu’est ce qui a changé dans ta mémoire",
        "ce qui a changé dans ta mémoire", "ce qui a change dans ta memoire",
        "memory history", "memory timeline", "what changed in your memory",
    )):
        return Intent("MEMORY_HISTORY", "memory", 0.9, "SAFE", False, "User asked SevenAI for local memory history.")

    if any(token in raw for token in (
        "insights mémoire sevenai", "insights memoire sevenai",
        "analyse ta mémoire", "analyse ta memoire", "analyse mémoire", "analyse memoire",
        "que recommandes-tu avec ma mémoire", "que recommandes tu avec ma memoire",
        "que proposes-tu avec ma mémoire", "que proposes tu avec ma memoire",
        "rends ta mémoire proactive", "rends ta memoire proactive",
        "suggestions mémoire", "suggestions memoire", "mémoire proactive", "memoire proactive",
        "memory insights", "memory recommendations", "analyze your memory",
        "what do you recommend from memory",
    )):
        return Intent("MEMORY_INSIGHTS", "memory", 0.9, "SAFE", False, "User asked SevenAI for local memory insights and recommendations.")

    if any(token in raw for token in (
        "briefing mémoire", "briefing memoire", "briefing local", "briefing contexte",
        "contexte mémoire", "contexte memoire", "contexte mini os", "contexte mini-os",
        "que dois-je reprendre", "que dois je reprendre", "quoi reprendre maintenant",
        "aide-moi à reprendre", "aide moi a reprendre", "reprendre mon travail",
        "memory briefing", "context briefing", "what should i resume",
        "what should i pick up",
    )):
        return Intent("MEMORY_BRIEFING", "memory", 0.9, "SAFE", False, "User asked SevenAI for a contextual local memory briefing.")

    if any(token in raw for token in (
        "état apprentissage", "etat apprentissage", "statut apprentissage",
        "apprentissage local", "sources approuvées", "sources approuvees",
        "état de l'apprentissage", "etat de l'apprentissage",
        "learning status", "local learning status", "approved sources",
    )):
        return Intent("LEARNING_STATUS", "learning", 0.88, "SAFE", False, "User asked SevenAI for local learning status.")

    if any(token in raw for token in (
        "montre tes sources", "montre les sources", "liste tes sources",
        "sources de ta mémoire", "sources de ta memoire", "sources sevenai",
        "dossiers approuvés", "dossiers approuves", "show learning sources",
        "show memory sources", "list approved sources",
    )):
        return Intent("LEARNING_SOURCES", "sources", 0.9, "SAFE", False, "User asked SevenAI to list approved learning sources.")

    add_source_match = re.search(
        r"^(?:ajoute|autorise|approuve|add|approve)\s+(?:le\s+|la\s+|les\s+|mes\s+)?(?:dossier\s+|source\s+)?(.+?)\s+(?:a|à|dans|to)\s+(?:ta\s+|ton\s+|the\s+)?(?:memoire|mémoire|apprentissage|index local|local memory|learning)",
        raw,
    )
    if add_source_match:
        return Intent("LEARNING_ADD_SOURCE", add_source_match.group(1).strip(), 0.88, "CONFIRM", True, "Adding a learning source expands SevenAI's approved local memory scope.")

    remove_source_match = re.search(
        r"^(?:retire|enleve|enlève|supprime|remove|unapprove)\s+(?:le\s+|la\s+|les\s+|mes\s+)?(?:dossier\s+|source\s+)?(.+?)\s+(?:de|from)\s+(?:ta\s+|ton\s+|the\s+)?(?:memoire|mémoire|apprentissage|index local|local memory|learning)",
        raw,
    )
    if remove_source_match:
        return Intent("LEARNING_REMOVE_SOURCE", remove_source_match.group(1).strip(), 0.88, "CONFIRM", True, "Removing a learning source reduces SevenAI's approved local memory scope.")

    if any(token in raw for token in (
        "désactive ton apprentissage", "desactive ton apprentissage",
        "désactive l'apprentissage", "desactive l'apprentissage",
        "désactive ta mémoire locale", "desactive ta memoire locale",
        "coupe l'apprentissage", "stoppe l'apprentissage",
        "disable learning", "disable local learning", "disable local memory",
    )):
        return Intent("LEARNING_DISABLE", "learning", 0.88, "CONFIRM", True, "Disabling learning changes SevenAI local memory settings.")

    if any(token in raw for token in (
        "efface ton index local", "efface l'index local", "vide ton index local",
        "supprime ton index local", "oublie les fichiers indexés", "oublie les fichiers indexes",
        "clear local index", "clear learning index", "forget indexed files",
    )):
        return Intent("LEARNING_CLEAR_INDEX", "learning-index", 0.88, "CONFIRM", True, "Clearing the local index removes SevenAI's indexed file metadata.")

    if any(token in raw for token in (
        "efface les extraits", "supprime les extraits", "vide les extraits",
        "efface les extraits locaux", "supprime les extraits locaux",
        "clear snippets", "clear local snippets", "remove snippets",
    )):
        return Intent("LEARNING_CLEAR_SNIPPETS", "learning-snippets", 0.88, "CONFIRM", True, "Clearing snippets removes content excerpts while keeping file metadata.")

    if any(token in raw for token in (
        "active ton apprentissage", "active l'apprentissage",
        "active ta mémoire locale", "active ta memoire locale",
        "autorise l'apprentissage local", "autorise la mémoire locale",
        "autorise la memoire locale", "enable learning", "enable local learning",
        "enable local memory",
    )):
        return Intent("LEARNING_ENABLE", "learning", 0.88, "CONFIRM", True, "Enabling learning allows SevenAI to index approved local sources.")

    if any(token in raw for token in (
        "scanne avec extraits", "scan avec extraits", "active les extraits locaux",
        "indexe les extraits", "scanne le contenu", "indexe le contenu",
        "scan with snippets", "scan content", "index snippets", "enable local snippets",
    )):
        return Intent("LEARNING_SCAN_CONTENT", "learning-content", 0.87, "CONFIRM", True, "Content snippets read approved files and therefore require explicit confirmation.")

    if any(token in raw for token in (
        "scanne mes documents", "scan mes documents", "indexe mes documents",
        "scanne mes fichiers", "scan mes fichiers", "indexe mes fichiers",
        "rafraîchis l'index local", "rafraichis l'index local",
        "actualise l'index local", "scan local files", "scan my documents",
        "index my documents", "refresh local index",
    )):
        return Intent("LEARNING_SCAN", "learning", 0.87, "CONFIRM", True, "Scanning indexes metadata from approved local sources.")

    if any(token in raw for token in (
        "mes préférences", "mes preferences", "préférences sevenai", "preferences sevenai",
        "my preferences", "show preferences",
    )):
        return Intent("SHOW_PREFERENCES", "preferences", 0.88, "SAFE", False, "User asked SevenAI to show explicit local preferences.")

    if any(token in raw for token in (
        "oublie mes préférences", "oublie mes preferences", "efface mes préférences",
        "efface mes preferences", "forget my preferences", "clear my preferences",
    )):
        return Intent("FORGET_PREFERENCES", "preferences", 0.86, "SAFE", False, "User asked SevenAI to clear explicit local preferences.")

    if any(token in raw for token in (
        "état de ta mémoire", "etat de ta memoire", "memoire sevenai", "mémoire sevenai",
        "pourquoi tu ne mémorises pas", "pourquoi tu ne memorises pas",
        "pourquoi tu n'enregistres pas", "pourquoi tu n’enregistres pas",
        "mémoire locale sevenai", "memoire locale sevenai",
        "sevenai state", "ai state", "memory state", "local memory state",
        "why can't you remember", "why cant you remember", "why can't you save",
    )):
        return Intent("AI_STATE_STATUS", "state", 0.9, "SAFE", False, "User asked SevenAI for local memory/state health.")

    if any(token in raw for token in (
        "que peux tu faire", "que peux-tu faire", "qu'est ce que tu peux faire",
        "qu’est ce que tu peux faire", "aide sevenai", "capacités sevenai",
        "capacites sevenai", "fonctionnalités sevenai", "fonctionnalites sevenai",
        "comment tu peux m'aider", "comment tu peux m’aider",
        "what can you do", "sevenai capabilities", "how can you help",
    )):
        return Intent("SEVENAI_CAPABILITIES", "sevenai", 0.9, "SAFE", False, "User asked SevenAI to explain its capabilities and limits.")

    if any(token in raw for token in (
        "ton modele local", "ton modèle local", "modele local actif", "modèle local actif",
        "ollama actif", "ollama marche", "statut ollama", "statut llm", "statut du modele",
        "statut du modèle", "etat du modele", "état du modèle", "provider sevenai",
        "quel modele utilises", "quel modèle utilises", "local model status", "llm status",
        "is ollama active", "which model are you using", "model status",
    )):
        return Intent("MODEL_STATUS", "local-model", 0.88, "SAFE", False, "User asked SevenAI for local model/provider status.")

    if any(token in raw for token in (
        "active ton modele", "active ton modèle", "active ollama", "demarre ollama",
        "démarre ollama", "prepare ton modele", "prépare ton modèle", "configure ollama",
        "installer modele local", "installer modèle local", "setup local model",
        "start ollama", "enable ollama", "prepare local model", "configure local model",
    )):
        return Intent("MODEL_SETUP", "ollama", 0.86, "CONFIRM", True, "User asked SevenAI to prepare the local model runtime.")

    if any(token in raw for token in (
        "que dois-je faire", "quoi faire", "prochaine action", "prochaines actions",
        "recommande", "recommandation", "recommandations", "suggestion", "suggestions",
        "what should i do", "next action", "next actions", "recommend", "recommendations",
    )):
        return Intent("RECOMMEND_ACTIONS", "system", 0.84, "SAFE", False, "User asked SevenAI for contextual next actions.")

    mission_create_match = re.match(
        r"^(?:cree|crée|creer|créer|ajoute|prepare|prépare|start|create|new)\s+(?:une\s+)?mission\s+(.+)$",
        raw,
    )
    if mission_create_match:
        return Intent("CREATE_AI_MISSION", mission_create_match.group(1).strip(), 0.88, "SAFE", False, "User asked SevenAI to create a local mission plan.")

    if any(token in raw for token in (
        "mes missions", "missions sevenai", "missions en cours", "mission en cours",
        "suivi mission", "suivre mission", "liste missions", "mission board",
        "my missions", "active missions", "mission list", "show missions",
    )):
        return Intent("SHOW_AI_MISSIONS", "missions", 0.86, "SAFE", False, "User asked SevenAI to show local mission plans.")

    if any(token in raw for token in (
        "état mission", "etat mission", "progression mission", "progression de ma mission",
        "état de ma mission", "etat de ma mission", "statut de ma mission",
        "status de ma mission", "où en est ma mission", "ou en est ma mission",
        "où en est la mission", "ou en est la mission", "mission status",
        "mission progress", "where is my mission",
    )):
        return Intent("MISSION_STATUS", "missions", 0.88, "SAFE", False, "User asked SevenAI for local mission progress.")

    if any(token in raw for token in (
        "prochaine étape mission", "prochaine etape mission", "prochaine étape de ma mission",
        "prochaine etape de ma mission", "continuer ma mission", "continue ma mission",
        "reprendre ma mission", "mission suivante", "next mission step", "continue my mission",
    )):
        return Intent("NEXT_AI_MISSION_STEP", "missions", 0.88, "SAFE", False, "User asked SevenAI for the next local mission step.")

    if any(token in raw for token in (
        "termine l'étape", "termine l’etape", "terminer l'étape", "terminer l’etape",
        "marque l'étape", "marque l’etape", "étape terminée", "etape terminee",
        "complete mission step", "mark step done", "mission step done",
    )):
        return Intent("COMPLETE_AI_MISSION_STEP", "missions", 0.86, "SAFE", False, "User asked SevenAI to mark the next local mission step as done.")

    if any(token in raw for token in (
        "pourquoi tu proposes", "pourquoi cette action", "pourquoi cette recommandation",
        "pourquoi tu recommandes", "explique ton choix", "explique cette action",
        "explique cette recommandation", "pourquoi commencer par", "why this action",
        "why this recommendation", "explain this recommendation", "why do you recommend",
    )):
        return Intent("EXPLAIN_DECISION", "next-action", 0.88, "SAFE", False, "User asked SevenAI to explain the current recommendation.")

    if any(token in raw for token in (
        "qu'as tu fait", "qu’as tu fait", "qu'est-ce que tu as fait", "qu’est ce que tu as fait",
        "derniere action", "dernière action", "historique sevenai", "historique de sevenai",
        "explique ton action", "explique la derniere",
        "what did you do", "last action", "why this action", "explain your action", "sevenai history",
    )):
        return Intent("EXPLAIN_LEDGER", "recent", 0.86, "SAFE", False, "User asked SevenAI to explain recent local agent activity.")

    if any(token in raw for token in (
        "activité récente", "activite recente", "mon activité", "mon activite", "historique recent",
        "ce que j'ai fait", "ce que je fais souvent", "mes habitudes", "habitudes recentes",
        "recent activity", "my activity", "recent history", "what have i been doing", "my habits",
    )):
        return Intent("RECENT_ACTIVITY", "memory", 0.86, "SAFE", False, "User asked SevenAI to summarize local usage memory.")

    if any(token in raw for token in (
        "contexte actuel", "mon contexte", "où j'en suis", "ou j'en suis", "ce que je fais",
        "fenetre active", "fenêtre active", "app active", "application active",
        "current context", "what am i doing", "active window", "current app",
    )):
        return Intent("CURRENT_CONTEXT", "session", 0.86, "SAFE", False, "User asked SevenAI to summarize the active session context.")

    if any(token in raw for token in (
        "aide moi avec cette app", "aide-moi avec cette app", "aide moi avec cette application",
        "aide moi avec cette fenetre", "aide moi avec cette fenêtre",
        "aide-moi avec cette fenetre", "aide-moi avec cette fenêtre",
        "aide moi ici", "aide-moi ici", "que puis-je faire ici", "quoi faire ici",
        "aide sur cette fenetre", "aide sur cette fenêtre", "assistant cette app",
        "help me with this app", "help me here", "what can i do here", "assist current app",
    )):
        return Intent("ASSIST_ACTIVE_APP", "session", 0.88, "SAFE", False, "User asked SevenAI for help with the active app or window.")

    if any(token in raw for token in (
        "quel agent", "quelle agent", "agent sevenai", "agent sevenos", "qui peut m'aider",
        "qui peut m’aider", "qui doit gérer", "qui doit gerer", "route cette demande",
        "oriente cette demande", "choisis l'agent", "choisis l’agent", "agent adapté",
        "agent adapte", "which agent", "what agent", "route this", "best agent",
    )):
        return Intent("ROUTE_AGENT", raw, 0.88, "SAFE", False, "User asked SevenAI to route the request to the right SevenOS agent.")

    if any(token in raw for token in (
        "etat des agents", "état des agents", "statut des agents", "agents prêts", "agents prets",
        "agents sevenai", "agents sevenos", "mes agents", "liste des agents", "sante des agents",
        "santé des agents", "couverture agents", "couverture des agents", "qualité agents",
        "qualite agents", "contrats sevenai", "contrats ai", "contrat ui sevenai",
        "raccourcis sevenai", "raccourcis ai", "agent coverage", "agent quality", "ai contracts",
        "sevenai contracts",
        "agent status", "agents status", "are agents ready", "show agents",
    )):
        return Intent("AGENT_STATUS", "agents", 0.88, "SAFE", False, "User asked SevenAI for the multi-agent runtime status.")

    if any(token in raw for token in (
        "je veux coder", "je veux developper", "je veux développer", "creer une app", "créer une app",
        "faire un site", "faire une app", "debug", "compiler", "container", "docker", "podman",
        "monter une video", "monter une vidéo", "faire une video", "faire une vidéo", "creer une musique",
        "créer une musique", "streamer", "obs", "blender", "krita", "design graphique",
        "analyser le reseau", "analyser le réseau", "audit securite", "audit sécurité", "pentest",
        "forensic", "malware", "pare-feu", "firewall",
        "chercher un document", "organiser mes pdf", "ocr", "cartographie", "veille technologique",
        "culture africaine", "langue africaine", "baobab", "patrimoine", "rite", "histoire africaine",
        "jouer", "gaming", "steam", "proton", "lutris", "performance jeu",
        "regler mon systeme", "régler mon système", "mettre a jour", "mettre à jour", "reparer sevenos",
        "build a", "create an app", "edit a video", "make a video", "security audit", "play games",
        "research documents", "system repair", "update sevenos",
    )):
        return Intent("ROUTE_AGENT", raw, 0.84, "SAFE", False, "SevenAI detected a domain task and will route it to the right SevenOS agent.")

    if any(token in raw for token in ("optimise mon workspace", "optimise mon travail", "organise mon travail", "prepare mon espace", "prépare mon espace", "prepare my workspace", "optimize my workspace", "optimize my workflow")):
        return Intent("OPTIMIZE_WORKFLOW", "workspace", 0.84, "SAFE", False, "User asked for workspace and workflow guidance.")

    local_search_before_scope = re.match(
        r"^(cherche|recherche|retrouve|trouve|find|search)\s+(.+?)\s+dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local)$",
        raw,
    )
    if local_search_before_scope:
        query = local_search_before_scope.group(2).strip()
        if query:
            return Intent("LOCAL_SEARCH", query, 0.88, "SAFE", False, "User asked SevenAI to search the approved local index.")

    local_search_match = re.match(
        r"^(cherche|recherche|retrouve|trouve|find|search)\s+(?:dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local)\s+)?(.+)$",
        raw,
    )
    if local_search_match and any(scope in raw for scope in ("fichiers", "documents", "notes", "contexte local")):
        query = local_search_match.group(2).strip()
        if query and not query.startswith(("sur internet", "web ", "internet ")):
            return Intent("LOCAL_SEARCH", query, 0.86, "SAFE", False, "User asked SevenAI to search the approved local index.")

    local_search_tail = re.search(r"(?:dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local))\s+(.+)$", raw)
    if local_search_tail and any(token in raw for token in ("cherche", "recherche", "retrouve", "trouve", "find", "search")):
        query = local_search_tail.group(1).strip()
        if query:
            return Intent("LOCAL_SEARCH", query, 0.84, "SAFE", False, "User asked SevenAI to search the approved local index.")

    if any(token in raw for token in ("jeu vidéo", "jeu video", "histoire du mali", "empire du mali", "mali", "publish web", "publier une solution web", "site web", "déployer", "deployer", "mission")):
        return Intent("PLAN_MISSION", raw, 0.86, "SAFE", False, "User asked Equinox to plan a multi-mini-OS mission.")

    if any(token in raw for token in ("raccourcis", "shortcuts", "keybinds", "clavier", "hotkeys")):
        return Intent("SHOW_SHORTCUTS", "keyboard", 0.86, "SAFE", False, "User asked for SevenOS keyboard shortcuts.")

    if any(token in raw for token in ("politique d'execution", "politique d’execution", "politique d'exécution", "politique d’exécution", "execution policy", "garde-fous", "guardrails")):
        return Intent("SHOW_EXECUTION_POLICY", "sevenai", 0.9, "SAFE", False, "User asked how SevenAI executes or blocks system actions.")

    if any(token in raw for token in ("c'est quoi sevenos", "qu'est ce que sevenos", "what is sevenos", "parle de sevenos", "explique sevenos")):
        return Intent("EXPLAIN_SEVENOS", "sevenos", 0.88, "SAFE", False, "User asked for an explanation of SevenOS.")

    local_search_before_scope = re.match(
        r"^(cherche|recherche|retrouve|trouve|find|search)\s+(.+?)\s+dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local)$",
        raw,
    )
    if local_search_before_scope:
        query = local_search_before_scope.group(2).strip()
        if query:
            return Intent("LOCAL_SEARCH", query, 0.86, "SAFE", False, "User asked SevenAI to search the approved local index.")

    local_search_match = re.match(
        r"^(cherche|recherche|retrouve|trouve|find|search)\s+(?:dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local)\s+)?(.+)$",
        raw,
    )
    if local_search_match:
        query = local_search_match.group(2).strip()
        if query and not query.startswith(("sur internet", "web ", "internet ")):
            return Intent("LOCAL_SEARCH", query, 0.84, "SAFE", False, "User asked SevenAI to search the approved local index.")

    local_search_tail = re.search(r"(?:dans\s+(?:mes\s+)?(?:fichiers|documents|notes|contexte local))\s+(.+)$", raw)
    if local_search_tail and any(token in raw for token in ("cherche", "recherche", "retrouve", "trouve", "find", "search")):
        query = local_search_tail.group(1).strip()
        if query:
            return Intent("LOCAL_SEARCH", query, 0.82, "SAFE", False, "User asked SevenAI to search the approved local index.")

    web_match = re.match(r"^(search|cherche|recherche|web|internet)\s+(.+)$", raw)
    if web_match:
        return Intent("WEB_QUERY", web_match.group(2).strip(), 0.78, "WEB", False, "User asked SevenAI to search the web.")

    research_match = re.match(r"^(research|recherche profonde|cherche sur internet)\s+(.+)$", raw)
    if research_match:
        return Intent("RESEARCH_QUERY", research_match.group(2).strip(), 0.8, "WEB", False, "User asked SevenAI for cached local research.")

    if any(token in raw for token in ("guard", "garde", "garde-fou", "verdict", "bloque", "bloquer", "freeze", "gel")) and any(token in raw for token in ("footprint", "poids", "taille sevenos", "cache", "sevenos", "empreinte")):
        return Intent("ANSWER_SYSTEM_QUESTION", "footprint_guard", 0.89, "SAFE", False, "User asked SevenAI for the SevenOS footprint guard verdict.")

    if any(token in raw for token in ("tendance", "evolution", "évolution", "historique", "trend")) and any(token in raw for token in ("footprint", "poids", "taille sevenos", "cache", "sevenos")):
        return Intent("ANSWER_SYSTEM_QUESTION", "footprint_trend", 0.88, "SAFE", False, "User asked SevenAI for SevenOS footprint trend history.")

    if any(token in raw for token in ("compare", "comparer", "comparaison", "avant/apres", "avant/après", "delta")) and any(token in raw for token in ("footprint", "poids", "taille sevenos", "cache", "sevenos")):
        return Intent("ANSWER_SYSTEM_QUESTION", "footprint_compare", 0.88, "SAFE", False, "User asked SevenAI to compare SevenOS footprint evidence with the live state.")

    question_tokens = (
        "quel", "quelle", "combien", "taille", "how", "what", "which", "show", "affiche", "donne",
        "etat", "état", "ai je", "ai-je", "est ce", "est-ce", "y a", "y-a",
    )
    machine_tokens = (
        "disque", "disk", "stockage", "storage", "espace", "space",
        "poids", "taille sevenos", "footprint", "duplication", "cache",
        "memoire", "mémoire", "ram", "memory",
        "cpu", "processeur", "processor", "batterie", "battery",
        "reseau", "réseau", "network", "wifi", "machine", "pc", "ordinateur",
        "services", "systeme", "système", "system",
        "theme", "thème", "apparence", "mode", "sombre", "clair", "dark", "light",
        "profil", "profile", "mini os", "espace", "workspace",
        "mise a jour", "mise à jour", "mises a jour", "mises à jour", "update", "updates",
        "sante", "santé", "health", "sain", "saine", "healthy", "qualite", "qualité", "quality",
        "application", "applications", "app", "apps", "fenêtre", "fenetres", "fenêtres", "window", "windows",
        "processus", "process", "processes", "programme", "programmes", "consomme", "consumption",
    )
    if any(token in raw for token in question_tokens) and any(token in raw for token in machine_tokens):
        topic = "machine"
        if any(token in raw for token in ("guard", "garde", "garde-fou", "verdict", "bloque", "bloquer", "freeze", "gel")) and any(token in raw for token in ("footprint", "poids", "taille sevenos", "cache", "sevenos", "empreinte")):
            topic = "footprint_guard"
        elif any(token in raw for token in ("tendance", "evolution", "évolution", "historique", "trend")) and any(token in raw for token in ("footprint", "poids", "taille sevenos", "cache", "sevenos")):
            topic = "footprint_trend"
        elif any(token in raw for token in ("compare", "comparer", "comparaison", "avant/apres", "avant/après", "delta")) and any(token in raw for token in ("footprint", "poids", "taille sevenos", "cache", "sevenos")):
            topic = "footprint_compare"
        elif any(token in raw for token in ("footprint", "poids", "taille sevenos", "duplication", "cache")) and "sevenos" in raw:
            topic = "footprint"
        elif any(token in raw for token in ("mise a jour", "mise à jour", "mises a jour", "mises à jour", "update", "updates")):
            topic = "updates"
        elif any(token in raw for token in ("sante", "santé", "health", "sain", "saine", "healthy", "qualite", "qualité", "quality")):
            topic = "health"
        elif any(token in raw for token in ("theme", "thème", "apparence", "mode", "sombre", "clair", "dark", "light")):
            topic = "theme"
        elif any(token in raw for token in ("profil", "profile", "mini os", "workspace")):
            topic = "profile"
        elif any(token in raw for token in ("application", "applications", "app", "apps", "fenêtre", "fenetres", "fenêtres", "window", "windows", "programme", "programmes")):
            topic = "apps"
        elif any(token in raw for token in ("processus", "process", "processes", "consomme", "consumption")):
            topic = "processes"
        elif any(token in raw for token in ("disque", "disk", "stockage", "storage", "espace", "space")):
            topic = "disk"
        elif any(token in raw for token in ("memoire", "mémoire", "ram", "memory")):
            topic = "memory"
        elif any(token in raw for token in ("cpu", "processeur", "processor")):
            topic = "cpu"
        elif any(token in raw for token in ("batterie", "battery")):
            topic = "battery"
        elif any(token in raw for token in ("reseau", "réseau", "network", "wifi")):
            topic = "network"
        elif "services" in raw:
            topic = "services"
        return Intent("ANSWER_SYSTEM_QUESTION", topic, 0.86, "SAFE", False, "User asked a local machine/system question.")

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


def mission_plan(query: str, *, apply: bool) -> dict[str, Any]:
    command = [str(ROOT_DIR / "bin/seven"), "experience-center", "intent", query, "--json"]
    result = subprocess.run(command, cwd=str(ROOT_DIR), env={**os.environ, "SEVENOS_ROOT": str(ROOT_DIR)}, text=True, capture_output=True, check=False)
    plan: dict[str, Any] = {}
    if result.returncode == 0 and result.stdout.strip():
        try:
            data = json.loads(result.stdout)
            plan = data.get("intent_result", {}) if isinstance(data.get("intent_result"), dict) else {}
        except json.JSONDecodeError:
            plan = {}
    launch_command = f"seven experience-center intent {shlex.quote(query)} --gui"
    launched = run(["bash", "-lc", launch_command], apply=apply, cwd=ROOT_DIR) if apply else {"applied": False, "command": launch_command, "returncode": 0, "stdout": "", "stderr": ""}
    return {"applied": bool(launched.get("applied")), "command": launch_command, "plan": plan, "returncode": result.returncode, "stderr": result.stderr.strip()}


def read_missions() -> dict[str, Any]:
    fallback = {"schema": "sevenos.ai-missions.v1", "missions": []}
    try:
        data = json.loads(AI_MISSIONS_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return fallback
    if not isinstance(data, dict):
        return fallback
    missions = data.get("missions")
    if not isinstance(missions, list):
        data["missions"] = []
    data.setdefault("schema", "sevenos.ai-missions.v1")
    return data


def write_missions(data: dict[str, Any]) -> bool:
    try:
        AI_STATE_DIR.mkdir(parents=True, exist_ok=True)
        AI_MISSIONS_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return True
    except OSError:
        return False


def mission_steps_from_plan(plan: dict[str, Any], language: str) -> list[dict[str, Any]]:
    intent_result = plan.get("plan") if isinstance(plan.get("plan"), dict) else {}
    match = intent_result.get("match") if isinstance(intent_result.get("match"), dict) else {}
    raw_steps = match.get("steps") if isinstance(match.get("steps"), list) else []
    steps: list[dict[str, Any]] = []
    for index, item in enumerate(raw_steps[:6], 1):
        if not isinstance(item, dict):
            continue
        profile = str(item.get("profile") or item.get("profile_title") or "").strip()
        title = str(item.get("title") or item.get("output") or "").strip()
        steps.append({
            "index": index,
            "title": title or (f"Étape {index}" if language == "fr" else f"Step {index}"),
            "profile": profile,
            "status": "planned",
            "command": f"seven profile activate {shlex.quote(profile)}" if profile else "",
            "detail": str(item.get("detail") or item.get("output") or "").strip(),
        })
    if steps:
        return steps
    defaults_fr = [
        ("Clarifier l’objectif", "equinox", "Définir résultat attendu, contraintes et priorité."),
        ("Choisir l’agent principal", "equinox", "Router vers le Mini OS le plus adapté."),
        ("Préparer les ressources", "atlas", "Retrouver documents, fichiers ou contexte local."),
        ("Exécuter par étapes", "equinox", "Appliquer seulement après prévisualisation."),
    ]
    defaults_en = [
        ("Clarify the goal", "equinox", "Define expected outcome, constraints and priority."),
        ("Choose lead agent", "equinox", "Route to the best Mini OS for the task."),
        ("Prepare resources", "atlas", "Find documents, files or local context."),
        ("Execute in steps", "equinox", "Apply only after preview."),
    ]
    return [
        {"index": index, "title": title, "profile": profile, "status": "planned", "command": "", "detail": detail}
        for index, (title, profile, detail) in enumerate(defaults_fr if language == "fr" else defaults_en, 1)
    ]


def create_ai_mission(query: str, language: str) -> dict[str, Any]:
    query = query.strip() or ("Mission SevenOS" if language == "fr" else "SevenOS mission")
    route = agent_handoff_answer(query, language)
    plan = mission_plan(query, apply=False)
    missions = read_missions()
    items = missions.get("missions") if isinstance(missions.get("missions"), list) else []
    mission_id = f"mission-{int(time.time())}"
    selected = route.get("selected_agent") if isinstance(route.get("selected_agent"), dict) else {}
    handoffs = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "handoffs", "--json"],
        {"handoffs": []},
        timeout=4.0,
    )
    agents_by_id = {
        str(agent.get("agent")): agent
        for agent in (handoffs.get("handoffs") if isinstance(handoffs.get("handoffs"), list) else [])
        if isinstance(agent, dict) and agent.get("agent")
    }
    collaborator_ids: list[str] = []
    if selected.get("id"):
        collaborator_ids.append(str(selected.get("id")))
    for alternative in route.get("alternatives", []) if isinstance(route.get("alternatives"), list) else []:
        alt_id = str(alternative.get("id") or "")
        if alt_id:
            collaborator_ids.append(alt_id)
    q = normalize(query)
    if any(token in q for token in ("jeu", "game", "gaming", "proton")):
        collaborator_ids.extend(["pulse.gaming", "forge.dev", "studio.creator"])
    if any(token in q for token in ("mali", "afrique", "africain", "culture", "histoire", "history", "empire", "royaume")):
        collaborator_ids.extend(["baobab.culture", "atlas.research"])
    if any(token in q for token in ("document", "pdf", "research", "recherche", "ocr")):
        collaborator_ids.extend(["atlas.research"])
    collaborators = []
    seen: set[str] = set()
    for agent_id in collaborator_ids:
        if agent_id in seen:
            continue
        seen.add(agent_id)
        agent = agents_by_id.get(agent_id)
        if agent:
            collaborators.append({
                "id": agent_id,
                "name": agent.get("name"),
                "profile": agent.get("profile"),
                "mission": agent.get("mission"),
                "status_command": agent.get("status_command"),
            })
    mission = {
        "id": mission_id,
        "created_at": int(time.time()),
        "updated_at": int(time.time()),
        "title": query[:90],
        "state": "planned",
        "lead_agent": selected,
        "collaborators": collaborators[:6],
        "steps": mission_steps_from_plan(plan, language),
        "source": "seven-ai",
        "privacy": "local-state-only",
    }
    items.insert(0, mission)
    missions["missions"] = items[:20]
    stored = write_missions(missions)
    collaborator_names = [str(item.get("name") or item.get("id")) for item in collaborators[1:4]]
    if language == "fr":
        summary = f"J’ai créé une mission locale « {mission['title']} » avec {selected.get('name', 'SevenAI')} comme agent principal."
        if collaborator_names:
            summary += " Collaborateurs : " + ", ".join(collaborator_names) + "."
        if not stored:
            summary = f"J’ai préparé la mission « {mission['title']} », mais je n’ai pas pu l’enregistrer car l’état utilisateur est en lecture seule."
    else:
        summary = f"I created local mission “{mission['title']}” with {selected.get('name', 'SevenAI')} as lead agent."
        if collaborator_names:
            summary += " Collaborators: " + ", ".join(collaborator_names) + "."
        if not stored:
            summary = f"I prepared mission “{mission['title']}”, but could not save it because user state is read-only."
    return {
        "applied": False,
        "summary": summary,
        "mission": mission,
        "stored": stored,
        "warnings": [] if stored else ["mission-state-read-only"],
        "recommendations": [
            ai_action_card("Voir mes missions" if language == "fr" else "Show my missions", "Ouvrir le tableau local des missions SevenAI." if language == "fr" else "Open the local SevenAI mission board.", "seven ai missions --json"),
            ai_action_card("Voir le contexte actif" if language == "fr" else "View active context", "Adapter les étapes à la fenêtre actuelle." if language == "fr" else "Adapt steps to the current window.", "seven ai 'quel est mon contexte actuel'"),
            ai_action_card("Prochaine action" if language == "fr" else "Next action", "Demander une recommandation immédiate." if language == "fr" else "Ask for an immediate recommendation.", "seven ai 'que dois-je faire maintenant'"),
        ],
    }


def mission_progress(mission: dict[str, Any]) -> dict[str, Any]:
    steps = mission.get("steps") if isinstance(mission.get("steps"), list) else []
    total = len([step for step in steps if isinstance(step, dict)])
    done = len([step for step in steps if isinstance(step, dict) and step.get("status") == "done"])
    next_step = next_step_for_mission(mission)
    percent = round((done / total) * 100) if total else 0
    collaborators = mission.get("collaborators") if isinstance(mission.get("collaborators"), list) else []
    return {
        "total_steps": total,
        "done_steps": done,
        "percent": percent,
        "next_step": next_step,
        "lead_agent": mission.get("lead_agent") if isinstance(mission.get("lead_agent"), dict) else {},
        "collaborators": collaborators,
        "state": mission.get("state") or "planned",
    }


def mission_status(language: str) -> dict[str, Any]:
    mission = latest_active_mission()
    if not mission:
        return {
            "applied": False,
            "summary": "Aucune mission active à suivre." if language == "fr" else "No active mission to track.",
            "chat": {
                "title": "Suivi de mission" if language == "fr" else "Mission tracking",
                "answer": (
                    "Je ne vois aucune mission active pour le moment. Donne-moi un objectif et je le transformerai en étapes SevenOS."
                    if language == "fr"
                    else "I do not see an active mission right now. Give me a goal and I will turn it into SevenOS steps."
                ),
                "bullets": [],
            },
            "mission": None,
            "progress": {"percent": 0, "done_steps": 0, "total_steps": 0},
            "recommendations": [ai_action_card(
                "Créer une mission" if language == "fr" else "Create mission",
                "Transformer un objectif en étapes suivies." if language == "fr" else "Turn an objective into tracked steps.",
                "seven ai 'crée une mission organiser mes documents'",
            )],
        }
    progress = mission_progress(mission)
    next_step = progress.get("next_step") if isinstance(progress.get("next_step"), dict) else None
    lead = progress.get("lead_agent") if isinstance(progress.get("lead_agent"), dict) else {}
    collaborators = progress.get("collaborators") if isinstance(progress.get("collaborators"), list) else []
    agent_labels = [str(item.get("profile") or item.get("id")) for item in collaborators[:5] if isinstance(item, dict)]
    if language == "fr":
        summary = (
            f"Mission « {mission.get('title')} » : {progress['percent']}% "
            f"({progress['done_steps']}/{progress['total_steps']} étapes)."
        )
        chat_answer = f"Tu es à {progress['percent']}% de la mission « {mission.get('title')} »."
        chat_bullets = [f"{progress['done_steps']}/{progress['total_steps']} étapes terminées."]
        if next_step:
            summary += f" Prochaine étape : {next_step.get('title')} dans {next_step.get('profile', lead.get('profile', 'equinox'))}."
            chat_bullets.append(f"Prochaine étape : {next_step.get('title')} dans {next_step.get('profile', lead.get('profile', 'equinox'))}.")
            detail = str(next_step.get("detail") or "").strip()
            if detail:
                chat_bullets.append(detail)
        if agent_labels:
            summary += " Agents : " + ", ".join(agent_labels) + "."
            chat_bullets.append("Agents actifs : " + ", ".join(agent_labels) + ".")
    else:
        summary = (
            f"Mission “{mission.get('title')}”: {progress['percent']}% "
            f"({progress['done_steps']}/{progress['total_steps']} steps)."
        )
        chat_answer = f"You are at {progress['percent']}% of mission “{mission.get('title')}”."
        chat_bullets = [f"{progress['done_steps']}/{progress['total_steps']} steps complete."]
        if next_step:
            summary += f" Next step: {next_step.get('title')} in {next_step.get('profile', lead.get('profile', 'equinox'))}."
            chat_bullets.append(f"Next step: {next_step.get('title')} in {next_step.get('profile', lead.get('profile', 'equinox'))}.")
            detail = str(next_step.get("detail") or "").strip()
            if detail:
                chat_bullets.append(detail)
        if agent_labels:
            summary += " Agents: " + ", ".join(agent_labels) + "."
            chat_bullets.append("Active agents: " + ", ".join(agent_labels) + ".")
    recommendations = [
        ai_action_card(
            "Continuer la mission" if language == "fr" else "Continue mission",
            next_step.get("title") if next_step else ("Mission complète" if language == "fr" else "Mission complete"),
            "seven ai missions next --json",
        )
    ]
    if next_step:
        profile = str(next_step.get("profile") or lead.get("profile") or "equinox")
        recommendations.append(ai_action_card(
            "Ouvrir l’espace conseillé" if language == "fr" else "Open suggested space",
            profile,
            f"seven profile activate {shlex.quote(profile)}",
        ))
    recommendations.append(ai_action_card(
        "Voir toutes les missions" if language == "fr" else "View all missions",
        "Tableau local SevenAI." if language == "fr" else "Local SevenAI board.",
        "seven ai missions --json",
    ))
    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Suivi de mission" if language == "fr" else "Mission tracking",
            "answer": chat_answer,
            "bullets": chat_bullets[:5],
        },
        "mission": mission,
        "progress": progress,
        "recommendations": recommendations[:4],
    }


def missions_board(language: str) -> dict[str, Any]:
    missions = read_missions()
    items = missions.get("missions") if isinstance(missions.get("missions"), list) else []
    active = [item for item in items if isinstance(item, dict) and item.get("state") in {"planned", "active"}]
    if active:
        latest_collaborators = active[0].get("collaborators") if isinstance(active[0].get("collaborators"), list) else []
        collaboration = ""
        if latest_collaborators:
            collaboration = (
                f" Agents : {', '.join(str(item.get('profile') or item.get('id')) for item in latest_collaborators[:4])}."
                if language == "fr"
                else f" Agents: {', '.join(str(item.get('profile') or item.get('id')) for item in latest_collaborators[:4])}."
            )
        summary = (
            f"{len(active)} mission(s) locale(s) suivie(s). La plus récente : {active[0].get('title', 'mission')}.{collaboration}"
            if language == "fr"
            else f"{len(active)} local mission(s) tracked. Latest: {active[0].get('title', 'mission')}.{collaboration}"
        )
    else:
        summary = (
            "Aucune mission locale suivie pour le moment. Tu peux dire : crée une mission ..."
            if language == "fr"
            else "No local mission is being tracked yet. You can say: create mission ..."
        )
    recommendations = [
        ai_action_card(
            "Créer une mission" if language == "fr" else "Create mission",
            "Préparer une suite d’étapes avec agent principal." if language == "fr" else "Prepare a step sequence with a lead agent.",
            "seven ai 'crée une mission organiser mes documents'",
        ),
        ai_action_card(
            "Router une demande" if language == "fr" else "Route a request",
            "Trouver l’agent SevenOS adapté." if language == "fr" else "Find the appropriate SevenOS agent.",
            "seven ai 'quel agent peut m’aider ici'",
        ),
    ]
    return {
        "applied": False,
        "summary": summary,
        "path": str(AI_MISSIONS_FILE),
        "missions": [
            {
                **mission,
                "progress": mission_progress(mission),
            }
            for mission in active[:10]
        ],
        "recommendations": recommendations,
    }


def latest_active_mission(data: dict[str, Any] | None = None) -> dict[str, Any] | None:
    missions = data or read_missions()
    items = missions.get("missions") if isinstance(missions.get("missions"), list) else []
    for item in items:
        if isinstance(item, dict) and item.get("state") in {"planned", "active"}:
            return item
    return None


def next_step_for_mission(mission: dict[str, Any]) -> dict[str, Any] | None:
    steps = mission.get("steps") if isinstance(mission.get("steps"), list) else []
    for step in steps:
        if isinstance(step, dict) and step.get("status") != "done":
            return step
    return None


def mission_next_step(language: str) -> dict[str, Any]:
    mission = latest_active_mission()
    if not mission:
        return {
            "applied": False,
            "summary": "Aucune mission active. Tu peux dire : crée une mission ..." if language == "fr" else "No active mission. You can say: create mission ...",
            "chat": {
                "title": "Continuer la mission" if language == "fr" else "Continue mission",
                "answer": (
                    "Je n’ai pas encore de mission active à reprendre. Donne-moi un objectif et je préparerai un parcours clair avec les bons espaces SevenOS."
                    if language == "fr"
                    else "I do not have an active mission to resume yet. Give me a goal and I will prepare a clear route with the right SevenOS spaces."
                ),
                "bullets": [],
            },
            "mission": None,
            "recommendations": [ai_action_card(
                "Créer une mission" if language == "fr" else "Create mission",
                "Créer un objectif suivi localement." if language == "fr" else "Create a locally tracked objective.",
                "seven ai 'crée une mission organiser mes documents'",
            )],
        }
    step = next_step_for_mission(mission)
    if not step:
        mission["state"] = "done"
        mission["updated_at"] = int(time.time())
        data = read_missions()
        for item in data.get("missions", []):
            if isinstance(item, dict) and item.get("id") == mission.get("id"):
                item.update(mission)
                break
        write_missions(data)
        return {
            "applied": False,
            "summary": f"La mission « {mission.get('title')} » est complète." if language == "fr" else f"Mission “{mission.get('title')}” is complete.",
            "chat": {
                "title": "Mission complète" if language == "fr" else "Mission complete",
                "answer": (
                    f"La mission « {mission.get('title')} » est complète. On peut ouvrir une nouvelle mission quand tu veux."
                    if language == "fr"
                    else f"Mission “{mission.get('title')}” is complete. We can open a new mission whenever you want."
                ),
                "bullets": [],
            },
            "mission": mission,
            "recommendations": [ai_action_card(
                "Créer une nouvelle mission" if language == "fr" else "Create a new mission",
                "Préparer un nouveau parcours SevenOS." if language == "fr" else "Prepare a new SevenOS route.",
                "seven ai 'crée une mission ...'",
            )],
        }
    lead = mission.get("lead_agent") if isinstance(mission.get("lead_agent"), dict) else {}
    profile = str(step.get("profile") or lead.get("profile") or "equinox")
    command = str(step.get("command") or lead.get("status_command") or "seven ai 'quel agent peut m’aider ici'")
    if language == "fr":
        summary = (
            f"Prochaine étape pour « {mission.get('title')} » : {step.get('title')}. "
            f"Espace conseillé : {profile}. {step.get('detail') or ''}".strip()
        )
        chat_answer = f"La prochaine étape est « {step.get('title')} »."
        chat_bullets = [
            f"Espace conseillé : {profile}.",
            str(step.get("detail") or "").strip(),
            "Je peux ouvrir cet espace ou marquer l’étape terminée quand tu l’auras faite.",
        ]
    else:
        summary = (
            f"Next step for “{mission.get('title')}”: {step.get('title')}. "
            f"Suggested space: {profile}. {step.get('detail') or ''}".strip()
        )
        chat_answer = f"The next step is “{step.get('title')}”."
        chat_bullets = [
            f"Suggested space: {profile}.",
            str(step.get("detail") or "").strip(),
            "I can open that space or mark the step complete when you finish it.",
        ]
    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Prochaine étape" if language == "fr" else "Next step",
            "answer": chat_answer,
            "bullets": [item for item in chat_bullets if item][:5],
        },
        "mission": mission,
        "progress": mission_progress(mission),
        "profile": profile,
        "command": f"seven profile activate {shlex.quote(profile)}",
        "step": step,
        "next_step": step,
        "recommendations": [
            ai_action_card("Ouvrir l’espace conseillé" if language == "fr" else "Open suggested space", profile, f"seven profile activate {shlex.quote(profile)}"),
            ai_action_card("Vérifier l’agent" if language == "fr" else "Check agent", lead.get("name") or profile, command),
            ai_action_card("Marquer l’étape terminée" if language == "fr" else "Mark step done", "Met à jour seulement la mémoire locale SevenAI." if language == "fr" else "Only updates local SevenAI memory.", "seven ai missions complete --json"),
        ],
    }


def complete_next_mission_step(language: str) -> dict[str, Any]:
    data = read_missions()
    mission = latest_active_mission(data)
    if not mission:
        return {
            "applied": False,
            "summary": "Aucune mission active à mettre à jour." if language == "fr" else "No active mission to update.",
            "mission": None,
            "recommendations": [],
        }
    step = next_step_for_mission(mission)
    if not step:
        mission["state"] = "done"
        mission["updated_at"] = int(time.time())
        write_missions(data)
        return {
            "applied": False,
            "summary": f"La mission « {mission.get('title')} » était déjà complète." if language == "fr" else f"Mission “{mission.get('title')}” was already complete.",
            "mission": mission,
            "recommendations": [],
        }
    step["status"] = "done"
    step["completed_at"] = int(time.time())
    mission["state"] = "active"
    mission["updated_at"] = int(time.time())
    remaining = next_step_for_mission(mission)
    if remaining is None:
        mission["state"] = "done"
    write_missions(data)
    if language == "fr":
        summary = f"Étape terminée : {step.get('title')}."
        if remaining:
            summary += f" Prochaine étape : {remaining.get('title')}."
        else:
            summary += f" La mission « {mission.get('title')} » est complète."
    else:
        summary = f"Step completed: {step.get('title')}."
        if remaining:
            summary += f" Next step: {remaining.get('title')}."
        else:
            summary += f" Mission “{mission.get('title')}” is complete."
    return {
        "applied": False,
        "summary": summary,
        "mission": mission,
        "completed_step": step,
        "next_step": remaining,
        "recommendations": [
            ai_action_card("Voir la prochaine étape" if language == "fr" else "View next step", "Continuer la mission." if language == "fr" else "Continue the mission.", "seven ai missions next --json")
        ] if remaining else [],
    }


def confirmation_contract(intent: Intent, *, language: str | None = None) -> dict[str, Any]:
    language = language or active_language()
    safety = intent.safety.upper()
    if safety == "ROOT":
        level = "critical"
        impact = "Installe ou modifie des paquets système." if language == "fr" else "Installs or changes system packages."
        next_step = "Vérifie la source et applique seulement si tu fais confiance au paquet." if language == "fr" else "Review the source and apply only if you trust the package."
    elif safety == "SYSTEM":
        level = "warning"
        impact = "Peut modifier la session, les services, le thème ou des processus." if language == "fr" else "May change the session, services, theme or processes."
        next_step = "Prévisualise d’abord, puis applique si le résultat est attendu." if language == "fr" else "Preview first, then apply if the result is expected."
    elif safety == "WEB":
        level = "notice"
        impact = "Peut nécessiter une recherche web explicite." if language == "fr" else "May require explicit web research."
        next_step = "Le web reste désactivé tant que tu ne l’actives pas." if language == "fr" else "Web stays disabled until you enable it."
    else:
        level = "safe"
        impact = "Lecture locale ou action sûre." if language == "fr" else "Local read or safe action."
        next_step = "Tu peux lancer l’aperçu sans changer l’état système." if language == "fr" else "You can run the preview without changing system state."
    return {
        "schema": "sevenos.ai.confirmation.v1",
        "level": level,
        "safety": intent.safety,
        "needs_apply": intent.needs_apply,
        "impact": impact,
        "next_step": next_step,
    }


def launch_attempt(command: list[str], *, method: str, apply: bool) -> dict[str, Any]:
    result = run(command, apply=apply)
    result["method"] = method
    return result


def launch_app(app: AppEntry, *, apply: bool) -> dict[str, Any]:
    launcher = ROOT_DIR / "bin" / "seven-profile-launch"
    attempts: list[dict[str, Any]] = []
    try:
        command_parts = shlex.split(app.command)
    except ValueError:
        command_parts = ["sh", "-lc", app.command]

    if launcher.exists() and app.desktop_id:
        attempts.append(launch_attempt([str(launcher), app.desktop_id, "--", *command_parts], method="seven-profile-launch", apply=apply))
        if attempts[-1].get("returncode") == 0 and (DRY_RUN or apply):
            return {**attempts[-1], "attempts": attempts}
    if shutil.which("gtk-launch") and app.desktop_id:
        desktop_id = app.desktop_id.removesuffix(".desktop")
        attempts.append(launch_attempt(["gtk-launch", desktop_id], method="gtk-launch", apply=apply))
        if attempts[-1].get("returncode") == 0 and (DRY_RUN or apply):
            return {**attempts[-1], "attempts": attempts}
    if shutil.which("hyprctl"):
        attempts.append(launch_attempt(["hyprctl", "dispatch", "exec", app.command], method="hyprctl", apply=apply))
        if attempts[-1].get("returncode") == 0 and (DRY_RUN or apply):
            return {**attempts[-1], "attempts": attempts}
    attempts.append(launch_attempt(["sh", "-lc", f"setsid -f {app.command} >/dev/null 2>&1"], method="setsid", apply=apply))
    if attempts[-1].get("returncode") == 0 and (DRY_RUN or apply):
        return {**attempts[-1], "attempts": attempts}
    return {
        "applied": apply and not DRY_RUN,
        "dry_run": DRY_RUN,
        "method": "none",
        "command": attempts[-1].get("command", app.command) if attempts else app.command,
        "returncode": attempts[-1].get("returncode", 1) if attempts else 1,
        "stdout": attempts[-1].get("stdout", "") if attempts else "",
        "stderr": attempts[-1].get("stderr", "No launch method available.") if attempts else "No launch method available.",
        "attempts": attempts,
    }


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


def bytes_to_gib(value: int | float) -> float:
    return round(float(value) / 1024**3, 1)


def lsblk_devices() -> list[dict[str, Any]]:
    if not shutil.which("lsblk"):
        return []
    result = subprocess.run(
        ["lsblk", "-b", "-J", "-o", "NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,LABEL,MODEL"],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []

    devices: list[dict[str, Any]] = []

    def walk(items: list[dict[str, Any]], parent: str = "") -> None:
        for item in items:
            name = str(item.get("name") or "")
            size = int(item.get("size") or 0)
            mountpoints = [mp for mp in item.get("mountpoints") or [] if mp]
            entry = {
                "name": name,
                "parent": parent,
                "type": item.get("type") or "",
                "size_gb": bytes_to_gib(size) if size else 0,
                "filesystem": item.get("fstype") or "",
                "mountpoints": mountpoints,
                "label": item.get("label") or "",
                "model": item.get("model") or "",
            }
            devices.append(entry)
            children = item.get("children") or []
            if isinstance(children, list):
                walk(children, name)

    walk(payload.get("blockdevices") or [])
    return devices


def battery_status() -> dict[str, Any]:
    supplies = list(Path("/sys/class/power_supply").glob("BAT*"))
    if not supplies:
        return {"present": False}
    battery = supplies[0]
    try:
        capacity = int((battery / "capacity").read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        capacity = None
    try:
        status = (battery / "status").read_text(encoding="utf-8").strip()
    except OSError:
        status = "unknown"
    return {"present": True, "capacity": capacity, "status": status}


def cpu_summary() -> dict[str, Any]:
    model = ""
    cores = os.cpu_count() or 0
    try:
        for line in Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.lower().startswith("model name"):
                model = line.split(":", 1)[1].strip()
                break
    except OSError:
        pass
    return {"model": model or "unknown", "logical_cores": cores, "load": system_context()["load"]}


def active_windows(limit: int = 12) -> list[dict[str, Any]]:
    if not shutil.which("hyprctl"):
        return []
    try:
        result = subprocess.run(["hyprctl", "clients", "-j"], text=True, capture_output=True, check=False, timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        return []
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        clients = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    windows: list[dict[str, Any]] = []
    for client in clients if isinstance(clients, list) else []:
        if not isinstance(client, dict):
            continue
        workspace = client.get("workspace") if isinstance(client.get("workspace"), dict) else {}
        title = str(client.get("title") or "").strip()
        app_class = str(client.get("class") or "").strip()
        if not title and not app_class:
            continue
        windows.append({
            "class": app_class,
            "title": title,
            "workspace": workspace.get("id"),
            "floating": bool(client.get("floating")),
            "mapped": bool(client.get("mapped", True)),
        })
    return windows[:limit]


def machine_snapshot() -> dict[str, Any]:
    diag = diagnostics("system")
    home_usage = shutil.disk_usage(str(Path.home()))
    root_usage = shutil.disk_usage("/")
    return {
        "schema": "sevenos.ai.machine-snapshot.v1",
        "disk": {
            "home": {
                "path": str(Path.home()),
                "total_gb": bytes_to_gib(home_usage.total),
                "used_gb": bytes_to_gib(home_usage.used),
                "free_gb": bytes_to_gib(home_usage.free),
                "used_percent": round(home_usage.used / home_usage.total * 100, 1) if home_usage.total else 0,
            },
            "root": {
                "path": "/",
                "total_gb": bytes_to_gib(root_usage.total),
                "used_gb": bytes_to_gib(root_usage.used),
                "free_gb": bytes_to_gib(root_usage.free),
                "used_percent": round(root_usage.used / root_usage.total * 100, 1) if root_usage.total else 0,
            },
            "devices": lsblk_devices(),
        },
        "memory": diag["memory"],
        "cpu": cpu_summary(),
        "battery": battery_status(),
        "network": diag["network"],
        "windows": active_windows(),
        "top_processes": diag.get("top_processes", []),
        "failed_units": diag["failed_units"],
    }


def compact_machine_snapshot(snapshot: dict[str, Any]) -> dict[str, Any]:
    disk = snapshot.get("disk") if isinstance(snapshot.get("disk"), dict) else {}
    devices = disk.get("devices") if isinstance(disk.get("devices"), list) else []
    mounted = [
        {
            "name": item.get("name"),
            "size_gb": item.get("size_gb"),
            "filesystem": item.get("filesystem"),
            "mountpoints": item.get("mountpoints", [])[:2] if isinstance(item.get("mountpoints"), list) else [],
        }
        for item in devices
        if isinstance(item, dict) and item.get("mountpoints")
    ][:6]
    windows = snapshot.get("windows") if isinstance(snapshot.get("windows"), list) else []
    top_processes = snapshot.get("top_processes") if isinstance(snapshot.get("top_processes"), list) else []
    return {
        "schema": "sevenos.ai.machine-compact.v1",
        "disk": {
            "home": disk.get("home", {}),
            "root": disk.get("root", {}),
            "mounted": mounted,
            "device_count": len(devices),
        },
        "memory": snapshot.get("memory", {}),
        "cpu": {
            "model": (snapshot.get("cpu") or {}).get("model") if isinstance(snapshot.get("cpu"), dict) else "",
            "logical_cores": (snapshot.get("cpu") or {}).get("logical_cores") if isinstance(snapshot.get("cpu"), dict) else 0,
            "load": (snapshot.get("cpu") or {}).get("load", {}) if isinstance(snapshot.get("cpu"), dict) else {},
        },
        "battery": snapshot.get("battery", {}),
        "network": snapshot.get("network", {}),
        "windows": windows[:5],
        "top_processes": top_processes[:5],
        "failed_units": (snapshot.get("failed_units") or [])[:5] if isinstance(snapshot.get("failed_units"), list) else [],
    }


def compact_answer_details(topic: str, details: Any) -> Any:
    if topic == "health" and isinstance(details, dict):
        brain = details.get("brain") if isinstance(details.get("brain"), dict) else {}
        issues = details.get("issues") if isinstance(details.get("issues"), list) else []
        contracts = brain.get("contracts") if isinstance(brain.get("contracts"), dict) else {}
        compact_contracts = {
            key: value for key, value in contracts.items()
            if key in {"health", "security", "updates", "theme", "profile"}
        }
        return {
            "state": brain.get("state"),
            "score": brain.get("score"),
            "issues": issues[:6],
            "contracts": compact_contracts,
        }
    if topic == "processes" and isinstance(details, list):
        return details[:8]
    if topic == "apps" and isinstance(details, list):
        return details[:8]
    if topic == "services" and isinstance(details, list):
        return details[:8]
    if topic == "footprint" and isinstance(details, dict):
        return {
            "state": details.get("state"),
            "score": details.get("score"),
            "summary": details.get("summary", {}),
            "cleanup_summary": details.get("cleanup_summary", {}),
            "cleanup_plan": details.get("cleanup_plan", [])[:5] if isinstance(details.get("cleanup_plan"), list) else [],
            "checks": details.get("checks", [])[:5] if isinstance(details.get("checks"), list) else [],
            "evidence": details.get("evidence", {}),
            "policy": details.get("policy", "read-only"),
        }
    return details


def ai_action_card(title: str, detail: str, command: str, *, risk: str = "low", apply: bool = False) -> dict[str, Any]:
    return {
        "title": title,
        "detail": detail,
        "command": command,
        "risk": risk,
        "apply": apply,
    }


def human_issue_label(value: object, language: str) -> str:
    text = str(value or "").strip()
    normalized = normalize(text)
    fr_map = {
        "health needs attention": "La santé système demande attention.",
        "security needs attention": "La sécurité demande attention.",
        "storage needs attention": "Le stockage demande attention.",
        "updates need attention": "Les mises à jour demandent attention.",
        "public quality needs attention": "La qualité publique demande attention.",
        "home storage is getting full": "L’espace personnel se remplit.",
        "sevenai local memory is not writable": "La mémoire locale SevenAI n’est pas inscriptible.",
        "failed systemd units detected": "Des services systemd sont en erreur.",
    }
    en_map = {
        "health needs attention": "System health needs attention.",
        "security needs attention": "Security needs attention.",
        "storage needs attention": "Storage needs attention.",
        "updates need attention": "Updates need attention.",
        "public quality needs attention": "Public quality needs attention.",
        "home storage is getting full": "Home storage is getting full.",
        "sevenai local memory is not writable": "SevenAI local memory is not writable.",
        "failed systemd units detected": "Failed systemd units detected.",
    }
    return (fr_map if language == "fr" else en_map).get(normalized, text)


def read_preferences() -> dict[str, Any]:
    fallback = {"schema": "sevenos.ai-preferences.v1", "preferences": []}
    try:
        data = json.loads(AI_PREFERENCES_FILE.read_text(encoding="utf-8"))
    except Exception:
        return fallback
    if not isinstance(data, dict):
        return fallback
    prefs = data.get("preferences")
    if not isinstance(prefs, list):
        data["preferences"] = []
    else:
        for item in prefs:
            if isinstance(item, dict):
                item["category"] = preference_category(str(item.get("value") or ""))
    data.setdefault("schema", "sevenos.ai-preferences.v1")
    return data


def write_preferences(data: dict[str, Any]) -> None:
    AI_STATE_DIR.mkdir(parents=True, exist_ok=True)
    data["updated_at"] = int(time.time())
    AI_PREFERENCES_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def try_write_preferences(data: dict[str, Any]) -> bool:
    try:
        write_preferences(data)
        return True
    except OSError:
        return False


def ai_state_health(language: str | None = None) -> dict[str, Any]:
    language = language or active_language()
    directory = AI_STATE_DIR
    writable = False
    write_error = ""
    try:
        directory.mkdir(parents=True, exist_ok=True)
        probe = directory / f".write-test-{os.getpid()}"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink(missing_ok=True)
        writable = True
    except OSError as exc:
        write_error = str(exc)
    files = {
        "missions": {"path": str(AI_MISSIONS_FILE), "exists": AI_MISSIONS_FILE.exists()},
        "preferences": {"path": str(AI_PREFERENCES_FILE), "exists": AI_PREFERENCES_FILE.exists()},
        "sqlite": {"path": str(db_path()), "exists": db_path().exists()},
    }
    if language == "fr":
        summary = (
            "La mémoire locale SevenAI est inscriptible."
            if writable
            else "La mémoire locale SevenAI est en lecture seule ou inaccessible."
        )
        answer = summary
        bullets = [
            f"Dossier : {directory}",
            "Missions, préférences et historique utilisent cet emplacement.",
            "Les réponses restent disponibles même si l’écriture est bloquée.",
        ]
    else:
        summary = (
            "SevenAI local memory is writable."
            if writable
            else "SevenAI local memory is read-only or inaccessible."
        )
        answer = summary
        bullets = [
            f"Directory: {directory}",
            "Missions, preferences and history use this location.",
            "Answers remain available even when writes are blocked.",
        ]
    return {
        "schema": "sevenos.ai.state-health.v1",
        "state": "ready" if writable else "read-only",
        "writable": writable,
        "summary": summary,
        "chat": {
            "title": "Mémoire SevenAI" if language == "fr" else "SevenAI memory",
            "answer": answer,
            "bullets": bullets,
        },
        "directory": str(directory),
        "files": files,
        "error": write_error,
        "recommendations": [
            ai_action_card(
                "Vérifier la mémoire SevenAI" if language == "fr" else "Check SevenAI memory",
                "Afficher l’état local utilisé par les missions, préférences et historique." if language == "fr" else "Show local state used by missions, preferences and history.",
                "seven ai state --json",
                risk="low",
            )
        ],
    }


def sevenai_capabilities(language: str | None = None) -> dict[str, Any]:
    language = language or active_language()
    if language == "fr":
        summary = (
            "Je peux t’aider à comprendre SevenOS, ouvrir des apps, diagnostiquer la machine, "
            "chercher localement, suivre tes missions et préparer des actions système avec confirmation."
        )
        bullets = [
            "Réponses système : état machine, disque, réseau, batterie, thème, profil actif.",
            "Actions rapides : ouvrir des apps, afficher les réglages, retrouver des fichiers indexés.",
            "Actions sensibles : fermeture d’apps, installations, services et changements système avec aperçu ou confirmation.",
            "Mémoire locale : préférences explicites, missions et habitudes, avec état vérifiable.",
            "Limite saine : je ne modifie pas le système en profondeur sans contrat SevenOS et garde-fou.",
        ]
        capabilities = [
            {
                "title": "Ouvrir des applications",
                "detail": "Je peux résoudre les alias humains comme « paramètres », « fichiers » ou « navigateur ».",
                "example": 'seven ai "ouvre les paramètres"',
                "safety": "SAFE",
            },
            {
                "title": "Répondre sur la machine",
                "detail": "Je peux lire les contrats locaux pour expliquer stockage, mémoire, réseau et état système.",
                "example": 'seven ai "quelle est la taille de mon disque"',
                "safety": "SAFE",
            },
            {
                "title": "Chercher localement",
                "detail": "Je peux interroger l’index local approuvé sans envoyer tes fichiers en ligne.",
                "example": 'seven ai "cherche budget dans mes fichiers"',
                "safety": "SAFE",
            },
            {
                "title": "Préparer des missions",
                "detail": "Je peux transformer une intention large en étapes Forge, Studio, Atlas, Baobab, Shield ou Pulse.",
                "example": 'seven ai "crée une mission organiser mes documents"',
                "safety": "SAFE",
            },
            {
                "title": "Gérer avec garde-fous",
                "detail": "Je peux prévisualiser une action système et demander confirmation avant d’agir.",
                "example": 'seven ai "ferme firefox"',
                "safety": "CONFIRM",
            },
        ]
        limits = [
            "Les actions root, destructives ou ambiguës restent bloquées ou demandent confirmation.",
            "La lecture du contenu complet des documents reste opt-in.",
            "Le modèle local peut aider au raisonnement, mais l’exécution passe par les contrats SevenOS.",
        ]
        recommendations = [
            ai_action_card("État machine", "Voir la santé rapide de SevenOS.", 'seven ai "quel est l’état de ma machine"', risk="low"),
            ai_action_card("Mémoire SevenAI", "Vérifier si missions et préférences peuvent être enregistrées.", "seven ai state --json", risk="low"),
            ai_action_card("Politique d’exécution", "Comprendre ce que SevenAI applique, confirme ou bloque.", "seven ai execution --json", risk="low"),
        ]
        title = "Ce que je peux faire"
    else:
        summary = (
            "I can help you understand SevenOS, open apps, diagnose the machine, search locally, "
            "track missions and prepare system actions with confirmation."
        )
        bullets = [
            "System answers: machine state, disk, network, battery, theme and active profile.",
            "Quick actions: open apps, show settings, find approved local indexed files.",
            "Sensitive actions: closing apps, installs, services and system changes with preview or confirmation.",
            "Local memory: explicit preferences, missions and habits, with a verifiable state.",
            "Healthy limit: I do not deeply change the system without a SevenOS contract and guardrail.",
        ]
        capabilities = [
            {
                "title": "Open applications",
                "detail": "I can resolve human aliases like settings, files or browser.",
                "example": 'seven ai "open settings"',
                "safety": "SAFE",
            },
            {
                "title": "Answer about the machine",
                "detail": "I can read local contracts to explain storage, memory, network and system state.",
                "example": 'seven ai "how big is my disk"',
                "safety": "SAFE",
            },
            {
                "title": "Search locally",
                "detail": "I can query the approved local index without sending your files online.",
                "example": 'seven ai "search budget in my files"',
                "safety": "SAFE",
            },
            {
                "title": "Prepare missions",
                "detail": "I can turn broad intent into Forge, Studio, Atlas, Baobab, Shield or Pulse steps.",
                "example": 'seven ai "create a mission organize my documents"',
                "safety": "SAFE",
            },
            {
                "title": "Manage with guardrails",
                "detail": "I can preview a system action and ask for confirmation before acting.",
                "example": 'seven ai "close firefox"',
                "safety": "CONFIRM",
            },
        ]
        limits = [
            "Root, destructive or ambiguous actions stay blocked or require confirmation.",
            "Full document-content reading stays opt-in.",
            "The local model can help reasoning, but execution goes through SevenOS contracts.",
        ]
        recommendations = [
            ai_action_card("Machine state", "Show SevenOS quick health.", 'seven ai "what is my machine state"', risk="low"),
            ai_action_card("SevenAI memory", "Check whether missions and preferences can be saved.", "seven ai state --json", risk="low"),
            ai_action_card("Execution policy", "Understand what SevenAI applies, confirms or blocks.", "seven ai execution --json", risk="low"),
        ]
        title = "What I can do"
    return {
        "schema": "sevenos.ai.capabilities.v1",
        "applied": False,
        "state": "ready",
        "summary": summary,
        "chat": {
            "title": title,
            "answer": summary,
            "bullets": bullets,
        },
        "capabilities": capabilities,
        "limits": limits,
        "surfaces": ["Spotlight", "Terminal", "Settings", "Doctor", "Files", "Widgets"],
        "recommendations": recommendations,
    }


def preference_category(text: str) -> str:
    raw = normalize(text)
    if any(token in raw for token in ("ai", "sevenai", "agent", "réponse", "reponse", "réponses", "reponses", "confirmation")):
        return "assistant"
    if any(token in raw for token in ("theme", "thème", "sombre", "dark", "light", "clair", "apparence")):
        return "appearance"
    if any(token in raw for token in ("dock", "widgets", "workspace", "espace", "fenêtre", "fenetre", "layout")):
        return "interface"
    if any(token in raw for token in ("terminal", "kitty", "bash", "shell")):
        return "terminal"
    if any(token in raw for token in ("forge", "studio", "shield", "atlas", "baobab", "pulse", "mini os")):
        return "mini-os"
    return "general"


def remember_preference(text: str, language: str) -> dict[str, Any]:
    value = text.strip()
    value = re.sub(
        r"^(?:souviens[- ]toi que|souviens toi que|retient que|retiens que|memorise que|mémorise que|remember that|remember i|remember my)\s+",
        "",
        value,
        flags=re.IGNORECASE,
    ).strip()
    if not value:
        return {
            "applied": False,
            "summary": "Je n’ai pas trouvé la préférence à mémoriser." if language == "fr" else "I did not find a preference to remember.",
            "preferences": read_preferences().get("preferences", []),
            "recommendations": [],
        }
    data = read_preferences()
    prefs = data.get("preferences") if isinstance(data.get("preferences"), list) else []
    normalized_value = normalize(value)
    existing = next((item for item in prefs if isinstance(item, dict) and normalize(str(item.get("value") or "")) == normalized_value), None)
    now = int(time.time())
    if existing:
        existing["updated_at"] = now
        existing["count"] = int(existing.get("count") or 1) + 1
        existing["category"] = existing.get("category") or preference_category(value)
    else:
        prefs.insert(0, {
            "id": f"pref-{now}",
            "value": value,
            "category": preference_category(value),
            "source": "explicit-user",
            "created_at": now,
            "updated_at": now,
            "count": 1,
        })
    data["preferences"] = prefs[:80]
    stored = try_write_preferences(data)
    if stored:
        summary = (
            f"C’est noté : {value}. Je l’utiliserai comme préférence locale SevenAI."
            if language == "fr"
            else f"Noted: {value}. I will use it as a local SevenAI preference."
        )
    else:
        summary = (
            f"J’ai compris la préférence « {value} », mais je n’ai pas pu l’enregistrer car la mémoire SevenAI est en lecture seule."
            if language == "fr"
            else f"I understood preference “{value}”, but could not save it because SevenAI memory is read-only."
        )
    return {
        "applied": stored,
        "summary": summary,
        "path": str(AI_PREFERENCES_FILE),
        "stored": stored,
        "warnings": [] if stored else ["preferences-state-read-only"],
        "preference": existing or data["preferences"][0],
        "preferences": data["preferences"][:10],
        "recommendations": [
            ai_action_card(
                "Voir mes préférences" if language == "fr" else "View my preferences",
                "Afficher la mémoire explicite locale SevenAI." if language == "fr" else "Show the explicit local SevenAI memory.",
                "seven ai preferences --json",
            ),
            ai_action_card(
                "Diagnostiquer la mémoire SevenAI" if language == "fr" else "Diagnose SevenAI memory",
                "Vérifier pourquoi les préférences ne peuvent pas être écrites." if language == "fr" else "Check why preferences cannot be written.",
                "seven ai state --json",
            ),
        ],
    }


def preferences_summary(language: str) -> dict[str, Any]:
    data = read_preferences()
    prefs = [item for item in data.get("preferences", []) if isinstance(item, dict)]
    by_category: dict[str, int] = {}
    for item in prefs:
        category = str(item.get("category") or "general")
        by_category[category] = by_category.get(category, 0) + 1
    if prefs:
        lead = prefs[0].get("value", "")
        summary = (
            f"J’ai {len(prefs)} préférence(s) explicite(s). La plus récente : {lead}."
            if language == "fr"
            else f"I have {len(prefs)} explicit preference(s). Latest: {lead}."
        )
    else:
        summary = (
            "Je n’ai pas encore de préférence explicite mémorisée."
            if language == "fr"
            else "I do not have explicit remembered preferences yet."
        )
    return {
        "applied": False,
        "summary": summary,
        "path": str(AI_PREFERENCES_FILE),
        "count": len(prefs),
        "categories": by_category,
        "preferences": prefs[:20],
        "recommendations": [
            ai_action_card(
                "Ajouter une préférence" if language == "fr" else "Add preference",
                "Exemple : souviens-toi que je préfère les réponses courtes." if language == "fr" else "Example: remember that I prefer short answers.",
                "seven ai 'souviens-toi que je préfère les réponses courtes'",
            )
        ],
    }


def memory_profile_answer(language: str) -> dict[str, Any]:
    prefs = preferences_summary(language)
    memory = read_memory(8)
    learning = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "--json"],
        {"schema": "sevenos.ai-learning.v1", "state": "unknown", "config": {}, "index": {}, "habits": {}, "privacy": {}},
        timeout=2.0,
    )
    config = learning.get("config") if isinstance(learning.get("config"), dict) else {}
    index = learning.get("index") if isinstance(learning.get("index"), dict) else {}
    habits = learning.get("habits") if isinstance(learning.get("habits"), dict) else {}
    privacy = learning.get("privacy") if isinstance(learning.get("privacy"), dict) else {}
    sources = config.get("sources") if isinstance(config.get("sources"), list) else []
    docs = int(index.get("documents") or 0)
    habit_events = int((memory.get("health") or {}).get("total_events") or habits.get("events") or 0)
    pref_count = int(prefs.get("count") or 0)
    content_mode = str(config.get("content_mode") or privacy.get("default_content_mode") or "metadata")
    learning_enabled = bool(config.get("enabled"))

    if language == "fr":
        answer = (
            f"Je connais surtout des préférences explicites ({pref_count}), "
            f"un index local approuvé ({docs} élément(s)) et des habitudes d’usage locales ({habit_events} événement(s))."
        )
        bullets = [
            f"Apprentissage local : {'activé' if learning_enabled else 'désactivé'} · mode {content_mode}.",
            f"Sources approuvées : {len(sources)} dossier(s).",
            "Par défaut je n’indexe que des métadonnées; les extraits de contenu demandent un scan explicite.",
            "Je n’envoie pas cette mémoire au cloud et je ne lis pas mots de passe, clés privées ou données non approuvées.",
        ]
        if pref_count:
            latest = (prefs.get("preferences") or [{}])[0]
            if isinstance(latest, dict):
                bullets.insert(0, f"Préférence récente : {latest.get('value', '')}")
        recommendations = [
            ai_action_card("Voir les sources", "Afficher les dossiers approuvés pour l’index local.", "seven ai learning sources --json"),
            ai_action_card("Scanner les métadonnées", "Rafraîchir l’index local sans lire le contenu complet.", "seven ai learning scan --json"),
            ai_action_card("Voir mes préférences", "Afficher la mémoire explicite locale.", "seven ai preferences --json"),
            ai_action_card("Désactiver l’apprentissage", "Stopper les scans futurs de sources approuvées.", "seven ai learning disable --json", risk="low"),
        ]
        title = "Mémoire SevenAI"
        summary = f"Mémoire SevenAI : {pref_count} préférence(s), {docs} élément(s) indexés, {habit_events} événement(s) locaux."
    else:
        answer = (
            f"I mostly know explicit preferences ({pref_count}), "
            f"an approved local index ({docs} item(s)) and local usage habits ({habit_events} event(s))."
        )
        bullets = [
            f"Local learning: {'enabled' if learning_enabled else 'disabled'} · mode {content_mode}.",
            f"Approved sources: {len(sources)} folder(s).",
            "By default I index metadata only; content snippets require an explicit scan.",
            "I do not send this memory to cloud and I do not read passwords, private keys or unapproved data.",
        ]
        if pref_count:
            latest = (prefs.get("preferences") or [{}])[0]
            if isinstance(latest, dict):
                bullets.insert(0, f"Recent preference: {latest.get('value', '')}")
        recommendations = [
            ai_action_card("Show sources", "Display folders approved for local indexing.", "seven ai learning sources --json"),
            ai_action_card("Scan metadata", "Refresh the local index without reading full content.", "seven ai learning scan --json"),
            ai_action_card("Show preferences", "Display explicit local memory.", "seven ai preferences --json"),
            ai_action_card("Disable learning", "Stop future scans of approved sources.", "seven ai learning disable --json", risk="low"),
        ]
        title = "SevenAI memory"
        summary = f"SevenAI memory: {pref_count} preference(s), {docs} indexed item(s), {habit_events} local event(s)."

    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": title,
            "answer": answer,
            "bullets": [item for item in bullets if str(item).strip()][:5],
        },
        "preferences": {
            "count": pref_count,
            "categories": prefs.get("categories", {}),
            "latest": (prefs.get("preferences") or [{}])[0] if prefs.get("preferences") else {},
        },
        "learning": {
            "state": learning.get("state"),
            "enabled": learning_enabled,
            "documents": docs,
            "content_mode": content_mode,
            "sources": sources[:8],
            "privacy": privacy,
        },
        "habits": {
            "events": habit_events,
            "top_intents": (memory.get("summary") or {}).get("top_intents", [])[:5],
        },
        "recommendations": recommendations,
    }


def learning_control(action: str, *, apply: bool, language: str) -> dict[str, Any]:
    action = action.strip().lower()
    commands: dict[str, list[str]] = {
        "status": ["learning", "--json"],
        "enable": ["learning", "enable", "--json"],
        "disable": ["learning", "disable", "--json"],
        "scan": ["learning", "scan", "--json"],
        "scan_content": ["learning", "scan", "--content", "--json"],
        "clear_index": ["learning", "clear-index", "--json"],
        "clear_snippets": ["learning", "clear-snippets", "--json"],
    }
    labels_fr = {
        "status": "État de l’apprentissage local",
        "enable": "Activer l’apprentissage local",
        "disable": "Désactiver l’apprentissage local",
        "scan": "Scanner les métadonnées approuvées",
        "scan_content": "Scanner avec extraits locaux",
        "clear_index": "Effacer l’index local",
        "clear_snippets": "Effacer les extraits locaux",
    }
    labels_en = {
        "status": "Local learning status",
        "enable": "Enable local learning",
        "disable": "Disable local learning",
        "scan": "Scan approved metadata",
        "scan_content": "Scan with local snippets",
        "clear_index": "Clear local index",
        "clear_snippets": "Clear local snippets",
    }
    confirm_phrases_fr = {
        "enable": "active ton apprentissage",
        "disable": "désactive ton apprentissage",
        "scan": "scanne mes documents",
        "scan_content": "scanne avec extraits",
        "clear_index": "efface ton index local",
        "clear_snippets": "efface les extraits locaux",
    }
    confirm_phrases_en = {
        "enable": "enable local learning",
        "disable": "disable local learning",
        "scan": "scan my documents",
        "scan_content": "scan with snippets",
        "clear_index": "clear local index",
        "clear_snippets": "clear local snippets",
    }
    if action not in commands:
        action = "status"
    label = (labels_fr if language == "fr" else labels_en).get(action, action)
    status = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "--json"],
        {"schema": "sevenos.ai-learning.v1", "state": "unknown", "config": {}, "index": {}, "habits": {}, "privacy": {}},
        timeout=2.5,
    )
    config = status.get("config") if isinstance(status.get("config"), dict) else {}
    index = status.get("index") if isinstance(status.get("index"), dict) else {}
    habits = status.get("habits") if isinstance(status.get("habits"), dict) else {}
    sources = config.get("sources") if isinstance(config.get("sources"), list) else []
    enabled = bool(config.get("enabled"))
    documents = int(index.get("documents") or 0)
    content_mode = str(config.get("content_mode") or "metadata")
    base_command = "seven ai " + " ".join(shlex.quote(part) for part in commands[action])

    if action == "status":
        if language == "fr":
            answer = (
                f"Apprentissage local {'activé' if enabled else 'désactivé'} : "
                f"{documents} élément(s) indexés, {len(sources)} source(s) approuvée(s), mode {content_mode}."
            )
            bullets = [
                "Le scan par défaut reste metadata-only.",
                "Les extraits de contenu demandent une confirmation séparée.",
                f"Habitudes locales : {int(habits.get('events') or 0)} événement(s).",
            ]
            recommendations = [
                ai_action_card("Scanner les documents", "Rafraîchir l’index local metadata-only.", "seven ai \"scanne mes documents\" --apply --json"),
                ai_action_card("Activer les extraits", "Scanner les sources approuvées avec de courts extraits.", "seven ai \"scanne avec extraits\" --apply --json", risk="low"),
                ai_action_card("Voir la mémoire", "Comprendre ce que SevenAI sait localement.", "seven ai \"ce que tu sais de moi\""),
            ]
        else:
            answer = (
                f"Local learning is {'enabled' if enabled else 'disabled'}: "
                f"{documents} indexed item(s), {len(sources)} approved source(s), {content_mode} mode."
            )
            bullets = [
                "The default scan remains metadata-only.",
                "Content snippets require a separate confirmation.",
                f"Local habits: {int(habits.get('events') or 0)} event(s).",
            ]
            recommendations = [
                ai_action_card("Scan documents", "Refresh the metadata-only local index.", "seven ai \"scan my documents\" --apply --json"),
                ai_action_card("Enable snippets", "Scan approved sources with short snippets.", "seven ai \"scan with snippets\" --apply --json", risk="low"),
                ai_action_card("Show memory", "Understand what SevenAI knows locally.", "seven ai \"what do you know about me\""),
            ]
        return {
            "applied": False,
            "state": status.get("state", "unknown"),
            "summary": answer,
            "chat": {"title": label, "answer": answer, "bullets": bullets},
            "learning": {"enabled": enabled, "documents": documents, "sources": sources[:8], "content_mode": content_mode},
            "recommendations": recommendations,
            "privacy": "local-only; metadata by default; content snippets require explicit confirmation",
        }

    if not apply:
        if language == "fr":
            if action == "scan_content":
                answer = "Je peux scanner les sources approuvées avec de courts extraits, mais seulement après confirmation."
                bullets = [
                    "Cela lit le contenu de fichiers texte approuvés pour créer de courts extraits locaux.",
                    "Aucune donnée n’est envoyée en ligne.",
                    "Tu peux confirmer avec --apply si c’est bien ce que tu veux.",
                ]
            elif action == "clear_index":
                answer = "Je peux effacer l’index local SevenAI, mais seulement après confirmation."
                bullets = [
                    f"Cela retirera {documents} élément(s) indexé(s) de la mémoire de recherche locale.",
                    "Les fichiers originaux ne sont pas supprimés.",
                    "Les sources approuvées restent configurées pour un futur scan.",
                ]
            elif action == "clear_snippets":
                answer = "Je peux effacer uniquement les extraits locaux tout en gardant les métadonnées."
                bullets = [
                    "Les noms, chemins et dates des fichiers restent disponibles.",
                    "Les courts extraits de contenu seront vidés.",
                    "Les fichiers originaux ne sont pas modifiés.",
                ]
            elif action == "scan":
                answer = "Je peux rafraîchir l’index local en mode métadonnées, sans lire le contenu complet."
                bullets = [
                    f"Sources approuvées : {len(sources)}.",
                    "Le scan reste local et metadata-only.",
                    "Confirme avec --apply pour le lancer.",
                ]
            elif action == "enable":
                answer = "Je peux activer l’apprentissage local pour les sources approuvées."
                bullets = [
                    "SevenAI n’indexera que les dossiers explicitement approuvés.",
                    "Le contenu complet reste désactivé par défaut.",
                    "Confirme avec --apply pour modifier le réglage.",
                ]
            else:
                answer = "Je peux désactiver l’apprentissage local et arrêter les scans futurs."
                bullets = [
                    "Les données déjà indexées restent locales.",
                    "Tu pourras réactiver l’apprentissage plus tard.",
                    "Confirme avec --apply pour modifier le réglage.",
                ]
            phrase = (confirm_phrases_fr if language == "fr" else confirm_phrases_en).get(action, label.lower())
            confirm_command = f"seven ai {shlex.quote(phrase)} --apply --json"
        else:
            if action == "scan_content":
                answer = "I can scan approved sources with short snippets, but only after confirmation."
                bullets = [
                    "This reads approved text files to create short local snippets.",
                    "No data is sent online.",
                    "Confirm with --apply if this is what you want.",
                ]
            elif action == "clear_index":
                answer = "I can clear the SevenAI local index, but only after confirmation."
                bullets = [
                    f"This will remove {documents} indexed item(s) from local search memory.",
                    "Original files are not deleted.",
                    "Approved sources remain configured for future scans.",
                ]
            elif action == "clear_snippets":
                answer = "I can clear only local snippets while keeping metadata."
                bullets = [
                    "File names, paths and dates remain available.",
                    "Short content snippets will be emptied.",
                    "Original files are not modified.",
                ]
            elif action == "scan":
                answer = "I can refresh the local metadata index without reading full content."
                bullets = [
                    f"Approved sources: {len(sources)}.",
                    "The scan stays local and metadata-only.",
                    "Confirm with --apply to run it.",
                ]
            elif action == "enable":
                answer = "I can enable local learning for approved sources."
                bullets = [
                    "SevenAI will only index explicitly approved folders.",
                    "Full content stays disabled by default.",
                    "Confirm with --apply to change the setting.",
                ]
            else:
                answer = "I can disable local learning and stop future scans."
                bullets = [
                    "Already indexed data remains local.",
                    "You can re-enable learning later.",
                    "Confirm with --apply to change the setting.",
                ]
            phrase = (confirm_phrases_fr if language == "fr" else confirm_phrases_en).get(action, label.lower())
            confirm_command = f"seven ai {shlex.quote(phrase)} --apply --json"
        return {
            "applied": False,
            "state": "preview",
            "summary": answer,
            "chat": {"title": label, "answer": answer, "bullets": bullets},
            "plan": {"command": base_command, "requires_confirmation": True, "action": action},
            "learning": {"enabled": enabled, "documents": documents, "sources": sources[:8], "content_mode": content_mode},
            "recommendations": [
                ai_action_card(
                    "Confirmer" if language == "fr" else "Confirm",
                    "Lancer cette action maintenant." if language == "fr" else "Run this action now.",
                    confirm_command,
                    risk="low",
                    apply=True,
                ),
                ai_action_card(
                    "Voir les sources" if language == "fr" else "Show sources",
                    "Afficher les dossiers approuvés." if language == "fr" else "Display approved folders.",
                    "seven ai learning sources --json",
                ),
            ],
            "privacy": "local-only; no cloud call; content snippets require explicit confirmation",
        }

    payload = run_json([str(ROOT_DIR / "scripts/ai.sh"), *commands[action]], {"state": "error", "error": "learning-command-failed"}, timeout=45.0)
    if language == "fr":
        if action == "enable":
            answer = "Apprentissage local activé pour les sources approuvées."
        elif action == "disable":
            answer = "Apprentissage local désactivé. SevenAI n’effectuera plus de scan automatique."
        elif action == "scan_content":
            answer = f"Scan avec extraits terminé : {int(payload.get('indexed') or payload.get('documents') or 0)} document(s) traités."
        elif action == "clear_index":
            answer = f"Index local effacé : {int(payload.get('cleared') or 0)} élément(s) retiré(s)."
        elif action == "clear_snippets":
            answer = f"Extraits locaux effacés : {int(payload.get('cleared') or 0)} élément(s) nettoyé(s)."
        else:
            answer = f"Scan metadata-only terminé : {int(payload.get('indexed') or payload.get('documents') or 0)} document(s) indexés."
        bullets = [
            f"État : {payload.get('state', payload.get('enabled', 'ok'))}.",
            "Tout reste stocké localement.",
            "Tu peux demander “ce que tu sais de moi” pour vérifier la mémoire.",
        ]
    else:
        if action == "enable":
            answer = "Local learning is enabled for approved sources."
        elif action == "disable":
            answer = "Local learning is disabled. SevenAI will not run future scans automatically."
        elif action == "scan_content":
            answer = f"Snippet scan completed: {int(payload.get('indexed') or payload.get('documents') or 0)} document(s) processed."
        elif action == "clear_index":
            answer = f"Local index cleared: {int(payload.get('cleared') or 0)} item(s) removed."
        elif action == "clear_snippets":
            answer = f"Local snippets cleared: {int(payload.get('cleared') or 0)} item(s) cleaned."
        else:
            answer = f"Metadata-only scan completed: {int(payload.get('indexed') or payload.get('documents') or 0)} document(s) indexed."
        bullets = [
            f"State: {payload.get('state', payload.get('enabled', 'ok'))}.",
            "Everything stays local.",
            "You can ask “what do you know about me” to review memory.",
        ]
    return {
        "applied": True,
        "state": payload.get("state", "done"),
        "summary": answer,
        "chat": {"title": label, "answer": answer, "bullets": bullets},
        "command": base_command,
        "payload": payload,
        "recommendations": [
            ai_action_card("Voir la mémoire" if language == "fr" else "Show memory", "Contrôler l’état après changement." if language == "fr" else "Review state after the change.", "seven ai \"ce que tu sais de moi\""),
            ai_action_card("Rechercher localement" if language == "fr" else "Search locally", "Tester l’index local." if language == "fr" else "Test the local index.", "seven ai \"cherche README dans mes fichiers\""),
        ],
        "privacy": "local-only",
    }


def memory_audit_answer(language: str) -> dict[str, Any]:
    audit = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "audit", "--json"],
        {"schema": "sevenos.ai-learning-audit.v1", "state": "unknown", "score": 0, "privacy": {}, "index": {}, "sources": [], "issues": []},
        timeout=3.0,
    )
    privacy = audit.get("privacy") if isinstance(audit.get("privacy"), dict) else {}
    index = audit.get("index") if isinstance(audit.get("index"), dict) else {}
    sources = audit.get("sources") if isinstance(audit.get("sources"), list) else []
    issues = [str(item) for item in audit.get("issues", []) if str(item).strip()] if isinstance(audit.get("issues"), list) else []
    documents = int(index.get("documents") or 0)
    snippets = int(index.get("snippets") or privacy.get("snippets") or 0)
    missing = sum(1 for item in sources if isinstance(item, dict) and not item.get("exists"))
    score = int(audit.get("score") or 0)
    store_bytes = int(index.get("store_bytes") or 0)
    store_mb = round(store_bytes / (1024 * 1024), 2)

    if language == "fr":
        state_label = "sain" if audit.get("state") == "ready" else "à surveiller"
        answer = (
            f"Audit mémoire SevenAI : {state_label}, score {score}/100. "
            f"{documents} élément(s) indexés, {snippets} extrait(s), {len(sources)} source(s)."
        )
        bullets = [
            "Stockage : local uniquement, aucun réseau.",
            f"Base locale : {store_mb} MiB.",
            f"Sources manquantes : {missing}.",
            "Export texte complet : désactivé.",
        ]
        if issues:
            bullets.append("Points à surveiller : " + ", ".join(issues[:3]) + ".")
        recommendations = [
            ai_action_card("Voir les sources", "Afficher les dossiers approuvés.", "seven ai 'montre tes sources'"),
            ai_action_card("Effacer les extraits", "Garder les métadonnées mais supprimer les snippets.", "seven ai 'efface les extraits locaux'", risk="low"),
            ai_action_card("Effacer l’index", "Retirer toute recherche locale indexée.", "seven ai 'efface ton index local'", risk="low"),
        ]
        title = "Audit mémoire SevenAI"
    else:
        state_label = "healthy" if audit.get("state") == "ready" else "needs attention"
        answer = (
            f"SevenAI memory audit: {state_label}, score {score}/100. "
            f"{documents} indexed item(s), {snippets} snippet(s), {len(sources)} source(s)."
        )
        bullets = [
            "Storage: local only, no network.",
            f"Local database: {store_mb} MiB.",
            f"Missing sources: {missing}.",
            "Full text export: disabled.",
        ]
        if issues:
            bullets.append("Watch points: " + ", ".join(issues[:3]) + ".")
        recommendations = [
            ai_action_card("Show sources", "Display approved folders.", "seven ai 'show memory sources'"),
            ai_action_card("Clear snippets", "Keep metadata but remove snippets.", "seven ai 'clear local snippets'", risk="low"),
            ai_action_card("Clear index", "Remove all indexed local search data.", "seven ai 'clear local index'", risk="low"),
        ]
        title = "SevenAI memory audit"

    return {
        "applied": False,
        "summary": answer,
        "chat": {"title": title, "answer": answer, "bullets": bullets[:5]},
        "audit": {
            "state": audit.get("state", "unknown"),
            "score": score,
            "documents": documents,
            "snippets": snippets,
            "sources": sources[:8],
            "issues": issues,
            "store": index.get("store", ""),
            "store_bytes": store_bytes,
        },
        "recommendations": recommendations,
        "privacy": privacy,
    }


def memory_plan_answer(language: str) -> dict[str, Any]:
    audit = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "audit", "--json"],
        {"schema": "sevenos.ai-learning-audit.v1", "state": "unknown", "score": 0, "privacy": {}, "index": {}, "sources": [], "issues": []},
        timeout=3.0,
    )
    config = audit.get("config") if isinstance(audit.get("config"), dict) else {}
    index = audit.get("index") if isinstance(audit.get("index"), dict) else {}
    privacy = audit.get("privacy") if isinstance(audit.get("privacy"), dict) else {}
    sources = audit.get("sources") if isinstance(audit.get("sources"), list) else []
    issues = audit.get("issues") if isinstance(audit.get("issues"), list) else []
    documents = int(index.get("documents") or 0)
    snippets = int(index.get("snippets") or privacy.get("snippets") or 0)
    enabled = bool(config.get("enabled"))
    missing = sum(1 for item in sources if isinstance(item, dict) and not item.get("exists"))

    steps: list[dict[str, Any]] = []

    def add_step(title: str, detail: str, command: str, *, risk: str = "low", apply: bool = False) -> None:
        steps.append({
            "title": title,
            "detail": detail,
            "command": command,
            "risk": risk,
            "apply": apply,
        })

    if language == "fr":
        if not enabled:
            add_step(
                "Activer l’apprentissage local",
                "Autoriser SevenAI à utiliser uniquement les sources approuvées.",
                "seven ai 'active ton apprentissage' --apply --json",
                apply=True,
            )
        if enabled and documents == 0:
            add_step(
                "Scanner les métadonnées",
                "Créer une mémoire de recherche sans lire le contenu complet.",
                "seven ai 'scanne mes documents' --apply --json",
                apply=True,
            )
        elif enabled:
            add_step(
                "Rafraîchir l’index",
                f"Mettre à jour les {documents} élément(s) indexés en metadata-only.",
                "seven ai 'scanne mes documents' --apply --json",
                apply=True,
            )
        if enabled and documents > 0 and snippets == 0:
            add_step(
                "Ajouter des extraits, seulement si utile",
                "Permettre de meilleurs résumés locaux avec de courts extraits approuvés.",
                "seven ai 'scanne avec extraits' --apply --json",
                risk="medium",
                apply=True,
            )
        if snippets:
            add_step(
                "Nettoyer les extraits si tu veux rester strict",
                f"Supprimer {snippets} extrait(s) tout en gardant les métadonnées.",
                "seven ai 'efface les extraits locaux' --apply --json",
                apply=True,
            )
        if missing:
            add_step(
                "Réviser les sources manquantes",
                f"{missing} source(s) configurée(s) ne sont plus accessibles.",
                "seven ai 'montre tes sources'",
            )
        add_step(
            "Contrôler la mémoire",
            "Relire le rapport confidentialité avant toute étape plus profonde.",
            "seven ai 'audit mémoire SevenAI'",
        )
        answer = (
            f"Je te propose un plan mémoire local-first en {len(steps)} étape(s). "
            f"Aujourd’hui : {documents} élément(s), {snippets} extrait(s), {len(sources)} source(s)."
        )
        bullets = [f"{index + 1}. {step['title']} · {step['detail']}" for index, step in enumerate(steps[:5])]
        title = "Plan mémoire SevenAI"
    else:
        if not enabled:
            add_step(
                "Enable local learning",
                "Allow SevenAI to use approved sources only.",
                "seven ai 'enable local learning' --apply --json",
                apply=True,
            )
        if enabled and documents == 0:
            add_step(
                "Scan metadata",
                "Create searchable memory without reading full content.",
                "seven ai 'scan my documents' --apply --json",
                apply=True,
            )
        elif enabled:
            add_step(
                "Refresh index",
                f"Update {documents} metadata-only indexed item(s).",
                "seven ai 'scan my documents' --apply --json",
                apply=True,
            )
        if enabled and documents > 0 and snippets == 0:
            add_step(
                "Add snippets only if useful",
                "Enable better local summaries with short approved snippets.",
                "seven ai 'scan with snippets' --apply --json",
                risk="medium",
                apply=True,
            )
        if snippets:
            add_step(
                "Clear snippets for strict privacy",
                f"Remove {snippets} snippet(s) while keeping metadata.",
                "seven ai 'clear local snippets' --apply --json",
                apply=True,
            )
        if missing:
            add_step(
                "Review missing sources",
                f"{missing} configured source(s) are no longer reachable.",
                "seven ai 'show memory sources'",
            )
        add_step(
            "Review memory audit",
            "Read the privacy report before deeper learning.",
            "seven ai 'privacy report'",
        )
        answer = (
            f"I suggest a local-first memory plan in {len(steps)} step(s). "
            f"Current state: {documents} item(s), {snippets} snippet(s), {len(sources)} source(s)."
        )
        bullets = [f"{index + 1}. {step['title']} · {step['detail']}" for index, step in enumerate(steps[:5])]
        title = "SevenAI memory plan"

    return {
        "applied": False,
        "summary": answer,
        "chat": {"title": title, "answer": answer, "bullets": bullets},
        "plan": steps,
        "audit": {
            "state": audit.get("state", "unknown"),
            "score": int(audit.get("score") or 0),
            "documents": documents,
            "snippets": snippets,
            "sources": len(sources),
            "issues": issues,
        },
        "recommendations": steps[:3],
        "privacy": "local-first; sensitive steps require --apply confirmation",
    }


def memory_history_answer(language: str) -> dict[str, Any]:
    history = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "history", "--json"],
        {
            "schema": "sevenos.ai-learning-history.v1",
            "state": "unknown",
            "summary": {},
            "timeline": [],
            "recent_documents": [],
            "privacy": {},
        },
        timeout=3.0,
    )
    summary = history.get("summary") if isinstance(history.get("summary"), dict) else {}
    timeline = history.get("timeline") if isinstance(history.get("timeline"), list) else []
    recent_documents = history.get("recent_documents") if isinstance(history.get("recent_documents"), list) else []
    documents = int(summary.get("documents") or 0)
    snippets = int(summary.get("snippets") or 0)
    scans = int(summary.get("scans") or len(timeline))
    sources = int(summary.get("sources") or 0)
    habits = int(summary.get("habit_events") or 0)

    def scan_line(item: dict[str, Any]) -> str:
        ts = int(item.get("ts") or 0)
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(ts)) if ts else "date inconnue"
        status = str(item.get("status") or "unknown")
        mode = str(item.get("content_mode") or "metadata")
        indexed = int(item.get("files_indexed") or 0)
        seen = int(item.get("files_seen") or 0)
        if language == "fr":
            return f"{when} · {status} · {indexed}/{seen} élément(s) · mode {mode}"
        return f"{when} · {status} · {indexed}/{seen} item(s) · {mode} mode"

    if language == "fr":
        answer = (
            f"Historique mémoire SevenAI : {scans} scan(s) récent(s), "
            f"{documents} élément(s) indexés, {snippets} extrait(s), {sources} source(s)."
        )
        bullets = [scan_line(item) for item in timeline[:4] if isinstance(item, dict)]
        if not bullets:
            bullets = ["Aucun scan local n’est encore enregistré."]
        if recent_documents:
            names = ", ".join(str(item.get("name") or "").strip() for item in recent_documents[:3] if isinstance(item, dict) and item.get("name"))
            if names:
                bullets.append(f"Derniers éléments vus : {names}.")
        bullets.append(f"Habitudes locales : {habits} événement(s).")
        recommendations = [
            ai_action_card("Audit mémoire", "Vérifier confidentialité, sources et extraits.", "seven ai 'audit mémoire SevenAI'"),
            ai_action_card("Voir les sources", "Afficher les dossiers approuvés.", "seven ai 'montre tes sources'"),
            ai_action_card("Rafraîchir", "Relancer un scan metadata-only.", "seven ai 'scanne mes documents' --apply --json"),
        ]
        title = "Historique mémoire SevenAI"
    else:
        answer = (
            f"SevenAI memory history: {scans} recent scan(s), "
            f"{documents} indexed item(s), {snippets} snippet(s), {sources} source(s)."
        )
        bullets = [scan_line(item) for item in timeline[:4] if isinstance(item, dict)]
        if not bullets:
            bullets = ["No local scan has been recorded yet."]
        if recent_documents:
            names = ", ".join(str(item.get("name") or "").strip() for item in recent_documents[:3] if isinstance(item, dict) and item.get("name"))
            if names:
                bullets.append(f"Latest seen items: {names}.")
        bullets.append(f"Local habit events: {habits}.")
        recommendations = [
            ai_action_card("Memory audit", "Review privacy, sources and snippets.", "seven ai 'memory audit'"),
            ai_action_card("Show sources", "Display approved folders.", "seven ai 'show memory sources'"),
            ai_action_card("Refresh", "Run a metadata-only scan.", "seven ai 'scan my documents' --apply --json"),
        ]
        title = "SevenAI memory history"

    return {
        "applied": False,
        "summary": answer,
        "chat": {"title": title, "answer": answer, "bullets": bullets[:6]},
        "history": {
            "state": history.get("state", "unknown"),
            "summary": summary,
            "timeline": timeline[:8],
            "recent_documents": recent_documents[:8],
        },
        "recommendations": recommendations,
        "privacy": history.get("privacy", {}),
    }


def memory_insights_answer(language: str) -> dict[str, Any]:
    payload = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "insights", "--json"],
        {
            "schema": "sevenos.ai-learning-insights.v1",
            "state": "unknown",
            "score": 0,
            "signals": {},
            "insights": [],
            "privacy": {},
        },
        timeout=3.0,
    )
    signals = payload.get("signals") if isinstance(payload.get("signals"), dict) else {}
    insights = payload.get("insights") if isinstance(payload.get("insights"), list) else []
    documents = int(signals.get("documents") or 0)
    snippets = int(signals.get("snippets") or 0)
    groups = signals.get("groups") if isinstance(signals.get("groups"), dict) else {}
    top_ext = signals.get("top_ext") if isinstance(signals.get("top_ext"), list) else []
    score = int(payload.get("score") or 0)

    fr_insight_labels = {
        "learning.disabled": (
            "Apprentissage local disponible mais désactivé",
            "SevenAI restera générique tant que l’apprentissage local n’est pas explicitement activé.",
        ),
        "index.empty": (
            "Aucun contexte local indexé",
            "Lance un scan metadata-only pour que SevenAI retrouve les fichiers approuvés sans lire leur contenu complet.",
        ),
        "index.ready": (
            "Contexte local recherchable",
            f"{documents} élément(s) approuvé(s) sont indexés. SevenAI peut répondre aux questions fichiers et sources localement.",
        ),
        "privacy.snippets": (
            "Des extraits de contenu existent",
            f"{snippets} extrait(s) court(s) améliorent les réponses locales, mais tu peux les effacer en gardant les métadonnées.",
        ),
        "privacy.metadata": (
            "Mode métadonnées strict actif",
            "SevenAI peut chercher noms, titres et types de fichiers sans lire le corps des documents.",
        ),
        "sources.missing": (
            "Certaines sources approuvées sont manquantes",
            "Des dossiers configurés ne sont plus accessibles et doivent être vérifiés.",
        ),
        "atlas.documents": (
            "Atlas peut utiliser ton contexte documentaire",
            f"{int(groups.get('documents') or 0)} élément(s) documentaires sont indexés pour lecture, notes et recherche.",
        ),
        "forge.code": (
            "Forge peut utiliser ton contexte code",
            f"{int(groups.get('code') or 0)} élément(s) code/config sont indexés pour retrouver des projets.",
        ),
        "studio.media": (
            "Studio peut utiliser ton contexte média",
            f"{int(groups.get('media') or 0)} média(s) sont indexés pour les workflows créatifs.",
        ),
        "scan.stale": (
            "L’index local peut être ancien",
            "Le dernier scan enregistré date de plusieurs jours.",
        ),
    }

    def insight_text(item: dict[str, Any]) -> tuple[str, str]:
        if language == "fr":
            mapped = fr_insight_labels.get(str(item.get("key") or ""))
            if mapped:
                return mapped
        return str(item.get("title") or "Insight"), str(item.get("detail") or "")

    if language == "fr":
        answer = (
            f"Analyse mémoire SevenAI : score {score}/100, {documents} élément(s) indexés, "
            f"{snippets} extrait(s). Je vois surtout {int(groups.get('documents') or 0)} document(s), "
            f"{int(groups.get('code') or 0)} élément(s) code et {int(groups.get('media') or 0)} média(s)."
        )
        bullets = [
            f"{insight_text(item)[0]} · {insight_text(item)[1]}"
            for item in insights[:5]
            if isinstance(item, dict) and item.get("title")
        ]
        if not bullets:
            bullets = ["Aucun signal prioritaire : la mémoire locale est calme."]
        if top_ext:
            ext_summary = ", ".join(f"{item.get('ext')}:{item.get('count')}" for item in top_ext[:4] if isinstance(item, dict))
            if ext_summary:
                bullets.append(f"Types dominants : {ext_summary}.")
        recommendations = [
            ai_action_card(
                insight_text(item)[0],
                insight_text(item)[1],
                str(item.get("command") or "seven ai 'audit mémoire SevenAI'"),
                risk=str(item.get("risk") or "low"),
            )
            for item in insights[:3]
            if isinstance(item, dict)
        ] or [
            ai_action_card("Audit mémoire", "Contrôler les sources et la confidentialité.", "seven ai 'audit mémoire SevenAI'"),
        ]
        title = "Insights mémoire SevenAI"
    else:
        answer = (
            f"SevenAI memory insights: score {score}/100, {documents} indexed item(s), "
            f"{snippets} snippet(s). I see {int(groups.get('documents') or 0)} document item(s), "
            f"{int(groups.get('code') or 0)} code item(s) and {int(groups.get('media') or 0)} media item(s)."
        )
        bullets = [
            f"{item.get('title')} · {item.get('detail')}"
            for item in insights[:5]
            if isinstance(item, dict) and item.get("title")
        ]
        if not bullets:
            bullets = ["No priority signal: local memory is calm."]
        if top_ext:
            ext_summary = ", ".join(f"{item.get('ext')}:{item.get('count')}" for item in top_ext[:4] if isinstance(item, dict))
            if ext_summary:
                bullets.append(f"Dominant types: {ext_summary}.")
        recommendations = [
            ai_action_card(
                str(item.get("title") or "Memory action"),
                str(item.get("detail") or "Recommended local action."),
                str(item.get("command") or "seven ai 'memory audit'"),
                risk=str(item.get("risk") or "low"),
            )
            for item in insights[:3]
            if isinstance(item, dict)
        ] or [
            ai_action_card("Memory audit", "Review sources and privacy.", "seven ai 'memory audit'"),
        ]
        title = "SevenAI memory insights"

    return {
        "applied": False,
        "summary": answer,
        "chat": {"title": title, "answer": answer, "bullets": bullets[:6]},
        "insights": insights,
        "signals": signals,
        "recommendations": recommendations,
        "privacy": payload.get("privacy", {}),
    }


def memory_briefing_answer(language: str) -> dict[str, Any]:
    payload = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "briefing", "--json"],
        {
            "schema": "sevenos.ai-memory-briefing.v1",
            "state": "unknown",
            "profile": "equinox",
            "summary": {},
            "focus": {},
            "recent_documents": [],
            "recommended": [],
            "privacy": {},
        },
        timeout=3.0,
    )
    profile = str(payload.get("profile") or "equinox")
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    focus = payload.get("focus") if isinstance(payload.get("focus"), dict) else {}
    recent_documents = payload.get("recent_documents") if isinstance(payload.get("recent_documents"), list) else []
    recommended = payload.get("recommended") if isinstance(payload.get("recommended"), list) else []
    documents = int(summary.get("documents") or 0)
    snippets = int(summary.get("snippets") or 0)
    media = int(summary.get("media_group") or 0)
    docs = int(summary.get("documents_group") or 0)
    code = int(summary.get("code_group") or 0)

    fr_focus_titles = {
        "Daily system context": "Contexte quotidien Equinox",
        "Forge project context": "Contexte projet Forge",
        "Studio creative context": "Contexte créatif Studio",
        "Shield audit context": "Contexte audit Shield",
        "Atlas knowledge context": "Contexte connaissance Atlas",
        "Baobab cultural context": "Contexte culturel Baobab",
        "Pulse play context": "Contexte Pulse",
    }
    fr_focus_details = {
        "Review recent personal context before changing system settings.": "Revoir le contexte personnel récent avant de changer des réglages système.",
        "Look for project notes, code references and configuration files.": "Retrouver notes de projet, références code et fichiers de configuration.",
        "Use recent media assets and project files for creative work.": "Utiliser les médias récents et fichiers projet pour le travail créatif.",
        "Review reports, logs and sensitive notes before security actions.": "Relire rapports, logs et notes sensibles avant les actions sécurité.",
        "Resume reading, documentation and research from indexed documents.": "Reprendre lecture, documentation et recherche depuis les documents indexés.",
        "Review cultural archives, language notes and local sources.": "Revoir archives culturelles, notes linguistiques et sources locales.",
        "Find game notes, media and launch context before performance mode.": "Retrouver notes de jeu, médias et contexte de lancement avant le mode performance.",
    }
    fr_recommendation_labels = {
        "Local context is searchable": (
            "Contexte local recherchable",
            f"{documents} élément(s) approuvé(s) sont indexés. SevenAI peut répondre localement aux questions fichiers et sources.",
        ),
        "Strict metadata mode is active": (
            "Mode métadonnées strict actif",
            "SevenAI cherche noms, titres et types de fichiers sans lire le corps des documents.",
        ),
        "Atlas can use your document context": (
            "Atlas peut utiliser ton contexte documentaire",
            f"{docs} élément(s) documentaire(s) sont indexés pour lecture, notes et recherche.",
        ),
        "Studio can use your media context": (
            "Studio peut utiliser ton contexte média",
            f"{media} média(s) sont indexés pour les workflows créatifs.",
        ),
        "Forge can use your code context": (
            "Forge peut utiliser ton contexte code",
            f"{code} élément(s) code/config sont indexés pour retrouver des projets.",
        ),
    }

    def localized_title(item: dict[str, Any]) -> str:
        title = str(item.get("title") or "")
        if language == "fr":
            return fr_focus_titles.get(title, title)
        return title

    def localized_detail(item: dict[str, Any]) -> str:
        title = str(item.get("title") or "")
        detail = str(item.get("detail") or "")
        if language == "fr":
            if title in fr_recommendation_labels:
                return fr_recommendation_labels[title][1]
            return fr_focus_details.get(detail, detail)
        return detail

    def localized_recommendation_title(item: dict[str, Any]) -> str:
        title = str(item.get("title") or "")
        if language == "fr" and title in fr_recommendation_labels:
            return fr_recommendation_labels[title][0]
        return localized_title(item)

    if language == "fr":
        focus_title = fr_focus_titles.get(str(focus.get("title") or ""), str(focus.get("title") or "Contexte SevenOS"))
        focus_detail = fr_focus_details.get(str(focus.get("detail") or ""), str(focus.get("detail") or ""))
        answer = (
            f"Briefing local pour {profile} : {documents} élément(s) indexés, "
            f"{snippets} extrait(s), avec {docs} document(s), {code} élément(s) code et {media} média(s)."
        )
        bullets = [f"Focus : {focus_title} · {focus_detail}"]
        names = ", ".join(str(item.get("name") or "").strip() for item in recent_documents[:3] if isinstance(item, dict) and item.get("name"))
        if names:
            bullets.append(f"Récents : {names}.")
        for item in recommended[:3]:
            if isinstance(item, dict):
                title = localized_recommendation_title(item)
                detail = localized_detail(item)
                if title != focus_title:
                    bullets.append(f"{title} · {detail}")
        recommendations = [
            ai_action_card(
                localized_recommendation_title(item),
                localized_detail(item) or "Action locale recommandée.",
                str(item.get("command") or "seven ai 'analyse ta mémoire'"),
                risk=str(item.get("risk") or "low"),
            )
            for item in recommended[:3]
            if isinstance(item, dict)
        ]
        title = "Briefing mémoire SevenAI"
    else:
        answer = (
            f"Local briefing for {profile}: {documents} indexed item(s), "
            f"{snippets} snippet(s), with {docs} document item(s), {code} code item(s) and {media} media item(s)."
        )
        bullets = [f"Focus: {focus.get('title', 'SevenOS context')} · {focus.get('detail', '')}"]
        names = ", ".join(str(item.get("name") or "").strip() for item in recent_documents[:3] if isinstance(item, dict) and item.get("name"))
        if names:
            bullets.append(f"Recent: {names}.")
        for item in recommended[:3]:
            if isinstance(item, dict):
                bullets.append(f"{item.get('title')} · {item.get('detail', '')}")
        recommendations = [
            ai_action_card(
                str(item.get("title") or "Recommended action"),
                str(item.get("detail") or "Recommended local action."),
                str(item.get("command") or "seven ai 'memory insights'"),
                risk=str(item.get("risk") or "low"),
            )
            for item in recommended[:3]
            if isinstance(item, dict)
        ]
        title = "SevenAI memory briefing"

    return {
        "applied": False,
        "summary": answer,
        "chat": {"title": title, "answer": answer, "bullets": bullets[:6]},
        "briefing": {
            "profile": profile,
            "summary": summary,
            "focus": focus,
            "recent_documents": recent_documents[:8],
            "recommended": recommended[:6],
        },
        "recommendations": recommendations,
        "privacy": payload.get("privacy", {}),
    }


def learning_source_control(action: str, target: str = "", *, apply: bool, language: str) -> dict[str, Any]:
    action = action.strip().lower()
    sources_payload = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "sources", "--json"],
        {"schema": "sevenos.ai-learning-sources.v1", "config": {"sources": []}},
        timeout=2.5,
    )
    config = sources_payload.get("config") if isinstance(sources_payload.get("config"), dict) else {}
    sources = [str(item) for item in config.get("sources", []) if str(item).strip()] if isinstance(config.get("sources"), list) else []

    if action == "list":
        if language == "fr":
            answer = (
                f"SevenAI a {len(sources)} source(s) locale(s) approuvée(s)."
                if sources else
                "SevenAI n’a encore aucune source locale approuvée."
            )
            bullets = sources[:6] or ["Ajoute un dossier comme Documents pour commencer."]
            recommendations = [
                ai_action_card("Ajouter Documents", "Autoriser l’index local metadata-only de Documents.", "seven ai 'ajoute documents à ta mémoire' --apply --json"),
                ai_action_card("Scanner ensuite", "Rafraîchir l’index après ajout.", "seven ai 'scanne mes documents' --apply --json"),
            ]
            title = "Sources SevenAI"
        else:
            answer = (
                f"SevenAI has {len(sources)} approved local source(s)."
                if sources else
                "SevenAI does not have any approved local source yet."
            )
            bullets = sources[:6] or ["Add a folder such as Documents to begin."]
            recommendations = [
                ai_action_card("Add Documents", "Approve metadata-only local indexing for Documents.", "seven ai 'add documents to local memory' --apply --json"),
                ai_action_card("Scan next", "Refresh the index after adding a source.", "seven ai 'scan my documents' --apply --json"),
            ]
            title = "SevenAI sources"
        return {
            "applied": False,
            "summary": answer,
            "chat": {"title": title, "answer": answer, "bullets": bullets},
            "sources": sources,
            "recommendations": recommendations,
            "privacy": "local approved folders only",
        }

    target = target.strip() or "Documents"
    command_parts = ["learning", "add-source" if action == "add" else "remove-source", target, "--json"]
    command = "seven ai " + " ".join(shlex.quote(part) for part in command_parts)
    if not apply:
        if language == "fr":
            title = "Ajouter une source SevenAI" if action == "add" else "Retirer une source SevenAI"
            answer = (
                f"Je peux ajouter « {target} » aux sources approuvées de SevenAI."
                if action == "add"
                else f"Je peux retirer « {target} » des sources approuvées de SevenAI."
            )
            bullets = [
                "Cela modifie seulement la liste des dossiers autorisés.",
                "Aucun scan n’est lancé sans confirmation séparée.",
                "Confirme avec --apply pour appliquer ce changement.",
            ]
            phrase = (
                f"ajoute {target} à ta mémoire"
                if action == "add"
                else f"retire {target} de ta mémoire"
            )
            confirm_title = "Confirmer"
            confirm_detail = "Modifier les sources approuvées."
        else:
            title = "Add SevenAI source" if action == "add" else "Remove SevenAI source"
            answer = (
                f"I can add “{target}” to SevenAI's approved sources."
                if action == "add"
                else f"I can remove “{target}” from SevenAI's approved sources."
            )
            bullets = [
                "This only changes the approved folder list.",
                "No scan runs without separate confirmation.",
                "Confirm with --apply to apply this change.",
            ]
            phrase = (
                f"add {target} to local memory"
                if action == "add"
                else f"remove {target} from local memory"
            )
            confirm_title = "Confirm"
            confirm_detail = "Update approved sources."
        return {
            "applied": False,
            "state": "preview",
            "summary": answer,
            "chat": {"title": title, "answer": answer, "bullets": bullets},
            "plan": {"command": command, "target": target, "action": action, "requires_confirmation": True},
            "sources": sources,
            "recommendations": [
                ai_action_card(confirm_title, confirm_detail, f"seven ai {shlex.quote(phrase)} --apply --json", risk="low", apply=True),
                ai_action_card("Voir les sources" if language == "fr" else "Show sources", "Contrôler la liste actuelle." if language == "fr" else "Review the current list.", "seven ai 'montre tes sources'"),
            ],
            "privacy": "local approved folders only",
        }

    payload = run_json([str(ROOT_DIR / "scripts/ai.sh"), *command_parts], {"state": "error", "error": "source-command-failed"}, timeout=5.0)
    new_config = payload.get("config") if isinstance(payload.get("config"), dict) else {}
    new_sources = [str(item) for item in new_config.get("sources", []) if str(item).strip()] if isinstance(new_config.get("sources"), list) else []
    if language == "fr":
        if action == "add":
            ok = payload.get("state") != "invalid-source"
            answer = (
                f"Source ajoutée : {payload.get('added') or target}."
                if ok else
                f"Je n’ai pas ajouté « {target} » : ce dossier n’existe pas ou n’est pas accessible."
            )
        else:
            removed = payload.get("removed") if isinstance(payload.get("removed"), list) else []
            answer = (
                f"Source retirée : {', '.join(removed)}."
                if removed else
                f"Je n’ai trouvé aucune source correspondant à « {target} »."
            )
        bullets = [
            f"Sources approuvées maintenant : {len(new_sources)}.",
            "L’index reste local.",
            "Lance un scan metadata-only si tu veux rafraîchir la mémoire.",
        ]
        title = "Sources SevenAI"
    else:
        if action == "add":
            ok = payload.get("state") != "invalid-source"
            answer = (
                f"Source added: {payload.get('added') or target}."
                if ok else
                f"I did not add “{target}”: this folder does not exist or is not accessible."
            )
        else:
            removed = payload.get("removed") if isinstance(payload.get("removed"), list) else []
            answer = (
                f"Source removed: {', '.join(removed)}."
                if removed else
                f"I did not find any source matching “{target}”."
            )
        bullets = [
            f"Approved sources now: {len(new_sources)}.",
            "The index remains local.",
            "Run a metadata-only scan if you want to refresh memory.",
        ]
        title = "SevenAI sources"
    return {
        "applied": True,
        "state": payload.get("state", "ready"),
        "summary": answer,
        "chat": {"title": title, "answer": answer, "bullets": bullets},
        "command": command,
        "payload": payload,
        "sources": new_sources,
        "recommendations": [
            ai_action_card("Scanner maintenant" if language == "fr" else "Scan now", "Rafraîchir l’index metadata-only." if language == "fr" else "Refresh the metadata-only index.", "seven ai 'scanne mes documents' --apply --json"),
            ai_action_card("Voir les sources" if language == "fr" else "Show sources", "Afficher la liste complète." if language == "fr" else "Display the full list.", "seven ai 'montre tes sources'"),
        ],
        "privacy": "local approved folders only",
    }


def forget_preferences(language: str) -> dict[str, Any]:
    before = len(read_preferences().get("preferences", []))
    stored = try_write_preferences({"schema": "sevenos.ai-preferences.v1", "preferences": []})
    return {
        "applied": stored,
        "summary": (
            (f"J’ai effacé {before} préférence(s) explicite(s) SevenAI." if stored else f"Je n’ai pas pu effacer les préférences : la mémoire SevenAI est en lecture seule.")
            if language == "fr"
            else (f"I cleared {before} explicit SevenAI preference(s)." if stored else "I could not clear preferences because SevenAI memory is read-only.")
        ),
        "path": str(AI_PREFERENCES_FILE),
        "count": 0,
        "preferences": [],
        "stored": stored,
        "warnings": [] if stored else ["preferences-state-read-only"],
        "recommendations": [] if stored else [ai_action_card(
            "Diagnostiquer la mémoire SevenAI" if language == "fr" else "Diagnose SevenAI memory",
            "Vérifier pourquoi les préférences ne peuvent pas être écrites." if language == "fr" else "Check why preferences cannot be written.",
            "seven ai state --json",
        )],
    }


def machine_recommendations(snapshot: dict[str, Any], *, language: str) -> list[dict[str, Any]]:
    disk = snapshot.get("disk", {}) if isinstance(snapshot.get("disk"), dict) else {}
    home = disk.get("home", {}) if isinstance(disk.get("home"), dict) else {}
    memory = snapshot.get("memory", {}) if isinstance(snapshot.get("memory"), dict) else {}
    network = snapshot.get("network", {}) if isinstance(snapshot.get("network"), dict) else {}
    failed = snapshot.get("failed_units") if isinstance(snapshot.get("failed_units"), list) else []
    cards: list[dict[str, Any]] = []

    if float(home.get("used_percent") or 0) >= 85:
        cards.append(ai_action_card(
            "Nettoyer l’espace personnel" if language == "fr" else "Clean home storage",
            "Le disque personnel approche de la limite confortable." if language == "fr" else "Home storage is close to the comfort limit.",
            "seven ai diagnose disk --json",
            risk="low",
        ))
    if float(memory.get("used_percent") or 0) >= 85:
        cards.append(ai_action_card(
            "Inspecter la mémoire" if language == "fr" else "Inspect memory",
            "La RAM est élevée; regarde les processus avant de fermer quoi que ce soit." if language == "fr" else "RAM use is high; inspect processes before closing anything.",
            "seven ai diagnose system --json",
            risk="low",
        ))
    nm_state = str(network.get("networkmanager") or "")
    if nm_state and nm_state != "active":
        cards.append(ai_action_card(
            "Réparer le réseau" if language == "fr" else "Repair network",
            "NetworkManager n’est pas actif; la réparation demande confirmation." if language == "fr" else "NetworkManager is not active; repair requires confirmation.",
            "seven ai 'répare le wifi'",
            risk="medium",
            apply=True,
        ))
    if failed:
        cards.append(ai_action_card(
            "Analyser les services" if language == "fr" else "Analyze services",
            f"{len(failed)} service(s) en erreur détecté(s)." if language == "fr" else f"{len(failed)} failed service(s) detected.",
            "seven ai diagnose services --json",
            risk="low",
        ))
    if not cards:
        cards.extend([
            ai_action_card(
                "Ouvrir les paramètres" if language == "fr" else "Open Settings",
                "Ajuster thème, énergie, réseau ou Mini OS." if language == "fr" else "Adjust theme, power, network or Mini OS.",
                "seven ai 'ouvre les paramètres'",
                risk="low",
            ),
            ai_action_card(
                "Voir le Doctor" if language == "fr" else "Open Doctor",
                "Contrôler santé système, services et performances." if language == "fr" else "Check system health, services and performance.",
                "seven ai 'ouvre doctor'",
                risk="low",
            ),
        ])
    return cards[:5]


def brain_recommendations(brain: dict[str, Any], *, language: str) -> list[dict[str, Any]]:
    snapshot = brain.get("machine") if isinstance(brain.get("machine"), dict) else machine_snapshot()
    cards: list[dict[str, Any]] = []
    preferences = brain.get("preferences") if isinstance(brain.get("preferences"), dict) else preferences_summary(language)
    pref_items = preferences.get("preferences") if isinstance(preferences.get("preferences"), list) else []
    mission = latest_active_mission()
    if mission:
        step = next_step_for_mission(mission)
        if step:
            cards.append(ai_action_card(
                f"Continuer : {mission.get('title', 'mission')}" if language == "fr" else f"Continue: {mission.get('title', 'mission')}",
                f"Prochaine étape : {step.get('title')}" if language == "fr" else f"Next step: {step.get('title')}",
                "seven ai missions next --json",
                risk="low",
            ))
    cards.extend(machine_recommendations(snapshot, language=language))
    contracts = brain.get("contracts") if isinstance(brain.get("contracts"), dict) else {}
    for key, item in contracts.items():
        if key == "footprint":
            continue
        if not isinstance(item, dict) or item.get("ready", True):
            continue
        title = f"Vérifier {key}" if language == "fr" else f"Check {key}"
        cards.append(ai_action_card(title, f"État : {item.get('state', 'unknown')}", f"seven ai diagnose {key} --json", risk="low"))
    models = brain.get("models") if isinstance(brain.get("models"), dict) else {}
    if str(models.get("state") or "") in {"model-needs-start", "model-needs-download"}:
        cards.append(ai_action_card(
            "Préparer le modèle local" if language == "fr" else "Prepare local model",
            str(models.get("summary") or ("Ollama peut être activé avec confirmation." if language == "fr" else "Ollama can be enabled with confirmation.")),
            "seven ai model-setup --apply --json",
            risk="medium",
            apply=True,
        ))
    footprint = brain.get("footprint") if isinstance(brain.get("footprint"), dict) else {}
    if footprint and str(footprint.get("state") or "") not in {"ready", "ok", "OK", "unknown"}:
        summary = footprint.get("summary") if isinstance(footprint.get("summary"), dict) else {}
        detail = (
            f"Repo {summary.get('repo', 'inconnu')} · /opt {summary.get('opt', 'inconnu')} · audit lecture seule."
            if language == "fr"
            else f"Repo {summary.get('repo', 'unknown')} · /opt {summary.get('opt', 'unknown')} · read-only audit."
        )
        cards.append(ai_action_card(
            "Auditer le poids SevenOS" if language == "fr" else "Audit SevenOS footprint",
            detail,
            "seven footprint plan --json",
            risk="low",
        ))
    if pref_items:
        latest = pref_items[0] if isinstance(pref_items[0], dict) else {}
        cards.append(ai_action_card(
            "Adapter à tes préférences" if language == "fr" else "Adapt to your preferences",
            str(latest.get("value") or ("Préférences locales actives." if language == "fr" else "Local preferences are active.")),
            "seven ai preferences --json",
            risk="low",
        ))
    proactive = brain.get("proactive") if isinstance(brain.get("proactive"), dict) else {}
    title_translations = {
        "Search local context": "Rechercher dans le contexte local",
        "Use learned habits": "Utiliser les habitudes apprises",
        "Equinox daily context": "Contexte quotidien Equinox",
        "Continue reading": "Continuer la lecture",
        "Browse visual assets": "Parcourir les ressources visuelles",
    }
    detail_translations = {
        "Find documents, notes and recent work indexed locally.": "Retrouver documents, notes et travaux récents indexés localement.",
        "1500 approved local item(s) are indexed. Search by name, type or title without cloud.": "1500 élément(s) locaux approuvés sont indexés. Recherche par nom, type ou titre sans cloud.",
        "Review local usage patterns before suggesting automations.": "Examiner les habitudes locales avant de proposer des automatisations.",
        "SevenAI sees 415 local interaction(s). Dominant patterns: KILL_PROCESS, SET_THEME, REPAIR_NETWORK.": "SevenAI voit 415 interaction(s) locales. Tendances dominantes : fermeture d’apps, thème et réseau.",
        "Prepare a calm daily briefing for the active Mini OS.": "Préparer un briefing calme pour le Mini OS actif.",
        "Review recent documents and recurring actions before changing system state.": "Relire les documents récents et actions récurrentes avant de changer l’état système.",
        "Open Seven Reader for documents and PDFs.": "Ouvrir Seven Reader pour les documents et PDF.",
        "PDF documents are present in the approved index. Open Seven Reader or search document titles.": "Des PDF sont présents dans l’index approuvé. Ouvre Seven Reader ou recherche par titre.",
        "Search local images and wallpapers.": "Rechercher les images et fonds d’écran locaux.",
    }
    for card in proactive.get("cards", []) if isinstance(proactive.get("cards"), list) else []:
        if isinstance(card, dict) and card.get("command"):
            title = str(card.get("title") or "Suggestion")
            detail = str(card.get("detail") or "")
            if language == "fr":
                title = title_translations.get(title, title)
                detail = detail_translations.get(detail, detail)
                if "approved local item(s) are indexed" in detail:
                    count = detail.split(" ", 1)[0]
                    detail = f"{count} élément(s) locaux approuvés sont indexés. Recherche par nom, type ou titre sans cloud."
                elif "SevenAI sees" in detail and "local interaction" in detail:
                    count_match = re.search(r"SevenAI sees\s+([0-9]+)", detail)
                    count = count_match.group(1) if count_match else "plusieurs"
                    detail = f"SevenAI voit {count} interaction(s) locales et les transforme en suggestions prudentes."
            cards.append(ai_action_card(title, detail, str(card.get("command")), risk="low"))
    dedup: list[dict[str, Any]] = []
    seen: set[str] = set()
    for card in cards:
        command = str(card.get("command") or "")
        if command in seen:
            continue
        seen.add(command)
        dedup.append(card)
    return dedup[:6]


def read_key_value_file(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    try:
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            data[key.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    return data


def current_profile() -> dict[str, Any]:
    candidates = [
        Path(os.environ.get("SEVENOS_PROFILE_FILE", "")) if os.environ.get("SEVENOS_PROFILE_FILE") else None,
        Path.home() / ".config/sevenos/profile.conf",
        Path.home() / ".config/sevenos/profile",
        Path.home() / ".config/hypr/conf/sevenos-profile.conf",
    ]
    profile = os.environ.get("SEVENOS_PROFILE", "").strip()
    source = "env" if profile else "fallback"
    for candidate in [item for item in candidates if item]:
        values = read_key_value_file(candidate)
        for key in ("SEVENOS_PROFILE", "profile", "PROFILE", "mini_os", "MINI_OS"):
            if values.get(key):
                profile = values[key].strip().lower()
                source = str(candidate)
                break
        if profile:
            break
    if not profile:
        profile = "equinox"
    titles = {
        "equinox": "Equinox Balance",
        "forge": "Forge",
        "shield": "Shield",
        "studio": "Studio",
        "atlas": "Atlas",
        "baobab": "Baobab",
        "pulse": "Pulse",
    }
    return {
        "key": profile,
        "title": titles.get(profile, profile.title()),
        "source": source,
        "role": "host" if profile == "equinox" else "mini-os",
    }


def current_theme() -> dict[str, Any]:
    values = read_key_value_file(Path.home() / ".config/sevenos/theme.conf")
    theme = (
        os.environ.get("SEVENOS_THEME")
        or values.get("SEVENOS_THEME")
        or values.get("theme")
        or values.get("THEME")
        or ""
    ).strip().lower()
    if not theme:
        gtk = run_json(["bash", "-lc", "gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null"], "", timeout=0.6)
        if isinstance(gtk, str) and "light" in gtk.lower():
            theme = "light"
        elif isinstance(gtk, str) and gtk.strip():
            theme = "dark"
    if theme not in {"light", "dark"}:
        theme = "dark"
    return {
        "mode": theme,
        "source": "env/config/gsettings",
        "contrast": "normal",
        "dynamic": True,
    }


def compact_contract(data: Any, *, fallback_state: str = "unknown") -> dict[str, Any]:
    if not isinstance(data, dict):
        return {"state": fallback_state, "score": 0, "issues": 0, "ready": False}
    state = str(
        data.get("state")
        or data.get("status")
        or data.get("posture")
        or data.get("readiness")
        or data.get("decision")
        or fallback_state
    )
    score_value = data.get("score")
    if score_value is not None and isinstance(data.get("max"), (int, float)) and int(data.get("max") or 0) > 0:
        score_value = round(float(score_value) / float(data.get("max")) * 100)
    if score_value is None:
        score_value = data.get("percent")
    if score_value is None and isinstance(data.get("summary"), dict):
        summary = data["summary"]
        score_value = summary.get("score") or summary.get("readiness")
        if score_value is None and summary.get("total"):
            ready_count = summary.get("ready", summary.get("ok", 0))
            try:
                score_value = round(float(ready_count) / float(summary.get("total")) * 100)
            except (TypeError, ValueError, ZeroDivisionError):
                score_value = None
    if score_value is None and isinstance(data.get("maturity"), dict):
        score_value = (data["maturity"].get("summary") or {}).get("score")
    try:
        score = int(float(score_value))
    except (TypeError, ValueError):
        score = 100 if data.get("ready") is True or state in {"ready", "healthy", "public-ready", "productized"} else 0
    issues_raw = data.get("issues")
    if isinstance(issues_raw, list):
        issues = len(issues_raw)
    elif isinstance(issues_raw, int):
        issues = issues_raw
    elif isinstance(data.get("summary"), dict) and isinstance(data["summary"].get("issues"), int):
        issues = int(data["summary"].get("issues", 0))
    else:
        issues = 0
    ready_states = {"ready", "healthy", "ok", "OK", "public-ready", "productized", "complete", "RUNTIME_READY"}
    return {
        "state": state,
        "score": max(0, min(score, 100)),
        "issues": issues,
        "ready": bool(data.get("ready") is True or state in ready_states or score >= 90),
    }


def app_summary() -> dict[str, Any]:
    apps = app_registry()
    categories: dict[str, int] = {}
    sevenos_apps = 0
    for app in apps:
        categories[app.category] = categories.get(app.category, 0) + 1
        if app.source == "sevenos" or app.desktop_id.startswith("seven-"):
            sevenos_apps += 1
    top_categories = [
        {"category": key, "count": value}
        for key, value in sorted(categories.items(), key=lambda item: (-item[1], item[0]))[:8]
    ]
    return {
        "total": len(apps),
        "sevenos": sevenos_apps,
        "categories": top_categories,
        "surface": "Spotlight AI",
        "open_command": "seven ai \"ouvre <app>\"",
    }


def action_summary() -> dict[str, Any]:
    actions = run_json([str(ROOT_DIR / "scripts/actions.sh"), "--json"], {"actions": []}, timeout=2.0)
    registry = actions.get("actions") if isinstance(actions, dict) and isinstance(actions.get("actions"), list) else []
    safe = [item for item in registry if item.get("impact") == "safe"]
    confirm = [item for item in registry if item.get("impact") != "safe"]
    return {
        "total": len(registry),
        "safe": len(safe),
        "confirmation": len(confirm),
        "ready": len(registry) >= 50,
    }


def footprint_snapshot() -> dict[str, Any]:
    fallback = {
        "schema": "sevenos.footprint-audit.v1",
        "state": "unknown",
        "score": 0,
        "summary": {},
        "checks": [],
        "recommendations": [],
    }
    ttl = int(os.environ.get("SEVENAI_FOOTPRINT_CACHE_TTL", "300"))
    if os.environ.get("SEVENAI_FOOTPRINT_REFRESH") != "1":
        try:
            if AI_FOOTPRINT_CACHE.exists() and time.time() - AI_FOOTPRINT_CACHE.stat().st_mtime < ttl:
                cached = json.loads(AI_FOOTPRINT_CACHE.read_text(encoding="utf-8"))
                cached["cached"] = True
                return cached
        except Exception:
            pass
    script = ROOT_DIR / "scripts/footprint-audit.sh"
    if not script.exists():
        return fallback | {"state": "missing", "summary": {"repo": "unknown", "opt": "unknown"}}
    data = run_json([str(script), "--json"], fallback, timeout=float(os.environ.get("SEVENAI_FOOTPRINT_TIMEOUT", "24")))
    if not isinstance(data, dict):
        return fallback
    if data.get("state") == "unknown":
        try:
            if AI_FOOTPRINT_CACHE.exists():
                cached = json.loads(AI_FOOTPRINT_CACHE.read_text(encoding="utf-8"))
                cached["cached"] = True
                cached["stale"] = True
                return cached
        except Exception:
            pass
    try:
        AI_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        AI_FOOTPRINT_CACHE.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass
    return data


def footprint_compare_snapshot() -> dict[str, Any]:
    fallback = {
        "schema": "sevenos.footprint-compare.v1",
        "state": "unknown",
        "score": 0,
        "summary": {},
        "recommendations": [],
    }
    script = ROOT_DIR / "scripts/footprint-audit.sh"
    if not script.exists():
        return fallback | {"state": "missing"}
    data = run_json([str(script), "compare", "--json"], fallback, timeout=float(os.environ.get("SEVENAI_FOOTPRINT_TIMEOUT", "24")))
    return data if isinstance(data, dict) else fallback


def footprint_trend_snapshot() -> dict[str, Any]:
    fallback = {
        "schema": "sevenos.footprint-trend.v1",
        "state": "unknown",
        "score": 0,
        "samples": 0,
        "summary": {},
        "recommendations": [],
    }
    script = ROOT_DIR / "scripts/footprint-audit.sh"
    if not script.exists():
        return fallback | {"state": "missing"}
    data = run_json([str(script), "trend", "--json"], fallback, timeout=float(os.environ.get("SEVENAI_FOOTPRINT_TIMEOUT", "24")))
    return data if isinstance(data, dict) else fallback


def footprint_guard_snapshot() -> dict[str, Any]:
    fallback = {
        "schema": "sevenos.footprint-guard.v1",
        "state": "unknown",
        "score": 0,
        "summary": {},
        "reasons": [],
        "recommendations": [],
    }
    script = ROOT_DIR / "scripts/footprint-audit.sh"
    if not script.exists():
        return fallback | {"state": "missing"}
    data = run_json([str(script), "guard", "--json"], fallback, timeout=float(os.environ.get("SEVENAI_FOOTPRINT_TIMEOUT", "24")))
    return data if isinstance(data, dict) else fallback


def brain_snapshot() -> dict[str, Any]:
    ttl = int(os.environ.get("SEVENAI_BRAIN_CACHE_TTL", "20"))
    if os.environ.get("SEVENAI_BRAIN_REFRESH") != "1":
        try:
            if AI_BRAIN_CACHE.exists() and time.time() - AI_BRAIN_CACHE.stat().st_mtime < ttl:
                cached = json.loads(AI_BRAIN_CACHE.read_text(encoding="utf-8"))
                cached["cached"] = True
                return cached
        except Exception:
            pass

    machine = machine_snapshot()
    profile = current_profile()
    theme = current_theme()
    health_raw = run_json([str(ROOT_DIR / "bin/seven"), "core", "health", "--json"], {"state": "unknown", "score": 0}, timeout=1.5)
    theme_raw = run_json([str(ROOT_DIR / "bin/seven"), "theme", "doctor", "--json"], {"state": theme["mode"], "score": 100}, timeout=2.0)
    profiles_raw = run_json([str(ROOT_DIR / "bin/seven"), "profile", "health", "--json"], {"state": "unknown", "summary": {}}, timeout=2.0)
    public_raw = run_json(
        [str(ROOT_DIR / "scripts/public-experience.sh"), "doctor", "--json"],
        {"state": "deferred", "score": 100, "issues": [], "detail": "Full public-quality gate is long; use seven public-experience doctor --json for a deep pass."},
        timeout=2.0,
    )
    update_raw = run_json([str(ROOT_DIR / "bin/seven"), "update", "status", "--json"], {"state": "unknown"}, timeout=2.0)
    security_raw = run_json([str(ROOT_DIR / "bin/seven"), "shield", "status", "--json"], {"state": "unknown", "score": 0}, timeout=2.0)
    spotlight_raw = run_json([str(ROOT_DIR / "bin/seven-spotlight"), "doctor", "--json"], {"state": "unknown", "score": 0}, timeout=2.0)
    learning_raw = run_json([str(ROOT_DIR / "scripts/ai.sh"), "learning", "--json"], {"state": "unknown", "index": {}, "habits": {}}, timeout=2.0)
    proactive_raw = run_json([str(ROOT_DIR / "scripts/ai.sh"), "proactive", "--json"], {"state": "unknown", "cards": []}, timeout=2.0)
    footprint_raw = footprint_snapshot()
    preferences = preferences_summary(active_language())
    state_health = ai_state_health(active_language())

    contracts = {
        "health": compact_contract(health_raw),
        "theme": compact_contract(theme_raw),
        "profiles": compact_contract(profiles_raw),
        "public_quality": compact_contract(public_raw),
        "updates": compact_contract(update_raw),
        "security": compact_contract(security_raw),
        "spotlight": compact_contract(spotlight_raw),
        "learning": compact_contract(learning_raw),
        "proactive": compact_contract(proactive_raw),
        "footprint": compact_contract(footprint_raw),
    }
    issues: list[dict[str, str]] = []
    for key, item in contracts.items():
        if not item["ready"] and item["state"] not in {"unknown", "unsupported"}:
            issues.append({"key": key, "state": item["state"], "detail": f"{key} needs attention"})
    disk_home = machine["disk"]["home"]
    if disk_home.get("used_percent", 0) >= 85:
        issues.append({"key": "storage", "state": "attention", "detail": "Home storage is getting full"})
    if machine.get("failed_units"):
        issues.append({"key": "services", "state": "attention", "detail": "Failed systemd units detected"})
    if not state_health.get("writable"):
        issues.append({"key": "ai-state", "state": "read-only", "detail": "SevenAI local memory is not writable"})
    if contracts["footprint"]["state"] not in {"ready", "ok", "OK", "unknown"} and contracts["footprint"]["score"] < 85:
        issues.append({"key": "footprint", "state": contracts["footprint"]["state"], "detail": "SevenOS footprint needs review before public release"})

    model = model_manager()
    apps = app_summary()
    actions = action_summary()
    score_parts = [
        contracts["health"]["score"] or 100,
        contracts["theme"]["score"] or 100,
        contracts["profiles"]["score"] or 100,
        contracts["spotlight"]["score"] or 100,
        100 if actions["ready"] else 70,
        100 if apps["total"] >= 20 else 70,
    ]
    score = round(sum(score_parts) / len(score_parts))
    if issues:
        score = max(0, score - min(len(issues) * 4, 24))
    payload = {
        "schema": "sevenos.ai.brain.v1",
        "cached": False,
        "created_at": int(time.time()),
        "state": "brain-ready" if score >= 85 and len(issues) <= 2 else "brain-needs-attention",
        "score": score,
        "profile": profile,
        "theme": theme,
        "machine": machine,
        "contracts": contracts,
        "apps": apps,
        "actions": actions,
        "models": model,
        "model_runtime": model.get("runtime", {}),
        "footprint": {
            "state": footprint_raw.get("state") if isinstance(footprint_raw, dict) else "unknown",
            "score": footprint_raw.get("score") if isinstance(footprint_raw, dict) else 0,
            "summary": footprint_raw.get("summary", {}) if isinstance(footprint_raw, dict) else {},
            "cleanup_summary": footprint_raw.get("cleanup_summary", {}) if isinstance(footprint_raw, dict) else {},
            "checks": footprint_raw.get("checks", [])[:5] if isinstance(footprint_raw, dict) and isinstance(footprint_raw.get("checks"), list) else [],
            "evidence": footprint_raw.get("evidence", {}) if isinstance(footprint_raw, dict) else {},
            "policy": footprint_raw.get("policy", "read-only") if isinstance(footprint_raw, dict) else "read-only",
        },
        "learning": {
            "state": learning_raw.get("state") if isinstance(learning_raw, dict) else "unknown",
            "documents": int((learning_raw.get("index") or {}).get("documents", 0) or 0) if isinstance(learning_raw, dict) and isinstance(learning_raw.get("index"), dict) else 0,
            "habit_events": int((learning_raw.get("habits") or {}).get("events", 0) or 0) if isinstance(learning_raw, dict) and isinstance(learning_raw.get("habits"), dict) else 0,
            "privacy": learning_raw.get("privacy", {}) if isinstance(learning_raw, dict) else {},
        },
        "state_storage": state_health,
        "preferences": {
            "state": "ready" if state_health.get("writable") else "read-only",
            "count": preferences.get("count", 0),
            "categories": preferences.get("categories", {}),
            "summary": preferences.get("summary", ""),
            "preferences": preferences.get("preferences", [])[:8],
        },
        "proactive": {
            "state": proactive_raw.get("state") if isinstance(proactive_raw, dict) else "unknown",
            "cards": proactive_raw.get("cards", [])[:5] if isinstance(proactive_raw, dict) and isinstance(proactive_raw.get("cards"), list) else [],
        },
        "issues": issues[:12],
        "recommendations": [],
        "next": [
            "Use `seven ai brain --json` as the fast whole-system AI map.",
            "Use Spotlight AI for natural-language app launching and machine questions.",
            "Use `seven ai operate \"<demande>\" --json` before any system-changing action.",
            "Enable Ollama or a GGUF model only when you want deeper local reasoning.",
        ],
    }
    payload["recommendations"] = brain_recommendations(payload, language=active_language())
    try:
        AI_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        AI_BRAIN_CACHE.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass
    return payload


def answer_system_question(topic: str, text: str) -> dict[str, Any]:
    language = language_for_text(text)
    snapshot = machine_snapshot()
    disk = snapshot["disk"]
    memory = snapshot["memory"]
    cpu = snapshot["cpu"]
    battery = snapshot["battery"]
    network = snapshot["network"]
    windows = snapshot.get("windows", [])
    processes = snapshot.get("top_processes", [])
    failed = snapshot["failed_units"]
    summary = ""

    if topic == "disk":
        home = disk["home"]
        root = disk["root"]
        mounted = [
            item for item in disk.get("devices", [])
            if item.get("mountpoints") and item.get("size_gb")
        ][:8]
        if language == "fr":
            summary = (
                f"Ton espace personnel fait {home['total_gb']} GiB : "
                f"{home['used_gb']} GiB utilisés, {home['free_gb']} GiB libres "
                f"({home['used_percent']}%). La racine système fait {root['total_gb']} GiB."
            )
        else:
            summary = (
                f"Your home storage is {home['total_gb']} GiB: "
                f"{home['used_gb']} GiB used, {home['free_gb']} GiB free "
                f"({home['used_percent']}%). The system root is {root['total_gb']} GiB."
            )
        details = mounted
    elif topic == "memory":
        if language == "fr":
            summary = (
                f"Ta mémoire totale est {memory['total_mb']} MiB. "
                f"{memory['available_mb']} MiB sont disponibles, utilisation estimée {memory['used_percent']}%."
            )
        else:
            summary = (
                f"Total memory is {memory['total_mb']} MiB. "
                f"{memory['available_mb']} MiB is available, estimated use {memory['used_percent']}%."
            )
        details = memory
    elif topic == "cpu":
        load = cpu.get("load", {})
        if language == "fr":
            summary = f"CPU : {cpu['model']} avec {cpu['logical_cores']} coeurs logiques. Charge 1 min : {load.get('1m', 0):.2f}."
        else:
            summary = f"CPU: {cpu['model']} with {cpu['logical_cores']} logical cores. 1 min load: {load.get('1m', 0):.2f}."
        details = cpu
    elif topic == "battery":
        if not battery.get("present"):
            summary = "Aucune batterie détectée." if language == "fr" else "No battery was detected."
        else:
            summary = (
                f"Batterie : {battery.get('capacity')}%, état {battery.get('status')}."
                if language == "fr"
                else f"Battery: {battery.get('capacity')}%, status {battery.get('status')}."
            )
        details = battery
    elif topic == "network":
        wifi = network.get("wifi", {})
        nm_state = network.get("networkmanager")
        detail = wifi.get("detail") if isinstance(wifi, dict) else ""
        if language == "fr":
            summary = f"Réseau : NetworkManager est {nm_state}. Wi-Fi : {detail or 'état non détaillé'}."
        else:
            summary = f"Network: NetworkManager is {nm_state}. Wi-Fi: {detail or 'no detailed state'}."
        details = network
    elif topic == "theme":
        theme = current_theme()
        mode = str(theme.get("mode") or "unknown")
        mode_label = {"dark": "sombre", "light": "clair"}.get(mode, mode) if language == "fr" else mode
        if language == "fr":
            summary = f"Le thème SevenOS actif est {mode_label}. Source : {theme.get('source', 'inconnue')}."
        else:
            summary = f"The active SevenOS theme is {mode_label}. Source: {theme.get('source', 'unknown')}."
        details = theme
    elif topic == "profile":
        profile = current_profile()
        if language == "fr":
            role = "hôte" if profile.get("role") == "host" else "mini OS"
            summary = f"L’espace actif est {profile.get('title', 'SevenOS')} ({role})."
        else:
            summary = f"The active space is {profile.get('title', 'SevenOS')} ({profile.get('role', 'profile')})."
        details = profile
    elif topic == "health":
        brain = brain_snapshot()
        issues = brain.get("issues") if isinstance(brain.get("issues"), list) else []
        if language == "fr":
            summary = f"Santé SevenOS : {brain.get('score', 0)}/100, état {brain.get('state', 'unknown')}."
            if issues:
                issue_text = issues[0].get("detail", issues[0]) if isinstance(issues[0], dict) else issues[0]
                summary += f" Priorité : {human_issue_label(issue_text, language)}"
        else:
            summary = f"SevenOS health: {brain.get('score', 0)}/100, state {brain.get('state', 'unknown')}."
            if issues:
                issue_text = issues[0].get("detail", issues[0]) if isinstance(issues[0], dict) else issues[0]
                summary += f" Priority: {human_issue_label(issue_text, language)}"
        details = {"brain": brain, "issues": issues[:6]}
    elif topic == "updates":
        brain = brain_snapshot()
        contracts = brain.get("contracts") if isinstance(brain.get("contracts"), dict) else {}
        updates = contracts.get("updates") if isinstance(contracts.get("updates"), dict) else {}
        state = updates.get("state") or "unknown"
        score = updates.get("score")
        if language == "fr":
            summary = f"Mises à jour SevenOS : état {state}."
            if score not in (None, ""):
                summary += f" Score {score}/100."
        else:
            summary = f"SevenOS updates: state {state}."
            if score not in (None, ""):
                summary += f" Score {score}/100."
        details = updates
    elif topic == "footprint":
        details = footprint_snapshot()
        footprint_summary = details.get("summary") if isinstance(details.get("summary"), dict) else {}
        if language == "fr":
            summary = (
                f"Empreinte SevenOS : repo {footprint_summary.get('repo', 'inconnu')}, "
                f"/opt {footprint_summary.get('opt', 'inconnu')}, SevenBus {footprint_summary.get('sevenbus', 'inconnu')}. "
                f"État {details.get('state', 'unknown')} ({details.get('score', 0)}/100)."
            )
        else:
            summary = (
                f"SevenOS footprint: repo {footprint_summary.get('repo', 'unknown')}, "
                f"/opt {footprint_summary.get('opt', 'unknown')}, SevenBus {footprint_summary.get('sevenbus', 'unknown')}. "
                f"State {details.get('state', 'unknown')} ({details.get('score', 0)}/100)."
            )
    elif topic == "footprint_compare":
        details = footprint_compare_snapshot()
        compare_summary = details.get("summary") if isinstance(details.get("summary"), dict) else {}
        if language == "fr":
            state_label = {
                "unchanged": "stable",
                "improved": "meilleure",
                "regressed": "en recul",
                "mixed": "mitigée",
                "needs-baseline": "sans preuve de base",
                "unknown": "inconnue",
            }.get(str(details.get("state", "unknown")), str(details.get("state", "unknown")))
            summary = (
                f"Comparaison empreinte SevenOS : {state_label}. "
                f"Repo {compare_summary.get('repo_delta', 'inconnu')}, "
                f"/opt {compare_summary.get('runtime_delta', 'inconnu')}, "
                f"SevenBus {compare_summary.get('sevenbus_delta', 'inconnu')}."
            )
        else:
            summary = (
                f"SevenOS footprint comparison: {details.get('state', 'unknown')}. "
                f"Repo {compare_summary.get('repo_delta', 'unknown')}, "
                f"/opt {compare_summary.get('runtime_delta', 'unknown')}, "
                f"SevenBus {compare_summary.get('sevenbus_delta', 'unknown')}."
            )
    elif topic == "footprint_trend":
        details = footprint_trend_snapshot()
        trend_summary = details.get("summary") if isinstance(details.get("summary"), dict) else {}
        if language == "fr":
            state_label = {
                "stable": "stable",
                "improving": "en amélioration",
                "regressing": "en recul",
                "mixed": "mitigée",
                "single-sample": "encore trop courte",
                "needs-evidence": "sans preuve",
                "unknown": "inconnue",
            }.get(str(details.get("state", "unknown")), str(details.get("state", "unknown")))
            summary = (
                f"Tendance empreinte SevenOS : {state_label}, {details.get('samples', 0)} preuve(s). "
                f"Repo {trend_summary.get('repo_delta', 'inconnu')}, "
                f"/opt {trend_summary.get('runtime_delta', 'inconnu')}, "
                f"SevenBus {trend_summary.get('sevenbus_delta', 'inconnu')}."
            )
        else:
            summary = (
                f"SevenOS footprint trend: {details.get('state', 'unknown')}, {details.get('samples', 0)} sample(s). "
                f"Repo {trend_summary.get('repo_delta', 'unknown')}, "
                f"/opt {trend_summary.get('runtime_delta', 'unknown')}, "
                f"SevenBus {trend_summary.get('sevenbus_delta', 'unknown')}."
            )
    elif topic == "footprint_guard":
        details = footprint_guard_snapshot()
        guard_summary = details.get("summary") if isinstance(details.get("summary"), dict) else {}
        if language == "fr":
            state_label = {
                "pass": "OK",
                "warn": "attention",
                "block": "bloqué",
                "unknown": "inconnu",
            }.get(str(details.get("state", "unknown")), str(details.get("state", "unknown")))
            summary = (
                f"Garde-fou empreinte SevenOS : {state_label}. "
                f"Repo {guard_summary.get('repo_delta', 'inconnu')}, "
                f"/opt {guard_summary.get('runtime_delta', 'inconnu')}, "
                f"SevenBus {guard_summary.get('sevenbus_delta', 'inconnu')}."
            )
        else:
            summary = (
                f"SevenOS footprint guard: {details.get('state', 'unknown')}. "
                f"Repo {guard_summary.get('repo_delta', 'unknown')}, "
                f"/opt {guard_summary.get('runtime_delta', 'unknown')}, "
                f"SevenBus {guard_summary.get('sevenbus_delta', 'unknown')}."
            )
    elif topic == "apps":
        visible = [item for item in windows if item.get("mapped", True)]
        names = []
        for item in visible[:8]:
            label = item.get("class") or item.get("title") or "app"
            if label not in names:
                names.append(str(label))
        fallback_processes = [str(item.get("name") or "") for item in processes[:8] if item.get("name")]
        if language == "fr":
            summary = (
                f"{len(visible)} fenêtre(s) active(s) détectée(s) : " + ", ".join(names)
                if visible
                else "Je ne détecte aucune fenêtre active via Hyprland pour le moment. Processus visibles : " + ", ".join(fallback_processes)
                if fallback_processes
                else "Je ne détecte aucune fenêtre active via Hyprland pour le moment."
            )
        else:
            summary = (
                f"{len(visible)} active window(s) detected: " + ", ".join(names)
                if visible
                else "I do not detect active Hyprland windows right now. Visible processes: " + ", ".join(fallback_processes)
                if fallback_processes
                else "I do not detect active Hyprland windows right now."
            )
        details = visible or processes[:8]
    elif topic == "processes":
        names = [f"{item.get('name')} ({item.get('rss_mb')} MiB)" for item in processes[:6]]
        if language == "fr":
            summary = "Processus principaux : " + ", ".join(names) if names else "Aucun processus lisible détecté."
        else:
            summary = "Top processes: " + ", ".join(names) if names else "No readable process was detected."
        details = processes
    elif topic == "services":
        if failed:
            summary = (
                "Services en erreur : " + ", ".join(failed)
                if language == "fr"
                else "Failed services: " + ", ".join(failed)
            )
        else:
            summary = "Aucun service systemd en erreur détecté." if language == "fr" else "No failed systemd services detected."
        details = failed
    else:
        home = disk["home"]
        if language == "fr":
            summary = (
                f"Machine : {cpu['logical_cores']} coeurs logiques, {memory['total_mb']} MiB RAM, "
                f"{home['total_gb']} GiB d’espace personnel dont {home['free_gb']} GiB libres."
            )
        else:
            summary = (
                f"Machine: {cpu['logical_cores']} logical cores, {memory['total_mb']} MiB RAM, "
                f"{home['total_gb']} GiB home storage with {home['free_gb']} GiB free."
            )
        details = snapshot

    chat_title = {
        "disk": "Stockage" if language == "fr" else "Storage",
        "memory": "Mémoire" if language == "fr" else "Memory",
        "cpu": "Processeur" if language == "fr" else "Processor",
        "battery": "Batterie" if language == "fr" else "Battery",
        "network": "Réseau" if language == "fr" else "Network",
        "theme": "Thème" if language == "fr" else "Theme",
        "profile": "Espace actif" if language == "fr" else "Active space",
        "health": "Santé SevenOS" if language == "fr" else "SevenOS health",
        "updates": "Mises à jour" if language == "fr" else "Updates",
        "footprint": "Poids SevenOS" if language == "fr" else "SevenOS footprint",
        "footprint_compare": "Avant/après SevenOS" if language == "fr" else "SevenOS before/after",
        "footprint_trend": "Tendance SevenOS" if language == "fr" else "SevenOS trend",
        "footprint_guard": "Garde-fou SevenOS" if language == "fr" else "SevenOS guard",
        "apps": "Applications" if language == "fr" else "Applications",
        "processes": "Processus" if language == "fr" else "Processes",
        "services": "Services" if language == "fr" else "Services",
    }.get(topic, "État machine" if language == "fr" else "Machine state")
    chat_bullets: list[str] = []
    if topic == "disk":
        home = disk["home"]
        root = disk["root"]
        chat_answer = (
            f"Ton espace personnel fait {home['total_gb']} GiB, avec {home['free_gb']} GiB libres."
            if language == "fr"
            else f"Your home storage is {home['total_gb']} GiB, with {home['free_gb']} GiB free."
        )
        chat_bullets = [
            (f"Utilisé : {home['used_gb']} GiB ({home['used_percent']}%)." if language == "fr" else f"Used: {home['used_gb']} GiB ({home['used_percent']}%)."),
            (f"Racine système : {root['total_gb']} GiB." if language == "fr" else f"System root: {root['total_gb']} GiB."),
            (f"Volumes montés visibles : {len(details)}." if language == "fr" else f"Visible mounted volumes: {len(details)}."),
        ]
    elif topic == "memory":
        chat_answer = (
            f"Tu as {memory['total_mb']} MiB de RAM, dont {memory['available_mb']} MiB disponibles."
            if language == "fr"
            else f"You have {memory['total_mb']} MiB of RAM, with {memory['available_mb']} MiB available."
        )
        chat_bullets = [
            (f"Utilisation estimée : {memory['used_percent']}%." if language == "fr" else f"Estimated use: {memory['used_percent']}%."),
        ]
    elif topic == "cpu":
        load = cpu.get("load", {})
        chat_answer = (
            f"Ton CPU a {cpu['logical_cores']} coeurs logiques."
            if language == "fr"
            else f"Your CPU has {cpu['logical_cores']} logical cores."
        )
        chat_bullets = [
            str(cpu.get("model") or "").strip(),
            (f"Charge 1 min : {load.get('1m', 0):.2f}." if language == "fr" else f"1 min load: {load.get('1m', 0):.2f}."),
        ]
    elif topic == "battery":
        if battery.get("present"):
            chat_answer = (
                f"Batterie à {battery.get('capacity')}%, état {battery.get('status')}."
                if language == "fr"
                else f"Battery is at {battery.get('capacity')}%, status {battery.get('status')}."
            )
        else:
            chat_answer = "Je ne détecte pas de batterie." if language == "fr" else "I do not detect a battery."
    elif topic == "network":
        wifi = network.get("wifi", {})
        detail = wifi.get("detail") if isinstance(wifi, dict) else ""
        chat_answer = (
            f"NetworkManager est {network.get('networkmanager')}."
            if language == "fr"
            else f"NetworkManager is {network.get('networkmanager')}."
        )
        chat_bullets = [
            (f"Wi-Fi : {detail or 'état non détaillé'}." if language == "fr" else f"Wi-Fi: {detail or 'no detailed state'}."),
        ]
    elif topic == "theme":
        theme = details if isinstance(details, dict) else current_theme()
        mode = str(theme.get("mode") or "unknown")
        mode_label = {"dark": "sombre", "light": "clair"}.get(mode, mode) if language == "fr" else mode
        chat_answer = (
            f"SevenOS est actuellement en thème {mode_label}."
            if language == "fr"
            else f"SevenOS is currently using the {mode_label} theme."
        )
        chat_bullets = [
            (f"Source : {theme.get('source', 'inconnue')}." if language == "fr" else f"Source: {theme.get('source', 'unknown')}."),
            ("Commande utile : seven theme doctor --json." if language == "fr" else "Useful command: seven theme doctor --json."),
        ]
    elif topic == "profile":
        profile = details if isinstance(details, dict) else current_profile()
        chat_answer = (
            f"Tu es dans {profile.get('title', 'SevenOS')}."
            if language == "fr"
            else f"You are in {profile.get('title', 'SevenOS')}."
        )
        chat_bullets = [
            (f"Rôle : {profile.get('role', 'unknown')}." if language == "fr" else f"Role: {profile.get('role', 'unknown')}."),
            (f"Source : {profile.get('source', 'unknown')}." if language == "fr" else f"Source: {profile.get('source', 'unknown')}."),
        ]
    elif topic == "health":
        brain = details.get("brain") if isinstance(details, dict) and isinstance(details.get("brain"), dict) else brain_snapshot()
        issues = details.get("issues") if isinstance(details, dict) and isinstance(details.get("issues"), list) else []
        chat_answer = (
            f"Le score santé SevenOS est {brain.get('score', 0)}/100."
            if language == "fr"
            else f"SevenOS health score is {brain.get('score', 0)}/100."
        )
        chat_bullets = [
            human_issue_label(item.get("detail") if isinstance(item, dict) else item, language)
            for item in issues[:5]
            if item
        ] or [
            "Aucun point critique détecté dans le brain rapide." if language == "fr" else "No critical issue detected in the quick brain."
        ]
    elif topic == "updates":
        updates = details if isinstance(details, dict) else {}
        state = updates.get("state") or "unknown"
        score = updates.get("score")
        chat_answer = (
            f"L’état des mises à jour est {state}."
            if language == "fr"
            else f"Update state is {state}."
        )
        chat_bullets = [
            (f"Score : {score}/100." if language == "fr" else f"Score: {score}/100.") if score not in (None, "") else "",
            ("Commande utile : seven update status --json." if language == "fr" else "Useful command: seven update status --json."),
        ]
    elif topic == "footprint":
        footprint = details if isinstance(details, dict) else {}
        footprint_summary = footprint.get("summary") if isinstance(footprint.get("summary"), dict) else {}
        cleanup_summary = footprint.get("cleanup_summary") if isinstance(footprint.get("cleanup_summary"), dict) else {}
        git_summary = footprint_summary.get("git") if isinstance(footprint_summary.get("git"), dict) else {}
        chat_answer = (
            f"SevenOS pèse {footprint_summary.get('repo', 'inconnu')} côté dépôt et {footprint_summary.get('opt', 'inconnu')} côté runtime."
            if language == "fr"
            else f"SevenOS currently uses {footprint_summary.get('repo', 'unknown')} in the source tree and {footprint_summary.get('opt', 'unknown')} in the runtime."
        )
        source_iso = footprint_summary.get("source_iso") if isinstance(footprint_summary.get("source_iso"), dict) else {}
        installed_iso = footprint_summary.get("installed_iso") if isinstance(footprint_summary.get("installed_iso"), dict) else {}
        chat_bullets = [
            (f"État : {footprint.get('state', 'unknown')} · score {footprint.get('score', 0)}/100." if language == "fr" else f"State: {footprint.get('state', 'unknown')} · score {footprint.get('score', 0)}/100."),
            (f"SevenBus : {footprint_summary.get('sevenbus', 'inconnu')}." if language == "fr" else f"SevenBus: {footprint_summary.get('sevenbus', 'unknown')}."),
            (f"Git : {git_summary.get('state', 'unknown')} · {git_summary.get('dirty_count', 0)} chemin(s)." if language == "fr" else f"Git: {git_summary.get('state', 'unknown')} · {git_summary.get('dirty_count', 0)} path(s)."),
            (f"ISO source : {source_iso.get('state', 'unknown')} · ISO /opt : {installed_iso.get('state', 'unknown')}." if language == "fr" else f"Source ISO: {source_iso.get('state', 'unknown')} · /opt ISO: {installed_iso.get('state', 'unknown')}."),
            (f"Plan : {cleanup_summary.get('items', 0)} zone(s) à revoir, {cleanup_summary.get('reviewable_reclaim', 'inconnu')} potentiels." if language == "fr" else f"Plan: {cleanup_summary.get('items', 0)} area(s) to review, {cleanup_summary.get('reviewable_reclaim', 'unknown')} potential."),
            ("Politique : audit lecture seule, aucune suppression automatique." if language == "fr" else "Policy: read-only audit, no automatic deletion."),
        ]
    elif topic == "footprint_compare":
        compare = details if isinstance(details, dict) else {}
        compare_summary = compare.get("summary") if isinstance(compare.get("summary"), dict) else {}
        baseline = compare.get("baseline") if isinstance(compare.get("baseline"), dict) else {}
        state_label = str(compare.get("state", "unknown"))
        if language == "fr":
            state_label = {
                "unchanged": "stable",
                "improved": "meilleure",
                "regressed": "en recul",
                "mixed": "mitigée",
                "needs-baseline": "sans preuve de base",
                "unknown": "inconnue",
            }.get(state_label, state_label)
        chat_answer = (
            f"La comparaison SevenOS est {state_label}."
            if language == "fr"
            else f"The SevenOS comparison is {state_label}."
        )
        chat_bullets = [
            (f"Base : {baseline.get('path', 'aucune preuve')}." if language == "fr" else f"Baseline: {baseline.get('path', 'no evidence')}."),
            (f"Dépôt : {compare_summary.get('repo_delta', 'inconnu')}." if language == "fr" else f"Source tree: {compare_summary.get('repo_delta', 'unknown')}."),
            (f"Runtime /opt : {compare_summary.get('runtime_delta', 'inconnu')}." if language == "fr" else f"/opt runtime: {compare_summary.get('runtime_delta', 'unknown')}."),
            (f"SevenBus : {compare_summary.get('sevenbus_delta', 'inconnu')}." if language == "fr" else f"SevenBus: {compare_summary.get('sevenbus_delta', 'unknown')}."),
            (f"Git dirty : {compare_summary.get('git_dirty_delta', 'inconnu')}." if language == "fr" else f"Git dirty: {compare_summary.get('git_dirty_delta', 'unknown')}."),
            ("Politique : comparaison lecture seule, aucune suppression automatique." if language == "fr" else "Policy: read-only comparison, no automatic deletion."),
        ]
    elif topic == "footprint_trend":
        trend = details if isinstance(details, dict) else {}
        trend_summary = trend.get("summary") if isinstance(trend.get("summary"), dict) else {}
        state_label = str(trend.get("state", "unknown"))
        if language == "fr":
            state_label = {
                "stable": "stable",
                "improving": "en amélioration",
                "regressing": "en recul",
                "mixed": "mitigée",
                "single-sample": "encore trop courte",
                "needs-evidence": "sans preuve",
                "unknown": "inconnue",
            }.get(state_label, state_label)
        chat_answer = (
            f"La tendance SevenOS est {state_label} sur {trend.get('samples', 0)} preuve(s)."
            if language == "fr"
            else f"The SevenOS trend is {state_label} across {trend.get('samples', 0)} sample(s)."
        )
        chat_bullets = [
            (f"Dépôt : {trend_summary.get('repo_delta', 'inconnu')}." if language == "fr" else f"Source tree: {trend_summary.get('repo_delta', 'unknown')}."),
            (f"Runtime /opt : {trend_summary.get('runtime_delta', 'inconnu')}." if language == "fr" else f"/opt runtime: {trend_summary.get('runtime_delta', 'unknown')}."),
            (f"SevenBus : {trend_summary.get('sevenbus_delta', 'inconnu')}." if language == "fr" else f"SevenBus: {trend_summary.get('sevenbus_delta', 'unknown')}."),
            (f"Git dirty : {trend_summary.get('git_dirty_delta', 'inconnu')}." if language == "fr" else f"Git dirty: {trend_summary.get('git_dirty_delta', 'unknown')}."),
            (f"Score : {trend_summary.get('score_delta', 'inconnu')}." if language == "fr" else f"Score: {trend_summary.get('score_delta', 'unknown')}."),
            ("Politique : tendance lecture seule, aucune suppression automatique." if language == "fr" else "Policy: read-only trend, no automatic deletion."),
        ]
    elif topic == "footprint_guard":
        guard = details if isinstance(details, dict) else {}
        guard_summary = guard.get("summary") if isinstance(guard.get("summary"), dict) else {}
        state_label = str(guard.get("state", "unknown"))
        compare_label = str(guard.get("compare_state", "unknown"))
        current_label = str(guard.get("current_state", "unknown"))
        if language == "fr":
            state_label = {
                "pass": "OK",
                "warn": "en attention",
                "block": "bloqué",
                "unknown": "inconnu",
            }.get(state_label, state_label)
            compare_label = {
                "unchanged": "stable",
                "improved": "meilleure",
                "regressed": "en recul",
                "mixed": "mitigée",
                "needs-baseline": "sans preuve de base",
                "unknown": "inconnue",
            }.get(compare_label, compare_label)
            current_label = {
                "needs-trim": "à alléger",
                "needs-source-iso": "ISO source manquante",
                "ready": "prêt",
                "unknown": "inconnu",
            }.get(current_label, current_label)
        reasons = guard.get("reasons") if isinstance(guard.get("reasons"), list) else []
        chat_answer = (
            f"Le garde-fou SevenOS est {state_label}."
            if language == "fr"
            else f"The SevenOS guard is {state_label}."
        )
        chat_bullets = [
            (f"Comparaison : {compare_label}." if language == "fr" else f"Comparison: {compare_label}."),
            (f"État courant : {current_label}." if language == "fr" else f"Current state: {current_label}."),
            (f"Dépôt : {guard_summary.get('repo_delta', 'inconnu')}." if language == "fr" else f"Source tree: {guard_summary.get('repo_delta', 'unknown')}."),
            (f"Runtime /opt : {guard_summary.get('runtime_delta', 'inconnu')}." if language == "fr" else f"/opt runtime: {guard_summary.get('runtime_delta', 'unknown')}."),
            (f"SevenBus : {guard_summary.get('sevenbus_delta', 'inconnu')}." if language == "fr" else f"SevenBus: {guard_summary.get('sevenbus_delta', 'unknown')}."),
            (f"Raison : {reasons[0]}." if reasons and language == "fr" else f"Reason: {reasons[0]}." if reasons else ""),
            ("Politique : garde-fou lecture seule, aucune suppression automatique." if language == "fr" else "Policy: read-only guard, no automatic deletion."),
        ]
        chat_bullets = [item for item in chat_bullets if item]
    elif topic == "apps":
        count = len(details) if isinstance(details, list) else 0
        chat_answer = (
            f"Je vois {count} élément(s) d’activité côté fenêtres ou processus."
            if language == "fr"
            else f"I see {count} activity item(s) from windows or processes."
        )
        chat_bullets = [
            str((item.get("class") or item.get("title") or item.get("name") or "app")).strip()
            for item in details[:5]
            if isinstance(item, dict)
        ]
    elif topic == "processes":
        chat_answer = (
            "Voici les processus les plus visibles côté mémoire."
            if language == "fr"
            else "Here are the most visible processes by memory."
        )
        chat_bullets = [
            f"{item.get('name')} · {item.get('rss_mb')} MiB"
            for item in processes[:5]
            if isinstance(item, dict) and item.get("name")
        ]
    elif topic == "services":
        if failed:
            chat_answer = (
                f"{len(failed)} service(s) systemd demandent attention."
                if language == "fr"
                else f"{len(failed)} systemd service(s) need attention."
            )
            chat_bullets = [str(item) for item in failed[:5]]
        else:
            chat_answer = (
                "Aucun service systemd en erreur n’est détecté."
                if language == "fr"
                else "No failed systemd service is detected."
            )
    else:
        home = disk["home"]
        chat_answer = (
            f"Ta machine a {cpu['logical_cores']} coeurs logiques, {memory['total_mb']} MiB RAM et {home['free_gb']} GiB libres."
            if language == "fr"
            else f"Your machine has {cpu['logical_cores']} logical cores, {memory['total_mb']} MiB RAM and {home['free_gb']} GiB free."
        )
        chat_bullets = [
            (f"Stockage personnel : {home['used_percent']}% utilisé." if language == "fr" else f"Home storage: {home['used_percent']}% used."),
            (f"RAM utilisée : {memory['used_percent']}%." if language == "fr" else f"RAM used: {memory['used_percent']}%."),
        ]

    response = {
        "applied": False,
        "topic": topic,
        "language": language,
        "summary": summary,
        "chat": {
            "title": chat_title,
            "answer": chat_answer,
            "bullets": [item for item in chat_bullets if str(item).strip()][:5],
        },
        "ui_snapshot": compact_machine_snapshot(snapshot),
        "details": compact_answer_details(topic, details),
        "recommendations": machine_recommendations(snapshot, language=language),
    }
    if os.environ.get("SEVENAI_VERBOSE") == "1":
        response["snapshot"] = snapshot
        response["raw_details"] = details
    return response


def local_search(query: str, *, language: str) -> dict[str, Any]:
    query = query.strip()
    payload = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "learning", "search", query, "--json"],
        {"schema": "sevenos.ai-learning-search.v1", "query": query, "results": [], "count": 0},
        timeout=4.0,
    )
    results = payload.get("results") if isinstance(payload.get("results"), list) else []
    cards: list[dict[str, Any]] = []
    has_snippets = any(str(item.get("snippet") or "").strip() for item in results if isinstance(item, dict))
    for item in results[:5]:
        if not isinstance(item, dict):
            continue
        path = str(item.get("path") or "").strip()
        name = str(item.get("name") or item.get("title") or path).strip()
        if not path:
            continue
        cards.append(ai_action_card(
            f"Ouvrir {name}" if language == "fr" else f"Open {name}",
            str(item.get("source") or item.get("ext") or path),
            f"xdg-open {shlex.quote(path)}",
            risk="low",
        ))
    count = int(payload.get("count") or len(results))
    if count:
        summary = (
            f"J’ai trouvé {count} résultat(s) localement pour « {query} »."
            if language == "fr"
            else f"I found {count} local result(s) for “{query}”."
        )
        names: list[str] = []
        compact_results: list[dict[str, Any]] = []
        for item in results[:5]:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name") or item.get("title") or item.get("path") or "").strip()
            snippet = str(item.get("snippet") or "").strip()
            score = item.get("score")
            ext = str(item.get("ext") or "").strip()
            if snippet:
                names.append(f"{name} : {snippet[:110]}")
            elif score is not None:
                names.append(f"{name} · {ext or 'document'} · score {score}")
            else:
                names.append(name)
            compact_results.append({
                "name": name,
                "path": item.get("path"),
                "ext": ext,
                "score": score,
                "matched_fields": item.get("matched_fields", []),
                "snippet": snippet[:220] if snippet else "",
            })
        chat_answer = (
            f"J’ai trouvé {count} résultat(s) dans l’index local pour « {query} ». Je classe d’abord les noms, titres, extraits et fichiers récents."
            if language == "fr"
            else f"I found {count} result(s) in the local index for “{query}”. I rank names, titles, snippets and recent files first."
        )
        chat_bullets = names
        if not has_snippets:
            cards.append(ai_action_card(
                "Activer les extraits locaux" if language == "fr" else "Enable local snippets",
                "Scanner les sources approuvées avec de courts extraits pour permettre les résumés." if language == "fr" else "Scan approved sources with short snippets to enable summaries.",
                "seven ai learning scan --content --json",
                risk="low",
            ))
    else:
        summary = (
            f"Je n’ai rien trouvé dans l’index local pour « {query} ». Tu peux lancer un scan local si le dossier n’est pas encore indexé."
            if language == "fr"
            else f"I found nothing in the local index for “{query}”. You can run a local scan if the folder is not indexed yet."
        )
        chat_answer = (
            f"Je n’ai rien trouvé pour « {query} » dans l’index local."
            if language == "fr"
            else f"I found nothing for “{query}” in the local index."
        )
        chat_bullets = [
            "L’index reste local et metadata-only." if language == "fr" else "The index stays local and metadata-only.",
            "Tu peux lancer un scan si le dossier n’est pas encore indexé." if language == "fr" else "You can run a scan if the folder is not indexed yet.",
        ]
        cards.append(ai_action_card(
            "Scanner le contexte local" if language == "fr" else "Scan local context",
            "Indexation metadata-only des sources approuvées." if language == "fr" else "Metadata-only indexing of approved sources.",
            "seven ai learning scan --json",
            risk="low",
        ))
        compact_results = []
    return {
        "applied": False,
        "query": query,
        "summary": summary,
        "chat": {
            "title": "Recherche locale" if language == "fr" else "Local search",
            "answer": chat_answer,
            "bullets": [item for item in chat_bullets if str(item).strip()][:5],
        },
        "results": compact_results if count else [],
        "raw_results": results[:8] if os.environ.get("SEVENAI_VERBOSE") == "1" else [],
        "count": count,
        "ranking": payload.get("ranking", {}),
        "recommendations": cards,
        "privacy": "local-index-only; no web or cloud call",
    }


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
    shell_context: dict[str, Any] = {}
    try:
        shell_context = json.loads(WAYBAR_CONTEXT_FILE.read_text(encoding="utf-8") or "{}")
    except Exception:
        shell_context = {}
    return {
        "schema": "sevenos.ai.context.v1",
        "load": {"1m": load[0], "5m": load[1], "15m": load[2]},
        "process_sample": processes[:25],
        "active_window": active_window,
        "shell_context": shell_context if shell_context.get("schema") == "sevenos.waybar.context.v1" else {},
    }


def active_context_answer(language: str) -> dict[str, Any]:
    context = system_context()
    profile = current_profile()
    theme = current_theme()
    window = context.get("active_window") if isinstance(context.get("active_window"), dict) else {}
    window_title = str(window.get("title") or window.get("initialTitle") or "").strip()
    window_class = str(window.get("class") or window.get("initialClass") or "").strip()
    workspace = window.get("workspace") if isinstance(window.get("workspace"), dict) else {}
    workspace_name = str(workspace.get("name") or workspace.get("id") or "").strip()
    load = context.get("load") if isinstance(context.get("load"), dict) else {}
    focus = window_class or window_title or ("aucune fenêtre active" if language == "fr" else "no active window")

    if language == "fr":
        summary = (
            f"Contexte actuel : {profile.get('title', 'SevenOS')} en thème {theme.get('mode', 'dark')}. "
            f"Fenêtre active : {focus}. Espace : {workspace_name or 'non détecté'}. "
            f"Charge 1 min : {float(load.get('1m') or 0):.2f}."
        )
        chat_answer = f"Tu es dans {profile.get('title', 'SevenOS')} avec {focus} au premier plan."
        chat_bullets = [
            f"Thème : {theme.get('mode', 'dark')}.",
            f"Espace : {workspace_name or 'non détecté'}.",
            f"Charge système : {float(load.get('1m') or 0):.2f}.",
        ]
    else:
        summary = (
            f"Current context: {profile.get('title', 'SevenOS')} using {theme.get('mode', 'dark')} theme. "
            f"Active window: {focus}. Workspace: {workspace_name or 'unknown'}. "
            f"1 min load: {float(load.get('1m') or 0):.2f}."
        )
        chat_answer = f"You are in {profile.get('title', 'SevenOS')} with {focus} in front."
        chat_bullets = [
            f"Theme: {theme.get('mode', 'dark')}.",
            f"Workspace: {workspace_name or 'unknown'}.",
            f"System load: {float(load.get('1m') or 0):.2f}.",
        ]

    recommendations: list[dict[str, Any]] = []
    normalized_focus = normalize(f"{window_class} {window_title}")
    if any(token in normalized_focus for token in ("code", "vscode", "codium")):
        recommendations.extend([
            ai_action_card("Préparer Forge" if language == "fr" else "Prepare Forge", "Adapter SevenOS au développement via un parcours guidé." if language == "fr" else "Adapt SevenOS for development through a guided route.", "seven ai 'mission forge'", risk="low"),
            ai_action_card("Chercher dans le projet" if language == "fr" else "Search project", "Utiliser l’index local SevenAI." if language == "fr" else "Use the local SevenAI index.", "seven ai learning search code --json"),
        ])
    elif any(token in normalized_focus for token in ("firefox", "chromium", "browser")):
        recommendations.extend([
            ai_action_card("Préparer Atlas" if language == "fr" else "Prepare Atlas", "Passer en contexte recherche et documentation via un parcours guidé." if language == "fr" else "Switch to research and documentation through a guided route.", "seven ai 'mission atlas'", risk="low"),
            ai_action_card("Résumer le contexte local" if language == "fr" else "Summarize local context", "Chercher les notes et documents liés." if language == "fr" else "Search related notes and documents.", "seven ai learning search notes --json"),
        ])
    elif any(token in normalized_focus for token in ("seven-files", "nautilus", "files")):
        recommendations.append(ai_action_card(
            "Analyser le stockage" if language == "fr" else "Analyze storage",
            "Comprendre disque, dossiers et volumes montés." if language == "fr" else "Understand disk, folders and mounted volumes.",
            "seven ai diagnose disk --json",
        ))
    else:
        recommendations.extend([
            ai_action_card("Demander les prochaines actions" if language == "fr" else "Ask for next actions", "SevenAI prépare des cartes utiles sans rien appliquer." if language == "fr" else "SevenAI prepares useful cards without applying anything.", "seven ai 'que dois-je faire maintenant'"),
            ai_action_card("Ouvrir les paramètres" if language == "fr" else "Open Settings", "Ajuster le système depuis une surface stable." if language == "fr" else "Adjust the system from a stable surface.", "seven ai 'ouvre les paramètres'"),
        ])

    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Contexte actuel" if language == "fr" else "Current context",
            "answer": chat_answer,
            "bullets": chat_bullets[:5],
        },
        "context": {
            "profile": profile,
            "theme": theme,
            "active_window": window,
            "load": load,
        },
        "recommendations": recommendations[:4],
    }


def active_app_assist_answer(language: str) -> dict[str, Any]:
    base = active_context_answer(language)
    context = base.get("context") if isinstance(base.get("context"), dict) else {}
    window = context.get("active_window") if isinstance(context.get("active_window"), dict) else {}
    window_title = str(window.get("title") or window.get("initialTitle") or "").strip()
    window_class = str(window.get("class") or window.get("initialClass") or "").strip()
    focus = window_class or window_title or ("cette fenêtre" if language == "fr" else "this window")
    recommendations = base.get("recommendations") if isinstance(base.get("recommendations"), list) else []
    if language == "fr":
        summary = (
            f"Je vois {focus}. Je peux t’aider avec cette fenêtre en proposant des actions adaptées au contexte, "
            "sans appliquer de changement système automatiquement."
        )
        chat_answer = f"Je vois {focus}. Je peux t’aider à partir de cette fenêtre."
        chat_bullets = [
            "Je propose des actions adaptées au contexte actif.",
            "Les changements système restent en aperçu ou confirmation.",
        ]
    else:
        summary = (
            f"I see {focus}. I can help with this window by proposing context-aware actions "
            "without applying system changes automatically."
        )
        chat_answer = f"I see {focus}. I can help from this window."
        chat_bullets = [
            "I suggest actions adapted to the active context.",
            "System changes stay in preview or confirmation.",
        ]
    if not recommendations:
        recommendations = [
            ai_action_card(
                "Résumer le contexte" if language == "fr" else "Summarize context",
                "Relire l’état actuel de session." if language == "fr" else "Review the current session state.",
                "seven ai 'quel est mon contexte actuel'",
            )
        ]
    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Aide contextuelle" if language == "fr" else "Context help",
            "answer": chat_answer,
            "bullets": chat_bullets[:5],
        },
        "context": context,
        "recommendations": recommendations[:4],
    }


def agent_handoff_answer(text: str, language: str) -> dict[str, Any]:
    handoffs = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "handoffs", "--json"],
        {"schema": "sevenos.ai-handoffs.v1", "state": "unknown", "handoffs": []},
        timeout=4.0,
    )
    permissions_payload = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "permissions", "--json"],
        {"schema": "sevenos.ai-permission-graph.v1", "state": "unknown", "graph": []},
        timeout=4.0,
    )
    agents = handoffs.get("handoffs") if isinstance(handoffs.get("handoffs"), list) else []
    permissions_graph = permissions_payload.get("graph") if isinstance(permissions_payload.get("graph"), list) else []
    permissions_by_agent = {
        str(item.get("agent")): item
        for item in permissions_graph
        if isinstance(item, dict) and item.get("agent")
    }
    context = system_context()
    profile = current_profile()
    window = context.get("active_window") if isinstance(context.get("active_window"), dict) else {}
    active_focus = f"{window.get('class', '')} {window.get('initialClass', '')} {window.get('title', '')} {window.get('initialTitle', '')}"
    query_norm = normalize(f"{text} {active_focus} {profile.get('key', '')}")
    scored: list[dict[str, Any]] = []
    domain_boosts = {
        "forge": ("coder", "code", "python", "rust", "node", "git", "compiler", "developper", "développer", "docker", "podman"),
        "studio": ("video", "vidéo", "montage", "audio", "musique", "blender", "krita", "gimp", "obs", "streamer", "design"),
        "shield": ("analyser le reseau", "analyser le réseau", "analyse reseau", "analyse réseau", "audit", "securite", "sécurité", "pentest", "forensic", "malware", "firewall", "pare-feu"),
        "atlas": ("document", "pdf", "ocr", "recherche", "chercher", "cartographie", "carte", "veille", "knowledge"),
        "baobab": ("baobab", "culture", "afrique", "africaine", "africain", "langue", "patrimoine", "rite", "rituel"),
        "pulse": ("jouer", "jeu", "gaming", "steam", "proton", "lutris", "fps", "game"),
        "equinox": ("regler mon systeme", "régler mon système", "mettre a jour", "mettre à jour", "reparer sevenos", "réparer sevenos", "parametres", "paramètres"),
    }

    for agent in agents:
        if not isinstance(agent, dict):
            continue
        score = 0
        reasons: list[str] = []
        profile_key = str(agent.get("profile") or "")
        if profile_key and profile_key == str(profile.get("key") or ""):
            score += 5
            reasons.append("profil actif" if language == "fr" else "active profile")
        for phrase in domain_boosts.get(profile_key, ()):
            if normalize(phrase) in query_norm:
                score += 12
                reasons.append(phrase)
        for trigger in agent.get("triggers") or []:
            trigger_norm = normalize(str(trigger))
            if trigger_norm and trigger_norm in query_norm:
                score += 10
                reasons.append(str(trigger))
        for capability in agent.get("capabilities") or []:
            capability_norm = normalize(str(capability).replace("-", " "))
            if capability_norm and any(part in query_norm for part in capability_norm.split() if len(part) > 3):
                score += 5
                reasons.append(str(capability))
        for signal in agent.get("context_signals") or []:
            signal_norm = normalize(str(signal).replace("app:", "").replace("active_profile:", "").replace("issue:", "").replace("file:", ""))
            if signal_norm and signal_norm in query_norm:
                score += 4
                reasons.append(str(signal))
        if not score and str(agent.get("agent")) == "equinox.system":
            score = 2
            reasons.append("agent système par défaut" if language == "fr" else "default system agent")
        if score:
            item = dict(agent)
            item["score"] = score
            item["reasons"] = list(dict.fromkeys(reasons))[:6]
            scored.append(item)

    scored.sort(key=lambda item: int(item.get("score") or 0), reverse=True)
    selected = scored[0] if scored else {}
    agent_name = selected.get("name") or selected.get("agent") or ("Equinox System Steward" if language == "fr" else "Equinox System Steward")
    agent_id = str(selected.get("agent") or "equinox.system")
    selected_permissions = permissions_by_agent.get(agent_id, {})
    risk = str(selected.get("risk") or "low")
    if language == "fr":
        summary = (
            f"Je routerais cette demande vers {agent_name}. "
            f"Raison : {', '.join(selected.get('reasons') or ['c’est le meilleur contexte détecté'])}."
        )
        if risk == "high":
            summary += " Agent sensible : SevenAI reste en aperçu et demande confirmation pour les actions à risque."
    else:
        summary = (
            f"I would route this request to {agent_name}. "
            f"Reason: {', '.join(selected.get('reasons') or ['best detected context'])}."
        )
        if risk == "high":
            summary += " Sensitive agent: SevenAI stays in preview and requires confirmation for risky actions."

    recommendations: list[dict[str, Any]] = []
    status_command = str(selected.get("status_command") or "").strip()
    if status_command:
        recommendations.append(ai_action_card(
            "Vérifier cet agent" if language == "fr" else "Check this agent",
            agent_name,
            status_command,
            risk=str(selected.get("risk") or "low"),
        ))
    profile_commands = {
        "equinox": ("Ouvrir les réglages" if language == "fr" else "Open Settings", "seven ai 'ouvre les paramètres'"),
        "forge": ("Préparer Forge" if language == "fr" else "Prepare Forge", "seven ai 'mission forge'"),
        "studio": ("Préparer Studio" if language == "fr" else "Prepare Studio", "seven ai 'mission studio'"),
        "shield": ("Préparer Shield" if language == "fr" else "Prepare Shield", "seven ai 'mission shield'"),
        "atlas": ("Préparer Atlas" if language == "fr" else "Prepare Atlas", "seven ai 'mission atlas'"),
        "baobab": ("Préparer Baobab" if language == "fr" else "Prepare Baobab", "seven ai 'mission baobab'"),
        "pulse": ("Préparer Pulse" if language == "fr" else "Prepare Pulse", "seven ai 'mission pulse'"),
    }
    selected_profile = str(selected.get("profile") or "").lower()
    if selected_profile in profile_commands:
        title, command = profile_commands[selected_profile]
        recommendations.append(ai_action_card(
            title,
            "Créer un parcours guidé adapté à cette demande." if language == "fr" else "Create a guided route for this request.",
            command,
            risk="low",
        ))
    recommendations.append(ai_action_card(
        "Voir le contexte actif" if language == "fr" else "View active context",
        "Relier la demande à la fenêtre et au Mini OS courant." if language == "fr" else "Connect the request to the current window and Mini OS.",
        "seven ai 'quel est mon contexte actuel'",
    ))
    recommendations.append(ai_action_card(
        "Voir toutes les routes SevenAI" if language == "fr" else "View all SevenAI routes",
        "Inspecter les agents, capacités et déclencheurs." if language == "fr" else "Inspect agents, capabilities and triggers.",
        "seven ai handoffs --json",
    ))

    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Routage agent" if language == "fr" else "Agent routing",
            "answer": (
                f"Je confierais cette demande à {agent_name}."
                if language == "fr"
                else f"I would hand this request to {agent_name}."
            ),
            "bullets": [
                (
                    "Raison : " + ", ".join(selected.get("reasons") or ["meilleur contexte détecté"])
                    if language == "fr"
                    else "Reason: " + ", ".join(selected.get("reasons") or ["best detected context"])
                ),
                (
                    f"Risque : { {'low': 'faible', 'medium': 'moyen', 'high': 'élevé'}.get(risk, risk) }."
                    if language == "fr"
                    else f"Risk: {risk}."
                ),
                (
                    "Exécution : aperçu et confirmation pour les actions sensibles."
                    if language == "fr"
                    else "Execution: preview and confirmation for sensitive actions."
                ),
            ],
        },
        "selected_agent": {
            "id": agent_id,
            "name": agent_name,
            "profile": selected.get("profile"),
            "risk": selected.get("risk"),
            "mission": selected.get("mission"),
            "score": selected.get("score", 0),
            "reasons": selected.get("reasons", []),
            "capabilities": selected.get("capabilities", [])[:8],
            "surfaces": selected.get("surfaces", [])[:6],
        },
        "permission_summary": {
            "state": permissions_payload.get("state", "unknown"),
            "execution": (permissions_payload.get("default") or {}).get("execution", "preview") if isinstance(permissions_payload.get("default"), dict) else "preview",
            "allowed": selected_permissions.get("allowed", [])[:8] if isinstance(selected_permissions, dict) else [],
            "confirm": selected_permissions.get("confirm", [])[:8] if isinstance(selected_permissions, dict) else [],
            "denied": selected_permissions.get("denied", [])[:8] if isinstance(selected_permissions, dict) else [],
            "sensitive_confirmed": selected_permissions.get("sensitive_confirmed", [])[:8] if isinstance(selected_permissions, dict) else [],
        },
        "alternatives": [
            {
                "id": item.get("agent"),
                "name": item.get("name"),
                "profile": item.get("profile"),
                "score": item.get("score"),
                "reasons": item.get("reasons", [])[:4],
            }
            for item in scored[1:4]
        ],
        "context": {
            "profile": profile,
            "active_window": window,
        },
        "recommendations": recommendations[:4],
        "contract": "local-routing · preview-only · no system change",
    }


def agent_status_answer(language: str) -> dict[str, Any]:
    runtime = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "runtime", "--json"],
        {"schema": "sevenos.ai-runtime.v1", "state": "unknown", "registry": {}, "policy": {}, "ledger": {}, "issues": []},
        timeout=4.0,
    )
    agents_payload = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "agents", "--json"],
        {"schema": "sevenos.ai-agents.v1", "state": "unknown", "summary": {}, "agents": []},
        timeout=4.0,
    )
    permissions = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "permissions", "--json"],
        {"schema": "sevenos.ai-permission-graph.v1", "state": "unknown", "issues": [], "graph": []},
        timeout=4.0,
    )
    coverage = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "coverage", "--json"],
        {"schema": "sevenos.ai-agent-coverage.v1", "state": "unknown", "score": 0, "summary": {}, "issues": []},
        timeout=4.0,
    )
    contracts = run_json(
        [str(ROOT_DIR / "scripts/ai.sh"), "contracts", "--json"],
        {"schema": "sevenos.ai-interaction-contracts.v1", "state": "unknown", "score": 0, "summary": {}, "issues": []},
        timeout=4.0,
    )
    agents = agents_payload.get("agents") if isinstance(agents_payload.get("agents"), list) else []
    registry = runtime.get("registry") if isinstance(runtime.get("registry"), dict) else {}
    policy = runtime.get("policy") if isinstance(runtime.get("policy"), dict) else {}
    ledger = runtime.get("ledger") if isinstance(runtime.get("ledger"), dict) else {}
    permission_issues = permissions.get("issues") if isinstance(permissions.get("issues"), list) else []
    coverage_summary = coverage.get("summary") if isinstance(coverage.get("summary"), dict) else {}
    coverage_issues = coverage.get("issues") if isinstance(coverage.get("issues"), list) else []
    compact_agents: list[dict[str, Any]] = []
    for agent in agents:
        if not isinstance(agent, dict):
            continue
        compact_agents.append({
            "id": agent.get("id"),
            "name": agent.get("name"),
            "profile": agent.get("profile"),
            "state": agent.get("state"),
            "risk": agent.get("risk"),
            "mission": agent.get("mission"),
            "capabilities": (agent.get("capabilities") or [])[:5] if isinstance(agent.get("capabilities"), list) else [],
        })

    total = int(registry.get("agents") or len(compact_agents) or 0)
    ready = int(registry.get("ready") or sum(1 for item in compact_agents if item.get("state") == "ready"))
    high_risk = sum(1 for item in compact_agents if item.get("risk") == "high")
    ledger_events = ledger.get("events", 0)
    ledger_state = "écriture OK" if ledger.get("writable") else "lecture seule"
    coverage_state = str(coverage.get("state", "unknown"))
    coverage_score = int(coverage.get("score") or 0)
    coverage_complete = int(coverage_summary.get("complete") or 0)
    coverage_partial = int(coverage_summary.get("partial") or 0)
    contracts_state = str(contracts.get("state", "unknown"))
    contracts_score = int(contracts.get("score") or 0)
    if language == "fr":
        summary = (
            f"Agents SevenAI : {ready}/{total} prêts. "
            f"Couverture : {coverage_score}% ({coverage_complete} complet(s), {coverage_partial} partiel(s)). "
            f"Contrats UI : {contracts_score}%. "
            f"{high_risk} agent(s) sensible(s). Permissions : {permissions.get('state', 'unknown')}. "
            f"Journal : {ledger_events} événement(s), {ledger_state}."
        )
    else:
        ledger_state = "writable" if ledger.get("writable") else "read-only"
        summary = (
            f"SevenAI agents: {ready}/{total} ready. "
            f"Coverage: {coverage_score}% ({coverage_complete} complete, {coverage_partial} partial). "
            f"UI contracts: {contracts_score}%. "
            f"{high_risk} sensitive agent(s). Permissions: {permissions.get('state', 'unknown')}. "
            f"Ledger: {ledger_events} event(s), {ledger_state}."
        )

    recommendations = [
        ai_action_card(
            "Voir les contrats UI" if language == "fr" else "View UI contracts",
            "Contrôler réponse, raccourcis, surfaces et confirmations SevenAI." if language == "fr" else "Review SevenAI response, shortcuts, surfaces and confirmations.",
            "seven ai contracts --json",
        ),
        ai_action_card(
            "Voir la couverture agents" if language == "fr" else "View agent coverage",
            "Vérifier surfaces, outils, capacités et garde-fous par agent." if language == "fr" else "Check surfaces, tools, capabilities and safeguards per agent.",
            "seven ai coverage --json",
        ),
        ai_action_card(
            "Voir les routes agents" if language == "fr" else "View agent routes",
            "Comprendre quel agent prend chaque domaine." if language == "fr" else "Understand which agent owns each domain.",
            "seven ai handoffs --json",
        ),
        ai_action_card(
            "Voir les permissions" if language == "fr" else "View permissions",
            "Contrôler les actions autorisées, confirmées et interdites." if language == "fr" else "Review allowed, confirmed and denied actions.",
            "seven ai permissions --json",
        ),
        ai_action_card(
            "Voir le journal SevenAI" if language == "fr" else "View SevenAI ledger",
            "Relire les actions prévisualisées ou appliquées." if language == "fr" else "Review previewed or applied actions.",
            "seven ai ledger --json",
        ),
    ]
    if coverage_state != "ready" or coverage_issues:
        recommendations.insert(0, ai_action_card(
            "Compléter la couverture agents" if language == "fr" else "Complete agent coverage",
            f"{len(coverage_issues)} point(s) de couverture à revoir." if language == "fr" else f"{len(coverage_issues)} coverage issue(s) to review.",
            "seven ai coverage --json",
            risk="medium",
        ))
    if permission_issues:
        recommendations.insert(0, ai_action_card(
            "Corriger les permissions agents" if language == "fr" else "Fix agent permissions",
            f"{len(permission_issues)} souci(s) détecté(s)." if language == "fr" else f"{len(permission_issues)} issue(s) detected.",
            "seven ai permissions --json",
            risk="medium",
        ))

    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Agents SevenAI" if language == "fr" else "SevenAI agents",
            "answer": (
                f"{ready}/{total} agents sont prêts. SevenAI garde les actions sensibles sous confirmation."
                if language == "fr"
                else f"{ready}/{total} agents are ready. SevenAI keeps sensitive actions behind confirmation."
            ),
            "bullets": [
                (
                    f"Agents sensibles : {high_risk}."
                    if language == "fr"
                    else f"Sensitive agents: {high_risk}."
                ),
                (
                    f"Couverture : {coverage_state}, score {coverage_score}%."
                    if language == "fr"
                    else f"Coverage: {coverage_state}, score {coverage_score}%."
                ),
                (
                    f"Contrats UI : {contracts_state}, score {contracts_score}%."
                    if language == "fr"
                    else f"UI contracts: {contracts_state}, score {contracts_score}%."
                ),
                (
                    f"Permissions : {permissions.get('state', 'unknown')}."
                    if language == "fr"
                    else f"Permissions: {permissions.get('state', 'unknown')}."
                ),
                (
                    f"Journal : {ledger_events} événement(s), {ledger_state}."
                    if language == "fr"
                    else f"Ledger: {ledger_events} event(s), {ledger_state}."
                ),
            ],
        },
        "runtime": {
            "state": runtime.get("state"),
            "policy": policy,
            "ledger": ledger,
            "issues": runtime.get("issues", []),
        },
        "agents": compact_agents,
        "permission_summary": {
            "state": permissions.get("state", "unknown"),
            "issues": permission_issues[:5],
        },
        "coverage_summary": {
            "state": coverage_state,
            "score": coverage_score,
            "complete": coverage_complete,
            "partial": coverage_partial,
            "issues": coverage_issues[:5],
        },
        "contracts_summary": {
            "state": contracts_state,
            "score": contracts_score,
            "default_surface": contracts.get("default_surface", "unknown"),
            "issues": (contracts.get("issues") if isinstance(contracts.get("issues"), list) else [])[:5],
        },
        "recommendations": recommendations[:4],
    }


def recent_activity_answer(language: str) -> dict[str, Any]:
    memory = read_memory(10)
    events = memory.get("events") if isinstance(memory.get("events"), list) else []
    top_intents = (memory.get("summary") or {}).get("top_intents") if isinstance(memory.get("summary"), dict) else []
    health = memory.get("health") if isinstance(memory.get("health"), dict) else {}
    recent = list(reversed(events))[:6]
    if not recent:
        return {
            "applied": False,
            "summary": "Je n’ai pas encore assez d’activité locale pour résumer ton usage." if language == "fr" else "I do not have enough local activity yet to summarize usage.",
            "chat": {
                "title": "Activité récente" if language == "fr" else "Recent activity",
                "answer": (
                    "Je n’ai pas encore assez d’activité locale pour dégager une tendance utile."
                    if language == "fr"
                    else "I do not have enough local activity yet to detect a useful pattern."
                ),
                "bullets": [
                    "SevenAI apprend localement, à partir des demandes et actions SevenOS."
                    if language == "fr"
                    else "SevenAI learns locally from SevenOS requests and actions.",
                    "Aucune donnée n’est envoyée en ligne par ce résumé."
                    if language == "fr"
                    else "This summary does not send data online.",
                ],
            },
            "events": [],
            "top_intents": [],
            "recommendations": [ai_action_card(
                "Demander l’état système" if language == "fr" else "Ask for system status",
                "Créer un premier événement local utile." if language == "fr" else "Create the first useful local event.",
                "seven ai \"quel est l'état de ma machine\"",
            )],
        }

    last = recent[0]
    top_label = ""
    if isinstance(top_intents, list) and top_intents:
        top_label = str(top_intents[0].get("intent") or "")
    label_map_fr = {
        "KILL_PROCESS": "fermeture d’apps",
        "OPEN_APP": "ouverture d’apps",
        "ANSWER_SYSTEM_QUESTION": "questions système",
        "LOCAL_SEARCH": "recherche locale",
        "CURRENT_CONTEXT": "contexte actif",
        "ASSIST_ACTIVE_APP": "aide contextuelle",
        "HEALTH_PLAN": "plan santé",
        "DAILY_BRIEFING": "briefing",
        "RECOMMEND_ACTIONS": "recommandations",
        "EXPLAIN_DECISION": "explication de décision",
        "MEMORY_PROFILE": "profil mémoire",
        "EXPLAIN_LEDGER": "historique SevenAI",
    }
    label_map_en = {
        "KILL_PROCESS": "app closing",
        "OPEN_APP": "app launching",
        "ANSWER_SYSTEM_QUESTION": "system questions",
        "LOCAL_SEARCH": "local search",
        "CURRENT_CONTEXT": "active context",
        "ASSIST_ACTIVE_APP": "contextual help",
        "HEALTH_PLAN": "health plan",
        "DAILY_BRIEFING": "briefing",
        "RECOMMEND_ACTIONS": "recommendations",
        "EXPLAIN_DECISION": "decision explanation",
        "MEMORY_PROFILE": "memory profile",
        "EXPLAIN_LEDGER": "SevenAI history",
    }
    top_human = (label_map_fr if language == "fr" else label_map_en).get(top_label, top_label)
    last_human = (label_map_fr if language == "fr" else label_map_en).get(str(last.get("intent") or ""), str(last.get("intent") or "intent"))

    if language == "fr":
        summary = (
            f"Activité récente : dernière demande « {last.get('input', '')} » "
            f"({last_human}). Tendance dominante : {top_human or 'encore légère'}. "
            f"Mémoire locale : {health.get('total_events', len(events))} événement(s)."
        )
    else:
        summary = (
            f"Recent activity: latest request “{last.get('input', '')}” "
            f"({last_human}). Dominant pattern: {top_human or 'still light'}. "
            f"Local memory: {health.get('total_events', len(events))} event(s)."
        )

    recommendations: list[dict[str, Any]] = []
    last_input = str(last.get("input") or "").strip()
    if last_input:
        recommendations.append(ai_action_card(
            "Continuer le dernier sujet" if language == "fr" else "Continue last topic",
            last_input[:140],
            f"seven ai {shlex.quote(last_input)}",
            risk="low",
        ))
    recommendations.append(ai_action_card(
        "Voir les prochaines actions" if language == "fr" else "Show next actions",
        "Transformer l’activité récente en suggestions concrètes." if language == "fr" else "Turn recent activity into concrete suggestions.",
        "seven ai \"que dois-je faire maintenant\"",
        risk="low",
    ))
    if health.get("retention") == "compact-recommended":
        recommendations.append(ai_action_card(
            "Compacter la mémoire SevenAI" if language == "fr" else "Compact SevenAI memory",
            "Réduire les événements trop anciens sans perdre l’usage récent." if language == "fr" else "Reduce old events without losing recent usage.",
            "seven ai memory --compact --json",
            risk="low",
        ))
    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Activité récente" if language == "fr" else "Recent activity",
            "answer": (
                f"Dernière demande : « {last.get('input', '')} »."
                if language == "fr"
                else f"Latest request: “{last.get('input', '')}”."
            ),
            "bullets": [
                (
                    f"Tendance dominante : {top_human or 'encore légère'}."
                    if language == "fr"
                    else f"Dominant pattern: {top_human or 'still light'}."
                ),
                (
                    f"Dernier type : {last_human}."
                    if language == "fr"
                    else f"Latest type: {last_human}."
                ),
                (
                    f"Mémoire locale : {health.get('total_events', len(events))} événement(s)."
                    if language == "fr"
                    else f"Local memory: {health.get('total_events', len(events))} event(s)."
                ),
            ],
        },
        "events": recent,
        "top_intents": top_intents[:6] if isinstance(top_intents, list) else [],
        "health": health,
        "recommendations": recommendations[:4],
    }


def system_health_plan(language: str) -> dict[str, Any]:
    diag = diagnostics("system")
    machine = machine_snapshot()
    brain = brain_snapshot()
    priorities: list[dict[str, Any]] = []

    def add(priority: str, title_fr: str, title_en: str, detail_fr: str, detail_en: str, command: str, *, risk: str = "low") -> None:
        priorities.append({
            "priority": priority,
            "title": title_fr if language == "fr" else title_en,
            "detail": detail_fr if language == "fr" else detail_en,
            "command": command,
            "risk": risk,
        })

    memory = diag.get("memory", {}) if isinstance(diag.get("memory"), dict) else {}
    disk_home = diag.get("disk_home", {}) if isinstance(diag.get("disk_home"), dict) else {}
    failed = diag.get("failed_units") if isinstance(diag.get("failed_units"), list) else []
    network = diag.get("network", {}) if isinstance(diag.get("network"), dict) else {}
    load = diag.get("load", {}) if isinstance(diag.get("load"), dict) else {}

    if failed:
        add(
            "high",
            "Analyser les services en erreur",
            "Analyze failed services",
            f"{len(failed)} service(s) systemd demandent attention.",
            f"{len(failed)} systemd service(s) need attention.",
            "seven ai diagnose services --json",
        )
    if str(network.get("networkmanager") or "") not in {"active", "unknown", ""}:
        add(
            "high",
            "Stabiliser le réseau",
            "Stabilize network",
            "NetworkManager n’est pas actif; éviter les installations tant que le réseau est instable.",
            "NetworkManager is not active; avoid installs while networking is unstable.",
            "seven ai 'mon wifi ne marche pas'",
            risk="medium",
        )
    if float(disk_home.get("used_percent") or 0) >= 85:
        add(
            "medium",
            "Libérer de l’espace",
            "Free storage",
            f"Espace personnel utilisé à {disk_home.get('used_percent')}%.",
            f"Home storage is {disk_home.get('used_percent')}% used.",
            "seven ai diagnose disk --json",
        )
    if float(memory.get("used_percent") or 0) >= 85:
        add(
            "medium",
            "Inspecter la mémoire",
            "Inspect memory",
            f"RAM utilisée à {memory.get('used_percent')}%.",
            f"RAM use is {memory.get('used_percent')}%.",
            "seven ai 'quels processus consomment le plus'",
        )
    if float(load.get("1m") or 0) > max(2.0, (os.cpu_count() or 2) * 0.75):
        add(
            "medium",
            "Comprendre la charge CPU",
            "Understand CPU load",
            f"Charge 1 min : {float(load.get('1m') or 0):.2f}.",
            f"1 min load: {float(load.get('1m') or 0):.2f}.",
            "seven ai diagnose system --json",
        )

    brain_issues = brain.get("issues") if isinstance(brain.get("issues"), list) else []
    issue_labels = {
        "health": ("santé système", "system health"),
        "security": ("sécurité", "security"),
        "storage": ("stockage", "storage"),
        "profiles": ("Mini OS", "Mini OS"),
        "updates": ("mises à jour", "updates"),
        "public_quality": ("qualité publique", "public quality"),
    }
    issue_detail_fr = {
        "health needs attention": "La santé système demande attention.",
        "security needs attention": "La sécurité demande attention.",
        "storage needs attention": "Le stockage demande attention.",
        "updates need attention": "Les mises à jour demandent attention.",
        "public quality needs attention": "La qualité publique demande attention.",
        "home storage is getting full": "L’espace personnel se remplit.",
        "home storage is almost full": "L’espace personnel approche de la limite.",
    }

    def localized_issue_detail(detail: str, state: str) -> str:
        if language != "fr":
            return detail or f"State: {state}."
        normalized = detail.strip().lower()
        if not normalized:
            return f"État : {state}."
        if normalized in issue_detail_fr:
            return issue_detail_fr[normalized]
        if "storage" in normalized and ("full" in normalized or "attention" in normalized):
            return "Le stockage demande attention."
        if "security" in normalized and "attention" in normalized:
            return "La sécurité demande attention."
        if "health" in normalized and "attention" in normalized:
            return "La santé système demande attention."
        if "update" in normalized and "attention" in normalized:
            return "Les mises à jour demandent attention."
        return detail
    for issue in brain_issues[:3]:
        if isinstance(issue, dict):
            key = str(issue.get("key") or issue.get("domain") or "system")
            state = str(issue.get("state") or "attention")
            detail = str(issue.get("detail") or "")
        else:
            key = str(issue)
            state = "attention"
            detail = ""
        label_fr, label_en = issue_labels.get(key, (key, key))
        add(
            "low",
            f"Vérifier {label_fr}",
            f"Check {label_en}",
            localized_issue_detail(detail, state),
            detail or f"State: {state}.",
            f"seven ai diagnose {shlex.quote(key)} --json",
        )

    if not priorities:
        add(
            "low",
            "Conserver l’état actuel",
            "Keep current state",
            "Aucun blocage immédiat détecté. Surveille mises à jour, sauvegarde et espace disque.",
            "No immediate blocker detected. Keep watching updates, backups and storage.",
            "seven ai 'que dois-je faire maintenant'",
        )

    priority_score = {"high": 35, "medium": 18, "low": 7}
    penalty = sum(priority_score.get(str(item.get("priority")), 0) for item in priorities[:5])
    score = max(0, min(100, 100 - penalty))
    top = priorities[0]
    if language == "fr":
        summary = f"Plan santé SevenOS : score {score}/100. Priorité : {top['title']}."
    else:
        summary = f"SevenOS health plan: score {score}/100. Priority: {top['title']}."

    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Plan santé" if language == "fr" else "Health plan",
            "answer": (
                f"Score santé {score}/100. Je commencerais par : {top['title']}."
                if language == "fr"
                else f"Health score {score}/100. I would start with: {top['title']}."
            ),
            "bullets": [
                f"{str(item.get('priority', 'low')).upper()} · {item.get('title')} — {item.get('detail')}"
                for item in priorities[:4]
            ],
        },
        "score": score,
        "priorities": priorities[:6],
        "diagnostics": {
            "memory": memory,
            "disk_home": disk_home,
            "failed_units": failed,
            "network": network,
            "load": load,
        },
        "machine": {
            "battery": machine.get("battery", {}),
            "windows": machine.get("windows", [])[:5],
        },
        "recommendations": [
            ai_action_card(item["title"], item["detail"], item["command"], risk=str(item.get("risk") or "low"))
            for item in priorities[:4]
        ],
        "playbooks": {
            "slow_system": playbook("slow_system"),
            "failed_services": playbook("failed_services"),
            "disk_cleanup": playbook("disk_cleanup"),
        },
    }


def daily_briefing_answer(language: str) -> dict[str, Any]:
    brain = brain_snapshot()
    context = active_context_answer(language)
    health = system_health_plan(language)
    activity = recent_activity_answer(language)
    mission = mission_status(language)
    preferences = preferences_summary(language)
    profile = brain.get("profile") if isinstance(brain.get("profile"), dict) else {}
    theme = brain.get("theme") if isinstance(brain.get("theme"), dict) else {}
    machine = brain.get("machine") if isinstance(brain.get("machine"), dict) else {}
    battery = machine.get("battery") if isinstance(machine.get("battery"), dict) else {}
    disk = machine.get("disk") if isinstance(machine.get("disk"), dict) else {}
    home = disk.get("home") if isinstance(disk.get("home"), dict) else {}
    now = time.localtime()
    hour = now.tm_hour
    theme_mode = str(theme.get("mode") or "actuel")
    battery_status = str(battery.get("status") or "état inconnu")
    if language == "fr":
        moment = "matin" if hour < 12 else "après-midi" if hour < 18 else "soir"
        title = f"Briefing du {moment}"
        theme_mode = {"dark": "sombre", "light": "clair"}.get(theme_mode, theme_mode)
        battery_status = {
            "Discharging": "sur batterie",
            "Charging": "en charge",
            "Full": "chargée",
            "Not charging": "branchée",
        }.get(battery_status, battery_status)
        summary = (
            f"{title} : {profile.get('title', 'SevenOS')} est en mode {theme_mode}. "
            f"Score santé {health.get('score', brain.get('score', 0))}/100. "
            f"Priorité : {(health.get('priorities') or [{}])[0].get('title', 'aucune urgence')}."
        )
        if battery.get("present"):
            summary += f" Batterie {battery.get('capacity', '?')}% ({battery_status})."
        if home:
            summary += f" Espace libre : {home.get('free_gb', '?')} GiB."
    else:
        moment = "morning" if hour < 12 else "afternoon" if hour < 18 else "evening"
        title = f"{moment.title()} briefing"
        summary = (
            f"{title}: {profile.get('title', 'SevenOS')} is using {theme_mode} mode. "
            f"Health score {health.get('score', brain.get('score', 0))}/100. "
            f"Priority: {(health.get('priorities') or [{}])[0].get('title', 'no urgent issue')}."
        )
        if battery.get("present"):
            summary += f" Battery {battery.get('capacity', '?')}% ({battery.get('status', 'unknown')})."
        if home:
            summary += f" Free space: {home.get('free_gb', '?')} GiB."

    recommendations: list[dict[str, Any]] = []
    localized_brain = {"recommendations": brain_recommendations(brain, language=language)}
    seen_commands: set[str] = set()
    for source in (mission, health, localized_brain, context, activity):
        cards = source.get("recommendations") if isinstance(source, dict) else []
        if isinstance(cards, list):
            for card in cards:
                if isinstance(card, dict) and card.get("title") and card.get("command"):
                    command = str(card.get("command") or "")
                    if command not in seen_commands:
                        seen_commands.add(command)
                        recommendations.append(card)
                if len(recommendations) >= 6:
                    break
        if len(recommendations) >= 6:
            break

    chat_bullets: list[str] = []
    mission_progress = (mission.get("progress") if isinstance(mission, dict) else {}) or {}
    mission_next_step = mission_progress.get("next_step") if isinstance(mission_progress.get("next_step"), dict) else {}
    mission_next = str(mission_next_step.get("title") or mission_progress.get("next") or "").strip()
    if mission_progress.get("total_steps"):
        percent = mission_progress.get("percent", 0)
        chat_bullets.append(
            f"Mission : {percent}% · {mission_next or 'aucune étape immédiate'}"
            if language == "fr"
            else f"Mission: {percent}% · {mission_next or 'no immediate step'}"
        )
    health_priority = ((health.get("priorities") or [{}])[0] if isinstance(health, dict) else {})
    if health_priority.get("title"):
        chat_bullets.append(
            f"Santé : {health_priority.get('title')}"
            if language == "fr"
            else f"Health: {health_priority.get('title')}"
        )
    if isinstance(preferences, dict) and preferences.get("summary"):
        chat_bullets.append(str(preferences.get("summary")))
    if home:
        chat_bullets.append(
            f"Espace libre : {home.get('free_gb', '?')} GiB."
            if language == "fr"
            else f"Free space: {home.get('free_gb', '?')} GiB."
        )

    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": title,
            "answer": summary,
            "bullets": [item for item in chat_bullets if str(item).strip()][:5],
        },
        "title": title,
        "profile": profile,
        "theme": theme,
        "health": {
            "score": health.get("score"),
            "priorities": health.get("priorities", [])[:4],
        },
        "context": context.get("context", {}) if isinstance(context, dict) else {},
        "activity": {
            "summary": activity.get("summary") if isinstance(activity, dict) else "",
            "top_intents": activity.get("top_intents", [])[:4] if isinstance(activity, dict) else [],
        },
        "mission": {
            "summary": mission.get("summary") if isinstance(mission, dict) else "",
            "progress": mission.get("progress", {}) if isinstance(mission, dict) else {},
        },
        "preferences": {
            "summary": preferences.get("summary") if isinstance(preferences, dict) else "",
            "count": preferences.get("count", 0) if isinstance(preferences, dict) else 0,
            "items": preferences.get("preferences", [])[:4] if isinstance(preferences, dict) else [],
        },
        "recommendations": recommendations[:6],
    }


def recommendation_priority(card: dict[str, Any], *, index: int, language: str) -> tuple[int, str]:
    command = str(card.get("command") or "")
    title = normalize(str(card.get("title") or ""))
    detail = normalize(str(card.get("detail") or ""))
    risk = str(card.get("risk") or "low")
    score = 70 - (index * 3)
    reason = "contexte système" if language == "fr" else "system context"

    if "missions" in command or "mission" in title:
        score += 32
        reason = "mission active" if language == "fr" else "active mission"
    if any(token in command for token in ("diagnose services", "failed_services", "systemctl")) or "service" in title:
        score += 30
        reason = "services à surveiller" if language == "fr" else "services need attention"
    if "diagnose disk" in command or "storage" in command or "stockage" in title or "disque" in title:
        score += 28
        reason = "stockage à surveiller" if language == "fr" else "storage needs attention"
    if any(token in command for token in ("wifi", "network", "répare le wifi")) or "réseau" in title or "wifi" in title:
        score += 26
        reason = "réseau à stabiliser" if language == "fr" else "network needs stabilization"
    if "learning search" in command or "contexte local" in title or "local context" in title:
        score += 16
        reason = "mémoire locale utile" if language == "fr" else "useful local memory"
    if "learning scan" in command:
        score += 12
        reason = "mémoire locale à rafraîchir" if language == "fr" else "refresh local memory"
    if "model-setup" in command or "ollama" in detail or "modèle" in title:
        score += 10
        reason = "modèle local optionnel" if language == "fr" else "optional local model"
    if "footprint" in command or "empreinte" in title or "poids" in title:
        score += 24
        reason = "taille SevenOS à maîtriser" if language == "fr" else "SevenOS footprint needs control"
    if "preferences" in command:
        score -= 20
        if reason == ("contexte système" if language == "fr" else "system context"):
            reason = "préférence utilisateur" if language == "fr" else "user preference"
    if risk == "medium":
        score -= 8
    elif risk == "high":
        score -= 22
    return max(0, min(score, 100)), reason


def contextual_next_actions(language: str) -> dict[str, Any]:
    brain = brain_snapshot()
    mission = mission_status(language)
    context = active_context_answer(language)
    activity = recent_activity_answer(language)
    profile = brain.get("profile") if isinstance(brain.get("profile"), dict) else current_profile()
    recommendations = brain_recommendations(brain, language=language)
    mission_progress = mission.get("progress") if isinstance(mission.get("progress"), dict) else {}
    mission_next = mission_progress.get("next_step") if isinstance(mission_progress.get("next_step"), dict) else {}
    issues = brain.get("issues") if isinstance(brain.get("issues"), list) else []
    scored: list[dict[str, Any]] = []
    for index, card in enumerate(recommendations):
        if not isinstance(card, dict) or not card.get("title") or not card.get("command"):
            continue
        score, reason = recommendation_priority(card, index=index, language=language)
        item = dict(card)
        item["priority_score"] = max(0, min(score, 100))
        item["why"] = reason
        item["rank"] = len(scored) + 1
        scored.append(item)
    scored.sort(key=lambda item: int(item.get("priority_score") or 0), reverse=True)
    for rank, item in enumerate(scored, 1):
        item["rank"] = rank
    top = scored[0] if scored else ai_action_card(
        "Ouvrir les paramètres" if language == "fr" else "Open Settings",
        "Ajuster SevenOS depuis le centre principal." if language == "fr" else "Adjust SevenOS from the main control center.",
        "seven ai 'ouvre les paramètres'",
        risk="low",
    )
    if "priority_score" not in top:
        top["priority_score"] = 70
        top["why"] = "point d’entrée stable" if language == "fr" else "stable entry point"
        top["rank"] = 1

    bullets: list[str] = []
    if mission_progress.get("total_steps"):
        bullets.append(
            f"Mission active : {mission_progress.get('percent', 0)}%, prochaine étape {mission_next.get('title', 'à définir')}."
            if language == "fr"
            else f"Active mission: {mission_progress.get('percent', 0)}%, next step {mission_next.get('title', 'to define')}."
        )
    if issues:
        issue = issues[0]
        issue_label = human_issue_label(issue.get("detail") if isinstance(issue, dict) else issue, language)
        bullets.append(("Point à surveiller : " if language == "fr" else "Watch item: ") + issue_label)
    bullets.append(("Espace actif : " if language == "fr" else "Active space: ") + str(profile.get("title") or "SevenOS"))
    activity_summary = str(activity.get("summary") or "").strip() if isinstance(activity, dict) else ""
    if activity_summary:
        bullets.append(activity_summary[:180])

    if language == "fr":
        answer = f"Je commencerais par : {top.get('title')}."
        summary = f"Je te conseille de commencer par : {top.get('title')}. Raison : {top.get('why')}."
        title = "Prochaine action"
    else:
        answer = f"I would start with: {top.get('title')}."
        summary = f"I suggest starting with: {top.get('title')}. Reason: {top.get('why')}."
        title = "Next action"

    alternatives = [
        f"{item.get('title')} · {item.get('why')}"
        for item in scored[1:4]
        if item.get("title") and item.get("why")
    ]
    if alternatives:
        bullets.append(("Alternatives : " if language == "fr" else "Alternatives: ") + " / ".join(alternatives[:2]))

    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": title,
            "answer": answer,
            "bullets": [item for item in bullets if str(item).strip()][:5],
        },
        "primary_action": top,
        "ranked_actions": scored[:6],
        "mission": {
            "summary": mission.get("summary") if isinstance(mission, dict) else "",
            "progress": mission_progress,
        },
        "brain": {
            "state": brain.get("state"),
            "score": brain.get("score"),
            "profile": profile,
            "issues": issues[:5],
        },
        "context": context.get("context", {}) if isinstance(context, dict) else {},
        "activity": {
            "summary": activity_summary,
            "top_intents": activity.get("top_intents", [])[:4] if isinstance(activity, dict) else [],
        },
        "recommendations": scored[:6] or [top],
    }


def decision_explanation(language: str) -> dict[str, Any]:
    actions = contextual_next_actions(language)
    primary = actions.get("primary_action") if isinstance(actions.get("primary_action"), dict) else {}
    ranked = actions.get("ranked_actions") if isinstance(actions.get("ranked_actions"), list) else []
    brain = actions.get("brain") if isinstance(actions.get("brain"), dict) else {}
    mission = actions.get("mission") if isinstance(actions.get("mission"), dict) else {}
    activity = actions.get("activity") if isinstance(actions.get("activity"), dict) else {}
    title = str(primary.get("title") or ("Prochaine action" if language == "fr" else "Next action"))
    why = str(primary.get("why") or ("contexte système" if language == "fr" else "system context"))
    score = int(primary.get("priority_score") or 0)
    risk = str(primary.get("risk") or "low")
    risk_label = {
        "low": "faible",
        "medium": "moyen",
        "high": "élevé",
    }.get(risk, risk) if language == "fr" else risk
    alternatives = [
        f"{item.get('rank')}. {item.get('title')} ({item.get('why')})"
        for item in ranked[1:4]
        if isinstance(item, dict) and item.get("title")
    ]
    issues = brain.get("issues") if isinstance(brain.get("issues"), list) else []
    issue_hint = ""
    if issues:
        first_issue = issues[0]
        issue_hint = human_issue_label(first_issue.get("detail") if isinstance(first_issue, dict) else first_issue, language)
    mission_summary = str(mission.get("summary") or "").strip()
    if len(mission_summary) > 140:
        mission_summary = mission_summary[:137].rstrip(" ,.;") + "..."
    activity_summary = str(activity.get("summary") or "").strip()
    if language == "fr":
        answer = f"Je propose « {title} » parce que le signal principal est : {why}."
        bullets = [
            f"Score de priorité : {score}/100.",
            f"Niveau de risque : {risk_label}.",
        ]
        if mission_summary:
            bullets.append(f"Mission : {mission_summary[:150]}")
        if issue_hint:
            bullets.append(f"Signal système : {issue_hint}")
        if alternatives:
            bullets.append("Autres options : " + " / ".join(alternatives[:2]))
        summary = f"Décision expliquée : {title} est priorisé pour {why}."
        explain_title = "Pourquoi cette action"
    else:
        answer = f"I suggest “{title}” because the main signal is: {why}."
        bullets = [
            f"Priority score: {score}/100.",
            f"Risk level: {risk}.",
        ]
        if mission_summary:
            bullets.append(f"Mission: {mission_summary[:150]}")
        if issue_hint:
            bullets.append(f"System signal: {issue_hint}")
        if alternatives:
            bullets.append("Other options: " + " / ".join(alternatives[:2]))
        summary = f"Decision explained: {title} is prioritized for {why}."
        explain_title = "Why this action"
    if activity_summary and len(bullets) < 5:
        bullets.append(activity_summary[:180])
    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": explain_title,
            "answer": answer,
            "bullets": bullets[:5],
        },
        "primary_action": primary,
        "ranked_actions": ranked[:6],
        "evidence": {
            "brain": brain,
            "mission": mission,
            "activity": activity,
        },
        "recommendations": [primary] + [
            item for item in ranked[1:3] if isinstance(item, dict)
        ],
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
            "SevenOS est un OS personnel intelligent de nouvelle génération, avec contrôle système local, "
            "profils contextuels, cybersécurité, workflows créatifs "
            "et un langage visuel glass premium."
        )
        pillars = ["fluidité", "sécurité", "profils contextuels", "contrôle assisté par IA", "workflows création/dev/cyber"]
    else:
        summary = (
            "SevenOS is a next-generation intelligent personal OS with local-first system control, "
            "contextual profiles, cybersecurity tooling, "
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
        "primary_surfaces": ["Spotlight", "Seven Hub", "Seven Files", "SevenOS Bar", "SevenAI", "SevenShield"],
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
    runtime = model_runtime_status()
    if runtime["ollama"]["active"] and runtime["ollama"]["available"]:
        ollama_state = "active"
    elif runtime["ollama"]["available"]:
        ollama_state = "available"
    elif runtime["ollama"]["installed"]:
        ollama_state = "installed-stopped"
    else:
        ollama_state = "optional-missing"
    if runtime["llama_cpp"]["active"] and runtime["llama_cpp"]["available"]:
        llama_state = "active"
    elif runtime["llama_cpp"]["available"]:
        llama_state = "available"
    elif runtime["llama_cpp"]["installed"]:
        llama_state = "installed-needs-model"
    else:
        llama_state = "planned"
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
            {
                "key": "ollama",
                "status": ollama_state,
                "privacy": "local",
                "cost": "none",
                "network": "none",
                "model": runtime["ollama"]["model"],
                "enable": "SEVENAI_PROVIDER=ollama seven ai provider \"question\" --json",
            },
            {
                "key": "llama.cpp",
                "status": llama_state,
                "privacy": "local",
                "cost": "none",
                "network": "none",
                "model": runtime["llama_cpp"]["model"],
                "enable": "SEVENAI_PROVIDER=llama.cpp seven ai provider \"question\" --json",
            },
        ],
        "runtime": runtime,
        "web_policy": {
            "default": "disabled",
            "enable": "SEVENAI_WEB=1 seven ai web \"query\" --json",
            "storage": "Research results are cached locally under XDG_STATE_HOME/sevenos/ai.sqlite3.",
            "safety": "Do not send system context to the web unless the user explicitly asks.",
        },
    }


def model_manager(language: str | None = None) -> dict[str, Any]:
    runtime = model_runtime_status()
    actions = []
    ollama = runtime["ollama"]
    if ollama["available"]:
        state = "model-ready"
        score = 100
    elif ollama["installed"] and ollama["active"]:
        state = "model-needs-start" if not ollama["running"] else "model-needs-download"
        score = 72
    else:
        state = "fallback-ready"
        score = 86
    if ollama["installed"] and not ollama["running"]:
        actions.append({
            "key": "ollama.start",
            "title": "Start Ollama local model service",
            "command": "ollama serve",
            "safety": "USER_SERVICE",
            "apply": False,
            "reason": "Ollama is installed but not currently running.",
        })
    if ollama["running"] and not ollama["models"]:
        actions.append({
            "key": "ollama.pull.default",
            "title": "Download the default local model",
            "command": f"ollama pull {ollama['model']}",
            "safety": "NETWORK_DOWNLOAD",
            "apply": False,
            "reason": "Ollama is running but the default SevenAI model is not listed locally.",
        })
    llama_cpp = runtime["llama_cpp"]
    if llama_cpp["installed"] and not llama_cpp["model"]:
        actions.append({
            "key": "llama_cpp.model",
            "title": "Select a llama.cpp model file",
            "command": "export SEVENAI_LLAMA_MODEL=/path/to/model.gguf",
            "safety": "CONFIG",
            "apply": False,
            "reason": "llama.cpp is installed but SevenAI has no GGUF model path configured.",
        })
    language = language or active_language()
    active = str(runtime.get("active") or "seven-local")
    if language == "fr":
        if state == "model-ready":
            answer = f"Le modèle local est prêt. Provider actif : {active}."
        elif state == "model-needs-start":
            answer = "Ollama est installé mais arrêté. SevenAI utilise encore le fallback local sûr."
        elif state == "model-needs-download":
            answer = f"Ollama tourne, mais le modèle {ollama['model']} n’est pas encore disponible localement."
        else:
            answer = "SevenAI fonctionne avec le provider local déterministe. Le modèle profond reste optionnel."
        bullets = [
            f"Provider recommandé : {'Ollama' if ollama['available'] else 'seven-local'}.",
            f"Modèle cible : {ollama['model'] or 'llama3.2:3b'}.",
            "Aucune action système n’est exécutée par le modèle seul.",
        ]
        recommendations = []
        if state in {"model-needs-start", "model-needs-download"}:
            recommendations.append(ai_action_card(
                "Préparer le modèle local",
                "Démarrer Ollama puis vérifier ou télécharger le modèle cible.",
                "seven ai model-setup --apply --json",
                risk="medium",
                apply=True,
            ))
        recommendations.append(ai_action_card(
            "Tester le provider",
            "Poser une question au provider local actif.",
            "seven ai provider \"résume SevenOS\" --json",
            risk="low",
        ))
    else:
        if state == "model-ready":
            answer = f"The local model is ready. Active provider: {active}."
        elif state == "model-needs-start":
            answer = "Ollama is installed but stopped. SevenAI is still using the safe local fallback."
        elif state == "model-needs-download":
            answer = f"Ollama is running, but model {ollama['model']} is not available locally yet."
        else:
            answer = "SevenAI is using the deterministic local provider. Deep model reasoning remains optional."
        bullets = [
            f"Recommended provider: {'Ollama' if ollama['available'] else 'seven-local'}.",
            f"Target model: {ollama['model'] or 'llama3.2:3b'}.",
            "The model never executes system actions by itself.",
        ]
        recommendations = []
        if state in {"model-needs-start", "model-needs-download"}:
            recommendations.append(ai_action_card(
                "Prepare local model",
                "Start Ollama, then verify or download the target model.",
                "seven ai model-setup --apply --json",
                risk="medium",
                apply=True,
            ))
        recommendations.append(ai_action_card(
            "Test provider",
            "Ask the active local provider a question.",
            "seven ai provider \"summarize SevenOS\" --json",
            risk="low",
        ))
    return {
        "schema": "sevenos.ai.model-manager.v1",
        "state": state,
        "score": score,
        "applied": False,
        "summary": answer,
        "chat": {
            "title": "Modèle local SevenAI" if language == "fr" else "SevenAI local model",
            "answer": answer,
            "bullets": bullets,
        },
        "runtime": runtime,
        "recommended_provider": "seven-local" if not ollama["available"] else "ollama",
        "wake": "seven ai model-setup --apply --json" if state in {"model-needs-start", "model-needs-download"} else "",
        "actions": actions,
        "recommendations": recommendations,
        "guardrail": "Model providers explain and summarize. SevenAI intents, confirmations and SevenPkg still execute actions.",
    }


def wait_for_ollama(timeout: float = 12.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        runtime = model_runtime_status()
        if runtime["ollama"]["running"]:
            return True
        time.sleep(0.6)
    return False


def start_ollama_runtime() -> dict[str, Any]:
    attempts: list[dict[str, Any]] = []
    if not shutil.which("ollama"):
        return {"ok": False, "attempts": attempts, "error": "ollama is not installed"}
    if model_runtime_status()["ollama"]["running"]:
        return {"ok": True, "attempts": [{"method": "already-running", "returncode": 0}]}
    if shutil.which("systemctl"):
        result = subprocess.run(["systemctl", "--user", "start", "ollama.service"], text=True, capture_output=True, check=False, timeout=8)
        attempts.append({"method": "systemd-user", "returncode": result.returncode, "stderr": result.stderr.strip()[:500]})
        if result.returncode == 0 and wait_for_ollama(8):
            return {"ok": True, "attempts": attempts}
    log = AI_CACHE_DIR / "ollama-serve.log"
    try:
        AI_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        handle = log.open("ab")
        subprocess.Popen(["ollama", "serve"], stdout=handle, stderr=subprocess.STDOUT, start_new_session=True)
        attempts.append({"method": "background-serve", "returncode": 0, "log": str(log)})
    except Exception as exc:
        attempts.append({"method": "background-serve", "returncode": 1, "stderr": str(exc)})
    return {"ok": wait_for_ollama(12), "attempts": attempts, "log": str(log)}


def write_ai_provider_config(provider: str, model: str) -> None:
    AI_CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    AI_CONFIG_FILE.write_text(
        "\n".join([
            "# SevenAI local provider configuration",
            f"SEVENAI_PROVIDER={provider}",
            "SEVENAI_OLLAMA=1" if provider == "ollama" else "SEVENAI_OLLAMA=0",
            f"SEVENAI_OLLAMA_MODEL={model}",
            "",
        ]),
        encoding="utf-8",
    )


def setup_model_runtime(*, apply: bool, language: str | None = None) -> dict[str, Any]:
    runtime_before = model_runtime_status()
    language = language or active_language()
    model = runtime_before["ollama"]["model"] or "llama3.2:3b"
    plan = [
        {"step": "check", "title": "Check Ollama runtime", "state": "ready" if runtime_before["ollama"]["installed"] else "missing"},
        {"step": "start", "title": "Start local Ollama service", "state": "pending" if runtime_before["ollama"]["installed"] and not runtime_before["ollama"]["running"] else "ready"},
        {"step": "pull", "title": f"Ensure local model {model}", "state": "pending"},
        {"step": "configure", "title": "Persist SevenAI provider config", "state": "pending"},
    ]
    if not apply:
        answer = (
            f"Je peux préparer le modèle local {model}. Cela peut démarrer Ollama et télécharger le modèle uniquement après confirmation."
            if language == "fr"
            else f"I can prepare local model {model}. This can start Ollama and download the model only after confirmation."
        )
        bullets = (
            [
                "Aucun téléchargement n’est lancé dans cet aperçu.",
                "Le modèle reste local après téléchargement.",
                "Les actions système restent gouvernées par les contrats SevenOS.",
            ]
            if language == "fr"
            else [
                "No download is started in this preview.",
                "The model remains local after download.",
                "System actions remain governed by SevenOS contracts.",
            ]
        )
        return {
            "schema": "sevenos.ai.model-setup.v1",
            "applied": False,
            "state": "preview",
            "model": model,
            "summary": answer,
            "chat": {
                "title": "Préparer le modèle local" if language == "fr" else "Prepare local model",
                "answer": answer,
                "bullets": bullets,
            },
            "runtime": runtime_before,
            "plan": plan,
            "apply": "seven ai model-setup --apply --json",
            "recommendations": [
                ai_action_card(
                    "Confirmer la préparation" if language == "fr" else "Confirm setup",
                    "Démarrer Ollama et vérifier le modèle cible." if language == "fr" else "Start Ollama and verify the target model.",
                    "seven ai model-setup --apply --json",
                    risk="medium",
                    apply=True,
                ),
                ai_action_card(
                    "Voir le statut" if language == "fr" else "Show status",
                    "Afficher l’état du provider local." if language == "fr" else "Show the local provider state.",
                    "seven ai models --json",
                ),
            ],
            "privacy": "local-only after model download; no cloud API key is used.",
        }
    if not runtime_before["ollama"]["installed"]:
        answer = (
            "Ollama n’est pas installé. SevenAI reste sur le provider local sûr tant qu’un runtime modèle n’est pas disponible."
            if language == "fr"
            else "Ollama is not installed. SevenAI stays on the safe local provider until a model runtime is available."
        )
        return {
            "schema": "sevenos.ai.model-setup.v1",
            "applied": False,
            "state": "missing-ollama",
            "model": model,
            "summary": answer,
            "chat": {
                "title": "Ollama manquant" if language == "fr" else "Ollama missing",
                "answer": answer,
                "bullets": [
                    "Installer Ollama depuis les paquets SevenOS avant d’activer un modèle profond."
                    if language == "fr"
                    else "Install Ollama from SevenOS packages before enabling a deep model."
                ],
            },
            "runtime": runtime_before,
            "error": "Ollama is not installed.",
            "next": "Install ollama, then run seven ai model-setup --apply --json.",
        }
    started = start_ollama_runtime()
    runtime_running = model_runtime_status()
    pull_result: dict[str, Any] = {"skipped": True}
    if runtime_running["ollama"]["running"] and model not in runtime_running["ollama"]["models"]:
        try:
            result = subprocess.run(
                ["ollama", "pull", model],
                text=True,
                capture_output=True,
                check=False,
                timeout=float(os.environ.get("SEVENAI_MODEL_PULL_TIMEOUT", "1800")),
            )
            pull_result = {
                "skipped": False,
                "returncode": result.returncode,
                "stdout_tail": result.stdout.strip()[-1200:],
                "stderr_tail": result.stderr.strip()[-1200:],
            }
        except Exception as exc:
            pull_result = {"skipped": False, "returncode": 1, "error": str(exc)}
    runtime_after_pull = model_runtime_status()
    configured = False
    if runtime_after_pull["ollama"]["running"] and model in runtime_after_pull["ollama"]["models"]:
        write_ai_provider_config("ollama", model)
        configured = True
    runtime_after = model_runtime_status()
    ok = bool(runtime_after["ollama"]["available"] and model in runtime_after["ollama"]["models"] and runtime_after["active"] == "ollama")
    answer = (
        f"Le modèle local {model} est prêt et configuré." if ok and language == "fr"
        else f"Local model {model} is ready and configured." if ok
        else f"La préparation du modèle {model} demande encore attention." if language == "fr"
        else f"Model {model} setup still needs attention."
    )
    return {
        "schema": "sevenos.ai.model-setup.v1",
        "applied": True,
        "state": "ready" if ok else "needs-attention",
        "model": model,
        "summary": answer,
        "chat": {
            "title": "Modèle local SevenAI" if language == "fr" else "SevenAI local model",
            "answer": answer,
            "bullets": [
                f"Ollama démarré : {bool(started.get('ok'))}.",
                f"Provider actif : {runtime_after.get('active')}.",
                "Les actions système gardent preview/confirmation/blocage.",
            ] if language == "fr" else [
                f"Ollama started: {bool(started.get('ok'))}.",
                f"Active provider: {runtime_after.get('active')}.",
                "System actions keep preview/confirmation/blocking.",
            ],
        },
        "started": started,
        "pull": pull_result,
        "configured": configured,
        "config": str(AI_CONFIG_FILE),
        "runtime": runtime_after,
        "test": "SEVENAI_PROVIDER=ollama seven ai provider \"résume SevenOS\" --json",
    }


def intent_domain(intent: Intent) -> str:
    return {
        "OPEN_APP": "apps",
        "INSTALL_PACKAGE": "install",
        "SET_THEME": "theme",
        "SWITCH_WORKSPACE": "session",
        "KILL_PROCESS": "session",
        "CHECK_NETWORK": "network",
        "REPAIR_NETWORK": "network",
        "ANSWER_SYSTEM_QUESTION": "health",
        "DIAGNOSE_SYSTEM": "health",
        "HEALTH_PLAN": "health",
        "DAILY_BRIEFING": "assistant",
        "OPTIMIZE_SYSTEM": "repair",
        "OPTIMIZE_WORKFLOW": "workflow",
        "PLAN_MISSION": "missions",
        "SHOW_SHORTCUTS": "help",
        "SHOW_EXECUTION_POLICY": "policy",
        "RECOMMEND_ACTIONS": "assistant",
        "EXPLAIN_DECISION": "assistant",
        "CREATE_AI_MISSION": "missions",
        "SHOW_AI_MISSIONS": "missions",
        "MISSION_STATUS": "missions",
        "NEXT_AI_MISSION_STEP": "missions",
        "COMPLETE_AI_MISSION_STEP": "missions",
        "REMEMBER_PREFERENCE": "assistant",
        "SHOW_PREFERENCES": "assistant",
        "MEMORY_PROFILE": "assistant",
        "MEMORY_AUDIT": "assistant",
        "MEMORY_PLAN": "assistant",
        "MEMORY_HISTORY": "assistant",
        "MEMORY_INSIGHTS": "assistant",
        "MEMORY_BRIEFING": "assistant",
        "LEARNING_STATUS": "assistant",
        "LEARNING_SOURCES": "assistant",
        "LEARNING_ADD_SOURCE": "assistant",
        "LEARNING_REMOVE_SOURCE": "assistant",
        "LEARNING_ENABLE": "assistant",
        "LEARNING_DISABLE": "assistant",
        "LEARNING_SCAN": "assistant",
        "LEARNING_SCAN_CONTENT": "assistant",
        "LEARNING_CLEAR_INDEX": "assistant",
        "LEARNING_CLEAR_SNIPPETS": "assistant",
        "FORGET_PREFERENCES": "assistant",
        "AI_STATE_STATUS": "assistant",
        "SEVENAI_CAPABILITIES": "assistant",
        "MODEL_STATUS": "models",
        "MODEL_SETUP": "models",
        "EXPLAIN_LEDGER": "assistant",
        "RECENT_ACTIVITY": "assistant",
        "CURRENT_CONTEXT": "session",
        "ASSIST_ACTIVE_APP": "session",
        "ROUTE_AGENT": "agents",
        "AGENT_STATUS": "agents",
        "LOCAL_SEARCH": "files",
        "EXPLAIN_SEVENOS": "help",
        "WEB_QUERY": "research",
        "RESEARCH_QUERY": "research",
        "SYSTEM_STATUS": "health",
    }.get(intent.intent, "guidance")


def intent_command(intent: Intent) -> str:
    if intent.intent == "OPEN_APP":
        app = match_app(intent.target, app_registry())
        return app.command if app else f"seven ai open {shlex.quote(intent.target)}"
    if intent.intent == "INSTALL_PACKAGE":
        return f"sevenpkg install {shlex.quote(intent.target)}"
    if intent.intent == "SET_THEME":
        return f"./install.sh theme {shlex.quote(intent.target)}"
    if intent.intent == "SWITCH_WORKSPACE":
        dispatch_target = {"next": "r+1", "previous": "r-1"}.get(intent.target, intent.target)
        return f"hyprctl dispatch workspace {shlex.quote(dispatch_target)}"
    if intent.intent == "KILL_PROCESS":
        candidates = process_names_for_target(intent.target, app_registry())
        return " || ".join(f"pkill -x -- {shlex.quote(name)}" for name in candidates) if candidates else f"pkill -x -- {shlex.quote(intent.target)}"
    if intent.intent == "CHECK_NETWORK":
        return "seven ai diagnose network --json"
    if intent.intent == "REPAIR_NETWORK":
        return "systemctl restart NetworkManager.service"
    if intent.intent == "DIAGNOSE_SYSTEM":
        return f"seven ai diagnose {shlex.quote(intent.target or 'system')} --json"
    if intent.intent == "ANSWER_SYSTEM_QUESTION":
        if intent.target == "footprint_guard":
            return "seven footprint guard --json"
        if intent.target == "footprint_trend":
            return "seven footprint trend --json"
        if intent.target == "footprint_compare":
            return "seven footprint compare --json"
        if intent.target == "footprint":
            return "seven footprint --json"
        if intent.target in {"theme", "profile", "health", "updates"}:
            return "seven ai brain --json"
        return "seven ai machine --json"
    if intent.intent == "HEALTH_PLAN":
        return "seven ai 'plan santé système' --json"
    if intent.intent == "DAILY_BRIEFING":
        return "seven ai 'briefing SevenOS' --json"
    if intent.intent == "OPTIMIZE_SYSTEM":
        return "seven ai playbook slow_system --json"
    if intent.intent == "OPTIMIZE_WORKFLOW":
        return "seven ai workflow --json"
    if intent.intent == "PLAN_MISSION":
        return f"seven experience-center intent {shlex.quote(intent.target)} --gui"
    if intent.intent == "SHOW_SHORTCUTS":
        return "seven ai shortcuts --json"
    if intent.intent == "SHOW_EXECUTION_POLICY":
        return "seven ai execution --json"
    if intent.intent == "RECOMMEND_ACTIONS":
        return "seven ai brain --json"
    if intent.intent == "EXPLAIN_DECISION":
        return "seven ai 'que dois-je faire maintenant' --json"
    if intent.intent == "CREATE_AI_MISSION":
        return f"seven ai missions create {shlex.quote(intent.target)} --json"
    if intent.intent == "SHOW_AI_MISSIONS":
        return "seven ai missions --json"
    if intent.intent == "MISSION_STATUS":
        return "seven ai missions status --json"
    if intent.intent == "NEXT_AI_MISSION_STEP":
        return "seven ai missions next --json"
    if intent.intent == "COMPLETE_AI_MISSION_STEP":
        return "seven ai missions complete --json"
    if intent.intent == "REMEMBER_PREFERENCE":
        return f"seven ai {shlex.quote(intent.target)} --json"
    if intent.intent == "SHOW_PREFERENCES":
        return "seven ai preferences --json"
    if intent.intent == "MEMORY_PROFILE":
        return "seven ai learning --json"
    if intent.intent == "MEMORY_AUDIT":
        return "seven ai learning audit --json"
    if intent.intent == "MEMORY_PLAN":
        return "seven ai learning audit --json"
    if intent.intent == "MEMORY_HISTORY":
        return "seven ai learning history --json"
    if intent.intent == "MEMORY_INSIGHTS":
        return "seven ai learning insights --json"
    if intent.intent == "MEMORY_BRIEFING":
        return "seven ai learning briefing --json"
    if intent.intent == "LEARNING_STATUS":
        return "seven ai learning --json"
    if intent.intent == "LEARNING_SOURCES":
        return "seven ai learning sources --json"
    if intent.intent == "LEARNING_ADD_SOURCE":
        return f"seven ai learning add-source {shlex.quote(intent.target)} --json"
    if intent.intent == "LEARNING_REMOVE_SOURCE":
        return f"seven ai learning remove-source {shlex.quote(intent.target)} --json"
    if intent.intent == "LEARNING_ENABLE":
        return "seven ai learning enable --json"
    if intent.intent == "LEARNING_DISABLE":
        return "seven ai learning disable --json"
    if intent.intent == "LEARNING_SCAN":
        return "seven ai learning scan --json"
    if intent.intent == "LEARNING_SCAN_CONTENT":
        return "seven ai learning scan --content --json"
    if intent.intent == "LEARNING_CLEAR_INDEX":
        return "seven ai learning clear-index --json"
    if intent.intent == "LEARNING_CLEAR_SNIPPETS":
        return "seven ai learning clear-snippets --json"
    if intent.intent == "FORGET_PREFERENCES":
        return "seven ai preferences clear --json"
    if intent.intent == "LOCAL_SEARCH":
        return f"seven ai learning search {shlex.quote(intent.target)} --json"
    if intent.intent == "EXPLAIN_LEDGER":
        return "seven ai ledger --json"
    if intent.intent == "RECENT_ACTIVITY":
        return "seven ai memory --json"
    if intent.intent == "CURRENT_CONTEXT":
        return "seven ai context --json"
    if intent.intent == "ASSIST_ACTIVE_APP":
        return "seven ai 'quel est mon contexte actuel' --json"
    if intent.intent == "ROUTE_AGENT":
        return "seven ai handoffs --json"
    if intent.intent == "AGENT_STATUS":
        return "seven ai coverage --json"
    if intent.intent == "EXPLAIN_SEVENOS":
        return "seven ai knowledge --json"
    if intent.intent == "WEB_QUERY":
        return f"SEVENAI_WEB=1 seven ai web {shlex.quote(intent.target)} --json"
    if intent.intent == "RESEARCH_QUERY":
        return f"SEVENAI_WEB=1 seven ai research {shlex.quote(intent.target)} --json"
    if intent.intent == "SYSTEM_STATUS":
        return "seven state --json"
    if intent.intent == "AI_STATE_STATUS":
        return "seven ai state --json"
    if intent.intent == "SEVENAI_CAPABILITIES":
        return "seven ai capabilities --json"
    if intent.intent == "MODEL_STATUS":
        return "seven ai models --json"
    if intent.intent == "MODEL_SETUP":
        return "seven ai model-setup --apply --json"
    return "seven ai manager --json"


def intent_prechecks(intent: Intent) -> list[str]:
    checks = {
        "INSTALL_PACKAGE": [f"sevenpkg resolve {shlex.quote(intent.target)} --json", "sevenpkg doctor --json"],
        "SET_THEME": ["seven theme doctor --json", "test -x ./install.sh"],
        "REPAIR_NETWORK": ["seven ai diagnose network --json", "systemctl is-active NetworkManager.service"],
        "ANSWER_SYSTEM_QUESTION": ["seven ai brain --json"],
        "KILL_PROCESS": [f"pgrep -a {shlex.quote(intent.target)} || true"],
        "HEALTH_PLAN": ["seven ai diagnose system --json", "seven ai brain --json"],
        "DAILY_BRIEFING": ["seven ai brain --json", "seven ai memory --json"],
        "OPTIMIZE_SYSTEM": ["seven ai diagnose system --json", "seven performance-gate --json"],
        "PLAN_MISSION": ["seven missions --json", "seven profile health --json"],
        "WEB_QUERY": ["test \"$SEVENAI_WEB\" = \"1\""],
        "RESEARCH_QUERY": ["test \"$SEVENAI_WEB\" = \"1\""],
        "RECOMMEND_ACTIONS": ["seven ai brain --json"],
        "EXPLAIN_DECISION": ["seven ai brain --json", "seven ai memory --json"],
        "CREATE_AI_MISSION": ["seven ai handoffs --json", "seven ai brain --json"],
        "SHOW_AI_MISSIONS": ["test -d ~/.local/state/sevenos/ai || true"],
        "MISSION_STATUS": ["seven ai missions --json", "seven ai handoffs --json"],
        "NEXT_AI_MISSION_STEP": ["seven ai missions --json"],
        "COMPLETE_AI_MISSION_STEP": ["seven ai missions --json"],
        "REMEMBER_PREFERENCE": ["test -d ~/.local/state/sevenos/ai || true"],
        "SHOW_PREFERENCES": ["seven ai preferences --json"],
        "MEMORY_PROFILE": ["seven ai learning --json", "seven ai preferences --json", "seven ai memory --json"],
        "MEMORY_AUDIT": ["seven ai learning audit --json"],
        "MEMORY_PLAN": ["seven ai learning audit --json", "seven ai learning --json"],
        "MEMORY_HISTORY": ["seven ai learning history --json"],
        "MEMORY_INSIGHTS": ["seven ai learning insights --json"],
        "MEMORY_BRIEFING": ["seven ai learning briefing --json"],
        "LEARNING_STATUS": ["seven ai learning --json"],
        "LEARNING_SOURCES": ["seven ai learning sources --json"],
        "LEARNING_ADD_SOURCE": ["seven ai learning sources --json"],
        "LEARNING_REMOVE_SOURCE": ["seven ai learning sources --json"],
        "LEARNING_ENABLE": ["seven ai learning --json", "test -d ~/.config/sevenos || true"],
        "LEARNING_DISABLE": ["seven ai learning --json", "test -d ~/.config/sevenos || true"],
        "LEARNING_SCAN": ["seven ai learning sources --json"],
        "LEARNING_SCAN_CONTENT": ["seven ai learning sources --json"],
        "LEARNING_CLEAR_INDEX": ["seven ai learning --json"],
        "LEARNING_CLEAR_SNIPPETS": ["seven ai learning --json"],
        "FORGET_PREFERENCES": ["seven ai preferences --json"],
        "AI_STATE_STATUS": ["seven ai state --json"],
        "SEVENAI_CAPABILITIES": ["seven ai runtime --json", "seven ai state --json"],
        "MODEL_STATUS": ["seven ai models --json", "seven ai llm --json"],
        "MODEL_SETUP": ["seven ai models --json", "command -v ollama || true"],
        "LOCAL_SEARCH": [f"seven ai learning search {shlex.quote(intent.target)} --json"],
        "EXPLAIN_LEDGER": ["seven ai ledger --json"],
        "RECENT_ACTIVITY": ["seven ai memory --json"],
        "CURRENT_CONTEXT": ["hyprctl activewindow -j || true", "seven ai brain --json"],
        "ASSIST_ACTIVE_APP": ["hyprctl activewindow -j || true", "seven ai brain --json"],
        "ROUTE_AGENT": ["seven ai handoffs --json", "hyprctl activewindow -j || true"],
        "AGENT_STATUS": ["seven ai runtime --json", "seven ai coverage --json", "seven ai contracts --json", "seven ai permissions --json"],
    }
    return checks.get(intent.intent, ["seven ai manager --json"])


def intent_rollback(intent: Intent) -> list[str]:
    rollback = {
        "INSTALL_PACKAGE": [f"sevenpkg remove {shlex.quote(intent.target)}"],
        "SET_THEME": ["seven theme restore --last || seven theme doctor --repair"],
        "REPAIR_NETWORK": ["systemctl restart NetworkManager.service"],
        "KILL_PROCESS": ["Rouvrir l’application depuis Seven Files/Spotlight si nécessaire."],
        "OPTIMIZE_SYSTEM": ["seven restore latest --gui", "seven repair undo --last"],
    }
    return rollback.get(intent.intent, [])


def operation_plan(text: str) -> dict[str, Any]:
    intent = parse_intent(text)
    confirmation = confirmation_contract(intent)
    domain = intent_domain(intent)
    command = intent_command(intent)
    changing = intent.safety.upper() in {"ROOT", "SYSTEM"}
    execute_command = f"seven ai {shlex.quote(text)} --apply" if intent.needs_apply else f"seven ai {shlex.quote(text)}"
    return {
        "schema": "sevenos.ai.operation-plan.v1",
        "input": text,
        "language": active_language(),
        "domain": domain,
        "intent": asdict(intent),
        "summary": {
            "title": f"{domain}:{intent.intent.lower()}",
            "command": command,
            "safe_preview": True,
            "requires_apply": bool(intent.needs_apply),
            "requires_confirmation": changing,
        },
        "contract": {
            "observe": intent_prechecks(intent),
            "explain": intent.reason,
            "preview": command,
            "confirm": confirmation,
            "execute": execute_command,
            "rollback": intent_rollback(intent),
        },
        "guardrails": [
            "SevenAI ne lance pas d’action root ou système sans --apply.",
            "Les installations passent par SevenPkg et son catalogue de domaines.",
            "Les providers LLM expliquent et résument; l’exécution reste routée par les commandes SevenOS.",
        ],
    }


def execution_policy() -> dict[str, Any]:
    permissions = run_json([str(ROOT_DIR / "scripts/ai.sh"), "permissions", "--json"], {"state": "unknown", "graph": []}, timeout=2.0)
    runtime = run_json([str(ROOT_DIR / "scripts/ai.sh"), "runtime", "--json"], {"state": "unknown", "policy": {}, "ledger": {}}, timeout=2.0)
    graph = permissions.get("graph") if isinstance(permissions.get("graph"), list) else []
    return {
        "schema": "sevenos.ai.execution-policy.v1",
        "state": "ready" if permissions.get("state") == "ready" and runtime.get("state") == "ready" else "needs-attention",
        "principle": "The model can reason and explain; SevenOS contracts decide execution.",
        "modes": {
            "auto": {
                "scope": ["OPEN_APP", "SHOW_SHORTCUTS", "EXPLAIN_SEVENOS", "CHECK_NETWORK", "ANSWER_SYSTEM_QUESTION"],
                "examples": ["ouvrir Firefox", "quel est mon espace disque", "raccourcis clavier"],
                "guardrail": "No root write, no destructive file operation, no package change.",
            },
            "preview": {
                "scope": ["INSTALL_PACKAGE", "SET_THEME", "REPAIR_NETWORK", "OPTIMIZE_SYSTEM", "KILL_PROCESS"],
                "examples": ["installer Blender", "réparer le Wi-Fi", "fermer Firefox"],
                "guardrail": "SevenAI explains impact and shows commands before --apply.",
            },
            "confirm": {
                "scope": ["packages.install", "services.restart", "network.change", "theme.apply", "profile.switch", "files.delete"],
                "examples": ["redémarrer un service", "installer un paquet", "changer la session"],
                "guardrail": "Requires explicit --apply or a UI confirmation surface.",
            },
            "blocked": {
                "scope": ["credential exfiltration", "destructive disk writes", "silent privilege escalation", "cloud upload without opt-in"],
                "examples": ["supprimer un disque sans confirmation", "envoyer mes fichiers au cloud"],
                "guardrail": "Denied by default even if a model suggests it.",
            },
        },
        "runtime": {
            "state": runtime.get("state", "unknown"),
            "execution_default": (runtime.get("policy") or {}).get("execution_default", "preview"),
            "ledger": runtime.get("ledger", {}),
        },
        "permission_graph": {
            "state": permissions.get("state", "unknown"),
            "agents": len(graph),
            "issues": permissions.get("issues", []),
        },
        "operator": {
            "preview": "seven ai operate \"<demande>\" --json",
            "apply": "seven ai \"<demande>\" --apply",
            "ledger": "seven ai ledger --json",
        },
        "ui_guidance": [
            "Spotlight AI should show the action class before execution.",
            "Settings/Doctor/Store should use preview cards for system-changing actions.",
            "Root or package actions should never be triggered by raw model text.",
        ],
    }


def manager_domains() -> list[dict[str, Any]]:
    return [
        {"key": "health", "title": "Santé système", "command": "seven health --json", "safety": "SAFE", "scope": "system"},
        {"key": "footprint", "title": "Poids SevenOS", "command": "seven footprint --json", "safety": "SAFE", "scope": "release"},
        {"key": "updates", "title": "Mises à jour", "command": "seven update check", "safety": "SAFE", "scope": "system"},
        {"key": "repair", "title": "Réparation guidée", "command": "seven doctor open", "safety": "SAFE", "scope": "system"},
        {"key": "apps", "title": "Applications", "command": "seven store", "safety": "SAFE", "scope": "apps"},
        {"key": "install", "title": "Installation logicielle", "command": "sevenpkg install <app>", "safety": "ROOT_CONFIRM", "scope": "apps"},
        {"key": "files", "title": "Fichiers", "command": "seven files", "safety": "SAFE", "scope": "files"},
        {"key": "network", "title": "Réseau", "command": "seven ai diagnose network --json", "safety": "SAFE", "scope": "devices"},
        {"key": "theme", "title": "Thème et rendu", "command": "seven theme doctor --json", "safety": "SAFE", "scope": "appearance"},
        {"key": "profiles", "title": "Mini OS", "command": "seven profile health --json", "safety": "SAFE", "scope": "mini-os"},
        {"key": "security", "title": "Sécurité", "command": "seven shield audit", "safety": "SAFE", "scope": "security"},
        {"key": "privacy", "title": "Confidentialité", "command": "seven privacy-report --json", "safety": "SAFE", "scope": "privacy"},
        {"key": "learning", "title": "Apprentissage local", "command": "seven ai learning --json", "safety": "SAFE", "scope": "personal"},
        {"key": "installer", "title": "Installation SevenOS", "command": "seven installer release --json", "safety": "SAFE", "scope": "installer"},
        {"key": "reader", "title": "Lecture et documents", "command": "seven reader --json", "safety": "SAFE", "scope": "documents"},
        {"key": "windows", "title": "Apps Windows", "command": "seven-wincompat doctor --json", "safety": "SAFE", "scope": "compatibility"},
        {"key": "usb", "title": "USB Writer", "command": "seven usb status --json", "safety": "SAFE", "scope": "devices"},
    ]


def os_manager() -> dict[str, Any]:
    if os.environ.get("SEVENAI_MANAGER_REFRESH") != "1":
        try:
            if AI_MANAGER_CACHE.exists() and time.time() - AI_MANAGER_CACHE.stat().st_mtime < int(os.environ.get("SEVENAI_MANAGER_CACHE_TTL", "240")):
                cached = json.loads(AI_MANAGER_CACHE.read_text(encoding="utf-8"))
                cached["cached"] = True
                return cached
        except Exception:
            pass
    brain = brain_snapshot()
    model = model_manager()
    actions = brain.get("actions", {})
    domains = manager_domains()
    ready_domains = len(domains)
    score = int(brain.get("score", 0) or 0)
    payload = {
        "schema": "sevenos.ai.manager.v1",
        "cached": False,
        "state": "manager-ready" if score >= 85 else "manager-needs-attention",
        "score": score,
        "principle": "SevenAI manages SevenOS through contracts: observe, explain, preview, confirm, execute through SevenOS commands.",
        "operator": {
            "command": "seven ai operate \"<demande>\" --json",
            "contract": ["observe", "explain", "preview", "confirm", "execute", "rollback"],
            "default_mode": "preview",
        },
        "brain": {
            "state": brain.get("state"),
            "score": brain.get("score"),
            "profile": brain.get("profile", {}),
            "theme": brain.get("theme", {}),
            "command": "seven ai brain --json",
            "cached": brain.get("cached", False),
        },
        "domains": domains,
        "coverage": {
            "domains": len(domains),
            "ready_domains": ready_domains,
            "action_registry": int(actions.get("total", 0) or 0) if isinstance(actions, dict) else 0,
            "safe_actions": int(actions.get("safe", 0) or 0) if isinstance(actions, dict) else 0,
            "confirmation_actions": int(actions.get("confirmation", 0) or 0) if isinstance(actions, dict) else 0,
            "playbooks": len(PLAYBOOKS),
        },
        "status": {
            "health": brain.get("contracts", {}).get("health", {}),
            "public_quality": brain.get("contracts", {}).get("public_quality", {}),
            "profiles": brain.get("contracts", {}).get("profiles", {}),
            "updates": brain.get("contracts", {}).get("updates", {}),
            "security": brain.get("contracts", {}).get("security", {}),
            "spotlight": brain.get("contracts", {}).get("spotlight", {}),
            "learning": brain.get("learning", {}),
            "proactive": brain.get("proactive", {}),
            "models": model,
        },
        "issues": brain.get("issues", []),
        "next": [
            "Use `seven ai doctor --json` for assistant readiness.",
            "Use `seven ai brain --json` for the fast live SevenOS map.",
            "Use `seven ai manager --json` for the OS management map.",
            "Use `seven ai learning --json` to review local personal context and approved sources.",
            "Use `seven ai playbook <name> --json` before system-changing repairs.",
            "Use `SEVENAI_PROVIDER=ollama` only when the local model runtime is running and desired.",
        ],
    }
    try:
        AI_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        AI_MANAGER_CACHE.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass
    return payload


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
    if area in {"footprint", "size", "poids", "taille"}:
        data = footprint_snapshot()
        summary = data.get("summary") if isinstance(data.get("summary"), dict) else {}
        recommendations = data.get("recommendations") if isinstance(data.get("recommendations"), list) else []
        return {
            "schema": "sevenos.ai.diagnostics.v1",
            "area": "footprint",
            "state": data.get("state", "unknown"),
            "score": data.get("score", 0),
            "summary": summary,
            "checks": data.get("checks", [])[:8] if isinstance(data.get("checks"), list) else [],
            "recommendations": recommendations[:5],
            "policy": data.get("policy", "read-only"),
        }
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


def ledger_risk(intent: Intent, result: dict[str, Any]) -> str:
    confirmation = result.get("confirmation") if isinstance(result.get("confirmation"), dict) else {}
    safety = str(intent.safety or "").upper()
    if confirmation.get("blocked") or safety in {"DANGEROUS", "BLOCKED"}:
        return "high"
    if intent.needs_apply or safety in {"SYSTEM", "PREVIEW", "CONFIRM"}:
        return "medium"
    return "low"


def command_from_action(action: dict[str, Any] | None) -> str:
    if not isinstance(action, dict):
        return ""
    command = action.get("command")
    if isinstance(command, str):
        return command
    commands = action.get("commands")
    if isinstance(commands, list):
        return " ; ".join(str(item) for item in commands)
    return ""


def record_agent_ledger(text: str, intent: Intent, result: dict[str, Any]) -> dict[str, Any] | None:
    if write_ledger_event is None:
        return None
    action = result.get("action") if isinstance(result.get("action"), dict) else {}
    action_type = action.get("type") or intent.intent.lower()
    output = result.get("result") if isinstance(result.get("result"), dict) else {}
    confirmation = result.get("confirmation") if isinstance(result.get("confirmation"), dict) else {}
    conversation = result.get("conversation") if isinstance(result.get("conversation"), dict) else {}
    summary = str(output.get("summary") or output.get("detail") or intent.reason or "").strip()
    applied = bool(output.get("applied"))
    event = {
        "agent": "equinox.system",
        "source": "seven-ai-agent",
        "action": action_type,
        "input": text,
        "intent": intent.intent,
        "target": intent.target,
        "mode": result.get("mode", "preview"),
        "safety": intent.safety,
        "risk": ledger_risk(intent, result),
        "summary": summary[:500],
        "approved": applied,
        "applied": applied,
        "blocked": bool(confirmation.get("blocked")),
        "needs_confirmation": bool(confirmation.get("needs_confirmation") or intent.needs_apply),
        "conversation_used": bool(conversation.get("used")),
        "confidence": round(float(intent.confidence or 0), 3),
        "command": command_from_action(action),
        "contract": confirmation.get("contract") or confirmation.get("mode") or "",
    }
    try:
        return write_ledger_event(event)
    except Exception:
        return None


def recent_ledger(limit: int = 8) -> list[dict[str, Any]]:
    if ledger_events is None:
        return []
    try:
        return ledger_events(limit)
    except Exception:
        return []


def ledger_explanation(language: str) -> dict[str, Any]:
    events = recent_ledger(12)
    events = [event for event in events if event.get("action") not in {"explain_ledger"}]
    if not events:
        summary = (
            "Je n’ai pas encore d’historique SevenAI exploitable dans le ledger local."
            if language == "fr"
            else "I do not have a usable SevenAI local ledger history yet."
        )
        return {
            "applied": False,
            "summary": summary,
            "chat": {
                "title": "Journal SevenAI" if language == "fr" else "SevenAI ledger",
                "answer": summary,
                "bullets": [
                    "Les actions seront historisées localement avec leur niveau de risque."
                    if language == "fr"
                    else "Actions will be logged locally with their risk level."
                ],
            },
            "events": [],
            "recommendations": [],
        }
    recent = list(reversed(events))[:6]
    last = recent[0]
    confirmations = [event for event in recent if event.get("needs_confirmation") and not event.get("applied")]
    applied = [event for event in recent if event.get("applied")]
    high_risk = [event for event in recent if event.get("risk") == "high"]
    if language == "fr":
        summary = (
            f"Dernière action SevenAI : {last.get('action', 'action')} sur « {last.get('target') or last.get('input', '')} ». "
            f"Risque : {last.get('risk', 'low')}. "
            f"{len(confirmations)} action(s) récente(s) attendent une confirmation, {len(applied)} ont été appliquée(s)."
        )
    else:
        summary = (
            f"Latest SevenAI action: {last.get('action', 'action')} on “{last.get('target') or last.get('input', '')}”. "
            f"Risk: {last.get('risk', 'low')}. "
            f"{len(confirmations)} recent action(s) wait for confirmation, {len(applied)} were applied."
        )
    recommendations = []
    if confirmations:
        recommendations.append(ai_action_card(
            "Voir la politique d’exécution" if language == "fr" else "Review execution policy",
            "Comprendre pourquoi ces actions demandent confirmation." if language == "fr" else "Understand why these actions require confirmation.",
            "seven ai \"montre la politique d'exécution SevenAI\"",
            risk="low",
        ))
    if high_risk:
        recommendations.append(ai_action_card(
            "Examiner les actions risquées" if language == "fr" else "Review risky actions",
            f"{len(high_risk)} action(s) à risque élevé dans l’historique récent." if language == "fr" else f"{len(high_risk)} high-risk action(s) in recent history.",
            "seven ai ledger --json",
            risk="medium",
        ))
    return {
        "applied": False,
        "summary": summary,
        "chat": {
            "title": "Journal SevenAI" if language == "fr" else "SevenAI ledger",
            "answer": (
                f"Dernière action : {last.get('action', 'action')} sur « {last.get('target') or last.get('input', '')} »."
                if language == "fr"
                else f"Latest action: {last.get('action', 'action')} on “{last.get('target') or last.get('input', '')}”."
            ),
            "bullets": [
                (
                    f"Risque : {last.get('risk', 'low')}."
                    if language == "fr"
                    else f"Risk: {last.get('risk', 'low')}."
                ),
                (
                    f"{len(confirmations)} action(s) en attente de confirmation."
                    if language == "fr"
                    else f"{len(confirmations)} action(s) awaiting confirmation."
                ),
                (
                    f"{len(applied)} action(s) appliquée(s)."
                    if language == "fr"
                    else f"{len(applied)} applied action(s)."
                ),
                (
                    f"{len(high_risk)} action(s) à risque élevé."
                    if language == "fr"
                    else f"{len(high_risk)} high-risk action(s)."
                ),
            ],
        },
        "events": recent,
        "last": last,
        "pending_confirmation": confirmations,
        "recommendations": recommendations,
    }


def memory_health(conn: sqlite3.Connection) -> dict[str, Any]:
    total = int(conn.execute("select count(*) from events").fetchone()[0] or 0)
    top_intents = [
        dict(row)
        for row in conn.execute(
            "select intent, count(*) as count from events group by intent order by count desc limit 8"
        ).fetchall()
    ]
    noisy = [item for item in top_intents if int(item.get("count", 0) or 0) >= 500]
    return {
        "total_events": total,
        "retention": "compact-recommended" if total > 5000 or noisy else "ok",
        "noisy_intents": noisy[:4],
        "compact_command": "seven ai memory --compact --json",
    }


def compact_memory(max_events: int = 1500) -> dict[str, Any]:
    try:
        with db() as conn:
            before = int(conn.execute("select count(*) from events").fetchone()[0] or 0)
            conn.execute(
                "delete from events where id in ("
                "select id from ("
                "select id, row_number() over ("
                "partition by input, intent, target, safety, applied, source order by id desc"
                ") as rn from events"
                ") where rn > 20)"
            )
            if before > max_events:
                conn.execute(
                    "delete from events where id not in (select id from events order by id desc limit ?)",
                    (max_events,),
                )
            conn.execute("delete from research_cache where ts < ?", (int(time.time()) - 60 * 60 * 24 * 45,))
            conn.commit()
            conn.execute("vacuum")
            after = int(conn.execute("select count(*) from events").fetchone()[0] or 0)
            health = memory_health(conn)
    except sqlite3.Error as exc:
        return {
            "schema": "sevenos.ai.memory-compact.v1",
            "ok": False,
            "error": str(exc),
        }
    return {
        "schema": "sevenos.ai.memory-compact.v1",
        "ok": True,
        "before_events": before,
        "after_events": after,
        "removed_events": max(before - after, 0),
        "health": health,
    }


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
            health = memory_health(conn)
    except sqlite3.Error:
        events, top_intents, health = [], [], {"total_events": 0, "retention": "unknown", "noisy_intents": []}
    return {
        "schema": "sevenos.ai.memory.v2",
        "store": str(db_path()),
        "events": list(reversed(events)),
        "summary": {"top_intents": top_intents},
        "health": health,
    }


def contextualize_intent(text: str, intent: Intent) -> dict[str, Any]:
    raw = normalize(text)
    context: dict[str, Any] = {
        "used": False,
        "source": "direct",
        "previous": None,
        "reason": "",
    }
    if intent.intent != "GUIDANCE":
        return {"intent": intent, "context": context}

    topic_aliases = {
        "disk": ("disque", "disk", "stockage", "storage", "espace", "space"),
        "memory": ("ram", "memoire", "mémoire", "memory"),
        "cpu": ("cpu", "processeur", "processor"),
        "battery": ("batterie", "battery"),
        "network": ("wifi", "reseau", "réseau", "network"),
        "services": ("services", "service"),
        "apps": ("application", "applications", "app", "apps", "fenêtre", "fenetres", "fenêtres", "window", "windows", "programme", "programmes"),
        "processes": ("processus", "process", "processes", "consomme", "consumption"),
    }
    topic = next((key for key, aliases in topic_aliases.items() if any(token in raw for token in aliases)), "")
    followup_markers = ("et ", "and ", "aussi", "also", "encore", "pareil", "same", "le ", "la ", "les ")
    if not topic or not (raw.startswith(followup_markers) or len(raw.split()) <= 4):
        return {"intent": intent, "context": context}

    memory = read_memory(5)
    events = memory.get("events") if isinstance(memory.get("events"), list) else []
    previous = next(
        (
            event for event in reversed(events)
            if event.get("intent") in {"ANSWER_SYSTEM_QUESTION", "DIAGNOSE_SYSTEM", "SYSTEM_STATUS"}
        ),
        None,
    )
    if not previous:
        return {"intent": intent, "context": context}

    context.update({
        "used": True,
        "source": "local-memory",
        "previous": {
            "input": previous.get("input", ""),
            "intent": previous.get("intent", ""),
            "target": previous.get("target", ""),
        },
        "reason": "Resolved a short follow-up against the last local system question.",
    })
    return {
        "intent": Intent(
            "ANSWER_SYSTEM_QUESTION",
            topic,
            0.82,
            "SAFE",
            False,
            "Short follow-up resolved from local SevenAI memory.",
        ),
        "context": context,
    }


def response_style_from_preferences(language: str) -> dict[str, Any]:
    prefs = preferences_summary(language)
    values = " ".join(str(item.get("value") or "") for item in prefs.get("preferences", []) if isinstance(item, dict))
    raw = normalize(values)
    concise = any(token in raw for token in ("court", "courte", "courtes", "concis", "concise", "short", "brief"))
    action_first = any(token in raw for token in ("prochaine action", "action claire", "next action", "actionable"))
    detailed = any(token in raw for token in ("détaillé", "detaille", "detailed", "explique tout", "explain everything"))
    return {
        "language": language,
        "tone": "direct" if concise or action_first else "balanced",
        "length": "short" if concise and not detailed else "normal",
        "action_first": action_first,
        "show_confirmation": True,
        "source": "explicit-preferences" if prefs.get("count") else "default",
    }


def first_action_from_result(result_payload: dict[str, Any]) -> dict[str, Any] | None:
    result = result_payload.get("result") if isinstance(result_payload.get("result"), dict) else {}
    cards = result.get("recommendations") if isinstance(result.get("recommendations"), list) else []
    for card in cards:
        if isinstance(card, dict) and card.get("title") and card.get("command"):
            return {
                "title": card.get("title"),
                "detail": card.get("detail", ""),
                "command": card.get("command"),
                "risk": card.get("risk", "low"),
                "apply": bool(card.get("apply")),
            }
    action = result_payload.get("action") if isinstance(result_payload.get("action"), dict) else {}
    command = command_from_action(action)
    if command:
        return {
            "title": action.get("type", "action"),
            "detail": action.get("target", ""),
            "command": command,
            "risk": result_payload.get("confirmation", {}).get("level", "low") if isinstance(result_payload.get("confirmation"), dict) else "low",
            "apply": bool(result_payload.get("intent", {}).get("needs_apply")) if isinstance(result_payload.get("intent"), dict) else False,
        }
    return None


def decision_card(language: str, result_payload: dict[str, Any], next_action: dict[str, Any] | None) -> dict[str, Any]:
    intent = result_payload.get("intent") if isinstance(result_payload.get("intent"), dict) else {}
    confirmation = result_payload.get("confirmation") if isinstance(result_payload.get("confirmation"), dict) else {}
    action = result_payload.get("action") if isinstance(result_payload.get("action"), dict) else {}
    output = result_payload.get("result") if isinstance(result_payload.get("result"), dict) else {}
    needs_apply = bool(intent.get("needs_apply") or confirmation.get("needs_apply"))
    applied = bool(output.get("applied"))
    blocked = bool(confirmation.get("blocked"))
    action_type = str(action.get("type") or intent.get("intent") or "answer")
    if next_action and next_action.get("title") == action_type:
        friendly_titles = {
            "kill_process": "Fermer l’application" if language == "fr" else "Close application",
            "set_theme": "Changer le thème" if language == "fr" else "Change theme",
            "switch_workspace": "Changer d’espace" if language == "fr" else "Switch workspace",
            "install_package": "Installer le logiciel" if language == "fr" else "Install software",
            "repair_network": "Réparer le réseau" if language == "fr" else "Repair network",
            "open_app": "Ouvrir l’application" if language == "fr" else "Open application",
        }
        next_action = {**next_action, "title": friendly_titles.get(action_type, str(next_action.get("title") or action_type))}
    level = str(confirmation.get("level") or "safe")
    if blocked:
        state = "blocked"
        title = "Action bloquée" if language == "fr" else "Action blocked"
        detail = confirmation.get("impact") or ("SevenAI bloque cette action par sécurité." if language == "fr" else "SevenAI blocked this action for safety.")
    elif applied:
        state = "applied"
        title = "Action appliquée" if language == "fr" else "Action applied"
        detail = output.get("summary") or ("La demande a été exécutée." if language == "fr" else "The request was executed.")
    elif needs_apply:
        state = "needs-confirmation"
        title = "Confirmation requise" if language == "fr" else "Confirmation required"
        detail = confirmation.get("impact") or ("Cette action peut modifier le système." if language == "fr" else "This action may change the system.")
    elif next_action:
        state = "ready"
        title = "Réponse prête" if language == "fr" else "Answer ready"
        detail = "J’ai préparé une prochaine action claire." if language == "fr" else "I prepared a clear next action."
    else:
        state = "informational"
        title = "Réponse locale" if language == "fr" else "Local answer"
        detail = "Aucune modification système." if language == "fr" else "No system change."
    secondary = []
    if action_type not in {"show_execution_policy", "explain_ledger"}:
        secondary.append(ai_action_card(
            "Voir la politique d’exécution" if language == "fr" else "View execution policy",
            "Comprendre ce que SevenAI peut appliquer ou bloquer." if language == "fr" else "Understand what SevenAI can apply or block.",
            "seven ai execution --json",
            risk="low",
        ))
    if action_type != "explain_ledger":
        secondary.append(ai_action_card(
            "Voir l’historique SevenAI" if language == "fr" else "View SevenAI history",
            "Afficher les dernières décisions locales." if language == "fr" else "Show recent local decisions.",
            "seven ai ledger --json",
            risk="low",
        ))
    return {
        "schema": "sevenos.ai.decision-card.v1",
        "state": state,
        "title": title,
        "detail": detail,
        "level": level,
        "intent": intent.get("intent", ""),
        "action": action_type,
        "primary": next_action,
        "secondary": secondary[:2],
        "chips": [
            {"label": result_payload.get("mode", "preview"), "kind": "mode"},
            {"label": level, "kind": "safety"},
            {"label": "ledger", "kind": "audit"},
        ],
    }


def response_card(language: str, result_payload: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    output = result_payload.get("result") if isinstance(result_payload.get("result"), dict) else {}
    chat = output.get("chat") if isinstance(output.get("chat"), dict) else {}
    decision = context.get("decision") if isinstance(context.get("decision"), dict) else {}
    next_action = context.get("next_action") if isinstance(context.get("next_action"), dict) else None
    confirmation = result_payload.get("confirmation") if isinstance(result_payload.get("confirmation"), dict) else {}
    title = str(chat.get("title") or decision.get("title") or ("SevenAI" if language != "fr" else "SevenAI")).strip()
    answer = str(chat.get("answer") or output.get("summary") or decision.get("detail") or "").strip()
    bullets = chat.get("bullets") if isinstance(chat.get("bullets"), list) else []
    if not answer:
        answer = "Réponse prête." if language == "fr" else "Answer ready."
    quick_actions: list[dict[str, Any]] = []
    if isinstance(next_action, dict) and next_action.get("title") and next_action.get("command"):
        quick_actions.append({
            "role": "primary",
            "title": next_action.get("title"),
            "detail": next_action.get("detail", ""),
            "command": next_action.get("command"),
            "risk": next_action.get("risk", "low"),
            "apply": bool(next_action.get("apply")),
        })
    secondary = decision.get("secondary") if isinstance(decision.get("secondary"), list) else []
    for item in secondary[:2]:
        if isinstance(item, dict) and item.get("title") and item.get("command"):
            quick_actions.append({
                "role": "secondary",
                "title": item.get("title"),
                "detail": item.get("detail", ""),
                "command": item.get("command"),
                "risk": item.get("risk", "low"),
                "apply": bool(item.get("apply")),
            })
    return {
        "schema": "sevenos.ai.response-card.v1",
        "surface": "spotlight-chat",
        "title": title,
        "answer": answer,
        "bullets": [str(item).strip() for item in bullets if str(item).strip()][:5],
        "state": decision.get("state", "ready"),
        "safety": {
            "level": confirmation.get("level", "safe"),
            "needs_apply": bool(confirmation.get("needs_apply")),
            "blocked": bool(confirmation.get("blocked")),
            "impact": confirmation.get("impact", ""),
        },
        "quick_actions": quick_actions[:3],
        "controls": {
            "submit": "Enter",
            "newline": "Shift+Enter",
            "close": "Esc",
            "clear": "Ctrl+Backspace",
        },
        "render": {
            "layout": "conversation",
            "max_width": 860,
            "prefer_compact": True,
            "show_raw_json": False,
        },
    }


def assistant_context(language: str, result_payload: dict[str, Any]) -> dict[str, Any]:
    prefs = preferences_summary(language)
    mission = mission_status(language)
    progress = mission.get("progress") if isinstance(mission.get("progress"), dict) else {}
    next_step = progress.get("next_step") if isinstance(progress.get("next_step"), dict) else None
    next_action = first_action_from_result(result_payload)
    return {
        "schema": "sevenos.ai.assistant-context.v1",
        "style": response_style_from_preferences(language),
        "preferences": {
            "count": prefs.get("count", 0),
            "latest": (prefs.get("preferences", [{}]) or [{}])[0].get("value") if prefs.get("preferences") else "",
            "command": "seven ai preferences --json",
        },
        "mission": {
            "active": bool(mission.get("mission")),
            "summary": mission.get("summary", ""),
            "percent": progress.get("percent", 0),
            "next_step": next_step,
            "command": "seven ai missions next --json" if next_step else "seven ai missions --json",
        },
        "next_action": next_action,
        "decision": decision_card(language, result_payload, next_action),
        "safety": {
            "mode": result_payload.get("mode", "preview"),
            "confirmation": result_payload.get("confirmation", {}),
            "ledger": "required",
        },
    }


def execute_intent(intent: Intent, text: str, *, apply: bool) -> dict[str, Any]:
    apps = app_registry()
    contextual = contextualize_intent(text, intent)
    intent = contextual["intent"]
    language = language_for_text(text)
    result: dict[str, Any] = {
        "schema": "sevenos.ai.agent.v1",
        "input": text,
        "language": language,
        "intent": asdict(intent),
        "conversation": contextual["context"],
        "mode": "apply" if apply else "preview",
        "dry_run": DRY_RUN,
        "confirmation": confirmation_contract(intent, language=language),
        "action": None,
        "result": None,
    }
    effective_apply = apply or not intent.needs_apply

    if intent.intent == "OPEN_APP":
        app = match_app(intent.target, apps)
        suggestions = similar_apps(intent.target, apps)
        result["action"] = {
            "type": "open_app",
            "target": intent.target,
            "normalized_target": normalize_app_target(intent.target),
            "app": asdict(app) if app else None,
            "suggestions": suggestions if not app else [],
        }
        result["result"] = launch_app(app, apply=True) if app and (DRY_RUN or effective_apply) else (
            {"returncode": 1, "stderr": f"Application not found: {intent.target}", "applied": False, "suggestions": suggestions}
        )
        if app and not (result["result"] or {}).get("stderr"):
            result["result"]["summary"] = (
                f"J’ouvre {app.name}." if language == "fr" else f"Opening {app.name}."
            )
        else:
            names = ", ".join(item.get("name", "") for item in suggestions[:3] if item.get("name"))
            result["result"]["summary"] = (
                f"Je n’ai pas trouvé {intent.target}. Suggestions : {names or 'aucune'}."
                if language == "fr"
                else f"I could not find {intent.target}. Suggestions: {names or 'none'}."
            )
    elif intent.intent == "SET_THEME":
        command = [str(ROOT_DIR / "install.sh"), "theme", intent.target]
        result["action"] = {"type": "set_theme", "target": intent.target, "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply, cwd=ROOT_DIR)
        result["result"]["summary"] = (
            f"Je peux passer SevenOS en thème {intent.target}. Cette action modifie l’apparence de la session."
            if not apply and language == "fr"
            else f"SevenOS peut passer au thème {intent.target}." if language == "fr"
            else f"I can switch SevenOS to {intent.target} theme. This changes the session appearance." if not apply
            else f"SevenOS can switch to {intent.target} theme."
        )
    elif intent.intent == "SWITCH_WORKSPACE":
        dispatch_target = {"next": "r+1", "previous": "r-1"}.get(intent.target, intent.target)
        command = ["hyprctl", "dispatch", "workspace", dispatch_target]
        result["action"] = {"type": "switch_workspace", "target": intent.target, "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply)
        result["result"]["summary"] = (
            f"Je passe à l’espace de travail {intent.target}."
            if language == "fr"
            else f"Switching to workspace {intent.target}."
        )
    elif intent.intent == "KILL_PROCESS":
        processes = process_names_for_target(intent.target, apps)
        command = " || ".join(f"pkill -x -- {name}" for name in processes) if processes else f"pkill -x -- {intent.target}"
        result["action"] = {"type": "kill_process", "target": intent.target, "processes": processes, "command": command}
        result["result"] = stop_process(intent.target, apps, apply=effective_apply)
        if (result["result"] or {}).get("applied"):
            result["result"]["summary"] = f"J’ai demandé au système de fermer {intent.target}."
        elif processes:
            result["result"]["summary"] = f"Je peux fermer {intent.target}, mais cette action peut interrompre une fenêtre ou un travail en cours. Confirme avec --apply ou depuis l’interface."
        else:
            result["result"]["summary"] = f"Je n’ai pas trouvé de processus sûr correspondant à {intent.target}."
    elif intent.intent == "CHECK_NETWORK":
        result["language"] = language_for_text(text)
        result["action"] = {"type": "answer_system_question", "target": "network"}
        result["result"] = answer_system_question("network", text)
    elif intent.intent == "REPAIR_NETWORK":
        command = ["systemctl", "restart", "NetworkManager.service"]
        result["action"] = {"type": "repair_network", "target": "wifi", "command": " ".join(command), "playbook": playbook("wifi_repair")}
        result["result"] = run(command, apply=effective_apply)
        result["result"]["summary"] = (
            "Je peux tenter une réparation Wi-Fi. Elle peut redémarrer NetworkManager, donc je garde cette action en confirmation."
            if not apply and language == "fr"
            else "J’ai lancé la réparation Wi-Fi." if language == "fr"
            else "I can attempt a Wi-Fi repair. It may restart NetworkManager, so this stays behind confirmation." if not apply
            else "I started the Wi-Fi repair."
        )
    elif intent.intent == "DIAGNOSE_SYSTEM":
        result["action"] = {"type": "diagnose_system", "target": intent.target}
        diag = diagnostics(intent.target)
        provider = local_answer(text, {"diagnostics": diag, "system_context": system_context(), "language": language})
        result["result"] = {
            "applied": False,
            "diagnostics": diag,
            "provider": provider,
            "summary": provider.get("summary") or ("Diagnostic prêt." if language == "fr" else "Diagnostic ready."),
        }
    elif intent.intent == "HEALTH_PLAN":
        result["action"] = {"type": "health_plan", "target": "system", "command": "seven ai 'plan santé système' --json"}
        result["result"] = system_health_plan(language)
    elif intent.intent == "DAILY_BRIEFING":
        result["action"] = {"type": "daily_briefing", "target": "day", "command": "seven ai 'briefing SevenOS' --json"}
        result["result"] = daily_briefing_answer(language)
    elif intent.intent == "ANSWER_SYSTEM_QUESTION":
        result["language"] = language_for_text(text)
        result["action"] = {"type": "answer_system_question", "target": intent.target}
        result["result"] = answer_system_question(intent.target, text)
    elif intent.intent == "INSTALL_PACKAGE":
        command = [str(ROOT_DIR / "bin/sevenpkg"), "install", intent.target]
        result["action"] = {"type": "install_package", "target": intent.target, "command": " ".join(command)}
        result["result"] = run(command, apply=effective_apply, cwd=ROOT_DIR)
        result["result"]["summary"] = (
            f"Je peux préparer l’installation de {intent.target} via SevenPkg. Je montre d’abord l’impact avant toute modification."
            if not apply and language == "fr"
            else f"J’ai lancé l’installation de {intent.target} via SevenPkg." if language == "fr"
            else f"I can prepare installing {intent.target} through SevenPkg and preview the impact first." if not apply
            else f"I started installing {intent.target} through SevenPkg."
        )
    elif intent.intent == "OPTIMIZE_SYSTEM":
        result["action"] = {"type": "optimize_system", "commands": ["seven insights", "seven repair all", "seven scheduler plan"], "playbook": playbook("slow_system")}
        result["result"] = {
            "applied": False,
            "diagnostics": diagnostics("system"),
            "summary": "Je vais d’abord inspecter charge, mémoire, services et processus avant de proposer une optimisation." if language == "fr" else "I will inspect load, memory, services and processes before suggesting optimization.",
            "detail": "Preview first. Use SevenAI with --apply once the plan is acceptable.",
        }
    elif intent.intent == "SYSTEM_STATUS":
        result["action"] = {"type": "system_status", "command": "seven state --json"}
        result["result"] = run([str(ROOT_DIR / "bin/seven"), "state", "--json"], apply=True, cwd=ROOT_DIR)
        result["result"]["summary"] = "État SevenOS récupéré." if language == "fr" else "SevenOS state retrieved."
    elif intent.intent == "EXPLAIN_SEVENOS":
        result["action"] = {"type": "explain_sevenos", "target": "sevenos"}
        result["result"] = {
            "applied": False,
            "summary": "SevenOS est un environnement à sept espaces : Equinox coordonne, les Mini OS spécialisent l’usage, et SevenAI aide à comprendre et agir.",
            "knowledge": sevenos_knowledge(),
        }
    elif intent.intent == "SHOW_SHORTCUTS":
        result["action"] = {"type": "show_shortcuts", "target": "keyboard"}
        result["result"] = {
            "applied": False,
            "summary": "Voici les raccourcis SevenOS utiles pour naviguer, chercher, ouvrir Spotlight et gérer les espaces.",
            "shortcuts": shortcut_catalog(),
        }
    elif intent.intent == "SHOW_EXECUTION_POLICY":
        policy = execution_policy()
        result["action"] = {"type": "show_execution_policy", "target": "sevenai", "command": "seven ai execution --json"}
        result["result"] = {
            "applied": False,
            "summary": "SevenAI peut répondre et ouvrir des apps automatiquement, mais les changements système passent par aperçu, confirmation ou blocage.",
            "policy": policy,
        }
    elif intent.intent == "RECOMMEND_ACTIONS":
        result["action"] = {"type": "recommend_actions", "target": "system", "command": "seven ai brain --json"}
        result["result"] = contextual_next_actions(language)
    elif intent.intent == "EXPLAIN_DECISION":
        result["action"] = {"type": "explain_decision", "target": "next-action", "command": "seven ai 'que dois-je faire maintenant' --json"}
        result["result"] = decision_explanation(language)
    elif intent.intent == "CREATE_AI_MISSION":
        result["action"] = {"type": "create_ai_mission", "target": intent.target, "command": f"seven ai missions create {shlex.quote(intent.target)} --json"}
        result["result"] = create_ai_mission(intent.target, language)
    elif intent.intent == "SHOW_AI_MISSIONS":
        result["action"] = {"type": "show_ai_missions", "target": "missions", "command": "seven ai missions --json"}
        result["result"] = missions_board(language)
    elif intent.intent == "MISSION_STATUS":
        result["action"] = {"type": "mission_status", "target": "missions", "command": "seven ai missions status --json"}
        result["result"] = mission_status(language)
    elif intent.intent == "NEXT_AI_MISSION_STEP":
        result["action"] = {"type": "next_ai_mission_step", "target": "missions", "command": "seven ai missions next --json"}
        result["result"] = mission_next_step(language)
    elif intent.intent == "COMPLETE_AI_MISSION_STEP":
        result["action"] = {"type": "complete_ai_mission_step", "target": "missions", "command": "seven ai missions complete --json"}
        result["result"] = complete_next_mission_step(language)
    elif intent.intent == "REMEMBER_PREFERENCE":
        result["action"] = {"type": "remember_preference", "target": intent.target, "command": "seven ai preferences --json"}
        result["result"] = remember_preference(text, language)
    elif intent.intent == "SHOW_PREFERENCES":
        result["action"] = {"type": "show_preferences", "target": "preferences", "command": "seven ai preferences --json"}
        result["result"] = preferences_summary(language)
    elif intent.intent == "MEMORY_PROFILE":
        result["action"] = {"type": "memory_profile", "target": "memory", "command": "seven ai learning --json"}
        result["result"] = memory_profile_answer(language)
    elif intent.intent == "MEMORY_AUDIT":
        result["action"] = {"type": "memory_audit", "target": "memory", "command": "seven ai learning audit --json"}
        result["result"] = memory_audit_answer(language)
    elif intent.intent == "MEMORY_PLAN":
        result["action"] = {"type": "memory_plan", "target": "memory", "command": "seven ai learning audit --json"}
        result["result"] = memory_plan_answer(language)
    elif intent.intent == "MEMORY_HISTORY":
        result["action"] = {"type": "memory_history", "target": "memory", "command": "seven ai learning history --json"}
        result["result"] = memory_history_answer(language)
    elif intent.intent == "MEMORY_INSIGHTS":
        result["action"] = {"type": "memory_insights", "target": "memory", "command": "seven ai learning insights --json"}
        result["result"] = memory_insights_answer(language)
    elif intent.intent == "MEMORY_BRIEFING":
        result["action"] = {"type": "memory_briefing", "target": "memory", "command": "seven ai learning briefing --json"}
        result["result"] = memory_briefing_answer(language)
    elif intent.intent == "LEARNING_STATUS":
        result["action"] = {"type": "learning_status", "target": "learning", "command": "seven ai learning --json"}
        result["result"] = learning_control("status", apply=True, language=language)
    elif intent.intent == "LEARNING_SOURCES":
        result["action"] = {"type": "learning_sources", "target": "sources", "command": "seven ai learning sources --json"}
        result["result"] = learning_source_control("list", language=language, apply=False)
    elif intent.intent == "LEARNING_ADD_SOURCE":
        result["action"] = {"type": "learning_add_source", "target": intent.target, "command": f"seven ai learning add-source {shlex.quote(intent.target)} --json"}
        result["result"] = learning_source_control("add", intent.target, apply=effective_apply and apply, language=language)
    elif intent.intent == "LEARNING_REMOVE_SOURCE":
        result["action"] = {"type": "learning_remove_source", "target": intent.target, "command": f"seven ai learning remove-source {shlex.quote(intent.target)} --json"}
        result["result"] = learning_source_control("remove", intent.target, apply=effective_apply and apply, language=language)
    elif intent.intent == "LEARNING_ENABLE":
        result["action"] = {"type": "learning_enable", "target": "learning", "command": "seven ai learning enable --json"}
        result["result"] = learning_control("enable", apply=effective_apply and apply, language=language)
    elif intent.intent == "LEARNING_DISABLE":
        result["action"] = {"type": "learning_disable", "target": "learning", "command": "seven ai learning disable --json"}
        result["result"] = learning_control("disable", apply=effective_apply and apply, language=language)
    elif intent.intent == "LEARNING_SCAN":
        result["action"] = {"type": "learning_scan", "target": "learning", "command": "seven ai learning scan --json"}
        result["result"] = learning_control("scan", apply=effective_apply and apply, language=language)
    elif intent.intent == "LEARNING_SCAN_CONTENT":
        result["action"] = {"type": "learning_scan_content", "target": "learning-content", "command": "seven ai learning scan --content --json"}
        result["result"] = learning_control("scan_content", apply=effective_apply and apply, language=language)
    elif intent.intent == "LEARNING_CLEAR_INDEX":
        result["action"] = {"type": "learning_clear_index", "target": "learning-index", "command": "seven ai learning clear-index --json"}
        result["result"] = learning_control("clear_index", apply=effective_apply and apply, language=language)
    elif intent.intent == "LEARNING_CLEAR_SNIPPETS":
        result["action"] = {"type": "learning_clear_snippets", "target": "learning-snippets", "command": "seven ai learning clear-snippets --json"}
        result["result"] = learning_control("clear_snippets", apply=effective_apply and apply, language=language)
    elif intent.intent == "FORGET_PREFERENCES":
        result["action"] = {"type": "forget_preferences", "target": "preferences", "command": "seven ai preferences clear --json"}
        result["result"] = forget_preferences(language)
    elif intent.intent == "AI_STATE_STATUS":
        result["action"] = {"type": "ai_state_status", "target": "state", "command": "seven ai state --json"}
        result["result"] = ai_state_health(language)
    elif intent.intent == "SEVENAI_CAPABILITIES":
        result["action"] = {"type": "sevenai_capabilities", "target": "sevenai", "command": "seven ai capabilities --json"}
        result["result"] = sevenai_capabilities(language)
    elif intent.intent == "MODEL_STATUS":
        result["action"] = {"type": "model_status", "target": "local-model", "command": "seven ai models --json"}
        result["result"] = model_manager(language)
    elif intent.intent == "MODEL_SETUP":
        result["action"] = {"type": "model_setup", "target": "ollama", "command": "seven ai model-setup --apply --json"}
        result["result"] = setup_model_runtime(apply=effective_apply and apply, language=language)
    elif intent.intent == "LOCAL_SEARCH":
        result["action"] = {"type": "local_search", "target": intent.target, "command": f"seven ai learning search {shlex.quote(intent.target)} --json"}
        result["result"] = local_search(intent.target, language=language)
    elif intent.intent == "EXPLAIN_LEDGER":
        explanation = ledger_explanation(language)
        result["action"] = {"type": "explain_ledger", "target": "recent", "command": "seven ai ledger --json"}
        result["result"] = explanation
    elif intent.intent == "RECENT_ACTIVITY":
        result["action"] = {"type": "recent_activity", "target": "memory", "command": "seven ai memory --json"}
        result["result"] = recent_activity_answer(language)
    elif intent.intent == "CURRENT_CONTEXT":
        result["action"] = {"type": "current_context", "target": "session", "command": "seven ai context --json"}
        result["result"] = active_context_answer(language)
    elif intent.intent == "ASSIST_ACTIVE_APP":
        result["action"] = {"type": "assist_active_app", "target": "session", "command": "seven ai 'quel est mon contexte actuel' --json"}
        result["result"] = active_app_assist_answer(language)
    elif intent.intent == "ROUTE_AGENT":
        result["action"] = {"type": "route_agent", "target": intent.target, "command": "seven ai handoffs --json"}
        result["result"] = agent_handoff_answer(text, language)
    elif intent.intent == "AGENT_STATUS":
        result["action"] = {"type": "agent_status", "target": "agents", "command": "seven ai agents --json"}
        result["result"] = agent_status_answer(language)
    elif intent.intent == "OPTIMIZE_WORKFLOW":
        result["action"] = {"type": "optimize_workflow", "target": "workspace"}
        result["result"] = {
            "applied": False,
            "summary": "Je peux organiser ton espace selon le Mini OS actif, les apps ouvertes et les prochaines actions utiles.",
            "workflow": workflow_plan(),
        }
    elif intent.intent == "PLAN_MISSION":
        result["action"] = {"type": "plan_mission", "target": intent.target, "command": f"seven experience-center intent {shlex.quote(intent.target)} --gui"}
        result["result"] = mission_plan(intent.target, apply=effective_apply and apply)
        result["result"]["summary"] = "J’ai préparé un parcours multi-espaces SevenOS pour cette mission." if language == "fr" else "I prepared a multi-space SevenOS route for this mission."
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

    context = assistant_context(language, result)
    result["assistant_context"] = context
    result["response_card"] = response_card(language, result, context)

    remember({
        "ts": int(time.time()),
        "input": text,
        "intent": intent.intent,
        "target": intent.target,
        "safety": intent.safety,
        "applied": bool((result.get("result") or {}).get("applied")),
    })
    ledger_event = record_agent_ledger(text, intent, result)
    if ledger_event:
        result["ledger"] = {
            "recorded": True,
            "ts": ledger_event.get("ts"),
            "risk": ledger_event.get("risk", "low"),
            "action": ledger_event.get("action", ""),
            "path": str(Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "sevenos" / "ai" / "ledger.jsonl"),
        }
    else:
        result["ledger"] = {"recorded": False}
    return result


def print_human(data: dict[str, Any]) -> None:
    intent = data.get("intent", {})
    result = data.get("result") or {}
    action = data.get("action") or {}
    language = data.get("language") or active_language()
    action_type = action.get("type", "")
    target = action.get("target") or intent.get("target") or ""
    print(msg("title", language))
    print("=======")
    print(f"{msg('input', language)} : {data.get('input', '')}")

    card = data.get("response_card") if isinstance(data.get("response_card"), dict) else {}
    card_first_actions = {
        "answer_system_question",
        "recommend_actions",
        "explain_decision",
        "sevenai_capabilities",
        "agent_status",
        "agent_handoff",
        "daily_briefing",
        "current_context",
        "assist_active_app",
        "show_preferences",
        "memory_profile",
        "memory_audit",
        "memory_plan",
        "memory_history",
        "memory_insights",
        "memory_briefing",
        "learning_status",
        "learning_sources",
        "learning_add_source",
        "learning_remove_source",
        "learning_enable",
        "learning_disable",
        "learning_scan",
        "learning_scan_content",
        "learning_clear_index",
        "learning_clear_snippets",
        "recent_activity",
        "explain_ledger",
        "model_status",
        "model_setup",
        "local_search",
    }
    if card and card.get("answer") and action.get("type") in card_first_actions:
        print()
        print(f"{card.get('title', 'SevenAI')}")
        print(str(card.get("answer")))
        for item in card.get("bullets", []) if isinstance(card.get("bullets"), list) else []:
            print(f"- {item}")
        actions = card.get("quick_actions") if isinstance(card.get("quick_actions"), list) else []
        if actions:
            label = "Action proposée" if language == "fr" else "Suggested action"
            first = actions[0]
            print(f"{label} : {first.get('title')} · {first.get('command')}")
        return

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
    elif action_type == "answer_system_question":
        print(msg("diagnostic", result.get("language") or language))
    elif action_type == "explain_sevenos":
        print(msg("sevenos", language))
    elif action_type == "show_shortcuts":
        print(msg("shortcuts", language))
    elif action_type == "optimize_workflow":
        print(msg("workflow", language))
    elif action_type == "plan_mission":
        print(msg("mission", language))
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
    elif isinstance(result, dict) and result.get("plan"):
        plan = result.get("plan") or {}
        match = plan.get("match") if isinstance(plan.get("match"), dict) else {}
        if match:
            print(match.get("title", ""))
            print(match.get("detail", ""))
            for index, step_item in enumerate(match.get("steps", []) if isinstance(match.get("steps"), list) else [], 1):
                print(f"{index}. {step_item.get('profile_title')}: {step_item.get('title')}")
                if step_item.get("output"):
                    print(f"   -> {step_item.get('output')}")
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

    context = data.get("assistant_context") if isinstance(data.get("assistant_context"), dict) else {}
    next_action = context.get("next_action") if isinstance(context.get("next_action"), dict) else {}
    if next_action.get("title") and next_action.get("command"):
        label = "Prochaine action" if language == "fr" else "Next action"
        print(f"{label} : {next_action.get('title')} · {next_action.get('command')}")


def main() -> int:
    raw_args = sys.argv[1:]
    json_flag = "--json" in raw_args
    apply_flag = "--apply" in raw_args
    yes_flag = "--yes" in raw_args
    web_flag = "--web" in raw_args
    compact_flag = "--compact" in raw_args
    raw_args = [arg for arg in raw_args if arg not in ("--json", "--apply", "--yes", "--web", "--compact")]
    parser = argparse.ArgumentParser(prog="seven-ai-agent")
    parser.add_argument("action", nargs="?", default="ask", choices=("ask", "run", "intent", "operate", "execution", "apps", "context", "machine", "brain", "state", "capabilities", "memory", "preferences", "missions", "knowledge", "shortcuts", "workflow", "llm", "models", "model-setup", "manager", "web", "research", "diagnose", "playbook", "provider"))
    parser.add_argument("text", nargs=argparse.REMAINDER)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--web", action="store_true")
    parser.add_argument("--compact", action="store_true")
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args(raw_args)
    args.json = args.json or json_flag
    args.apply = args.apply or apply_flag
    args.yes = args.yes or yes_flag
    args.web = args.web or web_flag
    args.compact = args.compact or compact_flag

    if args.action == "apps":
        data = {"schema": "sevenos.ai.apps.v1", "apps": [asdict(app) for app in app_registry()]}
        print(json.dumps(data, indent=2) if args.json else "\n".join(f"{app['name']}\t{app['command']}" for app in data["apps"]))
        return 0
    if args.action == "context":
        data = system_context()
        print(json.dumps(data, indent=2) if args.json else f"Load: {data['load']['1m']:.2f} · processes: {len(data['process_sample'])}")
        return 0
    if args.action == "machine":
        data = machine_snapshot()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else f"Disk: {data['disk']['home']['total_gb']} GiB · RAM: {data['memory']['total_mb']} MiB")
        return 0
    if args.action == "brain":
        data = brain_snapshot()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else f"{data['state']} · {data['score']}% · {data['profile']['title']}")
        return 0
    if args.action == "state":
        data = ai_state_health(active_language())
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data["summary"])
        return 0
    if args.action == "capabilities":
        data = sevenai_capabilities(active_language())
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data["summary"])
        return 0
    if args.action == "memory":
        data = compact_memory() if args.compact else read_memory(args.limit)
        if args.json:
            print(json.dumps(data, indent=2))
        elif args.compact:
            print(f"Memory compacted: {data.get('before_events', 0)} -> {data.get('after_events', 0)} events")
        else:
            print("\n".join(f"{item.get('intent')} {item.get('target')}" for item in data["events"]))
        return 0
    if args.action == "preferences":
        language = active_language()
        text = " ".join(args.text).strip()
        if text in {"clear", "reset", "forget", "effacer", "oublier"}:
            data = forget_preferences(language)
        elif text:
            data = remember_preference(text, language)
        else:
            data = preferences_summary(language)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data["summary"])
        return 0
    if args.action == "missions":
        language = active_language()
        text = " ".join(args.text).strip()
        if text.startswith(("create ", "créer ", "creer ", "crée ", "cree ")):
            _, _, mission_query = text.partition(" ")
            data = create_ai_mission(mission_query, language)
        elif text in {"status", "statut", "etat", "état", "progress", "progression"}:
            data = mission_status(language)
        elif text in {"next", "suivant", "continue", "continuer"}:
            data = mission_next_step(language)
        elif text in {"complete", "done", "termine", "terminer", "completed"}:
            data = complete_next_mission_step(language)
        else:
            data = missions_board(language)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data["summary"])
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
    if args.action == "models":
        data = model_manager()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data.get("summary", data["guardrail"]))
        return 0
    if args.action == "execution":
        data = execution_policy()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else f"{data['state']} · {data['runtime']['execution_default']} execution")
        return 0
    if args.action == "model-setup":
        data = setup_model_runtime(apply=args.apply)
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else data.get("summary", f"{data['state']} · {data.get('model', '')}"))
        return 0
    if args.action == "manager":
        data = os_manager()
        print(json.dumps(data, indent=2, ensure_ascii=False) if args.json else f"{data['state']} · {data['score']}% · {data['coverage']['domains']} domains")
        return 0
    if args.action == "provider":
        prompt = " ".join(args.text).strip()
        learning = run_json([str(ROOT_DIR / "scripts/ai.sh"), "learning", "--json"], {"schema": "sevenos.ai-learning.v1", "state": "unknown"})
        data = provider_answer(prompt, {"diagnostics": diagnostics("system"), "memory": read_memory(8), "learning": learning, "system_context": system_context(), "language": active_language()})
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
    if args.action == "operate":
        data = operation_plan(text)
        if args.json:
            print(json.dumps(data, indent=2, ensure_ascii=False))
        else:
            summary = data["summary"]
            print(f"{summary['title']} · {summary['command']}")
            if summary["requires_apply"]:
                print("Preview only. Use --apply on the natural request after review.")
        return 0

    data = execute_intent(intent, text, apply=args.apply)
    if args.json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print_human(data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
