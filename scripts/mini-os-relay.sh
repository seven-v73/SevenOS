#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
export SEVENOS_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export SEVENOS_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

python - "$@" <<'PY'
import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(os.environ["SEVENOS_ROOT"])
CONFIG_HOME = Path(os.environ["SEVENOS_CONFIG_HOME"])
DATA_HOME = Path(os.environ["SEVENOS_DATA_HOME"])
STATE_DIR = CONFIG_HOME / "sevenos"
PROFILE_DIR = STATE_DIR / "profiles"
RELAY_DIR = DATA_HOME / "sevenos" / "bridge"
OBJECTS_DIR = DATA_HOME / "sevenos" / "objects"
RELATIONS_PATH = RELAY_DIR / "relations.json"
SWITCHER_PATH = RELAY_DIR / "switcher.json"
GRAPH_PATH = RELAY_DIR / "graph.json"
PROFILES = ["equinox", "baobab", "forge", "shield", "studio", "windows", "pulse"]
ALIASES = {"horizon": "forge"}

RELATIONS = [
    {
        "from": "baobab",
        "to": "studio",
        "channel": "heritage-to-creation",
        "objects": ["textile", "image", "story", "recipe", "sound-reference"],
        "phrase": "Baobab transmet une reference culturelle vers Studio pour creation.",
        "protected_boundary": "Studio recoit une copie declaree; Baobab garde la source patrimoniale.",
    },
    {
        "from": "studio",
        "to": "baobab",
        "channel": "creation-to-memory",
        "objects": ["illustration", "audio", "poster", "video", "visual-study"],
        "phrase": "Studio remet une creation a Baobab comme archive ou support pedagogique.",
        "protected_boundary": "Baobab marque la creation comme interpretation, pas comme source primaire.",
    },
    {
        "from": "forge",
        "to": "shield",
        "channel": "build-to-audit",
        "objects": ["project", "service", "dependency-list", "container"],
        "phrase": "Forge demande a Shield d'auditer un projet ou un service.",
        "protected_boundary": "Shield travaille sur un perimetre autorise et garde les preuves dans son espace.",
    },
    {
        "from": "shield",
        "to": "forge",
        "channel": "audit-to-fix",
        "objects": ["report", "finding", "remediation-plan", "evidence-summary"],
        "phrase": "Shield renvoie un rapport exploitable par Forge.",
        "protected_boundary": "Forge recoit le plan de correction, pas les donnees sensibles brutes.",
    },
    {
        "from": "studio",
        "to": "forge",
        "channel": "asset-to-product",
        "objects": ["web-export", "design-system", "asset-pack", "prototype"],
        "phrase": "Studio envoie des assets pour integration technique dans Forge.",
        "protected_boundary": "Forge integre les exports sans prendre possession du workspace creatif.",
    },
    {
        "from": "forge",
        "to": "windows",
        "channel": "product-to-compatibility",
        "objects": ["installer", "binary", "test-plan", "compatibility-request"],
        "phrase": "Forge utilise Windows Bridge pour verifier une compatibilite.",
        "protected_boundary": "Windows isole la VM et les dossiers partages.",
    },
    {
        "from": "windows",
        "to": "studio",
        "channel": "compatibility-to-creation",
        "objects": ["capture", "export", "windows-only-output"],
        "phrase": "Windows Bridge remet un asset cree ou ouvert avec une application Windows.",
        "protected_boundary": "Studio recoit l'asset, pas l'etat interne de la VM.",
    },
    {
        "from": "pulse",
        "to": "studio",
        "channel": "performance-to-media",
        "objects": ["clip", "screenshot", "benchmark-visual", "stream-asset"],
        "phrase": "Pulse envoie captures et clips vers Studio pour montage.",
        "protected_boundary": "Pulse garde les profils performance et Studio traite seulement les medias.",
    },
    {
        "from": "equinox",
        "to": "baobab",
        "channel": "daily-to-memory",
        "objects": ["note", "document", "reading-list"],
        "phrase": "Equinox confie une note ou lecture a Baobab pour classement culturel.",
        "protected_boundary": "Baobab conserve le contexte culturel sans absorber tout l'espace quotidien.",
    },
]


def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def normalize_profile(value):
    value = ALIASES.get((value or "").strip(), (value or "").strip())
    if value not in PROFILES:
        raise SystemExit(f"seven bridge: profil inconnu: {value}")
    return value


