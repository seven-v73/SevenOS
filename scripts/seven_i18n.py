"""Small SevenOS translation layer for native system surfaces."""

from __future__ import annotations

import os
from pathlib import Path


CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "sevenos"
LANGUAGE_CONF = CONFIG_DIR / "language.conf"


TRANSLATIONS = {
    "fr": {
        "settings.title": "Réglages SevenOS",
        "settings.subtitle": "Surface de contrôle complète pour le bureau, la sécurité, les profils, les appareils et l’exécution système.",
        "settings.overview": "Vue d’ensemble",
        "settings.general": "Général",
        "settings.general.subtitle": "Langue, région, thèmes et comportement quotidien de SevenOS.",
        "settings.appearance": "Apparence",
        "settings.wallpaper": "Fond d’écran",
        "settings.displays": "Écrans",
        "settings.wifi": "Wi-Fi",
        "settings.sound": "Son",
        "settings.keyboard": "Clavier",
        "settings.fonts": "Polices",
        "settings.security": "Sécurité",
        "settings.profiles": "Profils",
        "settings.power": "Énergie",
        "settings.apps": "Apps",
        "settings.system": "Système",
        "settings.language_region": "Langue et région",
        "settings.language": "Langue",
        "settings.language.note": "{label} · appliqué aux nouvelles apps et aux nouveaux terminaux",
        "settings.available_languages": "Langues disponibles",
        "settings.available_languages.note": "{count} langue(s) détectée(s) ou installable(s) sur cette machine.",
        "settings.list": "Liste",
        "settings.status": "État",
        "settings.keyboard_layouts": "Dispositions clavier",
        "settings.keyboard_layouts.note": "Garde les dispositions US/FR et le raccourci Alt+Maj indépendants de la langue d’affichage.",
        "settings.dark_or_light": "Sombre ou clair",
        "settings.dark_or_light.note": "Basculer entre SevenOS sombre immersif et SevenOS clair orienté lisibilité.",
        "settings.appearance.button": "Apparence",
        "settings.session_refresh": "Rafraîchir la session",
        "settings.session_refresh.note": "Recharge Hyprland après un changement de préférence globale.",
        "settings.reload": "Recharger",
        "settings.general_card": "Réglages généraux",
        "settings.general_card.note": "Langue, thèmes et comportement quotidien de SevenOS.",
        "settings.open": "Ouvrir",
        "hub.dashboard": "Tableau de bord",
        "hub.profiles": "Profils",
        "hub.actions": "Actions",
        "hub.ecosystem": "Écosystème",
        "hub.system_status": "ÉTAT DU SYSTÈME",
        "hub.native_online": "Hub natif en ligne",
        "hub.control_center": "Centre de contrôle SevenOS",
        "hub.heading": "Seven Hub",
        "hub.heading.subtitle": "Centre de contrôle de la session SevenOS active.",
        "hub.readiness": "Préparation",
        "hub.shield": "Bouclier",
        "hub.daily": "Quotidien",
        "hub.settings": "Réglages",
        "hub.security": "Sécurité",
        "hub.windows": "Windows",
        "hub.server": "Serveur",
        "hub.apps": "Apps",
        "hub.doctor": "Diagnostic",
        "hub.identity": "Identité",
        "language.system_default": "Défaut système",
        "language.english_us": "Anglais (États-Unis)",
        "language.french_fr": "Français (France)",
        "language.french_ca": "Français (Canada)",
        "language.spanish_es": "Espagnol (Espagne)",
        "language.german": "Allemand",
        "language.italian": "Italien",
        "language.portuguese_br": "Portugais (Brésil)",
        "language.arabic": "Arabe",
        "language.chinese_simplified": "Chinois simplifié",
        "language.japanese": "Japonais",
        "language.title": "Langue SevenOS",
        "language.current": "Actuelle",
        "language.locale": "Locale",
        "language.available": "Disponibles",
        "language.languages": "Langues",
    }
}


def configured_locale() -> str:
    if LANGUAGE_CONF.exists():
        for line in LANGUAGE_CONF.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("SEVENOS_LANGUAGE=") or line.startswith("LANG="):
                return line.split("=", 1)[1].strip().strip("'\"")
    return os.environ.get("SEVENOS_LANGUAGE") or os.environ.get("LANG", "en_US.UTF-8")


def language_code(locale_name: str | None = None) -> str:
    locale_name = locale_name or configured_locale()
    if locale_name.startswith("fr"):
        return "fr"
    return "en"


def tr(key: str, fallback: str | None = None, **values: object) -> str:
    text = TRANSLATIONS.get(language_code(), {}).get(key, fallback or key)
    return text.format(**values) if values else text
