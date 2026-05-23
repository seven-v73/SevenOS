#!/usr/bin/env python3
"""Shared SevenOS Design Engine helpers for native GTK surfaces.

The native apps still keep component-specific CSS locally, but this module
injects the same mode/profile/runtime tokens everywhere. That lets Settings,
Files, Store, Reader and Control Center move toward one design engine without
forcing a risky all-at-once UI rewrite.
"""

from __future__ import annotations

import json
import os
from pathlib import Path


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))


def seven_config_dir() -> Path:
    return config_home() / "sevenos"


def active_profile_key(default: str = "equinox") -> str:
    env = os.environ.get("SEVENOS_PROFILE_CONTAINER")
    if env:
        return env.strip().strip("'\"") or default
    env_path = seven_config_dir() / "profile.env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "SEVENOS_ACTIVE_PROFILE":
                return value.strip().strip("'\"") or default
    env = os.environ.get("SEVENOS_EXEC_PROFILE") or os.environ.get("SEVENOS_ACTIVE_PROFILE")
    if env:
        return env.strip().strip("'\"") or default
    return default


def profile_config_dir(profile: str | None = None) -> Path:
    return seven_config_dir() / "profiles" / (profile or active_profile_key())


def repo_root() -> Path:
    env_root = os.environ.get("SEVENOS_ROOT")
    if env_root and (Path(env_root) / "identity").is_dir():
        return Path(env_root)
    return Path(__file__).resolve().parent.parent


def current_theme_mode(default: str = "dark") -> str:
    env = os.environ.get("SEVENOS_THEME_MODE")
    if env in {"dark", "light"}:
        return env
    for theme_file in (profile_config_dir() / "theme.conf", seven_config_dir() / "theme.conf"):
        if theme_file.exists():
            for line in theme_file.read_text(encoding="utf-8", errors="ignore").splitlines():
                key, _, value = line.partition("=")
                if key.strip().lower() in {"sevenos_theme_mode", "theme_mode", "mode"}:
                    value = value.strip().strip("'\"").lower()
                    if value in {"dark", "light"}:
                        return value
    return default


def read_json(path: Path, fallback):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, type(fallback)) else fallback
    except Exception:
        return fallback


def runtime_state() -> dict:
    return read_json(
        seven_config_dir() / "theme-runtime.json",
        {"schema": "sevenos.theme-runtime.v1", "mode": current_theme_mode(), "toolkits": {}},
    )


def profile_state() -> dict:
    return read_json(seven_config_dir() / "profile-ui.json", {})


def wallpaper_state() -> dict:
    return read_json(
        seven_config_dir() / "wallpaper-theme.json",
        {
            "schema": "sevenos.wallpaper-theme.v1",
            "source": "fallback",
            "image": "",
            "colors": {},
        },
    )


def mode_palette(mode: str | None = None) -> dict[str, str]:
    mode = mode or current_theme_mode()
    if mode == "light":
        return {
            "bg": "#FFFFFF",
            "panel": "rgba(255, 255, 255, 0.82)",
            "panel_2": "rgba(245, 247, 250, 0.86)",
            "sidebar": "rgba(244, 247, 251, 0.86)",
            "text": "#1C1F26",
            "muted": "#6B7280",
            "border": "rgba(28, 31, 38, 0.08)",
            "hover": "rgba(47, 123, 255, 0.10)",
            "selected": "rgba(47, 123, 255, 0.18)",
            "accent": "#2F7BFF",
            "secondary": "#6A5CFF",
            "success": "#00A77A",
            "danger": "#D20F39",
            "warning": "#FE640B",
            "paper": "#F4E8D1",
            "paper_text": "#1C1F26",
            "paper_shadow": "rgba(0, 0, 0, 0.32)",
            "paper_edge": "rgba(90, 70, 42, 0.18)",
            "traffic_close": "#FF5F57",
            "traffic_minimize": "#FEBC2E",
            "traffic_maximize": "#28C840",
        }
    return {
        "bg": "#09090B",
        "panel": "rgba(18, 19, 26, 0.78)",
        "panel_2": "rgba(28, 31, 44, 0.72)",
        "sidebar": "rgba(17, 17, 27, 0.84)",
        "text": "#EDEDED",
        "muted": "#8A8F98",
        "border": "rgba(255, 255, 255, 0.08)",
        "hover": "rgba(77, 163, 255, 0.13)",
        "selected": "rgba(77, 163, 255, 0.20)",
        "accent": "#4DA3FF",
        "secondary": "#7A5CFF",
        "success": "#00FFB3",
        "danger": "#FF5976",
        "warning": "#FAB387",
        "paper": "#F4E8D1",
        "paper_text": "#1C1F26",
        "paper_shadow": "rgba(0, 0, 0, 0.42)",
        "paper_edge": "rgba(90, 70, 42, 0.18)",
        "traffic_close": "#FF5F57",
        "traffic_minimize": "#FEBC2E",
        "traffic_maximize": "#28C840",
    }