def active_profile():
    env_file = STATE_DIR / "profile.env"
    if env_file.is_file():
        for line in env_file.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("SEVENOS_ACTIVE_PROFILE="):
                return ALIASES.get(line.split("=", 1)[1].strip().strip('"'), line.split("=", 1)[1].strip().strip('"'))
    return os.environ.get("SEVENOS_ACTIVE_PROFILE") or "equinox"


def profile_paths(profile):
    return {
        "config": PROFILE_DIR / profile,
        "bridge": RELAY_DIR / profile,
        "inbox": RELAY_DIR / profile / "bridge-inbox.jsonl",
        "outbox": RELAY_DIR / profile / "bridge-outbox.jsonl",
        "session": PROFILE_DIR / profile / "session.json",
        "experience": PROFILE_DIR / profile / "experience.json",
        "ui": PROFILE_DIR / profile / "profile-ui.json",
        "theme": PROFILE_DIR / profile / "theme.conf",
        "wallpaper": PROFILE_DIR / profile / "wallpaper-state",
        "passage": PROFILE_DIR / profile / "passage.json",
    }


def read_json(path, fallback):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return fallback


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def update_json(path, mutator, fallback):
    data = read_json(path, fallback)
    data = mutator(data)
    write_json(path, data)
    return data


def append_jsonl(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(data, ensure_ascii=False) + "\n")


def read_jsonl(path, limit=20):
    path = Path(path)
    if not path.exists():
        return []
    items = []
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip():
            continue
        try:
            items.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return items[-limit:]


def slugify(value):
    value = re.sub(r"[^a-zA-Z0-9._-]+", "-", value.strip()).strip("-").lower()
    return value[:48] or "object"


def relation_between(source, target):
    for item in RELATIONS:
        if item["from"] == source and item["to"] == target:
            return item
    return {
        "from": source,
        "to": target,
        "channel": "explicit-transfer",
        "objects": ["object"],
        "phrase": "SevenOS transfere un objet declare entre deux mini OS.",
        "protected_boundary": "Les configs restent separees; seul l'objet reference traverse le pont.",
    }


def suggested_actions(source, target, kind):
    relation = relation_between(source, target)
    actions = [
        {"label": f"Ouvrir {target}", "command": f"seven profile activate {target}"},
        {"label": "Voir les relations", "command": "seven bridge relations"},
    ]
    if target == "studio":
        actions.insert(0, {"label": "Ouvrir Studio", "command": "seven profile activate studio && seven profile open studio"})
    elif target == "shield":
        actions.insert(0, {"label": "Preparer audit Shield", "command": "seven shield scope"})
    elif target == "baobab":
        actions.insert(0, {"label": "Ouvrir Baobab", "command": "seven baobab open"})
    elif target == "forge":
        actions.insert(0, {"label": "Ouvrir Forge", "command": "seven profile activate forge && seven profile open forge"})
    actions.append({"label": "Canal", "command": relation["channel"]})
    if kind:
        actions.append({"label": "Type d'objet", "command": kind})
    return actions


def init_state():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    RELAY_DIR.mkdir(parents=True, exist_ok=True)
    OBJECTS_DIR.mkdir(parents=True, exist_ok=True)
    for profile in PROFILES:
        paths = profile_paths(profile)
        paths["config"].mkdir(parents=True, exist_ok=True)
        paths["bridge"].mkdir(parents=True, exist_ok=True)
        paths["inbox"].touch(exist_ok=True)
        paths["outbox"].touch(exist_ok=True)
        if not paths["session"].exists():
            write_json(paths["session"], {
                "schema": "sevenos.profile-session.v1",
                "profile": profile,
                "recent_apps": [],
                "recent_paths": [],
                "recent_objects": [],
                "pinned_objects": [],
                "tasks": [],
                "mood": "ready",
                "updated_at": None,
            })
        for name, default in (
            ("theme", "mode=dark\nprofile=%s\n" % profile),
            ("wallpaper", "profile\t%s\nmode\tprofile-default\nvalue\t%s\n" % (profile, profile)),
        ):
            path = paths[name]
            if not path.exists():
                path.write_text(default, encoding="utf-8")
    write_json(RELATIONS_PATH, {
        "schema": "sevenos.bridge-relations.v1",
        "generated_at": now_iso(),
        "rule": "Chaque mini OS garde sa configuration; seuls les objets SevenOS declares traversent le pont.",
        "profiles": PROFILES,
        "relations": RELATIONS,
    })
    write_json(GRAPH_PATH, graph_payload(write=False))


