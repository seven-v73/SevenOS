#!/usr/bin/env python3
"""SevenAI local learning layer.

This indexes user-approved local sources and summarizes habits from SevenAI's
own local event memory. It never calls the network and keeps raw content out of
the default metadata index unless the user explicitly asks for snippets.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import time
from pathlib import Path
from typing import Any


CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "sevenos"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "sevenos"
CONFIG_FILE = CONFIG_DIR / "ai-learning.json"
DB_FILE = STATE_DIR / "ai-learning.sqlite3"
AI_MEMORY_DB = STATE_DIR / "ai.sqlite3"
PROFILE_ENV = CONFIG_DIR / "profile.env"

TEXT_EXTENSIONS = {
    ".md",
    ".markdown",
    ".txt",
    ".rst",
    ".org",
    ".csv",
    ".json",
    ".yaml",
    ".yml",
    ".toml",
    ".py",
    ".js",
    ".ts",
    ".html",
    ".css",
    ".sh",
}

DEFAULT_SOURCE_CANDIDATES = [
    Path.home() / "Documents",
    Path.home() / "Desktop",
    Path.home() / "Downloads",
    Path.home() / "Notes",
    Path.home() / "Code",
]

EXCLUDED_NAMES = {
    ".git",
    ".cache",
    ".local",
    ".mozilla",
    ".config",
    "node_modules",
    ".venv",
    "venv",
    "__pycache__",
}


def now() -> int:
    return int(time.time())


def default_config() -> dict[str, Any]:
    sources = [str(path) for path in DEFAULT_SOURCE_CANDIDATES if path.exists()]
    return {
        "schema": "sevenos.ai-learning-config.v1",
        "enabled": False,
        "content_mode": "metadata",
        "max_file_kb": 384,
        "max_files_per_scan": 1500,
        "sources": sources,
        "excluded_names": sorted(EXCLUDED_NAMES),
        "updated_at": now(),
    }


def load_config() -> dict[str, Any]:
    try:
        data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        fallback = default_config()
        fallback.update(data)
        return fallback
    except (OSError, json.JSONDecodeError):
        return default_config()


def save_config(config: dict[str, Any]) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    config["updated_at"] = now()
    CONFIG_FILE.write_text(json.dumps(config, indent=2, ensure_ascii=False), encoding="utf-8")


def db() -> sqlite3.Connection:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    conn.execute(
        "create table if not exists documents ("
        "path text primary key, name text not null, ext text, size integer, mtime integer, "
        "source text, title text, snippet text, indexed_at integer not null)"
    )
    conn.execute(
        "create table if not exists scans ("
        "id integer primary key autoincrement, ts integer not null, files_seen integer, "
        "files_indexed integer, content_mode text, status text)"
    )
    return conn


def clean_text(text: str, limit: int = 700) -> str:
    text = re.sub(r"\s+", " ", text.replace("\x00", " ")).strip()
    return text[:limit]


def read_snippet(path: Path, max_kb: int) -> str:
    if path.suffix.lower() not in TEXT_EXTENSIONS:
        return ""
    try:
        if path.stat().st_size > max_kb * 1024:
            return ""
        return clean_text(path.read_text(encoding="utf-8", errors="ignore"))
    except OSError:
        return ""


def iter_files(source: Path, excluded: set[str], max_files: int):
    count = 0
    for path in source.rglob("*"):
        if count >= max_files:
            break
        if any(part in excluded for part in path.parts):
            continue
        if not path.is_file():
            continue
        count += 1
        yield path


def scan_sources(include_content: bool = False) -> dict[str, Any]:
    config = load_config()
    if not config.get("enabled"):
        return {
            "schema": "sevenos.ai-learning-scan.v1",
            "state": "disabled",
            "indexed": 0,
            "message": "Learning is disabled. Run `seven ai learning enable --json` before scanning personal files.",
            "config": public_config(config),
        }
    sources = [Path(str(path)).expanduser() for path in config.get("sources", [])]
    excluded = set(config.get("excluded_names", [])) | EXCLUDED_NAMES
    max_files = int(config.get("max_files_per_scan", 1500) or 1500)
    max_kb = int(config.get("max_file_kb", 384) or 384)
    content_mode = "snippets" if include_content else str(config.get("content_mode", "metadata"))
    seen = 0
    indexed = 0
    with db() as conn:
        for source in sources:
            if not source.exists() or not source.is_dir():
                continue
            for path in iter_files(source, excluded, max_files - seen):
                seen += 1
                try:
                    stat = path.stat()
                except OSError:
                    continue
                snippet = read_snippet(path, max_kb) if content_mode == "snippets" else ""
                title = path.stem.replace("_", " ").replace("-", " ").strip() or path.name
                conn.execute(
                    "insert or replace into documents "
                    "(path, name, ext, size, mtime, source, title, snippet, indexed_at) "
                    "values (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        str(path),
                        path.name,
                        path.suffix.lower(),
                        int(stat.st_size),
                        int(stat.st_mtime),
                        str(source),
                        title,
                        snippet,
                        now(),
                    ),
                )
                indexed += 1
        conn.execute(
            "insert into scans (ts, files_seen, files_indexed, content_mode, status) values (?, ?, ?, ?, ?)",
            (now(), seen, indexed, content_mode, "ok"),
        )
    return {
        "schema": "sevenos.ai-learning-scan.v1",
        "state": "ready",
        "seen": seen,
        "indexed": indexed,
        "content_mode": content_mode,
        "store": str(DB_FILE),
    }


def public_config(config: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": config.get("schema", "sevenos.ai-learning-config.v1"),
        "enabled": bool(config.get("enabled")),
        "content_mode": config.get("content_mode", "metadata"),
        "max_file_kb": config.get("max_file_kb"),
        "max_files_per_scan": config.get("max_files_per_scan"),
        "sources": config.get("sources", []),
        "updated_at": config.get("updated_at"),
    }


def index_summary(limit: int = 8) -> dict[str, Any]:
    try:
        with db() as conn:
            total = int(conn.execute("select count(*) from documents").fetchone()[0] or 0)
            by_ext = [dict(row) for row in conn.execute("select ext, count(*) as count from documents group by ext order by count desc limit 8")]
            recent = [
                dict(row)
                for row in conn.execute(
                    "select path, name, ext, size, mtime, source, title, snippet from documents order by indexed_at desc limit ?",
                    (limit,),
                ).fetchall()
            ]
            scans = [dict(row) for row in conn.execute("select ts, files_seen, files_indexed, content_mode, status from scans order by id desc limit 5")]
    except sqlite3.Error:
        total, by_ext, recent, scans = 0, [], [], []
    return {
        "documents": total,
        "by_ext": by_ext,
        "recent": recent,
        "scans": scans,
    }


def habits_summary() -> dict[str, Any]:
    if not AI_MEMORY_DB.exists():
        return {"events": 0, "top_intents": [], "top_targets": [], "applied_ratio": 0}
    try:
        with sqlite3.connect(AI_MEMORY_DB) as conn:
            conn.row_factory = sqlite3.Row
            events = int(conn.execute("select count(*) from events").fetchone()[0] or 0)
            top_intents = [dict(row) for row in conn.execute("select intent, count(*) as count from events group by intent order by count desc limit 8")]
            top_targets = [dict(row) for row in conn.execute("select target, count(*) as count from events where target != '' group by target order by count desc limit 8")]
            applied = int(conn.execute("select count(*) from events where applied = 1").fetchone()[0] or 0)
    except sqlite3.Error:
        return {"events": 0, "top_intents": [], "top_targets": [], "applied_ratio": 0}
    return {
        "events": events,
        "top_intents": top_intents,
        "top_targets": top_targets,
        "applied_ratio": round(applied / events, 3) if events else 0,
    }


def active_profile() -> str:
    for key in ("SEVENOS_ACTIVE_PROFILE", "SEVENOS_PROFILE_CONTAINER", "SEVENOS_EXEC_PROFILE"):
        value = os.environ.get(key, "").strip().strip("'\"")
        if value:
            return value
    try:
        for line in PROFILE_ENV.read_text(encoding="utf-8", errors="ignore").splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "SEVENOS_ACTIVE_PROFILE":
                return value.strip().strip("'\"") or "equinox"
    except OSError:
        pass
    return "equinox"


def status_payload() -> dict[str, Any]:
    config = load_config()
    index = index_summary()
    habits = habits_summary()
    enabled = bool(config.get("enabled"))
    return {
        "schema": "sevenos.ai-learning.v1",
        "state": "ready" if enabled else "available",
        "privacy": {
            "local_only": True,
            "network": "none",
            "default_content_mode": "metadata",
            "snippets_require_scan_content": True,
        },
        "config": public_config(config),
        "index": index,
        "habits": habits,
        "recommendations": recommendations(config, index, habits),
    }


def audit_payload() -> dict[str, Any]:
    config = load_config()
    index = index_summary()
    habits = habits_summary()
    sources = [Path(str(path)).expanduser() for path in config.get("sources", [])]
    source_items: list[dict[str, Any]] = []
    missing_sources = 0
    for source in sources:
        exists = source.exists() and source.is_dir()
        if not exists:
            missing_sources += 1
        source_items.append({
            "path": str(source),
            "exists": exists,
            "readable": os.access(source, os.R_OK) if exists else False,
        })

    try:
        with db() as conn:
            snippets = int(conn.execute("select count(*) from documents where snippet != ''").fetchone()[0] or 0)
            indexed_sources = [
                dict(row)
                for row in conn.execute(
                    "select source, count(*) as documents from documents group by source order by documents desc"
                ).fetchall()
            ]
    except sqlite3.Error:
        snippets, indexed_sources = 0, []
    try:
        db_size = DB_FILE.stat().st_size if DB_FILE.exists() else 0
    except OSError:
        db_size = 0

    documents = int(index.get("documents") or 0)
    issues: list[str] = []
    if not config.get("enabled"):
        issues.append("learning-disabled")
    if missing_sources:
        issues.append("missing-sources")
    if documents == 0 and config.get("enabled"):
        issues.append("index-empty")
    if snippets:
        issues.append("content-snippets-present")

    score = 100
    if snippets:
        score -= 15
    if missing_sources:
        score -= min(20, missing_sources * 5)
    if not config.get("enabled"):
        score -= 5

    return {
        "schema": "sevenos.ai-learning-audit.v1",
        "state": "ready" if not issues else "attention",
        "score": max(0, score),
        "privacy": {
            "local_only": True,
            "network": "none",
            "content_mode": "snippets" if snippets else "metadata",
            "snippets": snippets,
            "full_text_export": False,
        },
        "config": public_config(config),
        "index": {
            "documents": documents,
            "snippets": snippets,
            "by_ext": index.get("by_ext", []),
            "recent_scans": index.get("scans", []),
            "indexed_sources": indexed_sources,
            "store": str(DB_FILE),
            "store_bytes": db_size,
        },
        "sources": source_items,
        "habits": habits,
        "issues": issues,
        "actions": [
            {"title": "Show sources", "command": "seven ai \"montre tes sources\""},
            {"title": "Clear snippets", "command": "seven ai \"efface les extraits locaux\" --apply --json"},
            {"title": "Clear index", "command": "seven ai \"efface ton index local\" --apply --json"},
            {"title": "Disable learning", "command": "seven ai \"désactive ton apprentissage\" --apply --json"},
        ],
    }


def history_payload(limit: int = 8) -> dict[str, Any]:
    config = load_config()
    limit = max(1, min(int(limit or 8), 30))
    index = index_summary(limit)
    habits = habits_summary()
    try:
        with db() as conn:
            scans = [
                dict(row)
                for row in conn.execute(
                    "select ts, files_seen, files_indexed, content_mode, status "
                    "from scans order by id desc limit ?",
                    (limit,),
                ).fetchall()
            ]
            snippets = int(conn.execute("select count(*) from documents where snippet != ''").fetchone()[0] or 0)
            sources = [
                dict(row)
                for row in conn.execute(
                    "select source, count(*) as documents, max(indexed_at) as last_indexed "
                    "from documents group by source order by last_indexed desc limit ?",
                    (limit,),
                ).fetchall()
            ]
    except sqlite3.Error:
        scans, snippets, sources = [], 0, []

    recent_documents: list[dict[str, Any]] = []
    for item in index.get("recent", []) if isinstance(index.get("recent"), list) else []:
        path = Path(str(item.get("path") or ""))
        source = Path(str(item.get("source") or ""))
        recent_documents.append({
            "name": item.get("name", path.name),
            "ext": item.get("ext", path.suffix.lower()),
            "source": str(source),
            "source_name": source.name or str(source),
            "mtime": item.get("mtime", 0),
            "size": item.get("size", 0),
            "has_snippet": bool(str(item.get("snippet") or "").strip()),
        })

    return {
        "schema": "sevenos.ai-learning-history.v1",
        "state": "ready",
        "privacy": {
            "local_only": True,
            "network": "none",
            "content": "metadata-only",
            "snippets_counted_only": True,
        },
        "config": public_config(config),
        "summary": {
            "documents": int(index.get("documents") or 0),
            "snippets": snippets,
            "scans": len(scans),
            "sources": len(config.get("sources", []) if isinstance(config.get("sources"), list) else []),
            "habit_events": int(habits.get("events") or 0),
        },
        "timeline": scans,
        "recent_documents": recent_documents,
        "indexed_sources": sources,
        "actions": [
            {"title": "Audit memory", "command": "seven ai \"audit mémoire SevenAI\" --json"},
            {"title": "Show sources", "command": "seven ai \"montre tes sources\" --json"},
            {"title": "Refresh metadata", "command": "seven ai \"scanne mes documents\" --apply --json"},
        ],
    }


def insights_payload(limit: int = 8) -> dict[str, Any]:
    config = load_config()
    audit = audit_payload()
    history = history_payload(limit)
    index = audit.get("index") if isinstance(audit.get("index"), dict) else {}
    privacy = audit.get("privacy") if isinstance(audit.get("privacy"), dict) else {}
    issues = [str(item) for item in audit.get("issues", []) if str(item).strip()] if isinstance(audit.get("issues"), list) else []
    by_ext = index.get("by_ext") if isinstance(index.get("by_ext"), list) else []
    documents = int(index.get("documents") or 0)
    snippets = int(index.get("snippets") or privacy.get("snippets") or 0)
    timeline = history.get("timeline") if isinstance(history.get("timeline"), list) else []

    ext_groups = {
        "documents": {".pdf", ".doc", ".docx", ".odt", ".txt", ".md", ".rst"},
        "code": {".py", ".js", ".ts", ".sh", ".json", ".yaml", ".yml", ".toml", ".html", ".css"},
        "media": {".png", ".jpg", ".jpeg", ".webp", ".mp4", ".mov", ".mp3", ".wav", ".flac"},
        "archives": {".zip", ".7z", ".rar", ".tar", ".gz", ".zst"},
    }
    group_counts = {name: 0 for name in ext_groups}
    top_ext: list[dict[str, Any]] = []
    for item in by_ext:
        ext = str(item.get("ext") or "").lower()
        count = int(item.get("count") or 0)
        if ext:
            top_ext.append({"ext": ext, "count": count})
        for group, members in ext_groups.items():
            if ext in members:
                group_counts[group] += count

    insights: list[dict[str, Any]] = []

    def add(key: str, title: str, detail: str, command: str, *, priority: str = "medium", risk: str = "low") -> None:
        insights.append({
            "key": key,
            "title": title,
            "detail": detail,
            "command": command,
            "priority": priority,
            "risk": risk,
        })

    if not config.get("enabled"):
        add(
            "learning.disabled",
            "Local learning is available but disabled",
            "SevenAI will stay generic until local learning is explicitly enabled.",
            "seven ai \"active ton apprentissage\" --apply --json",
            priority="high",
        )
    elif documents == 0:
        add(
            "index.empty",
            "No indexed local context yet",
            "Run a metadata-only scan to let SevenAI find approved files without reading full content.",
            "seven ai \"scanne mes documents\" --apply --json",
            priority="high",
        )
    else:
        add(
            "index.ready",
            "Local context is searchable",
            f"{documents} approved item(s) are indexed. SevenAI can answer file and source questions locally.",
            "seven ai \"cherche README dans mes fichiers\"",
            priority="high",
        )

    if snippets:
        add(
            "privacy.snippets",
            "Content snippets are present",
            f"{snippets} short snippet(s) improve local answers, but you can clear them while keeping metadata.",
            "seven ai \"efface les extraits locaux\" --apply --json",
            priority="medium",
            risk="medium",
        )
    elif documents:
        add(
            "privacy.metadata",
            "Strict metadata mode is active",
            "SevenAI can search names, titles and file types without reading document bodies.",
            "seven ai \"audit mémoire SevenAI\"",
            priority="medium",
        )

    missing_sources = sum(1 for source in audit.get("sources", []) if isinstance(source, dict) and not source.get("exists"))
    if missing_sources:
        add(
            "sources.missing",
            "Some approved sources are missing",
            f"{missing_sources} configured folder(s) are not reachable and should be reviewed.",
            "seven ai \"montre tes sources\"",
            priority="high",
        )

    if group_counts["documents"]:
        add(
            "atlas.documents",
            "Atlas can use your document context",
            f"{group_counts['documents']} document-oriented item(s) are indexed for reading, notes and research.",
            "seven ai \"cherche pdf dans mes fichiers\"",
            priority="medium",
        )
    if group_counts["code"]:
        add(
            "forge.code",
            "Forge can use your code context",
            f"{group_counts['code']} code/config item(s) are indexed for project recovery and search.",
            "seven ai \"cherche README dans mes fichiers\"",
            priority="medium",
        )
    if group_counts["media"]:
        add(
            "studio.media",
            "Studio can use your media context",
            f"{group_counts['media']} media item(s) are indexed for creative workflows.",
            "seven ai \"cherche image dans mes fichiers\"",
            priority="medium",
        )

    if timeline:
        latest = timeline[0] if isinstance(timeline[0], dict) else {}
        latest_ts = int(latest.get("ts") or 0)
        age_days = int((now() - latest_ts) // 86400) if latest_ts else 9999
        if age_days >= 7 and documents:
            add(
                "scan.stale",
                "Local index may be stale",
                f"The latest recorded scan is about {age_days} day(s) old.",
                "seven ai \"scanne mes documents\" --apply --json",
                priority="medium",
            )

    return {
        "schema": "sevenos.ai-learning-insights.v1",
        "state": "ready",
        "score": int(audit.get("score") or 0),
        "privacy": history.get("privacy", {}),
        "signals": {
            "documents": documents,
            "snippets": snippets,
            "issues": issues,
            "groups": group_counts,
            "top_ext": top_ext[:8],
            "recent_scans": len(timeline),
        },
        "insights": insights[:limit],
        "actions": [
            {"title": "Memory history", "command": "seven ai \"historique mémoire SevenAI\" --json"},
            {"title": "Memory audit", "command": "seven ai \"audit mémoire SevenAI\" --json"},
            {"title": "Memory plan", "command": "seven ai \"plan mémoire SevenAI\" --json"},
        ],
    }


def memory_briefing_payload(limit: int = 6) -> dict[str, Any]:
    profile = active_profile()
    insights = insights_payload(limit)
    history = history_payload(limit)
    proactive = proactive_cards(limit)
    signals = insights.get("signals") if isinstance(insights.get("signals"), dict) else {}
    groups = signals.get("groups") if isinstance(signals.get("groups"), dict) else {}
    recent_documents = history.get("recent_documents") if isinstance(history.get("recent_documents"), list) else []

    profile_focus = {
        "equinox": {
            "title": "Daily system context",
            "query": "notes",
            "detail": "Review recent personal context before changing system settings.",
        },
        "forge": {
            "title": "Forge project context",
            "query": "README",
            "detail": "Look for project notes, code references and configuration files.",
        },
        "studio": {
            "title": "Studio creative context",
            "query": "image",
            "detail": "Use recent media assets and project files for creative work.",
        },
        "shield": {
            "title": "Shield audit context",
            "query": "audit",
            "detail": "Review reports, logs and sensitive notes before security actions.",
        },
        "atlas": {
            "title": "Atlas knowledge context",
            "query": "pdf",
            "detail": "Resume reading, documentation and research from indexed documents.",
        },
        "baobab": {
            "title": "Baobab cultural context",
            "query": "baobab",
            "detail": "Review cultural archives, language notes and local sources.",
        },
        "pulse": {
            "title": "Pulse play context",
            "query": "game",
            "detail": "Find game notes, media and launch context before performance mode.",
        },
    }
    focus = profile_focus.get(profile, profile_focus["equinox"])
    cards = proactive.get("cards") if isinstance(proactive.get("cards"), list) else []
    insight_items = insights.get("insights") if isinstance(insights.get("insights"), list) else []
    recommended: list[dict[str, Any]] = []
    recommended.append({
        "title": focus["title"],
        "detail": focus["detail"],
        "command": f"seven ai learning search {focus['query']} --json",
        "priority": "high",
        "profile": profile,
        "risk": "low",
    })
    for item in insight_items[:3]:
        if isinstance(item, dict):
            recommended.append(item)
    for item in cards[:2]:
        if isinstance(item, dict):
            recommended.append({
                "title": item.get("title", "Next action"),
                "detail": item.get("detail", ""),
                "command": item.get("command", ""),
                "priority": item.get("priority", "medium"),
                "profile": item.get("profile", profile),
                "risk": "low",
            })

    return {
        "schema": "sevenos.ai-memory-briefing.v1",
        "state": "ready",
        "profile": profile,
        "privacy": {
            "local_only": True,
            "network": "none",
            "content": "metadata-first",
        },
        "summary": {
            "documents": int(signals.get("documents") or 0),
            "snippets": int(signals.get("snippets") or 0),
            "documents_group": int(groups.get("documents") or 0),
            "code_group": int(groups.get("code") or 0),
            "media_group": int(groups.get("media") or 0),
            "recent_items": len(recent_documents),
        },
        "focus": focus,
        "recent_documents": recent_documents[:limit],
        "recommended": recommended[:limit],
        "actions": [
            {"title": "Search focus", "command": f"seven ai learning search {focus['query']} --json"},
            {"title": "Memory insights", "command": "seven ai \"analyse ta mémoire\" --json"},
            {"title": "Memory audit", "command": "seven ai \"audit mémoire SevenAI\" --json"},
        ],
    }


def recommendations(config: dict[str, Any], index: dict[str, Any], habits: dict[str, Any]) -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    if not config.get("enabled"):
        items.append({
            "key": "enable",
            "title": "Enable local learning",
            "command": "seven ai learning enable --json",
            "reason": "SevenAI can learn from approved local folders only after explicit activation.",
        })
    if config.get("enabled") and not index.get("documents"):
        items.append({
            "key": "scan",
            "title": "Scan approved sources",
            "command": "seven ai learning scan --json",
            "reason": "No personal document metadata has been indexed yet.",
        })
    if habits.get("events", 0) > 250:
        items.append({
            "key": "habits",
            "title": "Use habits for suggestions",
            "command": "seven ai habits --json",
            "reason": "SevenAI has enough local interaction history to personalize shortcuts and next actions.",
        })
    return items


def extension_count(index: dict[str, Any], *extensions: str) -> int:
    wanted = {ext.lower() for ext in extensions}
    total = 0
    for item in index.get("by_ext", []) if isinstance(index.get("by_ext"), list) else []:
        if str(item.get("ext", "")).lower() in wanted:
            total += int(item.get("count", 0) or 0)
    return total


def proactive_cards(limit: int = 8) -> dict[str, Any]:
    config = load_config()
    index = index_summary()
    habits = habits_summary()
    profile = active_profile()
    enabled = bool(config.get("enabled"))
    documents = int(index.get("documents", 0) or 0)
    habit_events = int(habits.get("events", 0) or 0)
    cards: list[dict[str, Any]] = []

    def add(key: str, title: str, detail: str, command: str, *, priority: str = "medium", profile_hint: str = "") -> None:
        if len(cards) >= limit or any(item["key"] == key for item in cards):
            return
        cards.append({
            "key": key,
            "title": title,
            "detail": detail,
            "command": command,
            "priority": priority,
            "profile": profile_hint or profile,
            "safety": "SAFE",
            "privacy": "local-only",
        })

    if not enabled:
        add(
            "learning.enable",
            "Enable local learning",
            "SevenAI can personalize suggestions from approved folders only after explicit activation.",
            "seven ai learning enable --json",
            priority="high",
            profile_hint="equinox",
        )
    elif not documents:
        add(
            "learning.scan",
            "Scan approved sources",
            "No approved local files are indexed yet. The first scan uses metadata only.",
            "seven ai learning scan --json",
            priority="high",
            profile_hint="equinox",
        )
    else:
        add(
            "learning.search",
            "Search local context",
            f"{documents} approved local item(s) are indexed. Search by name, type or title without cloud.",
            "seven ai learning search README --json",
            priority="high",
            profile_hint=profile,
        )

    if habit_events >= 50:
        top = habits.get("top_intents") if isinstance(habits.get("top_intents"), list) else []
        top_label = ", ".join(str(item.get("intent")) for item in top[:3] if item.get("intent")) or "recent actions"
        add(
            "habits.shortcuts",
            "Use learned habits",
            f"SevenAI sees {habit_events} local interaction(s). Dominant patterns: {top_label}.",
            "seven ai habits --json",
            priority="medium",
            profile_hint="equinox",
        )

    profile_queries = {
        "forge": ("Forge project context", "Find project notes, README files and code references before opening a dev session.", "README"),
        "studio": ("Studio media context", "Find recent creative assets and production notes for the current session.", ".png"),
        "shield": ("Shield audit context", "Find reports, logs and security notes before running a sensitive action.", "audit"),
        "pulse": ("Pulse gaming context", "Find launchers, game notes and compatibility hints before switching to performance mode.", "game"),
        "atlas": ("Atlas knowledge context", "Find PDFs, notes and references for reading or research.", ".pdf"),
        "baobab": ("Baobab memory context", "Find cultural notes, language materials and local archives.", "baobab"),
        "equinox": ("Equinox daily context", "Review recent documents and recurring actions before changing system state.", "notes"),
    }
    title, detail, query = profile_queries.get(profile, profile_queries["equinox"])
    if enabled and documents:
        add(f"profile.{profile}.context", title, detail, f"seven ai learning search {query} --json", priority="medium", profile_hint=profile)

    if extension_count(index, ".pdf") > 0:
        add("documents.pdf", "Continue reading", "PDF documents are present in the approved index. Open Seven Reader or search document titles.", "seven reader", profile_hint="atlas")
    if extension_count(index, ".md", ".txt") > 0:
        add("notes.text", "Review notes", "Text and Markdown files are available for local search.", "seven ai learning search notes --json", profile_hint="equinox")
    if extension_count(index, ".png", ".jpg", ".jpeg", ".webp") > 0:
        add("media.assets", "Browse visual assets", "Images are present in the approved index. Studio can use them for creative workflows.", "seven ai learning search image --json", profile_hint="studio")

    return {
        "schema": "sevenos.ai-proactive.v1",
        "state": "ready" if cards else "empty",
        "profile": profile,
        "privacy": {
            "local_only": True,
            "network": "none",
            "content_mode": str(config.get("content_mode", "metadata")),
        },
        "signals": {
            "learning_enabled": enabled,
            "documents": documents,
            "habit_events": habit_events,
        },
        "cards": cards,
    }


def search_index(query: str, limit: int = 12) -> dict[str, Any]:
    query = query.strip()
    q = f"%{query.lower()}%"
    tokens = [token for token in re.split(r"[^a-zA-Z0-9_À-ÿ.-]+", query.lower()) if len(token) >= 2]

    def score_row(row: dict[str, Any]) -> tuple[int, int]:
        haystacks = {
            "name": str(row.get("name") or "").lower(),
            "title": str(row.get("title") or "").lower(),
            "snippet": str(row.get("snippet") or "").lower(),
            "path": str(row.get("path") or "").lower(),
            "ext": str(row.get("ext") or "").lower(),
        }
        score = 0
        matched: list[str] = []
        for token in tokens:
            if token in haystacks["name"]:
                score += 24
                matched.append("name")
            if token in haystacks["title"]:
                score += 18
                matched.append("title")
            if token in haystacks["snippet"]:
                score += 12
                matched.append("snippet")
            if token in haystacks["path"]:
                score += 4
                matched.append("path")
        ext = haystacks["ext"]
        if ext in {".md", ".txt", ".pdf", ".docx", ".odt"}:
            score += 5
        elif ext in {".py", ".js", ".ts", ".sh", ".json", ".yaml", ".yml"}:
            score += 3
        mtime = int(row.get("mtime") or 0)
        age_days = max(0, (now() - mtime) // 86400) if mtime else 9999
        if age_days <= 7:
            score += 8
        elif age_days <= 30:
            score += 5
        elif age_days <= 180:
            score += 2
        row["score"] = score
        row["matched_fields"] = sorted(set(matched))[:4]
        return (score, mtime)

    try:
        with db() as conn:
            rows = [
                dict(row)
                for row in conn.execute(
                    "select path, name, ext, size, mtime, source, title, snippet from documents "
                    "where lower(name) like ? or lower(title) like ? or lower(snippet) like ? "
                    "or lower(path) like ? order by mtime desc limit ?",
                    (q, q, q, q, max(limit * 4, 24)),
                ).fetchall()
            ]
    except sqlite3.Error:
        rows = []
    rows = sorted(rows, key=score_row, reverse=True)[:limit]
    return {
        "schema": "sevenos.ai-learning-search.v1",
        "query": query,
        "results": rows,
        "count": len(rows),
        "ranking": {
            "strategy": "token-name-title-snippet-recency",
            "metadata_only": all(not str(row.get("snippet") or "").strip() for row in rows),
        },
    }


def set_enabled(enabled: bool) -> dict[str, Any]:
    config = load_config()
    config["enabled"] = enabled
    save_config(config)
    return {"schema": "sevenos.ai-learning-config-change.v1", "enabled": enabled, "config": public_config(config)}


def normalize_source(path: str) -> str:
    raw = path.strip().strip("'\"")
    if not raw:
        raw = str(Path.home() / "Documents")
    aliases = {
        "documents": Path.home() / "Documents",
        "mes documents": Path.home() / "Documents",
        "document": Path.home() / "Documents",
        "downloads": Path.home() / "Downloads",
        "telechargements": Path.home() / "Downloads",
        "téléchargements": Path.home() / "Downloads",
        "bureau": Path.home() / "Desktop",
        "desktop": Path.home() / "Desktop",
        "notes": Path.home() / "Notes",
        "code": Path.home() / "Code",
    }
    candidate = aliases.get(raw.lower(), Path(raw).expanduser())
    try:
        return str(candidate.resolve())
    except OSError:
        return str(candidate)


def add_source(path: str) -> dict[str, Any]:
    config = load_config()
    source = normalize_source(path)
    source_path = Path(source)
    if not source_path.exists() or not source_path.is_dir():
        return {
            "schema": "sevenos.ai-learning-source.v1",
            "state": "invalid-source",
            "added": False,
            "source": source,
            "message": "Source must be an existing directory.",
            "config": public_config(config),
        }
    sources = list(config.get("sources", []))
    already_present = source in sources
    if not already_present:
        sources.append(source)
    config["sources"] = sources
    save_config(config)
    return {
        "schema": "sevenos.ai-learning-source.v1",
        "state": "ready",
        "added": source,
        "already_present": already_present,
        "config": public_config(config),
    }


def remove_source(path: str) -> dict[str, Any]:
    config = load_config()
    wanted = normalize_source(path)
    wanted_name = Path(wanted).name.lower()
    sources = [str(item) for item in config.get("sources", [])]
    kept: list[str] = []
    removed: list[str] = []
    for source in sources:
        source_path = Path(source)
        if source == wanted or str(source_path.expanduser()) == wanted or source_path.name.lower() == wanted_name:
            removed.append(source)
        else:
            kept.append(source)
    config["sources"] = kept
    save_config(config)
    return {
        "schema": "sevenos.ai-learning-source-remove.v1",
        "state": "ready" if removed else "not-found",
        "removed": removed,
        "target": wanted,
        "config": public_config(config),
    }


def clear_index() -> dict[str, Any]:
    before = index_summary()
    before_documents = int(before.get("documents") or 0)
    with db() as conn:
        conn.execute("delete from documents")
        conn.execute(
            "insert into scans (ts, files_seen, files_indexed, content_mode, status) values (?, ?, ?, ?, ?)",
            (now(), before_documents, 0, "metadata", "cleared"),
        )
    return {
        "schema": "sevenos.ai-learning-clear.v1",
        "state": "ready",
        "cleared": before_documents,
        "store": str(DB_FILE),
        "index": index_summary(),
    }


def clear_snippets() -> dict[str, Any]:
    with db() as conn:
        before = int(conn.execute("select count(*) from documents where snippet != ''").fetchone()[0] or 0)
        conn.execute("update documents set snippet = '' where snippet != ''")
        conn.execute(
            "insert into scans (ts, files_seen, files_indexed, content_mode, status) values (?, ?, ?, ?, ?)",
            (now(), before, 0, "snippets", "snippets-cleared"),
        )
    return {
        "schema": "sevenos.ai-learning-clear-snippets.v1",
        "state": "ready",
        "cleared": before,
        "store": str(DB_FILE),
        "index": index_summary(),
    }


def print_payload(payload: dict[str, Any], json_flag: bool) -> None:
    if json_flag:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return
    print(f"{payload.get('schema', 'sevenos.ai-learning')} · {payload.get('state', payload.get('enabled', 'ok'))}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="seven-ai-learning")
    parser.add_argument("command", nargs="?", default="status", choices=("status", "enable", "disable", "scan", "sources", "add-source", "remove-source", "clear-index", "clear-snippets", "audit", "history", "insights", "briefing", "habits", "search", "proactive"))
    parser.add_argument("extra", nargs="*")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--content", action="store_true", help="include short snippets from text files during this scan")
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args(argv)

    if args.command == "status":
        payload = status_payload()
    elif args.command == "enable":
        payload = set_enabled(True)
    elif args.command == "disable":
        payload = set_enabled(False)
    elif args.command == "scan":
        payload = scan_sources(include_content=args.content)
    elif args.command == "sources":
        payload = {"schema": "sevenos.ai-learning-sources.v1", "config": public_config(load_config())}
    elif args.command == "add-source":
        payload = add_source(" ".join(args.extra).strip() or str(Path.home() / "Documents"))
    elif args.command == "remove-source":
        payload = remove_source(" ".join(args.extra).strip() or str(Path.home() / "Documents"))
    elif args.command == "clear-index":
        payload = clear_index()
    elif args.command == "clear-snippets":
        payload = clear_snippets()
    elif args.command == "audit":
        payload = audit_payload()
    elif args.command == "history":
        payload = history_payload(args.limit)
    elif args.command == "insights":
        payload = insights_payload(args.limit)
    elif args.command == "briefing":
        payload = memory_briefing_payload(args.limit)
    elif args.command == "habits":
        payload = {"schema": "sevenos.ai-habits.v1", **habits_summary()}
    elif args.command == "proactive":
        payload = proactive_cards(args.limit)
    else:
        payload = search_index(" ".join(args.extra).strip(), args.limit)
    print_payload(payload, args.json)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