def gtk_app_css(
    surface: str = "app",
    mode: str | None = None,
    profile_override: dict | None = None,
    wallpaper_override: dict | None = None,
) -> str:
    mode = mode or current_theme_mode()
    palette = mode_palette(mode)
    profile = profile_override or profile_state()
    wallpaper = wallpaper_override or wallpaper_state()
    wallpaper_colors = wallpaper.get("colors", {}) if isinstance(wallpaper.get("colors"), dict) else {}
    accent = str(profile.get("accent") or palette["accent"])
    secondary = str(profile.get("secondary") or palette["secondary"])
    wallpaper_accent = str(wallpaper_colors.get("accent") or accent)
    wallpaper_secondary = str(wallpaper_colors.get("secondary") or secondary)
    wallpaper_cyan = str(wallpaper_colors.get("cyan") or wallpaper_accent)
    wallpaper_surface = str(wallpaper_colors.get("surface") or palette["panel_2"])
    profile_key = str(profile.get("profile") or "equinox")
    profile_title = str(profile.get("title") or "Equinox")
    runtime = runtime_state()
    toolkits = runtime.get("toolkits", {}) if isinstance(runtime.get("toolkits"), dict) else {}
    icon_theme = str(toolkits.get("icon_theme") or "")

    return f"""
    /* Seven Design Engine · shared native GTK tokens
       mode={mode} surface={surface} profile={profile_key} icon_theme={icon_theme} */
    @define-color seven_bg {palette["bg"]};
    @define-color seven_panel {palette["panel"]};
    @define-color seven_panel_2 {palette["panel_2"]};
    @define-color seven_sidebar {palette["sidebar"]};
    @define-color seven_text {palette["text"]};
    @define-color seven_muted {palette["muted"]};
    @define-color seven_border {palette["border"]};
    @define-color seven_hover {palette["hover"]};
    @define-color seven_selected {palette["selected"]};
    @define-color seven_accent {accent};
    @define-color seven_secondary {secondary};
    @define-color seven_profile_accent {accent};
    @define-color seven_profile_secondary {secondary};
    @define-color seven_wallpaper_accent {wallpaper_accent};
    @define-color seven_wallpaper_secondary {wallpaper_secondary};
    @define-color seven_wallpaper_cyan {wallpaper_cyan};
    @define-color seven_wallpaper_surface {wallpaper_surface};
    @define-color seven_success {palette["success"]};
    @define-color seven_danger {palette["danger"]};
    @define-color seven_warning {palette["warning"]};
    @define-color seven_paper {palette["paper"]};
    @define-color seven_paper_text {palette["paper_text"]};
    @define-color seven_paper_shadow {palette["paper_shadow"]};
    @define-color seven_paper_edge {palette["paper_edge"]};
    @define-color seven_traffic_close {palette["traffic_close"]};
    @define-color seven_traffic_minimize {palette["traffic_minimize"]};
    @define-color seven_traffic_maximize {palette["traffic_maximize"]};

    .seven-design-surface {{
      color: @seven_text;
      background: @seven_panel;
      border-color: @seven_border;
    }}

    .seven-design-muted {{ color: @seven_muted; }}
    .seven-design-accent {{ color: @seven_accent; }}
    .seven-design-card {{
      color: @seven_text;
      background: @seven_panel_2;
      border: 1px solid @seven_border;
      border-radius: 18px;
    }}
    """


def resolved_theme(
    surface: str = "app",
    mode: str | None = None,
    profile_override: dict | None = None,
    wallpaper_override: dict | None = None,
) -> dict:
    """Return the exact native theme contract used by SevenOS apps."""
    mode = mode or current_theme_mode()
    palette = mode_palette(mode)
    profile = profile_override or profile_state()
    wallpaper = wallpaper_override or wallpaper_state()
    runtime = runtime_state()
    toolkits = runtime.get("toolkits", {}) if isinstance(runtime.get("toolkits"), dict) else {}
    wallpaper_colors = wallpaper.get("colors", {}) if isinstance(wallpaper.get("colors"), dict) else {}
    accent = str(profile.get("accent") or palette["accent"])
    secondary = str(profile.get("secondary") or palette["secondary"])
    return {
        "schema": "sevenos.resolved-theme.v1",
        "surface": surface,
        "mode": mode,
        "mode_label": "Seven Latte" if mode == "light" else "Seven Mocha",
        "profile": str(profile.get("profile") or "equinox"),
        "profile_title": str(profile.get("title") or "Equinox Balance"),
        "profile_mood": str(profile.get("mood") or ""),
        "palette": {
            "background": palette["bg"],
            "panel": palette["panel"],
            "text": palette["text"],
            "muted": palette["muted"],
            "accent": accent,
            "secondary": secondary,
            "wallpaper_accent": str(wallpaper_colors.get("accent") or accent),
            "wallpaper_secondary": str(wallpaper_colors.get("secondary") or secondary),
            "wallpaper_cyan": str(wallpaper_colors.get("cyan") or wallpaper_colors.get("accent") or accent),
            "wallpaper_surface": str(wallpaper_colors.get("surface") or palette["panel_2"]),
        },
        "wallpaper": {
            "source": str(wallpaper.get("source") or "fallback"),
            "image": str(wallpaper.get("image") or ""),
        },
        "toolkits": toolkits,
    }


def runtime_css_path() -> Path:
    return data_home() / "sevenos" / "identity" / "runtime-theme.css"


def surface_css(surface: str, fallback: str = "", mode: str | None = None) -> str:
    """Load externalized CSS for a native app surface.

    Resolution order:
    1. identity/native/<surface>.css
    2. identity/native/<surface>-<mode>.css

    The mode-specific file is appended so it can override common surface rules.
    """
    mode = mode or current_theme_mode()
    native_dir = repo_root() / "identity" / "native"
    css_parts: list[str] = []
    for path in (native_dir / f"{surface}.css", native_dir / f"{surface}-{mode}.css"):
        try:
            if path.exists():
                css_parts.append(path.read_text(encoding="utf-8"))
        except OSError:
            continue
    if css_parts:
        return "\n\n".join(css_parts)
    return fallback