def status_payload():
    init_state()
    profiles = []
    for profile in PROFILES:
        paths = profile_paths(profile)
        required = ["theme", "wallpaper", "ui", "experience", "session", "passage", "inbox", "outbox"]
        missing = [name for name in required if not paths[name].exists()]
        profiles.append({
            "profile": profile,
            "config": str(paths["config"]),
            "inbox": str(paths["inbox"]),
            "outbox": str(paths["outbox"]),
            "inbox_count": len(read_jsonl(paths["inbox"], 100000)),
            "outbox_count": len(read_jsonl(paths["outbox"], 100000)),
            "session": paths["session"].exists(),
            "ready": not missing,
            "missing": missing,
        })
    return {
        "schema": "sevenos.bridge-status.v1",
        "active_profile": active_profile(),
        "objects_dir": str(OBJECTS_DIR),
        "object_count": len(list(OBJECTS_DIR.glob("*.json"))) if OBJECTS_DIR.exists() else 0,
        "relations": str(RELATIONS_PATH),
        "profiles": profiles,
    }


def doctor_payload():
    status = status_payload()
    profile_issues = []
    for item in status["profiles"]:
        if not item["ready"]:
            profile_issues.append({
                "profile": item["profile"],
                "severity": "high",
                "missing": item["missing"],
                "command": f"seven profile experience {item['profile']} --json && seven bridge init",
            })
    relation_pairs = {(item["from"], item["to"]) for item in RELATIONS}
    important_pairs = {
        ("baobab", "studio"),
        ("studio", "baobab"),
        ("forge", "shield"),
        ("shield", "forge"),
        ("studio", "forge"),
        ("pulse", "studio"),
    }
    missing_relations = sorted(["%s->%s" % pair for pair in important_pairs - relation_pairs])
    score = 100
    score -= len(profile_issues) * 8
    score -= len(missing_relations) * 5
    score = max(0, min(100, score))
    return {
        "schema": "sevenos.bridge-doctor.v1",
        "score": score,
        "state": "ready" if score >= 95 and not profile_issues else "needs-work",
        "profile_issues": profile_issues,
        "missing_relations": missing_relations,
        "checks": {
            "profiles": len(status["profiles"]),
            "ready_profiles": sum(1 for item in status["profiles"] if item["ready"]),
            "relations": len(RELATIONS),
            "objects": status["object_count"],
            "switcher": SWITCHER_PATH.exists(),
            "graph": GRAPH_PATH.exists(),
        },
        "next_actions": [
            {"label": "Initialize bridge", "command": "seven bridge init"},
            {"label": "Show relation graph", "command": "seven bridge graph"},
            {"label": "Preview a passage", "command": "seven bridge switch --to baobab"},
        ][: 0 if score >= 95 and not profile_issues else 3],
    }


def send_object(args):
    init_state()
    source = normalize_profile(args.source or active_profile())
    target = normalize_profile(args.target)
    if source == target:
        raise SystemExit("seven bridge: source et destination doivent etre differentes")
    asset = args.asset or ""
    kind = args.kind or "object"
    title = args.title or (Path(asset).name if asset else f"{kind} from {source}")
    object_id = f"{time.strftime('%Y%m%d%H%M%S')}-{source}-{target}-{slugify(title)}"
    relation = relation_between(source, target)
    object_path = OBJECTS_DIR / f"{object_id}.json"
    source_path = Path(asset).expanduser() if asset else None
    obj = {
        "schema": "sevenos.object.v1",
        "id": object_id,
        "created_at": now_iso(),
        "owner": source,
        "from": source,
        "to": target,
        "kind": kind,
        "title": title,
        "source": str(source_path) if source_path else "",
        "source_exists": bool(source_path and source_path.exists()),
        "rights": args.rights or "local-user-owned",
        "status": "sent",
        "channel": relation["channel"],
        "context": {
            "phrase": relation["phrase"],
            "protected_boundary": relation["protected_boundary"],
        },
        "suggested_actions": suggested_actions(source, target, kind),
    }
    write_json(object_path, obj)
    message = {
        "schema": "sevenos.bridge-message.v1",
        "id": object_id,
        "created_at": obj["created_at"],
        "from": source,
        "to": target,
        "kind": kind,
        "title": title,
        "object": str(object_path),
        "source": obj["source"],
        "status": "sent",
        "channel": relation["channel"],
    }
    append_jsonl(profile_paths(source)["outbox"], message)
    append_jsonl(profile_paths(target)["inbox"], message)
    session = read_json(profile_paths(source)["session"], {})
    recent = session.get("recent_objects") if isinstance(session.get("recent_objects"), list) else []
    session["recent_objects"] = [object_id, *[item for item in recent if item != object_id]][:20]
    session["updated_at"] = obj["created_at"]
    write_json(profile_paths(source)["session"], session)
    return {
        "schema": "sevenos.bridge-send.v1",
        "message": message,
        "object": obj,
    }


