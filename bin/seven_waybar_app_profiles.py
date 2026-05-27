#!/usr/bin/env python3
"""Shared active-app and app-menu contract for the SevenOS menu bar."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from seven_i18n import language_code  # noqa: E402
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "sevenos"
CONTEXT_FILE = RUNTIME_DIR / "waybar-context.json"
MENU_AREAS = ("file", "edit", "view", "extra", "tools", "window", "help")
LANG_CODE = language_code()


FR_TO_EN = {
    "Fichier": "File",
    "Édition": "Edit",
    "Affichage": "View",
    "Historique": "History",
    "Signets": "Bookmarks",
    "Fenêtre": "Window",
    "Aide": "Help",
    "Shell": "Shell",
    "Profils": "Profiles",
    "Session": "Session",
    "Présentation": "Layout",
    "Aller": "Go",
    "Actions": "Actions",
    "Outils": "Tools",
    "Export": "Export",
    "Lecture": "Playback",
    "Contrôles": "Controls",
    "Audio": "Audio",
    "Audit": "Audit",
    "Analyse": "Analysis",
    "Jeux": "Games",
    "Captures": "Captures",
    "Collections": "Collections",
    "Culture": "Culture",
    "Onglets": "Tabs",
    "Favoris": "Favorites",
    "Marque-pages": "Bookmarks",
    "Média": "Media",
    "Vidéo": "Video",
    "Sous-titres": "Subtitles",
    "Scènes": "Scenes",
    "Profil": "Profile",
    "Abonnements": "Subscriptions",
    "Message": "Message",
    "Libellés": "Labels",
    "Document": "Document",
    "Insertion": "Insert",
    "Format": "Format",
    "Classeur": "Workbook",
    "Données": "Data",
    "Nouveau": "New",
    "Projet": "Project",
    "Objet": "Object",
    "Page": "Page",
    "Base": "Database",
    "Actions": "Actions",
    "Lecture / pause": "Play / pause",
    "Vidéo suivante": "Next video",
    "Vidéo précédente": "Previous video",
    "Plein écran": "Full screen",
    "Mode cinéma": "Theater mode",
    "Taille normale": "Normal size",
    "Qualité": "Quality",
    "Volume": "Volume",
    "S'abonner": "Subscribe",
    "J'aime": "Like",
    "Partager": "Share",
    "Nouveau message": "New message",
    "Nouvelle fenêtre": "New window",
    "Fermer": "Close",
    "Rechercher mail": "Search mail",
    "Tout afficher": "Show all",
    "Archiver": "Archive",
    "Spam": "Spam",
    "Paramètres Gmail": "Gmail settings",
    "Copier titre": "Copy title",
    "Exporter": "Export",
    "Imprimer": "Print",
    "Enregistrer": "Save",
    "Image": "Image",
    "Lien": "Link",
    "Table": "Table",
    "Styles": "Styles",
    "Alignement": "Alignment",
    "Liste": "List",
    "Rechercher": "Search",
    "Orthographe": "Spelling",
    "Préférences": "Preferences",
    "Ligne": "Row",
    "Colonne": "Column",
    "Graphique": "Chart",
    "Trier": "Sort",
    "Filtrer": "Filter",
    "Validation": "Validation",
    "Ouvrir": "Open",
    "Téléverser": "Upload",
    "Dossier": "Folder",
    "Importer": "Import",
    "Cloner": "Clone",
    "Ouvrir projet Forge": "Open Forge project",
    "Terminal repo": "Repo terminal",
    "Historique": "History",
    "Nouvelle PR": "New PR",
    "Dupliquer": "Duplicate",
    "Grouper": "Group",
    "Dégrouper": "Ungroup",
    "Présenter": "Present",
    "Lien prototype": "Prototype link",
    "Inspecter": "Inspect",
    "Nouvelle page": "New page",
    "Calendrier": "Calendar",
    "Avancer": "Forward",
    "Reculer": "Back",
    "Zoom": "Zoom",
    "Muet": "Mute",
    "Suivant": "Next",
    "Précédent": "Previous",
    "Ajouter à la playlist": "Add to playlist",
    "Bibliothèque": "Library",
    "Nouvel onglet": "New tab",
    "Fenêtre privée": "Private window",
    "Rouvrir l'onglet fermé": "Reopen closed tab",
    "Onglet suivant": "Next tab",
    "Onglet précédent": "Previous tab",
    "Fermer l'onglet": "Close tab",
    "Téléchargements": "Downloads",
    "Barre d'adresse": "Address bar",
    "Ajouter cette page": "Bookmark this page",
    "Recharger": "Reload",
    "Zoom avant": "Zoom in",
    "Zoom arrière": "Zoom out",
    "Taille réelle": "Actual size",
    "Outils développeur": "Developer tools",
    "Tout sélectionner": "Select all",
    "Étendre sélection": "Expand selection",
    "Réduire sélection": "Shrink selection",
    "Palette commandes": "Command palette",
    "Nouveau terminal": "New terminal",
    "Annuler": "Undo",
    "Rétablir": "Redo",
    "Couper": "Cut",
    "Copier": "Copy",
    "Coller": "Paste",
    "Profil terminal": "Terminal profile",
    "Restaurer session": "Restore session",
    "Exporter sélection": "Export selection",
    "Audit rapide": "Quick audit",
    "Jeux Pulse": "Pulse games",
    "Contrôles fenêtre": "Window controls",
    "Centrer": "Center",
    "Flottante": "Floating",
    "Split gauche": "Split left",
    "Split droite": "Split right",
    "Aide app active": "Active app help",
    "Aide SevenOS": "SevenOS help",
    "Menus SevenOS": "SevenOS menus",
    "Service actif": "Active service",
    "Click: menu contextuel · Right click: fenêtre": "Click: context menu · Right click: window",
    "déplacé dans": "moved to",
    "Menu masqué": "Hidden menu",
    "menu de l'app active": "active app menu",
    "Click: ouvrir le menu natif · Right click: actions SevenOS": "Click: open native menu · Right click: SevenOS actions",
}


def ui(text: str) -> str:
    return FR_TO_EN.get(text, text) if LANG_CODE != "fr" else text


def localize_items(items: list[tuple[str, str, str]]) -> list[tuple[str, str, str]]:
    return [(icon, ui(label), shortcut) for icon, label, shortcut in items]


def run(command: list[str], timeout: float = 0.6) -> str:
    try:
        return subprocess.run(command, text=True, capture_output=True, check=False, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def compact_label(value: str, limit: int = 20) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= limit:
        return text
    return text[: max(1, limit - 1)].rstrip() + "…"


def read_json(path: Path, max_age: float = 2.5) -> dict:
    try:
        if max_age > 0 and time.time() - path.stat().st_mtime > max_age:
            return {}
        return json.loads(path.read_text(encoding="utf-8") or "{}")
    except Exception:
        return {}


def active_window() -> dict:
    if os.environ.get("SEVENOS_TEST_APP_CLASS"):
        klass = os.environ["SEVENOS_TEST_APP_CLASS"]
        return {
            "class": klass,
            "initialClass": klass,
            "title": os.environ.get("SEVENOS_TEST_APP_TITLE", "Test App"),
            "address": os.environ.get("SEVENOS_TEST_APP_ADDRESS", ""),
        }
    cached = read_json(CONTEXT_FILE)
    window = cached.get("window") if isinstance(cached.get("window"), dict) else {}
    if window:
        return window
    if shutil.which("hyprctl"):
        try:
            return json.loads(run(["hyprctl", "activewindow", "-j"], timeout=0.45) or "{}")
        except json.JSONDecodeError:
            return {}
    return {}


def active_profile_key() -> str:
    manager = ROOT / "profiles/profile-manager.sh"
    if manager.exists():
        try:
            data = json.loads(run([str(manager), "current", "--json"], timeout=0.8) or "{}")
            return str(data.get("key") or "equinox").lower()
        except json.JSONDecodeError:
            pass
    return os.environ.get("SEVENOS_PROFILE", "equinox").lower()


def mode_from_class(app_class: str, profile_key: str = "") -> str:
    klass = app_class.lower()
    if any(token in klass for token in ("google-chrome", "chromium", "chrome", "firefox", "brave", "vivaldi", "librewolf", "browser", "edge")):
        return "browser"
    if any(token in klass for token in ("code", "codium", "cursor", "jetbrains", "idea", "pycharm", "webstorm")):
        return "developer"
    if any(token in klass for token in ("terminal", "kitty", "foot", "alacritty", "wezterm", "console")):
        return "terminal"
    if any(token in klass for token in ("nautilus", "seven-files", "sevenfiles", "thunar", "dolphin", "nemo", "file")):
        return "files"
    if any(token in klass for token in ("libreoffice", "onlyoffice", "writer", "calc", "impress", "evince", "okular", "zathura", "reader")):
        return "documents"
    if any(token in klass for token in ("vlc", "mpv", "spotify", "audacious", "rhythmbox", "celluloid")):
        return "media"
    if any(token in klass for token in ("gimp", "inkscape", "blender", "kdenlive", "obs", "krita", "studio")):
        return "studio"
    if profile_key in {"studio", "shield", "atlas", "forge", "pulse", "baobab"}:
        return profile_key
    return "default"


def key_from_class(app_class: str) -> str:
    klass = app_class.lower()
    if "google-chrome" in klass:
        return "chrome"
    if "chromium" in klass:
        return "chromium"
    if "firefox" in klass or "librewolf" in klass:
        return "firefox"
    if "brave" in klass:
        return "brave"
    if klass in {"code", "code-url-handler"} or "visual-studio-code" in klass:
        return "vscode"
    if "codium" in klass:
        return "vscodium"
    if "cursor" in klass:
        return "cursor"
    if "jetbrains" in klass or "pycharm" in klass or "webstorm" in klass or "idea" in klass:
        return "jetbrains"
    if "kitty" in klass:
        return "kitty"
    if "seventerminal" in klass or "terminal" in klass:
        return "terminal"
    if "sevenfiles" in klass or "seven-files" in klass:
        return "seven-files"
    if "nautilus" in klass:
        return "nautilus"
    if "libreoffice" in klass or "onlyoffice" in klass:
        return "office"
    if "vlc" in klass:
        return "vlc"
    if "mpv" in klass:
        return "mpv"
    if "spotify" in klass:
        return "spotify"
    if "obs" in klass:
        return "obs"
    if "gimp" in klass or "inkscape" in klass or "krita" in klass or "blender" in klass:
        return "creative"
    return "generic"


def service_from_title(app_key: str, title: str) -> str:
    text = title.lower()
    if app_key not in {"chrome", "chromium", "firefox", "brave"}:
        return ""
    rules = (
        ("youtube", ("youtube", "youtu.be")),
        ("gmail", ("gmail", "inbox", "mail.google")),
        ("google-docs", ("google docs", "docs.google", "document sans titre")),
        ("google-sheets", ("google sheets", "sheets.google")),
        ("google-drive", ("google drive", "drive.google")),
        ("github", ("github",)),
        ("figma", ("figma",)),
        ("notion", ("notion",)),
        ("spotify-web", ("spotify",)),
        ("streaming", ("netflix", "prime video", "disney+", "canal+", "free movies")),
    )
    for service, tokens in rules:
        if service == "gmail":
            if "gmail" in text or "mail.google" in text or ("inbox" in text and "mail" in text):
                return service
            continue
        if any(token in text for token in tokens):
            return service
    return ""


MODE_LABELS = {
    "browser": ["Fichier", "Édition", "Affichage", "Historique", "Signets", "Fenêtre", "Aide"],
    "developer": ["Fichier", "Édition", "Affichage", "", "", "", ""],
    "terminal": ["Shell", "Édition", "Affichage", "Profils", "Session", "Fenêtre", "Aide"],
    "files": ["Fichier", "Édition", "Présentation", "Aller", "Actions", "Fenêtre", "Aide"],
    "documents": ["Fichier", "Édition", "Présentation", "Outils", "Export", "Fenêtre", "Aide"],
    "media": ["Lecture", "Édition", "Affichage", "Contrôles", "Audio", "Fenêtre", "Aide"],
    "studio": ["Fichier", "Édition", "Présentation", "Export", "Outils", "Fenêtre", "Aide"],
    "shield": ["Fichier", "Édition", "Audit", "Sandbox", "Analyse", "Fenêtre", "Aide"],
    "atlas": ["Fichier", "Édition", "Bridge", "Maps", "Apps", "Fenêtre", "Aide"],
    "forge": ["Fichier", "Édition", "Affichage", "", "", "", ""],
    "pulse": ["Fichier", "Édition", "Affichage", "Jeux", "Captures", "Fenêtre", "Aide"],
    "baobab": ["Fichier", "Édition", "Collections", "Culture", "Lecture", "Fenêtre", "Aide"],
    "default": ["Fichier", "Édition", "Affichage", "", "", "Fenêtre", "Aide"],
}

APP_LABELS = {
    "chrome": ["Onglets", "Édition", "Affichage", "Historique", "Favoris", "Fenêtre", "Aide"],
    "chromium": ["Onglets", "Édition", "Affichage", "Historique", "Favoris", "Fenêtre", "Aide"],
    "firefox": ["Fichier", "Édition", "Affichage", "Historique", "Marque-pages", "Fenêtre", "Aide"],
    "brave": ["Onglets", "Édition", "Affichage", "Historique", "Favoris", "Fenêtre", "Aide"],
    "vscode": ["Fichier", "Édition", "Affichage", "", "", "", ""],
    "vscodium": ["Fichier", "Édition", "Affichage", "", "", "", ""],
    "cursor": ["Fichier", "Édition", "Affichage", "", "", "", ""],
    "kitty": ["Shell", "Édition", "Affichage", "Profils", "Session", "Fenêtre", "Aide"],
    "terminal": ["Shell", "Édition", "Affichage", "Profils", "Session", "Fenêtre", "Aide"],
    "seven-files": ["Fichier", "Édition", "Présentation", "Aller", "Actions", "Fenêtre", "Aide"],
    "vlc": ["Média", "Lecture", "Audio", "Vidéo", "Sous-titres", "Fenêtre", "Aide"],
    "spotify": ["Lecture", "Édition", "Affichage", "Contrôles", "Audio", "Fenêtre", "Aide"],
    "obs": ["Fichier", "Édition", "Affichage", "Scènes", "Profil", "Fenêtre", "Aide"],
}

SERVICE_LABELS = {
    "youtube": ["Lecture", "Édition", "Affichage", "Vidéo", "Abonnements", "Fenêtre", "Aide"],
    "streaming": ["Lecture", "Édition", "Affichage", "Vidéo", "Audio", "Fenêtre", "Aide"],
    "spotify-web": ["Lecture", "Édition", "Affichage", "Playlist", "Audio", "Fenêtre", "Aide"],
    "gmail": ["Message", "Édition", "Affichage", "Libellés", "Outils", "Fenêtre", "Aide"],
    "google-docs": ["Document", "Édition", "Insertion", "Format", "Outils", "Fenêtre", "Aide"],
    "google-sheets": ["Classeur", "Édition", "Insertion", "Données", "Outils", "Fenêtre", "Aide"],
    "google-drive": ["Drive", "Édition", "Affichage", "Nouveau", "Outils", "Fenêtre", "Aide"],
    "github": ["Code", "Édition", "Projet", "Pull Request", "Actions", "Fenêtre", "Aide"],
    "figma": ["Fichier", "Édition", "Objet", "Prototype", "Dev Mode", "Fenêtre", "Aide"],
    "notion": ["Page", "Édition", "Affichage", "Base", "Outils", "Fenêtre", "Aide"],
}


def labels_for(mode: str, app_key: str, service: str) -> dict[str, str]:
    raw = SERVICE_LABELS.get(service) or APP_LABELS.get(app_key) or MODE_LABELS.get(mode) or MODE_LABELS["default"]
    return dict(zip(MENU_AREAS, [ui(label) for label in raw]))


def service_items(area: str, service: str) -> tuple[str, list[tuple[str, str, str]]] | None:
    specs = {
        "youtube": {
            "file": ("Lecture", [("󰐊", "Lecture / pause", "Space"), ("󰓩", "Vidéo suivante", "Shift+N"), ("󰓪", "Vidéo précédente", "Shift+P")]),
            "view": ("Affichage", [("󰊓", "Plein écran", "F"), ("󰍉", "Mode cinéma", "T"), ("󰾆", "Taille normale", "Esc")]),
            "extra": ("Vidéo", [("󰈐", "Qualité", ""), ("󰈈", "Sous-titres", "C"), ("󰕾", "Volume", "")]),
            "tools": ("Abonnements", [("󰐕", "S'abonner", ""), ("󰚢", "J'aime", ""), ("󰈙", "Partager", "")]),
        },
        "gmail": {
            "file": ("Message", [("󰇮", "Nouveau message", "C"), ("󰈔", "Nouvelle fenêtre", "Shift+C"), ("󰅖", "Fermer", "Esc")]),
            "view": ("Affichage", [("󰍉", "Rechercher mail", "/"), ("󰒆", "Tout afficher", "")]),
            "extra": ("Libellés", [("󰌕", "Libellés", ""), ("󰈤", "Archiver", "E"), ("󰩹", "Spam", "!")]),
            "tools": ("Outils", [("󰒓", "Paramètres Gmail", ""), ("󰅇", "Copier titre", "")]),
        },
        "google-docs": {
            "file": ("Document", [("󰈙", "Exporter", ""), ("󰐪", "Imprimer", "Ctrl+P"), ("󰆓", "Enregistrer", "Ctrl+S")]),
            "view": ("Insertion", [("󰉉", "Image", ""), ("󰌌", "Lien", "Ctrl+K"), ("󰉸", "Table", "")]),
            "extra": ("Format", [("󰉿", "Styles", ""), ("󰈙", "Alignement", ""), ("󰘦", "Liste", "")]),
            "tools": ("Outils", [("󰍉", "Rechercher", "Ctrl+F"), ("󰁨", "Orthographe", ""), ("󰒓", "Préférences", "")]),
        },
        "google-sheets": {
            "file": ("Classeur", [("󰈙", "Exporter", ""), ("󰐪", "Imprimer", "Ctrl+P")]),
            "view": ("Insertion", [("󰈛", "Ligne", ""), ("󰈜", "Colonne", ""), ("󰉸", "Graphique", "")]),
            "extra": ("Données", [("󰓫", "Trier", ""), ("󰈲", "Filtrer", ""), ("󰘦", "Validation", "")]),
            "tools": ("Outils", [("󰍉", "Rechercher", "Ctrl+F"), ("󰒓", "Paramètres", "")]),
        },
        "google-drive": {
            "file": ("Drive", [("󰝒", "Nouveau", ""), ("󰉋", "Ouvrir", ""), ("󰈙", "Téléverser", "")]),
            "extra": ("Nouveau", [("󰈔", "Dossier", ""), ("󰈙", "Importer", ""), ("󰉉", "Document", "")]),
            "tools": ("Outils", [("󰍉", "Rechercher", "/"), ("󰒓", "Paramètres Drive", "")]),
        },
        "github": {
            "file": ("Code", [("󰘬", "Cloner", ""), ("󰌢", "Ouvrir projet Forge", ""), ("󰆍", "Terminal repo", "")]),
            "view": ("Projet", [("󰊢", "Issues", ""), ("󰘬", "Pull requests", ""), ("󰋚", "Historique", "")]),
            "extra": ("Pull Request", [("󰘬", "Nouvelle PR", ""), ("󰑭", "Checks", ""), ("󰈙", "Review", "")]),
            "tools": ("Actions", [("󰐊", "Workflows", ""), ("󰒓", "Settings", "")]),
        },
        "figma": {
            "view": ("Objet", [("󰆏", "Dupliquer", ""), ("󰉿", "Grouper", ""), ("󰘬", "Dégrouper", "")]),
            "extra": ("Prototype", [("󰐊", "Présenter", ""), ("󰌌", "Lien prototype", "")]),
            "tools": ("Dev Mode", [("󰆍", "Inspecter", ""), ("󰈙", "Exporter assets", "")]),
        },
        "notion": {
            "file": ("Page", [("󰝒", "Nouvelle page", ""), ("󰆏", "Dupliquer", ""), ("󰈙", "Exporter", "")]),
            "extra": ("Base", [("󰉸", "Table", ""), ("󰃭", "Calendrier", ""), ("󰈲", "Filtrer", "")]),
            "tools": ("Outils", [("󰍉", "Rechercher", "Ctrl+P"), ("󰒓", "Paramètres", "")]),
        },
        "streaming": {
            "file": ("Lecture", [("󰐊", "Lecture / pause", "Space"), ("󰝚", "Avancer", "Right"), ("󰝙", "Reculer", "Left")]),
            "view": ("Affichage", [("󰊓", "Plein écran", "F"), ("󰍉", "Zoom", "")]),
            "extra": ("Vidéo", [("󰈐", "Qualité", ""), ("󰈈", "Sous-titres", "")]),
            "tools": ("Audio", [("󰕾", "Volume", ""), ("󰝟", "Muet", "M")]),
        },
        "spotify-web": {
            "file": ("Lecture", [("󰐊", "Lecture / pause", "Space"), ("󰒭", "Suivant", ""), ("󰒮", "Précédent", "")]),
            "extra": ("Playlist", [("󰐕", "Ajouter à la playlist", ""), ("󰋋", "Bibliothèque", "")]),
            "tools": ("Audio", [("󰕾", "Volume", ""), ("󰝟", "Muet", "")]),
        },
    }
    spec = specs.get(service, {})
    selected = spec.get(area)
    if not selected:
        return None
    title, items = selected
    return ui(title), localize_items(items)


def items_for(area: str, mode: str, key: str = "generic", service: str = "") -> tuple[str, list[tuple[str, str, str]]]:
    service_spec = service_items(area, service)
    if service_spec:
        return service_spec
    labels = labels_for(mode, key, service)
    title = labels.get(area, "") or "Actions"
    if key in {"chrome", "chromium", "brave", "firefox"}:
        if area == "file" and key in {"chrome", "chromium", "brave"}:
            return title, localize_items([("󰝒", "Nouvel onglet", "Ctrl+T"), ("󰈔", "Nouvelle fenêtre", "Ctrl+N"), ("󰈹", "Fenêtre privée", "Ctrl+Shift+N"), ("󰑖", "Rouvrir l'onglet fermé", "Ctrl+Shift+T"), ("󰓩", "Onglet suivant", "Ctrl+Tab"), ("󰓪", "Onglet précédent", "Ctrl+Shift+Tab"), ("󰅖", "Fermer l'onglet", "Ctrl+W")])
        if area == "extra":
            return title, localize_items([("󰋚", "Historique", "Ctrl+H"), ("󰉍", "Téléchargements", "Ctrl+J"), ("󰀂", "Barre d'adresse", "Ctrl+L")])
        if area == "tools":
            return title, localize_items([("󰃀", title, "Ctrl+Shift+O"), ("󰆤", "Ajouter cette page", "Ctrl+D"), ("󰈙", "Importer", "")])
        if area == "view":
            return title, localize_items([("󰑓", "Recharger", "Ctrl+R"), ("󰍉", "Zoom avant", "Ctrl++"), ("󰍉", "Zoom arrière", "Ctrl+-"), ("󰾆", "Taille réelle", "Ctrl+0"), ("󰙨", "Outils développeur", "Ctrl+Shift+I")])
    if key in {"vscode", "vscodium", "cursor", "jetbrains"}:
        if area == "view":
            return title, localize_items([("󰒆", "Tout sélectionner", "Ctrl+A"), ("󰉿", "Étendre sélection", ""), ("󰘬", "Réduire sélection", "")])
        if area == "extra":
            return title, localize_items([("󰕰", "Palette commandes", "Ctrl+Shift+P"), ("󰍉", "Rechercher", "Ctrl+F"), ("󰊓", "Plein écran", "F11")])
        if area == "tools":
            return title, localize_items([("󰆍", "Nouveau terminal", "Ctrl+Shift+`"), ("󰒓", "Terminal doctor", ""), ("󰌢", "Projet Forge", "")])
    if area == "file":
        return title, localize_items([("󰝒", "Nouvel onglet", "Ctrl+T"), ("󰈔", "Nouvelle fenêtre", "Ctrl+N"), ("󰉋", "Ouvrir", "Ctrl+O"), ("󰆓", "Enregistrer", "Ctrl+S"), ("󰐪", "Imprimer", "Ctrl+P"), ("󰅖", "Fermer", "Ctrl+W")])
    if area == "edit":
        return title, localize_items([("󰕌", "Annuler", "Ctrl+Z"), ("󰑎", "Rétablir", "Ctrl+Shift+Z"), ("󰅚", "Couper", "Ctrl+X"), ("󰆏", "Copier", "Ctrl+C"), ("󰆒", "Coller", "Ctrl+V"), ("󰒆", "Tout sélectionner", "Ctrl+A"), ("󰍉", "Rechercher", "Ctrl+F")])
    if area == "view":
        return title, localize_items([("󰑓", "Recharger", "Ctrl+R"), ("󰍉", "Zoom avant", "Ctrl++"), ("󰍉", "Zoom arrière", "Ctrl+-"), ("󰾆", "Taille réelle", "Ctrl+0"), ("󰊓", "Plein écran", "F11")])
    if area == "extra":
        mapping = {
            "terminal": [("󰗀", "Profil terminal", ""), ("󰆍", "Palette terminal", ""), ("󰒓", "Terminal doctor", "")],
            "files": [("󰉋", "Seven Files Home", ""), ("󰉋", "Seven Files profil", "")],
            "studio": [("󰈙", "Exports Studio", "")],
            "shield": [("󰒃", "Shield Center", ""), ("󰛵", "Sandbox Shield", "")],
            "atlas": [("󰖳", "Atlas Assistant", ""), ("󰿭", "Atlas Apps", "")],
            "pulse": [("󰓅", "Jeux Pulse", "")],
            "baobab": [("󰔱", "Collections Baobab", "")],
            "forge": [("󰌢", "Projet Forge", ""), ("󰆍", "Palette terminal", "")],
            "media": [("󰐊", "Lecture / pause", "Space"), ("󰝚", "Avancer", ""), ("󰝙", "Reculer", "")],
        }
        return title, localize_items(mapping.get(mode, [("󰍉", "Rechercher", "Ctrl+F"), ("󰊓", "Plein écran", "F11")]))
    if area == "tools":
        mapping = {
            "terminal": [("󰁯", "Restaurer session", ""), ("󰈔", "Nouvelle fenêtre", "Ctrl+Shift+N")],
            "files": [("󰉋", "Seven Files Home", ""), ("󰈙", "Exporter sélection", "")],
            "documents": [("󰈙", "Exporter", ""), ("󰐪", "Imprimer", "Ctrl+P")],
            "media": [("󰕾", "Volume", ""), ("󰝟", "Muet", "")],
            "shield": [("󰒃", "Shield Center", ""), ("󰛵", "Audit rapide", "")],
            "atlas": [("󰿭", "Atlas Apps", ""), ("󰖳", "Assistant", "")],
            "forge": [("󰒓", "Build", ""), ("󰑭", "Logs", "")],
            "pulse": [("󰹑", "Captures", ""), ("󰓅", "Jeux Pulse", "")],
            "baobab": [("󰔱", "Collections", ""), ("󰐅", "Lecture", "")],
        }
        return title, localize_items(mapping.get(mode, [("󰍉", "Rechercher", "Ctrl+F")]))
    if area == "window":
        return title, localize_items([("󰖲", "Contrôles fenêtre", ""), ("󰉌", "Centrer", ""), ("󰹑", "Flottante", ""), ("󰤼", "Split gauche", ""), ("󰤽", "Split droite", ""), ("󰅖", "Fermer", "Ctrl+W")])
    return title, localize_items([("󰋖", "Aide app active", "F1"), ("󰋖", "Aide SevenOS", "")])


def context_for_window(window: dict | None = None, profile_key: str | None = None) -> dict:
    window = window or active_window()
    profile = (profile_key or active_profile_key()).lower()
    app_class = str(window.get("class") or window.get("initialClass") or "").lower()
    title = str(window.get("title") or "").strip()
    key = key_from_class(app_class)
    service = service_from_title(key, title)
    mode = mode_from_class(app_class, profile)
    labels = labels_for(mode, key, service)
    return {
        "window": window,
        "profile": profile,
        "class": app_class,
        "title": title,
        "mode": mode,
        "key": key,
        "service": service,
        "labels": labels,
        "menu": "  ".join(label for label in labels.values() if label),
    }


def contract_matrix() -> dict:
    samples = [
        {"id": "browser.youtube", "class": "firefox", "title": "YouTube - Free Movies", "profile": "equinox", "expect": {"mode": "browser", "key": "firefox", "service": "youtube", "file": "Lecture"}},
        {"id": "browser.gmail", "class": "firefox", "title": "Gmail - Inbox", "profile": "equinox", "expect": {"mode": "browser", "key": "firefox", "service": "gmail", "file": "Message"}},
        {"id": "developer.vscode", "class": "Code", "title": "SevenOS - Visual Studio Code", "profile": "forge", "expect": {"mode": "developer", "key": "vscode", "service": "", "file": "Fichier"}},
        {"id": "terminal.kitty", "class": "kitty", "title": "Forge", "profile": "forge", "expect": {"mode": "terminal", "key": "kitty", "service": "", "file": "Shell"}},
        {"id": "files.native", "class": "SevenFilesNative", "title": "Seven Files", "profile": "equinox", "expect": {"mode": "files", "key": "seven-files", "service": "", "file": "Fichier"}},
        {"id": "media.vlc", "class": "vlc", "title": "Movie", "profile": "studio", "expect": {"mode": "media", "key": "vlc", "service": "", "file": "Média"}},
    ]
    checks = []
    for sample in samples:
        ctx = context_for_window({"class": sample["class"], "title": sample["title"]}, sample["profile"])
        label = str(ctx.get("labels", {}).get("file") or "")
        expected = sample["expect"]
        ok = (
            ctx.get("mode") == expected["mode"]
            and ctx.get("key") == expected["key"]
            and ctx.get("service") == expected["service"]
            and label == ui(expected["file"])
        )
        checks.append({
            "id": sample["id"],
            "state": "OK" if ok else "WARN",
            "mode": ctx.get("mode"),
            "key": ctx.get("key"),
            "service": ctx.get("service"),
            "file_label": label,
        })
    return {
        "schema": "sevenos.waybar.app-menu-contract.v1",
        "state": "OK" if all(item["state"] == "OK" for item in checks) else "WARN",
        "language": LANG_CODE,
        "menu_areas": list(MENU_AREAS),
        "checks": checks,
    }


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] in {"contract", "doctor", "--json"}:
        print(json.dumps(contract_matrix(), ensure_ascii=False))
        return 0
    if len(sys.argv) > 1 and sys.argv[1] == "context":
        print(json.dumps(context_for_window(), ensure_ascii=False))
        return 0
    print("Usage: seven_waybar_app_profiles.py [contract|context]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