def session_payload(profile):
    init_state()
    profile = normalize_profile(profile or active_profile())
    path = profile_paths(profile)["session"]
    session = read_json(path, {})
    session.setdefault("schema", "sevenos.profile-session.v1")
    session.setdefault("profile", profile)
    session["path"] = str(path)
    return session


def remember_payload(args):
    init_state()
    profile = normalize_profile(args.profile or active_profile())
    path = profile_paths(profile)["session"]

    def mutate(session):
        session.setdefault("schema", "sevenos.profile-session.v1")
        session.setdefault("profile", profile)
        session.setdefault("recent_apps", [])
        session.setdefault("recent_paths", [])
        session.setdefault("recent_objects", [])
        session.setdefault("pinned_objects", [])
        session.setdefault("tasks", [])
        if args.app:
            session["recent_apps"] = [args.app, *[item for item in session["recent_apps"] if item != args.app]][:20]
        if args.path:
            resolved = str(Path(args.path).expanduser())
            session["recent_paths"] = [resolved, *[item for item in session["recent_paths"] if item != resolved]][:20]
        if args.task:
            task = {"title": args.task, "created_at": now_iso(), "status": "open"}
            session["tasks"] = [task, *session["tasks"]][:50]
        if args.mood:
            session["mood"] = args.mood
        if args.pin:
            session["pinned_objects"] = [args.pin, *[item for item in session["pinned_objects"] if item != args.pin]][:30]
        session["updated_at"] = now_iso()
        return session

    session = update_json(path, mutate, {})
    return {
        "schema": "sevenos.session-remember.v1",
        "profile": profile,
        "session": session,
        "path": str(path),
    }


def passage_for(profile):
    paths = profile_paths(profile)
    payload = read_json(paths["passage"], {})
    if payload:
        return payload
    experience = read_json(paths["experience"], {})
    return (experience.get("experience") or {}).get("passage") or {
        "profile": profile,
        "enter": f"Tu entres dans {profile}.",
        "leave": f"Tu quittes {profile}.",
        "transition": "SevenOS prepare le passage.",
        "sound": "soft",
        "motion": "fade",
    }


def switch_payload(args):
    init_state()
    source = normalize_profile(args.source or active_profile())
    target = normalize_profile(args.target)
    if source == target:
        mode = "already-there"
    else:
        mode = "preview"
    source_passage = passage_for(source)
    target_passage = passage_for(target)
    payload = {
        "schema": "sevenos.mini-os-switch.v1",
        "created_at": now_iso(),
        "from": source,
        "to": target,
        "mode": mode,
        "phrase": f"{source_passage.get('leave')} {target_passage.get('enter')}",
        "transition": target_passage.get("transition"),
        "motion": target_passage.get("motion"),
        "sound": target_passage.get("sound"),
        "boundaries": {
            "source_config": str(profile_paths(source)["config"]),
            "target_config": str(profile_paths(target)["config"]),
            "rule": "projection globale mise a jour, source de verite conservee par profil",
        },
        "command": f"seven profile activate {target}",
    }
    write_json(SWITCHER_PATH, payload)
    if args.apply and source != target:
        result = subprocess.run([str(ROOT / "profiles/profile-manager.sh"), "activate", target], cwd=ROOT, text=True, capture_output=True, check=False)
        payload["applied"] = result.returncode == 0
        payload["activation_returncode"] = result.returncode
        payload["activation_output"] = result.stdout[-1000:]
        payload["activation_error"] = result.stderr[-1000:]
    return payload


def graph_payload(write=True):
    status = status_payload() if write else {
        "profiles": [
            {"profile": profile, "inbox_count": 0, "outbox_count": 0, "ready": True}
            for profile in PROFILES
        ],
        "object_count": len(list(OBJECTS_DIR.glob("*.json"))) if OBJECTS_DIR.exists() else 0,
    }
    nodes = []
    for item in status["profiles"]:
        session = read_json(profile_paths(item["profile"])["session"], {})
        nodes.append({
            "id": item["profile"],
            "ready": item.get("ready", False),
            "inbox_count": item.get("inbox_count", 0),
            "outbox_count": item.get("outbox_count", 0),
            "mood": session.get("mood", "ready"),
            "recent_objects": len(session.get("recent_objects", []) if isinstance(session.get("recent_objects"), list) else []),
        })
    edges = []
    for relation in RELATIONS:
        edges.append({
            "from": relation["from"],
            "to": relation["to"],
            "channel": relation["channel"],
            "objects": relation["objects"],
            "protected_boundary": relation["protected_boundary"],
        })
    payload = {
        "schema": "sevenos.bridge-graph.v1",
        "generated_at": now_iso(),
        "nodes": nodes,
        "edges": edges,
        "object_count": status.get("object_count", 0),
        "rule": "relations are visible contracts, not hidden shared state",
    }
    if write:
        write_json(GRAPH_PATH, payload)
    return payload


def list_objects(limit):
    init_state()
    items = []
    for path in sorted(OBJECTS_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime):
        data = read_json(path, {})
        if data:
            items.append(data)
    return {
        "schema": "sevenos.objects.v1",
        "objects": items[-limit:],
    }


def list_box(profile, box, limit):
    init_state()
    profile = normalize_profile(profile or active_profile())
    path = profile_paths(profile)["inbox" if box == "inbox" else "outbox"]
    return {
        "schema": f"sevenos.bridge-{box}.v1",
        "profile": profile,
        box: read_jsonl(path, limit),
        "path": str(path),
    }


def accept_payload(args):
    init_state()
    profile = normalize_profile(args.profile or active_profile())
    object_id = args.object_id or args.asset
    if not object_id:
        raise SystemExit("seven bridge accept demande un object id")
    object_path = OBJECTS_DIR / f"{object_id}.json"
    if not object_path.exists() and Path(object_id).exists():
        object_path = Path(object_id)
    obj = read_json(object_path, {})
    if not obj:
        raise SystemExit(f"seven bridge: objet introuvable: {object_id}")
    obj["status"] = "accepted"
    obj["accepted_by"] = profile
    obj["accepted_at"] = now_iso()
    write_json(object_path, obj)
    session_path = profile_paths(profile)["session"]

    def mutate(session):
        session.setdefault("schema", "sevenos.profile-session.v1")
        session.setdefault("profile", profile)
        recent = session.get("recent_objects") if isinstance(session.get("recent_objects"), list) else []
        session["recent_objects"] = [obj["id"], *[item for item in recent if item != obj["id"]]][:20]
        session["updated_at"] = now_iso()
        return session

    session = update_json(session_path, mutate, {})
    return {
        "schema": "sevenos.bridge-accept.v1",
        "profile": profile,
        "object": obj,
        "session": session,
    }


def relations_payload():
    init_state()
    return read_json(RELATIONS_PATH, {
        "schema": "sevenos.bridge-relations.v1",
        "profiles": PROFILES,
        "relations": RELATIONS,
    })


def print_human(payload, action):
    if action == "send":
        msg = payload["message"]
        print(f"Objet envoye: {msg['title']}")
        print(f"{msg['from']} -> {msg['to']} via {msg['channel']}")
        print(f"Objet: {msg['object']}")
        return
    if action == "relations":
        print("Relations mini OS SevenOS")
        print("=========================")
        for item in payload.get("relations", []):
            print(f"- {item['from']} -> {item['to']}: {item['channel']}")
            print(f"  {item['phrase']}")
        return
    if action in {"inbox", "outbox"}:
        print(f"{action} {payload['profile']}: {len(payload.get(action, []))} message(s)")
        for item in payload.get(action, []):
            print(f"- {item.get('title')} ({item.get('from')} -> {item.get('to')})")
        return
    if action == "objects":
        print(f"Objets SevenOS: {len(payload.get('objects', []))}")
        for item in payload.get("objects", []):
            print(f"- {item.get('id')}: {item.get('title')} [{item.get('from')} -> {item.get('to')}]")
        return
    if action == "session":
        print(f"Session {payload.get('profile')}")
        print("=" * (8 + len(str(payload.get('profile')))))
        print(f"humeur: {payload.get('mood', 'ready')}")
        print(f"apps recentes: {', '.join(payload.get('recent_apps', [])[:5]) or 'aucune'}")
        print(f"objets recents: {', '.join(payload.get('recent_objects', [])[:5]) or 'aucun'}")
        return
    if action == "remember":
        print(f"Memoire mise a jour: {payload['profile']}")
        print(payload["path"])
        return
    if action == "switch":
        print(f"Passage {payload['from']} -> {payload['to']}")
        print(payload.get("phrase"))
        print(f"motion: {payload.get('motion')} / sound: {payload.get('sound')}")
        if payload.get("applied"):
            print("Activation appliquee.")
        return
    if action == "graph":
        print("Relations SevenOS")
        print("================")
        for edge in payload.get("edges", []):
            print(f"- {edge['from']} -> {edge['to']}: {edge['channel']}")
        return
    if action == "doctor":
        print(f"Bridge doctor: {payload.get('state')} ({payload.get('score')}%)")
        for issue in payload.get("profile_issues", []):
            print(f"- {issue['profile']}: missing {', '.join(issue['missing'])}")
        return
    if action == "accept":
        print(f"Objet accepte par {payload['profile']}: {payload['object'].get('title')}")
        return
    print("SevenOS Bridge")
    print("==============")
    print(f"Profil actif: {payload.get('active_profile')}")
    print(f"Objets: {payload.get('object_count')} ({payload.get('objects_dir')})")
    for item in payload.get("profiles", []):
        print(f"- {item['profile']}: inbox {item['inbox_count']} / outbox {item['outbox_count']}")


def main():
    parser = argparse.ArgumentParser(prog="seven bridge", description="SevenOS explicit inter-mini-OS object bridge")
    parser.add_argument("action", nargs="?", default="status", choices=("status", "init", "send", "relations", "objects", "inbox", "outbox", "session", "remember", "switch", "graph", "doctor", "accept"))
    parser.add_argument("asset", nargs="?", help="asset path or label for send")
    parser.add_argument("object_id", nargs="?", help="object id for accept")
    parser.add_argument("--from", dest="source", help="source mini OS")
    parser.add_argument("--to", dest="target", help="target mini OS")
    parser.add_argument("--profile", help="profile for inbox/outbox")
    parser.add_argument("--kind", help="object type")
    parser.add_argument("--title", help="object title")
    parser.add_argument("--rights", help="rights/license note")
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--app", help="remember a recent app for a mini OS")
    parser.add_argument("--path", help="remember a recent path for a mini OS")
    parser.add_argument("--task", help="remember a task for a mini OS")
    parser.add_argument("--mood", help="remember the current mood/ambience for a mini OS")
    parser.add_argument("--pin", help="pin a SevenOS object id in a mini OS session")
    parser.add_argument("--apply", action="store_true", help="apply a switch after preparing the passage")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if args.action in {"status", "init"}:
        payload = status_payload()
    elif args.action == "relations":
        payload = relations_payload()
    elif args.action == "objects":
        payload = list_objects(args.limit)
    elif args.action == "inbox":
        payload = list_box(args.profile, "inbox", args.limit)
    elif args.action == "outbox":
        payload = list_box(args.profile, "outbox", args.limit)
    elif args.action == "session":
        payload = session_payload(args.profile)
    elif args.action == "remember":
        payload = remember_payload(args)
    elif args.action == "switch":
        if not args.target:
            raise SystemExit("seven bridge switch demande --to <mini-os>")
        payload = switch_payload(args)
    elif args.action == "graph":
        payload = graph_payload()
    elif args.action == "doctor":
        payload = doctor_payload()
    elif args.action == "accept":
        payload = accept_payload(args)
    elif args.action == "send":
        if not args.target:
            raise SystemExit("seven bridge send demande --to <mini-os>")
        payload = send_object(args)
    else:
        raise SystemExit(2)

    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print_human(payload, args.action)


if __name__ == "__main__":
    main()
PY
