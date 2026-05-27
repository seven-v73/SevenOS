#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
BAOBAB_PROFILE_CONFIG="$CONFIG_HOME/sevenos/profiles/baobab"
BAOBAB_PROFILE_DATA="$DATA_HOME/sevenos/profiles/baobab"
BAOBAB_PROFILE_CACHE="$CACHE_HOME/sevenos/profiles/baobab"
BAOBAB_CONFIG="$BAOBAB_PROFILE_CONFIG/baobab"
BAOBAB_DATA="$BAOBAB_PROFILE_DATA/baobab"
BAOBAB_CACHE="$BAOBAB_PROFILE_CACHE/baobab"
BAOBAB_NODE="$BAOBAB_PROFILE_DATA/node"
BAOBAB_LEGACY_CONFIG="$CONFIG_HOME/sevenos/baobab"
BAOBAB_LEGACY_DATA="$DATA_HOME/sevenos/baobab"
BAOBAB_LEGACY_CACHE="$CACHE_HOME/sevenos/baobab"
BAOBAB_WORKSPACE="$HOME/Baobab"
MANIFEST="$BAOBAB_DATA/manifest.json"
CONTENT_INDEX="$BAOBAB_DATA/catalog.json"
BAOBAB_DB="$BAOBAB_DATA/baobab.sqlite"
PACKS_DIR="$BAOBAB_DATA/packs"
BAOBAB_RUNTIME="$BAOBAB_CONFIG/runtime.json"
BAOBAB_ENV="$BAOBAB_CONFIG/env"
BAOBAB_CONFIG_MANIFEST="$BAOBAB_CONFIG/config-manifest.json"
BAOBAB_BIN="$BAOBAB_CONFIG/bin"
BAOBAB_DESKTOP_DIR="$BAOBAB_PROFILE_DATA/applications"
BAOBAB_APP_MANIFEST="$BAOBAB_CONFIG/apps.json"
BAOBAB_CAPABILITIES="$BAOBAB_CONFIG/capabilities.json"
BAOBAB_PROFILE_UI="$BAOBAB_PROFILE_CONFIG/profile-ui.json"
BAOBAB_SESSION="$BAOBAB_PROFILE_CONFIG/session.json"
BAOBAB_PASSAGE="$BAOBAB_PROFILE_CONFIG/passage.json"
BAOBAB_WALLPAPER_STATE="$BAOBAB_PROFILE_CONFIG/wallpaper-state"
BAOBAB_NATIVE_SETTINGS="$BAOBAB_CONFIG/native-settings.json"
BAOBAB_TRAIL="$BAOBAB_DATA/trail/events.jsonl"
AFRICA_TSV="$ROOT_DIR/identity/countries/africa.tsv"
BAOBAB_DB_DIR="$ROOT_DIR/identity/baobab_db"
UNESCO_CSV="$ROOT_DIR/identity/baobab_db/africanUnesco.csv"
COUNTRIES_JSON="$BAOBAB_DATA/explore/africa-countries.json"
UNESCO_JSON="$BAOBAB_DATA/heritage/african-unesco-ich.json"
DATASETS_JSON="$BAOBAB_DATA/offline/datasets.json"
LANGUAGES_SOURCE="$ROOT_DIR/identity/baobab_languages.json"
LANGUAGES_JSON="$BAOBAB_DATA/languages/african-languages.json"
IMMERSIONS_SOURCE="$ROOT_DIR/identity/baobab_immersions.json"
IMMERSIONS_JSON="$BAOBAB_DATA/immersions/baobab-immersions.json"
PROTOCOLS_SOURCE="$ROOT_DIR/identity/baobab_protocols.json"
PROTOCOLS_JSON="$BAOBAB_DATA/protocols/cultural-protocols.json"
VALIDATION_DIR="$BAOBAB_DATA/validation"
VALIDATORS_JSON="$VALIDATION_DIR/validators.json"
VILLAGE_HTML="$BAOBAB_WORKSPACE/Village/index.html"
HERITAGE_HTML="$BAOBAB_WORKSPACE/Heritage/index.html"
MUSEUM_HTML="$BAOBAB_WORKSPACE/Museum 3D/index.html"
STORY_HTML="$BAOBAB_WORKSPACE/Story Engine/index.html"
EXPLORE_HTML="$BAOBAB_WORKSPACE/Explore/index.html"

ACTION="status"
JSON_OUTPUT=0
MODULE_NAME=""
SEARCH_QUERY=""
PACK_TARGET=""
COUNTRY_QUERY=""
VIEW_TARGET=""

usage() {
  cat <<'EOF'
SevenOS Baobab

Usage:
  seven baobab [status|json|plan|doctor|bootstrap|install-core|install-optional|capabilities|capability-doctor|config|runtime|config-doctor|service-doctor|app-doctor|apply-config|sound|open|native|village|heritage|museum|story|explore|countries|country NAME|immersions|immersion ID|ritual|journal|route|ambiance [calme|apprentissage|terrain|scene]|compass|today|session|trail|remember TEXT|shell|unesco|datasets|catalog|search QUERY|stats|db|engines|tools|tool-doctor|languages|protocols|protocol-doctor|validation-kit|validation-doctor|integrations|integration NAME|roadmap|packs|audit-packs|seed-packs|enrich-packs|evidence-packs|sample-fieldwork|scaffold-pack NAME|import-pack PATH|modules|module NAME] [--json]
  ./scripts/baobab.sh [status|json|plan|doctor|bootstrap|install-core|install-optional|capabilities|capability-doctor|config|runtime|config-doctor|service-doctor|app-doctor|apply-config|sound|open|native|village|heritage|museum|story|explore|countries|country NAME|immersions|immersion ID|ritual|journal|route|ambiance [calme|apprentissage|terrain|scene]|compass|today|session|trail|remember TEXT|shell|unesco|datasets|catalog|search QUERY|stats|db|engines|tools|tool-doctor|languages|protocols|protocol-doctor|validation-kit|validation-doctor|integrations|integration NAME|roadmap|packs|audit-packs|seed-packs|enrich-packs|evidence-packs|sample-fieldwork|scaffold-pack NAME|import-pack PATH|modules|module NAME] [--json]

Baobab is the African cultural mini OS inside SevenOS: heritage, languages,
storytelling, sound, map exploration, fashion, food, wisdom and offline memory.
EOF
}

for arg in "$@"; do
  case "$arg" in
    status|json|plan|doctor|bootstrap|install-core|install-optional|capabilities|capability-doctor|config|runtime|config-doctor|service-doctor|app-doctor|apply-config|sound|open|native|village|heritage|museum|story|explore|countries|country|immersions|immersion|ritual|journal|route|ambiance|compass|today|session|trail|remember|shell|unesco|datasets|catalog|search|stats|db|engines|tools|tool-doctor|languages|protocols|protocol-doctor|validation-kit|validation-doctor|integrations|integration|roadmap|packs|audit-packs|seed-packs|enrich-packs|evidence-packs|sample-fieldwork|scaffold-pack|import-pack|modules|module)
      if [[ "$VIEW_TARGET" == "__next__" ]]; then
        VIEW_TARGET="$arg"
      else
        ACTION="$arg"
      fi
      ;;
    --json) JSON_OUTPUT=1 ;;
    --view) VIEW_TARGET="__next__" ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      if [[ "$ACTION" == "module" && -z "$MODULE_NAME" ]]; then
        MODULE_NAME="$arg"
      elif [[ "$ACTION" == "integration" && -z "$MODULE_NAME" ]]; then
        MODULE_NAME="$arg"
      elif [[ "$ACTION" == "search" || "$ACTION" == "remember" ]]; then
        SEARCH_QUERY="${SEARCH_QUERY:+$SEARCH_QUERY }$arg"
      elif [[ "$ACTION" == "country" ]]; then
        COUNTRY_QUERY="${COUNTRY_QUERY:+$COUNTRY_QUERY }$arg"
      elif [[ "$ACTION" == "immersion" ]]; then
        COUNTRY_QUERY="${COUNTRY_QUERY:+$COUNTRY_QUERY }$arg"
      elif [[ "$ACTION" == "ambiance" ]]; then
        COUNTRY_QUERY="${COUNTRY_QUERY:+$COUNTRY_QUERY }$arg"
      elif [[ "$VIEW_TARGET" == "__next__" ]]; then
        VIEW_TARGET="$arg"
      elif [[ "$ACTION" == "scaffold-pack" || "$ACTION" == "import-pack" ]]; then
        PACK_TARGET="${PACK_TARGET:+$PACK_TARGET }$arg"
      fi
      ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

module_rows() {
  cat <<'EOF'
heritage	Baobab Heritage	Library of stories, proverbs, archives, books, oral traditions and timelines	heritage,books,oral-tradition,archives	offline-first
story	Baobab Story Engine	Immersive narration, ancestor mode, fire-circle storytelling and guided learning	storytelling,narration,tts	planned
sound	Baobab Sound	Cultural audio, instruments, radios, podcasts, playlists and ambient soundscapes	audio,radio,instruments,soundscape	planned
explore	Baobab Explore	Interactive African cultural map with countries, languages, peoples, food and monuments	map,geojson,history,countries	offline-first
museum	Baobab Museum 3D	Digital archive for objects, architecture, instruments, textiles and monuments	3d,museum,objects,threejs	planned
languages	African Language Hub	Language learning, dictionaries, pronunciation, keyboards, TTS and translation	languages,dictionary,tts,translation	offline-first
fashion	Baobab Fashion	Traditional and modern African style, virtual try-on and ElegantStyle bridge	fashion,textiles,elegantstyle,market	planned
food	Baobab Food	Recipes, culinary history, regional dishes and grandmother-style narration	food,recipes,regions,narration	planned
wisdom	Baobab Wisdom	Philosophy, cosmology, ancestral wisdom, proverbs and cultural explanations	wisdom,philosophy,proverbs,ai	offline-first
market	Baobab Market	Cultural marketplace for artisans, stylists, musicians, ebooks and instruments	market,creators,crafts,community	planned
EOF
}

integration_rows() {
  cat <<'EOF'
shell	matshell	Matshell	Baobab Shell inspiration: Material-style AGS/Astal shell, dashboard, launcher and organic widgets	https://github.com/Neurarian/matshell	phase-1	evaluate-adapt
shell	ags	AGS	Widget runtime for Baobab Shell surfaces, village panels, notifications and launchers	https://github.com/Aylur/ags	phase-1	adopt
shell	astal	Astal	Modern AGS service bindings for GTK shell widgets and Hyprland-aware controls	https://aylur.github.io/astal	phase-1	adopt
shell	hyprpanel	HyprPanel	Dashboard and panel reference for Baobab cultural widgets and quick controls	https://github.com/Jas-SinghFSU/HyprPanel	phase-2	evaluate-adapt
shell	highbar	HighBar	Minimal AGS/Astal bar reference for cultural status and compact shell controls	https://github.com/h0i5/HighBar	phase-2	evaluate-adapt
heritage	arches	Arches Project	Heritage inventory model for monuments, sites, cultural geography and historical resources	https://github.com/archesproject/arches	phase-2	connect
heritage	dedalo	Dedalo	Multilingual cultural heritage archive model for oral history, media and field metadata	https://github.com/renderpci/dedalo	phase-2	connect
heritage	openatlas	OpenAtlas	Historical relationship graph and archaeology/humanities data model	https://github.com/craws/OpenAtlas	phase-3	connect
heritage	collectionscope	Collectionscope	Collection visualization inspiration for time, space and museum-style browsing	https://github.com/explore?q=collectionscope&type=repositories	phase-3	evaluate
museum	openvgal	OpenVGAL	WebGL gallery reference for Baobab Museum 3D and virtual exhibitions	https://github.com/explore?q=OpenVGAL&type=repositories	phase-2	evaluate
museum	ecorpus	eCorpus	3D heritage object annotation and sharing reference for cultural artifacts	https://github.com/explore?q=eCorpus+cultural+heritage&type=repositories	phase-3	evaluate
museum	cher-ob	CHER-Ob	2D/3D cultural object analysis and annotation reference	https://github.com/explore?q=CHER-Ob&type=repositories	phase-3	evaluate
museum	micromuseum	Micromuseum	Small museum publishing pattern for lightweight Baobab exhibitions	https://github.com/explore?q=micromuseum&type=repositories	phase-3	evaluate
3d	threejs	Three.js	WebGL engine for maps, museum scenes, artifacts and village spaces	https://github.com/mrdoob/three.js	phase-1	adopt
3d	babylonjs	Babylon.js	Immersive WebGL engine candidate for richer 3D cultural scenes	https://github.com/BabylonJS/Babylon.js	phase-2	evaluate
offline	nomad	Project NOMAD	Offline knowledge core inspiration: offline knowledge, maps, education and local-first deployments	https://github.com/explore?q=Project+NOMAD+offline+knowledge&type=repositories	phase-2	evaluate
offline	sqlite	SQLite	Local Baobab catalog and pack index already active through baobab.sqlite	https://www.sqlite.org/index.html	active	adopted
offline	meilisearch	Meilisearch	Fast local cultural search engine candidate when catalog grows beyond SQLite FTS	https://github.com/meilisearch/meilisearch	phase-3	evaluate
ai	ollama	Ollama	Local cultural assistant runtime for Seven Baobab AI	https://github.com/ollama/ollama	phase-2	connect
ai	piper	Piper TTS	Offline narration voice engine for story mode and guided heritage reading	https://github.com/rhasspy/piper	phase-2	connect
ai	argos	Argos Translate	Offline translation layer for African language learning workflows	https://github.com/argosopentech/argos-translate	phase-2	connect
reader	foliate	Foliate	Ebook reader reference and app integration for immersive reading	https://github.com/johnfactotum/foliate	phase-1	connect
EOF
}

engine_rows() {
  cat <<'EOF'
sqlite	Offline Core	sqlite3	python-sqlite	critical	Local Baobab catalog database and search index
seven-reader	Reader	bin/seven-reader	seven-reader	important	SevenOS native reading lane
foliate	Reader	foliate	foliate	optional	Ebook reader for immersive cultural reading
kiwix	Education	kiwix-desktop	kiwix-desktop	optional	Offline encyclopedias and school/village knowledge packs
kolibri	Education	kolibri	kolibri	optional	Offline education platform for low-connectivity contexts
ags	Shell	ags	ags	optional	AGS shell runtime candidate for Baobab Shell
astal	Shell	astal	astal	optional	Astal shell service bindings candidate
hyprland	Shell	Hyprland	hyprland	important	Wayland compositor foundation for Baobab Shell
waybar	Shell	waybar	waybar	important	Cultural status bar for language, proverb, audio and readiness widgets
eww	Widgets	eww	eww	optional	Lightweight cultural widgets for quotes, radio, map cards and events
swaync	Notifications	swaync	swaync	optional	Elegant Wayland notification center
pywal	Identity	wal	python-pywal	optional	Dynamic palettes from cultural images, textiles and Baobab wallpapers
pipewire	Sound	pipewire	pipewire	important	Modern local audio foundation for soundscapes, narration and radio
node	3D/Web	node	nodejs	optional	JavaScript runtime for Three.js or Babylon.js prototypes
npm	3D/Web	npm	npm	optional	Package manager for WebGL museum/village prototypes
ollama	AI	ollama	ollama	optional	Local LLM runtime for Seven Baobab AI
llama-cpp	AI	llama-cli	llama.cpp	optional	Light local model runtime for modest machines
open-webui	AI	open-webui	external:open-webui	optional	Local AI chat interface candidate for Baobab learning labs
piper	Narration	piper	piper	optional	Offline TTS narration engine
argos	Translation	trans	external:argos-translate	optional	Offline translation target with translate-shell fallback
meilisearch	Search	meilisearch	meilisearch	optional	Fast local search engine for large cultural archives
mpv	Sound	mpv	mpv	optional	Audio/video playback for Baobab Sound
tauon	Sound	tauon	tauon-music-box	optional	Music library for cultural playlists and local archives
syncthing	Sync	syncthing	syncthing	optional	Peer-to-peer local/community sync without central cloud
nextcloud	Sync	nextcloud	nextcloud	optional	Community cloud candidate for schools and cultural centers
krita	Creation	krita	krita	optional	Illustration and visual craft tool for cultural creators
blender	Creation	blender	blender	optional	3D creation for museum objects, scenes and education
kdenlive	Creation	kdenlive	kdenlive	optional	Video editing for oral tradition, interviews and lessons
EOF
}

tool_rows() {
  cat <<'EOF'
system	hyprland	Hyprland	hyprland	command:Hyprland	core	Compositeur fluide pour une expérience Baobab moderne et personnalisable.
system	waybar	Waybar	waybar	command:waybar	core	Barre culturelle: langues, proverbes, son, calendrier, état offline.
system	eww	Eww	eww	command-any:eww,eww-wayland	optional	Widgets légers pour citations, radio, carte culturelle et événements.
system	swaync	SwayNC	swaync	command:swaync	optional	Notifications élégantes compatibles Wayland.
identity	noto	Noto Fonts	noto-fonts	path:/usr/share/fonts/noto	core	Support typographique large pour langues et écritures.
identity	pywal	Pywal	python-pywal	command:wal	optional	Palette dynamique depuis textiles, paysages, photos et wallpapers culturels.
identity	pipewire	PipeWire	pipewire	command:pipewire	core	Base audio pour ambiances, narration, instruments et voix locales.
content	sqlite	SQLite	python-sqlite	python:sqlite3	core	Base locale pour proverbes, langues, histoires, recettes, textiles et patrimoine.
content	meilisearch	Meilisearch	meilisearch	command:meilisearch	optional	Recherche instantanée quand la bibliothèque Baobab devient massive.
content	leaflet	Leaflet	leaflet	file-env:BAOBAB_NODE/node_modules/leaflet	optional	Cartographie culturelle offline ou semi-native avec pays, langues et monuments.
ai	ollama	Ollama	ollama	command:ollama	optional	LLM local pour assistant culturel, narrateur, tuteur et recommandations.
ai	llama-cpp	llama.cpp	llama.cpp	command-any:llama-cli,llama-server,llama	optional	Runtime léger pour modèles locaux sur machines modestes.
ai	open-webui	Open WebUI	external:open-webui	contract:external-lab	optional	Interface IA locale pour labs éducatifs, séparée du chemin AUR par défaut.
ai	piper	Piper	piper-tts-bin	command-any:piper,/opt/piper-tts/piper,espeak-ng	optional	Narration vocale locale, avec espeak-ng comme fallback immédiat.
ai	argos	Argos Translate	external:argos-translate	command-any:argos-translate,trans	optional	Traduction locale cible, avec translate-shell comme fallback immédiat.
education	foliate	Foliate	foliate	command:foliate	optional	Lecteur EPUB/PDF pour livres, archives et lecture immersive.
education	kiwix	Kiwix	kiwix-desktop-git	command-any:kiwix-desktop,kiwix	optional	Encyclopédies offline pour écoles et faible connectivité.
education	kolibri	Kolibri	pipx:kolibri	command:kolibri	optional	Plateforme pédagogique locale pour salles de classe et communautés.
media	mpv	MPV	mpv	command:mpv	core	Lecture audio/vidéo légère pour Sound, Story et Museum.
media	audacity	Audacity	audacity	command:audacity	optional	Montage local pour interviews, récits, sons et archives orales.
media	tauon	Tauon Music Box	tauon-music-box	command:tauon	optional	Bibliothèque musicale culturelle locale.
media	radio-browser	Radio Browser API	radio-browser-api	contract:online-api	optional	Radios africaines quand internet est disponible, cache local ensuite.
store	packagekit	PackageKit	packagekit	command-any:pkcon,pkgcli	optional	Backend store propre pour exposer sources sans jargon technique.
store	flatpak	Flatpak	flatpak	command:flatpak	optional	Applications sandboxées pour Baobab Store.
sync	syncthing	Syncthing	syncthing	command:syncthing	optional	Sync locale entre familles, écoles et ateliers sans serveur central.
sync	nextcloud	Nextcloud	nextcloud,nextcloud-client	command-any:nextcloud,nextcloudcmd	optional	Cloud communautaire possible, pas requis pour le mode offline.
creation	krita	Krita	krita	command:krita	optional	Illustration pour artisans, motifs, pédagogie et supports visuels.
creation	blender	Blender	blender	command:blender	optional	3D pour objets, musées, scènes et architecture.
creation	kdenlive	Kdenlive	kdenlive	command:kdenlive	optional	Montage vidéo pour interviews, contes, cours et archives.
EOF
}

migrate_legacy_state() {
  local source target
  for source in "$BAOBAB_LEGACY_CONFIG" "$BAOBAB_LEGACY_DATA" "$BAOBAB_LEGACY_CACHE"; do
    case "$source" in
      "$BAOBAB_LEGACY_CONFIG") target="$BAOBAB_CONFIG" ;;
      "$BAOBAB_LEGACY_DATA") target="$BAOBAB_DATA" ;;
      "$BAOBAB_LEGACY_CACHE") target="$BAOBAB_CACHE" ;;
      *) continue ;;
    esac
    if [[ -d "$source" && ! -e "$target/.migrated-from-legacy" ]]; then
      mkdir -p "$target"
      cp -a "$source"/. "$target"/ 2>/dev/null || true
      printf '%s\n' "$source" > "$target/.migrated-from-legacy"
    fi
  done
}

baobab_json() {
  SEVENOS_ROOT="$ROOT_DIR" \
  BAOBAB_PROFILE_CONFIG="$BAOBAB_PROFILE_CONFIG" \
  BAOBAB_PROFILE_DATA="$BAOBAB_PROFILE_DATA" \
  BAOBAB_PROFILE_CACHE="$BAOBAB_PROFILE_CACHE" \
  BAOBAB_CONFIG="$BAOBAB_CONFIG" \
  BAOBAB_DATA="$BAOBAB_DATA" \
  BAOBAB_CACHE="$BAOBAB_CACHE" \
  BAOBAB_NODE="$BAOBAB_NODE" \
  BAOBAB_RUNTIME="$BAOBAB_RUNTIME" \
  BAOBAB_ENV="$BAOBAB_ENV" \
  BAOBAB_CONFIG_MANIFEST="$BAOBAB_CONFIG_MANIFEST" \
  BAOBAB_BIN="$BAOBAB_BIN" \
  BAOBAB_DESKTOP_DIR="$BAOBAB_DESKTOP_DIR" \
  BAOBAB_APP_MANIFEST="$BAOBAB_APP_MANIFEST" \
  BAOBAB_CAPABILITIES="$BAOBAB_CAPABILITIES" \
  BAOBAB_PROFILE_UI="$BAOBAB_PROFILE_UI" \
  BAOBAB_SESSION="$BAOBAB_SESSION" \
  BAOBAB_PASSAGE="$BAOBAB_PASSAGE" \
  BAOBAB_WALLPAPER_STATE="$BAOBAB_WALLPAPER_STATE" \
  BAOBAB_WORKSPACE="$BAOBAB_WORKSPACE" \
  MANIFEST="$MANIFEST" \
  CONTENT_INDEX="$CONTENT_INDEX" \
  BAOBAB_DB="$BAOBAB_DB" \
  VILLAGE_HTML="$VILLAGE_HTML" \
  HERITAGE_HTML="$HERITAGE_HTML" \
  MUSEUM_HTML="$MUSEUM_HTML" \
  STORY_HTML="$STORY_HTML" \
  EXPLORE_HTML="$EXPLORE_HTML" \
  PACKS_DIR="$PACKS_DIR" \
  AFRICA_TSV="$AFRICA_TSV" \
  UNESCO_CSV="$UNESCO_CSV" \
  COUNTRIES_JSON="$COUNTRIES_JSON" \
  UNESCO_JSON="$UNESCO_JSON" \
	  DATASETS_JSON="$DATASETS_JSON" \
	  LANGUAGES_JSON="$LANGUAGES_JSON" \
	  PROTOCOLS_JSON="$PROTOCOLS_JSON" \
	  MODULE_ROWS="$(module_rows)" \
  INTEGRATION_ROWS="$(integration_rows)" \
  ENGINE_ROWS="$(engine_rows)" \
  TOOL_ROWS="$(tool_rows)" \
  python - <<'PY'
import json
import os
import shutil
from pathlib import Path


def exists(path: str) -> bool:
    return Path(path).exists()


modules = []
for raw in os.environ["MODULE_ROWS"].splitlines():
    key, title, purpose, tags, state = raw.split("\t")
    modules.append({
        "key": key,
        "title": title,
        "purpose": purpose,
        "tags": tags.split(","),
        "state": state,
        "data_path": str(Path(os.environ["BAOBAB_DATA"]) / key),
        "workspace_path": str(Path(os.environ["BAOBAB_WORKSPACE"]) / title.replace("Baobab ", "").replace("African ", "")),
    })

integrations = []
for raw in os.environ["INTEGRATION_ROWS"].splitlines():
    group, key, title, role, source, phase, mode = raw.split("\t")
    integrations.append({
        "group": group,
        "key": key,
        "title": title,
        "role": role,
        "source": source,
        "phase": phase,
        "mode": mode,
    })

engines = []
for raw in os.environ["ENGINE_ROWS"].splitlines():
    key, group, command, package, priority, role = raw.split("\t")
    if command.startswith("bin/"):
        path = Path(os.environ["SEVENOS_ROOT"], command)
        resolved = str(path)
        available = path.exists()
    elif key == "sqlite":
        resolved = "python sqlite3"
        available = True
    else:
        resolved = shutil.which(command) or ""
        available = bool(resolved)
    engines.append({
        "key": key,
        "group": group,
        "command": command,
        "package": package,
        "priority": priority,
        "role": role,
        "state": "available" if available else "missing",
        "resolved": resolved,
    })

def tool_available(probe: str) -> tuple[str, str]:
    kind, _, value = probe.partition(":")
    if kind == "command":
        resolved = shutil.which(value) or ""
        return ("available" if resolved else "missing", resolved)
    if kind == "command-any":
        for command in [part.strip() for part in value.split(",") if part.strip()]:
            resolved = shutil.which(command) or ""
            if resolved:
                return ("available", resolved)
        return ("missing", value)
    if kind == "path":
        path = Path(value)
        return ("available" if path.exists() else "missing", str(path))
    if kind == "file":
        path = Path(os.environ["SEVENOS_ROOT"], value)
        return ("available" if path.exists() else "missing", str(path))
    if kind == "file-env":
        env_name, _, suffix = value.partition("/")
        base = Path(os.environ.get(env_name, ""))
        path = base / suffix if suffix else base
        return ("available" if path.exists() else "missing", str(path))
    if kind == "python":
        try:
            __import__(value)
            return ("available", f"python:{value}")
        except Exception:
            return ("missing", f"python:{value}")
    if kind == "contract":
        return ("planned", value)
    return ("missing", value)

tool_groups = {}
tools = []
for raw in os.environ["TOOL_ROWS"].splitlines():
    group, key, title, package, probe, priority, role = raw.split("\t")
    state, resolved = tool_available(probe)
    item = {
        "group": group,
        "key": key,
        "title": title,
        "package": package,
        "probe": probe,
        "priority": priority,
        "role": role,
        "state": state,
        "resolved": resolved,
    }
    tools.append(item)
    tool_groups.setdefault(group, []).append(item)

tool_summary = {}
for group, items in sorted(tool_groups.items()):
    core = [item for item in items if item["priority"] == "core"]
    ready_core = sum(1 for item in core if item["state"] == "available")
    available = sum(1 for item in items if item["state"] == "available")
    tool_summary[group] = {
        "available": available,
        "total": len(items),
        "core_available": ready_core,
        "core_total": len(core),
        "state": "ready" if not core or ready_core == len(core) else "needs-core-tool",
    }

paths = {
    "profile_config": os.environ["BAOBAB_PROFILE_CONFIG"],
    "profile_data": os.environ["BAOBAB_PROFILE_DATA"],
    "profile_cache": os.environ["BAOBAB_PROFILE_CACHE"],
    "config": os.environ["BAOBAB_CONFIG"],
    "data": os.environ["BAOBAB_DATA"],
        "cache": os.environ["BAOBAB_CACHE"],
        "node": os.environ["BAOBAB_NODE"],
    "workspace": os.environ["BAOBAB_WORKSPACE"],
    "manifest": os.environ["MANIFEST"],
}
ready_paths = sum(1 for value in paths.values() if exists(value))
core_ready = exists(paths["manifest"]) and exists(paths["workspace"]) and exists(paths["data"])
score = round((ready_paths / len(paths)) * 100)

print(json.dumps({
    "schema": "sevenos.baobab.v1",
    "state": "ready" if core_ready else "needs-bootstrap",
    "score": score,
    "name": "Baobab",
    "title": "Baobab Cultural Mini OS",
    "tagline": "Rooted technology for African memory, learning, creation and transmission.",
    "vision": "A calm African cultural computing environment: living memory, oral transmission, education, creation and community-owned knowledge.",
    "principles": [
        "African thinking before African decoration",
        "Rooted technology, calm intelligence and living memory",
        "Subtle cultural detail instead of folklore, safari, postcard or motif overload",
        "offline-first for schools, villages and low-connectivity environments",
        "no profile dependency, only explicit capability collaboration",
        "culture, education, creativity and preservation before tooling",
        "local-first AI and user-owned cultural memory",
    ],
    "village": [
        {"place": "Racines", "module": "home", "role": "orientation, memory and daily cultural continuity"},
        {"place": "Bibliothèque", "module": "heritage", "role": "books, oral traditions, archives and proverbs"},
        {"place": "Cercle", "module": "wisdom", "role": "history, traditions, philosophy and elder knowledge"},
        {"place": "Écoute", "module": "sound", "role": "music, narration, radio, instruments and sound memory"},
        {"place": "Marché", "module": "market", "role": "creators, crafts, textiles, books and instruments"},
        {"place": "Atelier", "module": "fashion", "role": "textiles, design, virtual try-on and ElegantStyle bridge"},
        {"place": "Branches", "module": "explore", "role": "countries, languages, food, monuments and timelines"},
        {"place": "Cuisine", "module": "food", "role": "recipes, stories and regional gastronomy"},
        {"place": "Archives", "module": "museum", "role": "objects, architecture, instruments and contextual collections"},
    ],
    "art_direction": {
        "name": "Rooted Technology",
        "tone": "calm, premium, contemplative, educational and modern",
        "avoid": ["safari", "postcard Africa", "folklore overload", "animals", "motifs everywhere", "mask-heavy identity", "red-green-yellow saturation"],
        "prefer": ["volcanic black", "warm ivory", "baobab green", "textile indigo", "copper light", "subtle root geometry", "generous spacing", "slow transitions"],
        "ux_metaphors": ["roots", "trunk", "branches", "leaves", "oral transmission", "community validation", "living memory"],
    },
    "modules": modules,
    "integrations": integrations,
    "engines": engines,
    "offline": {
        "database": os.environ["BAOBAB_DB"],
        "media_cache": str(Path(paths["cache"]) / "media"),
        "maps_cache": str(Path(paths["cache"]) / "maps"),
        "countries": os.environ["COUNTRIES_JSON"],
        "countries_source": os.environ["AFRICA_TSV"],
        "unesco_ich": os.environ["UNESCO_JSON"],
        "unesco_source": os.environ["UNESCO_CSV"],
        "datasets": os.environ["DATASETS_JSON"],
        "languages": os.environ["LANGUAGES_JSON"],
        "protocols": os.environ["PROTOCOLS_JSON"],
        "datasets_source": str(Path(os.environ["UNESCO_CSV"]).parent),
        "ai_memory": str(Path(paths["data"]) / "ai-memory"),
        "sync_policy": "manual or low-bandwidth sync; never require internet for core heritage content",
    },
    "ai": {
        "name": "Seven Baobab AI",
        "roles": ["calm cultural guide", "story narrator", "language tutor", "historian", "fashion recommender", "heritage librarian"],
        "tone": "wise, educational, contextual and human; never a generic robot persona",
        "future_stack": ["Ollama", "llama.cpp", "Open WebUI", "BGE embeddings", "ChromaDB", "Piper TTS", "Argos Translate", "SQLite"],
    },
    "tools": {
        "state": "ready" if all(item["state"] == "ready" for item in tool_summary.values()) else "partial",
        "summary": tool_summary,
        "items": tools,
        "install_optional": "seven profile install baobab",
        "aur_candidates": str(Path(os.environ["SEVENOS_ROOT"]) / "scripts/packages-culture-aur.txt"),
        "principle": "tools serve culture, offline use, education and community memory; they do not define the identity alone",
    },
    "strict_config": {
        "state": "profile-owned",
        "profile": "baobab",
        "rule": "Baobab writes durable config only under ~/.config/sevenos/profiles/baobab and data/cache only under ~/.local/share or ~/.cache/sevenos/profiles/baobab.",
        "profile_config": os.environ["BAOBAB_PROFILE_CONFIG"],
        "profile_data": os.environ["BAOBAB_PROFILE_DATA"],
    "profile_cache": os.environ["BAOBAB_PROFILE_CACHE"],
    "node": os.environ["BAOBAB_NODE"],
        "runtime": os.environ["BAOBAB_RUNTIME"],
        "env": os.environ["BAOBAB_ENV"],
        "config_manifest": os.environ["BAOBAB_CONFIG_MANIFEST"],
        "bin": os.environ["BAOBAB_BIN"],
        "desktop_dir": os.environ["BAOBAB_DESKTOP_DIR"],
        "app_manifest": os.environ["BAOBAB_APP_MANIFEST"],
        "capabilities": os.environ["BAOBAB_CAPABILITIES"],
        "profile_ui": os.environ["BAOBAB_PROFILE_UI"],
        "session": os.environ["BAOBAB_SESSION"],
        "passage": os.environ["BAOBAB_PASSAGE"],
        "wallpaper_state": os.environ["BAOBAB_WALLPAPER_STATE"],
        "global_projection_policy": "Global SevenOS files may display the active profile, but Baobab source-of-truth config remains profile-owned.",
    },
    "paths": paths,
    "content": {
        "index": os.environ["CONTENT_INDEX"],
        "packs_dir": os.environ["PACKS_DIR"],
        "village_html": os.environ["VILLAGE_HTML"],
        "heritage_html": os.environ["HERITAGE_HTML"],
        "museum_html": os.environ["MUSEUM_HTML"],
        "story_html": os.environ["STORY_HTML"],
        "explore_html": os.environ["EXPLORE_HTML"],
        "seed_policy": "starter metadata only; replace or extend with locally curated cultural sources",
    },
    "commands": {
        "status": "seven baobab",
        "bootstrap": "seven baobab bootstrap",
        "install_core": "seven baobab install-core",
        "install_optional": "seven baobab install-optional",
        "capabilities": "seven baobab capabilities",
        "capability_doctor": "seven baobab capability-doctor",
        "config": "seven baobab config",
        "runtime": "seven baobab runtime",
        "config_doctor": "seven baobab config-doctor",
        "service_doctor": "seven baobab service-doctor",
        "app_doctor": "seven baobab app-doctor",
        "apply_config": "seven baobab apply-config",
        "sound": "seven baobab sound",
        "open": "seven baobab open",
        "entry": "seven baobab native --view entry",
        "today": "seven baobab today",
        "native": "seven baobab native",
        "village": "seven baobab village",
        "heritage": "seven baobab heritage",
        "museum": "seven baobab museum",
        "story": "seven baobab story",
        "explore": "seven baobab explore",
        "countries": "seven baobab countries",
        "country": "seven baobab country <name>",
        "unesco": "seven baobab unesco",
        "datasets": "seven baobab datasets",
        "catalog": "seven baobab catalog",
        "search": "seven baobab search <query>",
        "stats": "seven baobab stats",
        "db": "seven baobab db",
        "engines": "seven baobab engines",
        "tools": "seven baobab tools",
        "tool_doctor": "seven baobab tool-doctor",
        "languages": "seven baobab languages",
        "protocols": "seven baobab protocols",
        "protocol_doctor": "seven baobab protocol-doctor",
        "validation_kit": "seven baobab validation-kit",
        "validation_doctor": "seven baobab validation-doctor",
        "packs": "seven baobab packs",
        "audit_packs": "seven baobab audit-packs",
        "seed_packs": "seven baobab seed-packs",
        "enrich_packs": "seven baobab enrich-packs",
        "evidence_packs": "seven baobab evidence-packs",
        "sample_fieldwork": "seven baobab sample-fieldwork",
        "scaffold_pack": "seven baobab scaffold-pack <name>",
        "import_pack": "seven baobab import-pack <path>",
        "modules": "seven baobab modules",
        "activate": "seven profile activate baobab",
        "ambiance": "seven baobab ambiance",
        "reader": "seven-reader",
    },
}, indent=2))
PY
}

seed_catalog_json() {
  cat <<'EOF'
{
  "schema": "sevenos.baobab.catalog.v1",
  "curation_note": "Starter metadata for offline Baobab. Treat entries as prompts for locally curated, source-backed cultural packs.",
  "packs": ["starter"],
  "records": [
    {
      "id": "heritage-oral-traditions",
      "module": "heritage",
      "title": "Oral Traditions Starter Shelf",
      "kind": "collection",
      "region": "pan-african",
      "summary": "A shelf for tales, epics, songs, family histories, community memories and elder-led narration.",
      "tags": ["oral-tradition", "stories", "memory", "elders"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    },
    {
      "id": "languages-learning-hub",
      "module": "languages",
      "title": "African Language Learning Hub",
      "kind": "learning-space",
      "region": "pan-african",
      "summary": "A local-first place for dictionaries, pronunciation notes, keyboards, lessons and translation packs.",
      "tags": ["languages", "dictionary", "tts", "translation"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    },
    {
      "id": "sound-instruments-radio",
      "module": "sound",
      "title": "Instruments, Radio and Soundscapes",
      "kind": "media-space",
      "region": "pan-african",
      "summary": "A cultural audio lane for instruments, local radio links, playlists, podcasts and ambient soundscapes.",
      "tags": ["music", "radio", "instruments", "soundscape"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    },
    {
      "id": "explore-africa-map",
      "module": "explore",
      "title": "Explore Africa Map Pack",
      "kind": "map-pack",
      "region": "africa",
      "summary": "A future offline map index for countries, peoples, languages, food, monuments, timelines and cultural notes.",
      "tags": ["map", "countries", "geojson", "history"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    },
    {
      "id": "fashion-textile-atelier",
      "module": "fashion",
      "title": "Textile and Style Atelier",
      "kind": "creative-space",
      "region": "pan-african",
      "summary": "A workspace for textile references, creator profiles, virtual try-on flows and ElegantStyle integration.",
      "tags": ["fashion", "textiles", "style", "elegantstyle"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    },
    {
      "id": "food-kitchen-memory",
      "module": "food",
      "title": "Kitchen Memory",
      "kind": "recipe-space",
      "region": "pan-african",
      "summary": "A place for recipes, food stories, regional ingredients, family notes and narrated cooking memories.",
      "tags": ["food", "recipes", "family-memory", "regions"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    },
    {
      "id": "wisdom-proverbs-council",
      "module": "wisdom",
      "title": "Council of Proverbs and Wisdom",
      "kind": "knowledge-space",
      "region": "pan-african",
      "summary": "A respectful index for proverbs, philosophy, cosmology, traditional knowledge and sourced explanations.",
      "tags": ["wisdom", "proverbs", "philosophy", "knowledge"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    },
    {
      "id": "market-creator-roster",
      "module": "market",
      "title": "Creator and Artisan Roster",
      "kind": "market-space",
      "region": "pan-african",
      "summary": "A local roster for artisans, stylists, musicians, writers, sculptors, books, instruments and cultural goods.",
      "tags": ["market", "artisans", "creators", "community"],
      "source": "starter-metadata",
      "license": "CC0-1.0-metadata",
      "curator": "SevenOS Baobab",
      "confidence": "starter",
      "language": "en",
      "country": "pan-african"
    }
  ]
}
EOF
}

write_seed_catalog() {
  if [[ ! -s "$CONTENT_INDEX" ]]; then
    local tmp
    tmp="$(mktemp "$CONTENT_INDEX.tmp.XXXXXX")"
    seed_catalog_json > "$tmp"
    mv "$tmp" "$CONTENT_INDEX"
  fi
}

safe_pack_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]_.-' '-' | sed 's/^-//;s/-$//'
}

normalize_catalog_metadata() {
  write_seed_catalog
  BAOBAB_CATALOG="$CONTENT_INDEX" python - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["BAOBAB_CATALOG"])
data = json.loads(path.read_text(encoding="utf-8"))
changed = False
for item in data.get("records", []):
    source_pack = item.get("source_pack")
    defaults = {
        "source": "starter-metadata" if not source_pack else "sources/README.md",
        "license": "CC0-1.0-metadata" if not source_pack else "custom-local",
        "curator": "SevenOS Baobab" if not source_pack else source_pack,
        "confidence": "starter" if not source_pack else "draft",
        "language": item.get("language") or "en",
        "country": item.get("country") or ("local" if source_pack else "pan-african"),
        "cultural_protocol": item.get("cultural_protocol") or {
            "sensitivity": "unknown",
            "access": "local-first",
            "protocols": ["CARE", "source-context-consent", "community-review-before-publication"],
            "publication": "draft-local",
        },
    }
    for key, value in defaults.items():
        if not item.get(key):
            item[key] = value
            changed = True
    if item.get("confidence") == "draft":
        tags = item.setdefault("tags", [])
        if isinstance(tags, list) and "needs-source" not in tags:
            tags.append("needs-source")
            changed = True
if changed:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
}

normalize_packs_metadata() {
  mkdir -p "$PACKS_DIR"
  PACKS_DIR="$PACKS_DIR" python - <<'PY'
import json
import os
from pathlib import Path

required_confidence = {"draft", "starter", "low", "medium", "high", "community-validated"}
for pack_file in Path(os.environ["PACKS_DIR"]).glob("*/pack.json"):
    try:
        pack = json.loads(pack_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    changed = False
    pack_name = pack.get("name") or pack_file.parent.name
    for key, value in {
        "schema": "sevenos.baobab.pack.v1",
        "name": pack_name,
        "title": pack_name.replace("-", " ").title(),
        "description": "Local Baobab cultural pack. Add sourced, community-approved records before import.",
        "curator": "local",
        "license": "custom-local",
        "source_notes": "Document sources in sources/ before publishing or sharing.",
        "community_review": "not-reviewed",
    }.items():
        if not pack.get(key):
            pack[key] = value
            changed = True
    for record in pack.get("records", []):
        for key, value in {
            "source": "sources/README.md",
            "license": pack.get("license", "custom-local"),
            "curator": pack.get("curator", "local"),
            "confidence": "draft",
            "language": "und",
            "country": "local",
        }.items():
            if not record.get(key):
                record[key] = value
                changed = True
        if not record.get("cultural_protocol"):
            record["cultural_protocol"] = {
                "sensitivity": "unknown",
                "access": "local-first",
                "protocols": ["CARE", "source-context-consent", "community-review-before-publication"],
                "publication": "draft-local",
            }
            changed = True
        if record.get("confidence") not in required_confidence:
            record["confidence"] = "draft"
            changed = True
        tags = record.setdefault("tags", [])
        if record.get("confidence") == "draft" and isinstance(tags, list) and "needs-source" not in tags:
            tags.append("needs-source")
            changed = True
    if changed:
        pack_file.write_text(json.dumps(pack, indent=2) + "\n", encoding="utf-8")
PY
}

sync_countries() {
  mkdir -p "$(dirname "$COUNTRIES_JSON")"
  AFRICA_TSV="$AFRICA_TSV" COUNTRIES_JSON="$COUNTRIES_JSON" python - <<'PY'
import json
import os
from pathlib import Path

source = Path(os.environ["AFRICA_TSV"])
target = Path(os.environ["COUNTRIES_JSON"])
countries = []
if source.exists():
    for raw in source.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.startswith("#"):
            continue
        parts = raw.split("\t")
        if len(parts) < 4:
            continue
        flag, name, capital, population = parts[:4]
        try:
            population_value = int(population)
        except ValueError:
            population_value = 0
        countries.append({
            "flag": flag,
            "name": name,
            "capital": capital,
            "population": population_value,
            "source": str(source),
            "license": "local-metadata",
            "confidence": "starter",
            "language": "en",
            "country": name,
        })
payload = {
    "schema": "sevenos.baobab.africa-countries.v1",
    "source": str(source),
    "count": len(countries),
    "countries": countries,
}
target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
}

sync_unesco() {
  mkdir -p "$(dirname "$UNESCO_JSON")"
  AFRICA_TSV="$AFRICA_TSV" UNESCO_CSV="$UNESCO_CSV" UNESCO_JSON="$UNESCO_JSON" python - <<'PY'
import csv
import json
import os
from pathlib import Path


def flag_to_alpha2(flag: str) -> str:
    letters = []
    for char in flag.strip():
        code = ord(char)
        if 0x1F1E6 <= code <= 0x1F1FF:
            letters.append(chr(ord("A") + code - 0x1F1E6))
    return "".join(letters)


africa_source = Path(os.environ["AFRICA_TSV"])
unesco_source = Path(os.environ["UNESCO_CSV"])
target = Path(os.environ["UNESCO_JSON"])
country_names = {}
for raw in africa_source.read_text(encoding="utf-8").splitlines():
    if not raw.strip() or raw.startswith("#"):
        continue
    parts = raw.split("\t")
    if len(parts) < 2:
        continue
    code = flag_to_alpha2(parts[0])
    if code:
        country_names[code] = parts[1]

items = []
if unesco_source.exists():
    with unesco_source.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            codes = [part.strip() for part in row.get("Countries", "").replace(";", ",").split(",") if part.strip()]
            african_codes = [code for code in codes if code in country_names]
            if not african_codes:
                continue
            title_en = row.get("Title EN", "").strip()
            title_fr = row.get("Title FR", "").strip()
            description_en = " ".join(row.get("Description EN", "").split())
            description_fr = " ".join(row.get("Description FR", "").split())
            concepts = [part.strip() for part in (row.get("Concepts primary names", "") + "," + row.get("Concept secondary names", "")).split(",") if part.strip()]
            item = {
                "id": f"unesco-ich-{row.get('ICH Public REF', '').strip() or row.get('UUID', '').strip()}",
                "uuid": row.get("UUID", "").strip(),
                "ref": row.get("ICH Public REF", "").strip(),
                "year": row.get("Inscription Year", "").strip(),
                "title_en": title_en,
                "title_fr": title_fr,
                "summary_en": description_en[:640],
                "summary_fr": description_fr[:640],
                "type_en": row.get("Type of element EN", "").strip(),
                "type_fr": row.get("Type of element FR", "").strip(),
                "type_acronym": row.get("Type Acronym", "").strip(),
                "country_codes": african_codes,
                "countries": [country_names[code] for code in african_codes],
                "url_en": row.get("URL EN", "").strip(),
                "url_fr": row.get("URL FR", "").strip(),
                "main_image": row.get("Main image", "").strip(),
                "image_caption_en": row.get("Main Image Caption EN", "").strip(),
                "image_caption_fr": row.get("Main Image Caption FR", "").strip(),
                "image_copyright": row.get("Main Image Copyright", "").strip(),
                "image_author": row.get("Main Image Author", "").strip(),
                "concepts": concepts[:24],
                "source": str(unesco_source),
                "license": "UNESCO metadata; verify media rights before redistribution",
                "curator": "UNESCO ICH / SevenOS Baobab import",
                "confidence": "starter",
                "language": "en,fr",
            }
            items.append(item)

items.sort(key=lambda item: (item.get("countries", [""])[0], item.get("title_en") or item.get("title_fr")))
payload = {
    "schema": "sevenos.baobab.unesco-ich.v1",
    "source": str(unesco_source),
    "filter": "UNESCO ICH rows whose country code intersects identity/countries/africa.tsv",
    "count": len(items),
    "items": items,
}
target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
}

sync_datasets() {
  mkdir -p "$(dirname "$DATASETS_JSON")"
  BAOBAB_DB_DIR="$BAOBAB_DB_DIR" DATASETS_JSON="$DATASETS_JSON" UNESCO_CSV="$UNESCO_CSV" UNESCO_JSON="$UNESCO_JSON" python - <<'PY'
import csv
import json
import os
from pathlib import Path


def inspect_table(path: Path) -> dict:
    suffix = path.suffix.lower()
    info = {
        "name": path.stem,
        "path": str(path),
        "kind": suffix.lstrip(".") or "data",
        "size": path.stat().st_size,
        "rows": 0,
        "fields": [],
        "sample": [],
        "role": "unesco-ich" if path == Path(os.environ["UNESCO_CSV"]) else "source-dataset",
    }
    try:
        if suffix in {".csv", ".tsv"}:
            dialect = "excel-tab" if suffix == ".tsv" else "excel"
            with path.open(encoding="utf-8-sig", newline="") as handle:
                reader = csv.DictReader(handle, dialect=dialect)
                info["fields"] = list(reader.fieldnames or [])
                for index, row in enumerate(reader):
                    if index < 3:
                        info["sample"].append({key: " ".join(row.get(key, "").split())[:160] for key in info["fields"][:10]})
                    info["rows"] += 1
        elif suffix == ".json":
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, list):
                info["rows"] = len(data)
                first = data[0] if data else {}
                info["fields"] = sorted(first.keys()) if isinstance(first, dict) else []
                info["sample"] = data[:3]
            elif isinstance(data, dict):
                list_key = next((key for key, value in data.items() if isinstance(value, list)), "")
                rows = data.get(list_key, []) if list_key else []
                info["rows"] = len(rows) if isinstance(rows, list) else 1
                info["fields"] = sorted(data.keys())
                info["sample"] = rows[:3] if isinstance(rows, list) else [data]
        if info["role"] == "unesco-ich":
            derived = Path(os.environ["UNESCO_JSON"])
            if derived.exists():
                projection = json.loads(derived.read_text(encoding="utf-8"))
                info["derived_african_records"] = projection.get("count", 0)
                info["derived_path"] = str(derived)
    except Exception as exc:
        info["error"] = str(exc)
    return info


source_dir = Path(os.environ["BAOBAB_DB_DIR"])
target = Path(os.environ["DATASETS_JSON"])
sources = []
if source_dir.exists():
    for path in sorted(source_dir.iterdir()):
        if path.is_file() and path.suffix.lower() in {".csv", ".tsv", ".json"}:
            sources.append(inspect_table(path))

payload = {
    "schema": "sevenos.baobab.datasets.v1",
    "source_dir": str(source_dir),
    "count": len(sources),
    "sources": sources,
}
target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
}

sync_languages() {
  mkdir -p "$(dirname "$LANGUAGES_JSON")"
  if [[ -s "$LANGUAGES_SOURCE" ]]; then
    cp "$LANGUAGES_SOURCE" "$LANGUAGES_JSON"
  elif [[ ! -s "$LANGUAGES_JSON" ]]; then
    cat > "$LANGUAGES_JSON" <<'EOF'
{
  "schema": "sevenos.baobab.languages.v1",
  "curation_note": "Starter language metadata for Baobab. Phrases must be verified by local speakers before publication or teaching use.",
  "languages": []
}
EOF
  fi
}

sync_immersions() {
  mkdir -p "$(dirname "$IMMERSIONS_JSON")"
  if [[ -s "$IMMERSIONS_SOURCE" ]]; then
    cp "$IMMERSIONS_SOURCE" "$IMMERSIONS_JSON"
  elif [[ ! -s "$IMMERSIONS_JSON" ]]; then
    cat > "$IMMERSIONS_JSON" <<'EOF'
{
  "schema": "sevenos.baobab.immersions.v1",
  "regions": [],
  "pathways": []
}
EOF
  fi
}

sync_protocols() {
  mkdir -p "$(dirname "$PROTOCOLS_JSON")"
  if [[ -s "$PROTOCOLS_SOURCE" ]]; then
    cp "$PROTOCOLS_SOURCE" "$PROTOCOLS_JSON"
  elif [[ ! -s "$PROTOCOLS_JSON" ]]; then
    cat > "$PROTOCOLS_JSON" <<'EOF'
{
  "schema": "sevenos.baobab.protocols.v1",
  "principles": [],
  "sensitivity_levels": [],
  "workflow": ["source", "context", "rights", "sensitivity", "consent", "community_review", "publication_decision"],
  "default_record_protocol": {
    "sensitivity": "unknown",
    "access": "local-first",
    "protocols": ["source-context-consent"],
    "publication": "draft-local"
  }
}
EOF
  fi
}

print_protocols() {
  bootstrap_baobab >/dev/null
  PROTOCOLS_JSON="$PROTOCOLS_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["PROTOCOLS_JSON"]).read_text(encoding="utf-8"))
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Cultural Protocols")
    print("=========================")
    print("Principles:")
    for item in payload.get("principles", []):
        print(f"- {item.get('title_fr') or item.get('title_en')}: {item.get('body_fr') or item.get('body_en')}")
    print()
    print("Sensitivity levels:")
    for item in payload.get("sensitivity_levels", []):
        print(f"- {item.get('title_fr') or item.get('title_en')} ({item.get('key')}): {item.get('default_action_fr') or item.get('default_action_en')}")
    print()
    print("Workflow: " + " -> ".join(payload.get("workflow", [])))
PY
}

protocol_doctor() {
  bootstrap_baobab >/dev/null
  PACKS_DIR="$PACKS_DIR" PROTOCOLS_JSON="$PROTOCOLS_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
protocols = json.loads(Path(os.environ["PROTOCOLS_JSON"]).read_text(encoding="utf-8"))
valid_sensitivity = {item.get("key") for item in protocols.get("sensitivity_levels", [])}
valid_sensitivity.discard(None)
required_protocol_fields = {"sensitivity", "access", "protocols", "publication"}
reports = []
warnings = 0
errors = 0

for pack_file in sorted(packs_dir.glob("*/pack.json")):
    try:
        pack = json.loads(pack_file.read_text(encoding="utf-8"))
    except Exception as exc:
        reports.append({"name": pack_file.parent.name, "state": "invalid", "errors": [str(exc)], "warnings": []})
        errors += 1
        continue
    pack_warnings = []
    pack_errors = []
    for record in pack.get("records", []):
        rid = record.get("id", "record")
        protocol = record.get("cultural_protocol") or {}
        missing = sorted(field for field in required_protocol_fields if not protocol.get(field))
        if missing:
            pack_warnings.append(f"{rid}: missing cultural protocol fields: {', '.join(missing)}")
        sensitivity = protocol.get("sensitivity", "unknown")
        if sensitivity not in valid_sensitivity:
            pack_errors.append(f"{rid}: invalid sensitivity level: {sensitivity}")
        if sensitivity in {"family", "community", "sacred-restricted", "unknown"} and record.get("confidence") in {"high", "community-validated"} and protocol.get("publication") == "public":
            pack_errors.append(f"{rid}: sensitive record cannot be public by default")
        if sensitivity == "sacred-restricted" and protocol.get("publication") not in {"do-not-publish", "local-protected"}:
            pack_errors.append(f"{rid}: sacred/restricted material must stay protected")
    warnings += len(pack_warnings)
    errors += len(pack_errors)
    reports.append({
        "name": pack.get("name", pack_file.parent.name),
        "path": str(pack_file),
        "records": len(pack.get("records", [])),
        "state": "pass" if not pack_errors else "fail",
        "warnings": pack_warnings,
        "errors": pack_errors,
    })

payload = {
    "schema": "sevenos.baobab.protocol-doctor.v1",
    "state": "pass" if errors == 0 else "fail",
    "score": max(0, 100 - errors * 25 - warnings * 4),
    "protocols": str(Path(os.environ["PROTOCOLS_JSON"])),
    "errors": errors,
    "warnings": warnings,
    "packs": reports,
    "rules": {
        "valid_sensitivity": sorted(valid_sensitivity),
        "required_protocol_fields": sorted(required_protocol_fields),
        "principle": "unknown or sensitive cultural material stays local-first until authority, consent and review are explicit",
    },
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Protocol Doctor")
    print("======================")
    print(f"State: {payload['state']} · Score: {payload['score']}%")
    print(f"Warnings: {warnings} · Errors: {errors}")
    for pack in reports:
        print(f"- {pack['name']}: {pack['state']} ({pack['records']} records)")
        for item in (pack.get("errors") or pack.get("warnings") or [])[:2]:
            print(f"  {item}")
PY
}

validation_kit() {
  evidence_packs >/dev/null
  PACKS_DIR="$PACKS_DIR" VALIDATION_DIR="$VALIDATION_DIR" VALIDATORS_JSON="$VALIDATORS_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
validation_dir = Path(os.environ["VALIDATION_DIR"])
validators_path = Path(os.environ["VALIDATORS_JSON"])
validation_dir.mkdir(parents=True, exist_ok=True)

roles = [
    {"key": "protocol-steward", "title_fr": "Gardien de protocole", "purpose": "Décide du niveau d'accès culturel et de la publication."},
    {"key": "local-speaker", "title_fr": "Locuteur local", "purpose": "Valide langue, orthographe, ton, prononciation et contexte."},
    {"key": "family-reviewer", "title_fr": "Relecteur familial", "purpose": "Valide mémoire familiale, recettes, photos et récits privés."},
    {"key": "creator-or-artisan", "title_fr": "Créateur ou artisan", "purpose": "Valide textiles, objets, photos, styles, crédit et conditions d'usage."},
    {"key": "practitioner", "title_fr": "Praticien", "purpose": "Valide son, instrument, geste, performance ou pratique vivante."},
    {"key": "archivist", "title_fr": "Archiviste / documentaliste", "purpose": "Valide source, provenance, citation, droits et conservation."},
]
if validators_path.exists():
    validators = json.loads(validators_path.read_text(encoding="utf-8"))
else:
    validators = {
        "schema": "sevenos.baobab.validators.v1",
        "updated": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "principle": "A validator is a local authority for a scope; registering a validator is not the same as validating content.",
        "roles": roles,
        "people": [],
    }
    validators_path.write_text(json.dumps(validators, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

created = [str(validators_path)]
requests = []

def roles_for(record):
    module = record.get("module")
    sensitivity = (record.get("cultural_protocol") or {}).get("sensitivity", "unknown")
    result = {"protocol-steward"}
    if module == "languages":
        result.add("local-speaker")
    if module == "food" or sensitivity == "family":
        result.add("family-reviewer")
    if module == "fashion":
        result.add("creator-or-artisan")
    if module == "sound":
        result.add("practitioner")
    if module in {"heritage", "museum", "explore"}:
        result.add("archivist")
    if sensitivity == "sacred-restricted":
        result.update({"protocol-steward", "archivist"})
    return sorted(result)

for pack_file in sorted(packs_dir.glob("*/pack.json")):
    try:
        pack = json.loads(pack_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    pack_dir = pack_file.parent
    pack_validation = pack_dir / "validation"
    attestations = pack_validation / "attestations"
    attestations.mkdir(parents=True, exist_ok=True)
    request = {
        "schema": "sevenos.baobab.validation-request.v1",
        "pack": pack.get("name", pack_dir.name),
        "created": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "pending-community-validation",
        "records": [
            {
                "id": record.get("id"),
                "title": record.get("title"),
                "module": record.get("module"),
                "sensitivity": (record.get("cultural_protocol") or {}).get("sensitivity", "unknown"),
                "publication": (record.get("cultural_protocol") or {}).get("publication", "draft-local"),
                "required_roles": roles_for(record),
                "attestation_file": f"validation/attestations/{record.get('id')}.json",
            }
            for record in pack.get("records", [])
        ],
    }
    request_path = pack_validation / "validation-request.json"
    request_path.write_text(json.dumps(request, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    created.append(str(request_path))
    requests.append(request)

    template = {
        "schema": "sevenos.baobab.community-attestation.v1",
        "record_id": "<record id>",
        "validator": {
            "display_name": "",
            "role": "protocol-steward",
            "community_or_scope": "",
            "contact_optional": "",
        },
        "decision": "pending",
        "allowed_publication": "draft-local",
        "sensitivity": "unknown",
        "statements": {
            "source_reviewed": False,
            "context_reviewed": False,
            "rights_reviewed": False,
            "language_reviewed": False,
            "publication_reviewed": False,
        },
        "notes": "",
        "date": "",
        "local_signature": "",
        "warning": "This template becomes validation only when completed by a real validator with local authority.",
    }
    template_path = attestations / "attestation-template.json"
    template_path.write_text(json.dumps(template, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    created.append(str(template_path))

board = {
    "schema": "sevenos.baobab.validation-board.v1",
    "updated": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "packs": len(requests),
    "requests": sum(len(item.get("records", [])) for item in requests),
    "validators_registered": len(validators.get("people", [])),
    "state": "ready-for-real-validators",
    "next": [
        "Register real validators in validators.json",
        "Complete one attestation JSON per record after review",
        "Run seven baobab validation-doctor",
        "Run seven baobab audit-packs",
    ],
}
board_path = validation_dir / "board.json"
board_path.write_text(json.dumps(board, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
created.append(str(board_path))

payload = {
    "schema": "sevenos.baobab.validation-kit.v1",
    "state": "ready-for-real-validators",
    "validators": str(validators_path),
    "board": str(board_path),
    "created": sorted(set(created)),
    "requests": board["requests"],
    "validators_registered": board["validators_registered"],
    "principle": "Baobab can prepare validation, but only real people with local authority can validate content.",
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab validation kit ready")
    print("===========================")
    print(f"Requests: {payload['requests']} · Validators: {payload['validators_registered']}")
    print("Next: add real validators, complete attestations, run validation-doctor.")
PY
}

validation_doctor() {
  bootstrap_baobab >/dev/null
  PACKS_DIR="$PACKS_DIR" VALIDATORS_JSON="$VALIDATORS_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
validators_path = Path(os.environ["VALIDATORS_JSON"])
validators = json.loads(validators_path.read_text(encoding="utf-8")) if validators_path.exists() else {"people": [], "roles": []}
people = validators.get("people", [])
people_roles = {person.get("role") for person in people if person.get("role")}
reports = []
requests = 0
attestations = 0
valid_attestations = 0
missing_roles = set()

def attestation_valid(payload):
    validator = payload.get("validator") or {}
    statements = payload.get("statements") or {}
    required = ["source_reviewed", "context_reviewed", "rights_reviewed", "publication_reviewed"]
    return (
        payload.get("record_id")
        and validator.get("display_name")
        and validator.get("role")
        and payload.get("decision") in {"validated-local", "validated-community", "do-not-publish", "revise"}
        and payload.get("date")
        and payload.get("local_signature")
        and all(statements.get(key) is True for key in required)
    )

for request_file in sorted(packs_dir.glob("*/validation/validation-request.json")):
    try:
        request = json.loads(request_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    pack_name = request.get("pack", request_file.parents[1].name)
    pack_requests = request.get("records", [])
    requests += len(pack_requests)
    pack_valid = 0
    pack_attestations = 0
    for item in pack_requests:
        for role in item.get("required_roles", []):
            if role not in people_roles:
                missing_roles.add(role)
        attestation_path = request_file.parents[1] / item.get("attestation_file", "")
        if attestation_path.exists() and attestation_path.name != "attestation-template.json":
            try:
                payload = json.loads(attestation_path.read_text(encoding="utf-8"))
            except Exception:
                payload = {}
            pack_attestations += 1
            attestations += 1
            if attestation_valid(payload):
                pack_valid += 1
                valid_attestations += 1
    reports.append({
        "pack": pack_name,
        "requests": len(pack_requests),
        "attestations": pack_attestations,
        "valid_attestations": pack_valid,
        "state": "validated" if pack_requests and pack_valid == len(pack_requests) else "pending",
    })

ready = requests > 0 and validators_path.exists()
payload = {
    "schema": "sevenos.baobab.validation-doctor.v1",
    "state": "ready-with-actions" if ready and valid_attestations < requests else ("validated" if requests and valid_attestations == requests else "not-ready"),
    "workflow_ready": ready,
    "requests": requests,
    "validators_registered": len(people),
    "missing_validator_roles": sorted(missing_roles),
    "attestations": attestations,
    "valid_attestations": valid_attestations,
    "community_validation_score": round((valid_attestations / requests) * 100) if requests else 0,
    "packs": reports,
    "next": [
        "Add real validators to validators.json" if not people else "",
        "Complete attestation JSON files after real review",
        "Run seven baobab audit-packs to reflect validation scores",
    ],
}
payload["next"] = [item for item in payload["next"] if item]
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Validation Doctor")
    print("========================")
    print(f"State: {payload['state']} · Community validation: {payload['community_validation_score']}%")
    print(f"Requests: {requests} · Validators: {len(people)} · Valid attestations: {valid_attestations}")
PY
}

print_immersions() {
  bootstrap_baobab >/dev/null
  IMMERSIONS_JSON="$IMMERSIONS_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["IMMERSIONS_JSON"]).read_text(encoding="utf-8"))
regions = payload.get("regions", [])
pathways = payload.get("pathways", [])
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Immersions")
    print("=================")
    print("Regions:")
    for item in regions:
        countries = ", ".join(item.get("countries", [])[:5])
        print(f"- {item.get('id')}: {item.get('name_fr') or item.get('name_en')}")
        print(f"  {item.get('tone_fr') or item.get('tone_en', '')}")
        print(f"  Pays: {countries}")
    print()
    print("Parcours:")
    for item in pathways:
        print(f"- {item.get('id')}: {item.get('title_fr') or item.get('title_en')}")
PY
}

print_immersion() {
  local query="${1:-}"
  if [[ -z "$query" ]]; then
    log_error "Missing immersion id."
    return 1
  fi
  bootstrap_baobab >/dev/null
  IMMERSIONS_JSON="$IMMERSIONS_JSON" QUERY="$query" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sys
from pathlib import Path

query = os.environ["QUERY"].lower()
payload = json.loads(Path(os.environ["IMMERSIONS_JSON"]).read_text(encoding="utf-8"))
regions = payload.get("regions", [])
matches = [
    item for item in regions
    if query in item.get("id", "").lower()
    or query in item.get("name_fr", "").lower()
    or query in item.get("name_en", "").lower()
    or any(query in country.lower() for country in item.get("countries", []))
]
if not matches:
    print(f"No Baobab immersion match: {query}", file=sys.stderr)
    sys.exit(1)
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps({"schema": "sevenos.baobab.immersion.v1", "query": query, "count": len(matches), "immersions": matches}, indent=2, ensure_ascii=False))
else:
    for item in matches:
        print(item.get("name_fr") or item.get("name_en"))
        print("=" * len(item.get("name_fr") or item.get("name_en") or "Immersion"))
        print(item.get("tone_fr") or item.get("tone_en", ""))
        print("Pays: " + ", ".join(item.get("countries", [])))
        print("Ancres: " + ", ".join(item.get("anchors", [])))
        print("Rituels:")
        for step in item.get("daily_rituals_fr", []):
            print(f"- {step}")
        print()
PY
}

print_ritual() {
  bootstrap_baobab >/dev/null
  IMMERSIONS_JSON="$IMMERSIONS_JSON" BAOBAB_NATIVE_SETTINGS="$BAOBAB_NATIVE_SETTINGS" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from datetime import date
from pathlib import Path

immersions = json.loads(Path(os.environ["IMMERSIONS_JSON"]).read_text(encoding="utf-8"))
settings_path = Path(os.environ["BAOBAB_NATIVE_SETTINGS"])
settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
regions = immersions.get("regions", [])
focus_id = settings.get("immersion_focus") or (regions[0].get("id") if regions else "")
region = next((item for item in regions if item.get("id") == focus_id), regions[0] if regions else {})
rituals = region.get("daily_rituals_fr") or region.get("daily_rituals_en") or ["Choisir un pays, lire une fiche et créer une note en brouillon."]
ritual = rituals[date.today().toordinal() % len(rituals)]
payload = {
    "schema": "sevenos.baobab.ritual.v1",
    "date": date.today().isoformat(),
    "immersion": region,
    "country_focus": settings.get("country_focus", ""),
    "ritual": ritual,
    "suggested_commands": [
        "seven baobab native --view immersions",
        f"seven baobab immersion {region.get('id', 'sahel')}",
        "seven baobab native --view collect",
    ],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Ritual")
    print("=============")
    print(f"Date: {payload['date']}")
    print(f"Immersion: {region.get('name_fr') or region.get('name_en') or 'Baobab'}")
    if payload["country_focus"]:
        print(f"Pays focus: {payload['country_focus']}")
    print(f"Rituel: {ritual}")
    print()
    print("Commandes:")
    for command in payload["suggested_commands"]:
        print(f"- {command}")
PY
}

print_journal() {
  bootstrap_baobab >/dev/null
  JOURNAL_DIR="$BAOBAB_WORKSPACE/Rituels du jour" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from datetime import datetime
from pathlib import Path

folder = Path(os.environ["JOURNAL_DIR"])
notes = []
if folder.exists():
    for path in sorted(folder.glob("*.md"), key=lambda item: item.stat().st_mtime, reverse=True):
        preview = []
        try:
            for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
                text = line.strip()
                if text and not text.startswith("#"):
                    preview.append(text)
                if len(preview) >= 3:
                    break
        except OSError:
            preview = []
        notes.append({
            "name": path.name,
            "path": str(path),
            "modified": datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
            "size": path.stat().st_size,
            "preview": preview,
        })
payload = {
    "schema": "sevenos.baobab.journal.v1",
    "folder": str(folder),
    "count": len(notes),
    "notes": notes,
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Journal")
    print("==============")
    print(f"Dossier: {folder}")
    print(f"Notes: {len(notes)}")
    if not notes:
        print()
        print("Aucune note rituelle pour l'instant.")
        print("Créez-en une depuis la vue native Journal ou avec le rituel du jour.")
        print("Commandes utiles:")
        print("- seven baobab ritual")
        print("- seven baobab native --view journal")
    else:
        for item in notes[:20]:
            print(f"- {item['name']} · {item['modified']}")
            for line in item.get("preview", [])[:2]:
                print(f"  {line}")
PY
}

print_route() {
  bootstrap_baobab >/dev/null
  IMMERSIONS_JSON="$IMMERSIONS_JSON" BAOBAB_NATIVE_SETTINGS="$BAOBAB_NATIVE_SETTINGS" JOURNAL_DIR="$BAOBAB_WORKSPACE/Rituels du jour" BAOBAB_DATA="$BAOBAB_DATA" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from datetime import date
from pathlib import Path

immersions = json.loads(Path(os.environ["IMMERSIONS_JSON"]).read_text(encoding="utf-8"))
settings_path = Path(os.environ["BAOBAB_NATIVE_SETTINGS"])
settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
regions = immersions.get("regions", [])
focus_id = settings.get("immersion_focus") or (regions[0].get("id") if regions else "")
active = next((item for item in regions if item.get("id") == focus_id), regions[0] if regions else {})
country = settings.get("country_focus", "")
journal_dir = Path(os.environ["JOURNAL_DIR"])
today_note = next(iter(sorted(journal_dir.glob(f"{date.today().isoformat()}-rituel-baobab*.md"))), None) if journal_dir.exists() else None
data = Path(os.environ["BAOBAB_DATA"])
datasets_path = data / "offline/datasets.json"
packs_path = data / "packs/manifest.json"
datasets = json.loads(datasets_path.read_text(encoding="utf-8")) if datasets_path.exists() else {"sources": []}
packs = json.loads(packs_path.read_text(encoding="utf-8")) if packs_path.exists() else {"packs": []}
steps = [
    {"label": "Immersion choisie", "done": bool(active), "value": active.get("name_fr") or active.get("name_en") or "Baobab"},
    {"label": "Pays focus", "done": bool(country), "value": country or "a choisir"},
    {"label": "Note du jour", "done": today_note is not None, "value": str(today_note) if today_note else "non creee"},
    {"label": "Sources locales", "done": bool(datasets.get("sources")), "value": f"{len(datasets.get('sources', []))} source(s)"},
    {"label": "Packs culturels", "done": bool(packs.get("packs")), "value": f"{len(packs.get('packs', []))} pack(s)"},
]
done = sum(1 for item in steps if item["done"])
payload = {
    "schema": "sevenos.baobab.route.v1",
    "date": date.today().isoformat(),
    "score": round(done / max(len(steps), 1) * 100),
    "done": done,
    "total": len(steps),
    "immersion": active,
    "country_focus": country,
    "today_note": str(today_note) if today_note else "",
    "steps": steps,
    "suggested_commands": [
        "seven baobab native --view immersions",
        "seven baobab native --view journal",
        "seven baobab native --view collect",
    ],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Route")
    print("============")
    print(f"Progression: {done}/{len(steps)} ({payload['score']}%)")
    print(f"Immersion: {payload['immersion'].get('name_fr') or payload['immersion'].get('name_en') or 'Baobab'}")
    if country:
        print(f"Pays focus: {country}")
    print()
    for item in steps:
        marker = "OK" if item["done"] else ".."
        print(f"[{marker}] {item['label']}: {item['value']}")
    print()
    print("Commandes:")
    for command in payload["suggested_commands"]:
        print(f"- {command}")
PY
}

print_ambiance() {
  bootstrap_baobab >/dev/null
  local requested="${1:-}"
  BAOBAB_NATIVE_SETTINGS="$BAOBAB_NATIVE_SETTINGS" REQUESTED="$requested" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sys
from pathlib import Path

settings_path = Path(os.environ["BAOBAB_NATIVE_SETTINGS"])
settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
modes = {
    "calme": {
        "label": "Calme",
        "subtitle": "lecture, écoute douce et mémoire personnelle",
        "waybar": "Calme · mémoire",
        "accent": "#8baa7b",
        "workspace_hint": "Racines",
        "actions": ["seven baobab native --view heritage", "seven baobab native --view journal"],
    },
    "apprentissage": {
        "label": "Apprentissage",
        "subtitle": "langues, patrimoine, parcours et transmission",
        "waybar": "Apprendre · transmettre",
        "accent": "#6aaed6",
        "workspace_hint": "Mémoire",
        "actions": ["seven baobab native --view languages", "seven baobab native --view immersions"],
    },
    "terrain": {
        "label": "Terrain",
        "subtitle": "collecte, source, consentement et relecture locale",
        "waybar": "Terrain · collecte",
        "accent": "#c89b63",
        "workspace_hint": "Terrain",
        "actions": ["seven baobab native --view collect", "seven baobab native --view packs"],
    },
    "scene": {
        "label": "Scène",
        "subtitle": "son, récit, musée, création et présentation",
        "waybar": "Scène · création",
        "accent": "#b78fe8",
        "workspace_hint": "Scène",
        "actions": ["seven baobab sound", "seven baobab native --view story"],
    },
}
requested = os.environ.get("REQUESTED", "").strip().lower()
changed = False
if requested:
    aliases = {"apprendre": "apprentissage", "learning": "apprentissage", "field": "terrain", "collecte": "terrain", "stage": "scene", "scène": "scene", "sound": "scene", "quiet": "calme"}
    requested = aliases.get(requested, requested)
    if requested not in modes:
        print(f"Unknown Baobab ambiance: {requested}", file=sys.stderr)
        sys.exit(2)
    settings["ambiance"] = requested
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings_path.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    changed = True
current = settings.get("ambiance", "calme")
if current not in modes:
    current = "calme"
mode = modes[current]
payload = {
    "schema": "sevenos.baobab.ambiance.v1",
    "state": "updated" if changed else "ready",
    "current": current,
    "label": mode["label"],
    "subtitle": mode["subtitle"],
    "waybar": mode["waybar"],
    "accent": mode["accent"],
    "workspace_hint": mode["workspace_hint"],
    "actions": mode["actions"],
    "modes": modes,
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Ambiance")
    print("================")
    print(f"Mode: {mode['label']}")
    print(mode["subtitle"])
    print(f"Workspace conseillé: {mode['workspace_hint']}")
    print()
    print("Modes disponibles:")
    for key, item in modes.items():
        marker = "*" if key == current else "-"
        print(f"{marker} {key}: {item['subtitle']}")
PY
}

print_compass() {
  bootstrap_baobab >/dev/null
  IMMERSIONS_JSON="$IMMERSIONS_JSON" BAOBAB_NATIVE_SETTINGS="$BAOBAB_NATIVE_SETTINGS" JOURNAL_DIR="$BAOBAB_WORKSPACE/Rituels du jour" BAOBAB_DATA="$BAOBAB_DATA" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from datetime import date
from pathlib import Path

settings_path = Path(os.environ["BAOBAB_NATIVE_SETTINGS"])
settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
immersions_path = Path(os.environ["IMMERSIONS_JSON"])
immersions = json.loads(immersions_path.read_text(encoding="utf-8")) if immersions_path.exists() else {"regions": []}
regions = immersions.get("regions", [])
focus_id = settings.get("immersion_focus") or (regions[0].get("id") if regions else "")
region = next((item for item in regions if item.get("id") == focus_id), regions[0] if regions else {})
country = settings.get("country_focus", "")
journal_dir = Path(os.environ["JOURNAL_DIR"])
today_note = next(iter(sorted(journal_dir.glob(f"{date.today().isoformat()}-rituel-baobab*.md"))), None) if journal_dir.exists() else None
packs_manifest = Path(os.environ["BAOBAB_DATA"]) / "packs/manifest.json"
packs = json.loads(packs_manifest.read_text(encoding="utf-8")) if packs_manifest.exists() else {"packs": []}
ambiance = settings.get("ambiance", "calme")
directions = [
    {
        "key": "comprendre",
        "title": "Comprendre",
        "body": "Lire le contexte avant de classer ou transmettre.",
        "state": "ready" if region else "todo",
        "command": "seven baobab native --view immersions",
    },
    {
        "key": "relier",
        "title": "Relier",
        "body": "Associer pays, langue, son, geste et source.",
        "state": "ready" if country else "todo",
        "command": "seven baobab native --view explore",
    },
    {
        "key": "ecouter",
        "title": "Écouter",
        "body": "Passer par le son, la voix ou la lecture lente.",
        "state": "ready",
        "command": "seven baobab sound",
    },
    {
        "key": "collecter",
        "title": "Collecter",
        "body": "Créer un brouillon, jamais une vérité publique immédiate.",
        "state": "ready" if today_note else "todo",
        "command": "seven baobab native --view collect",
    },
    {
        "key": "sourcer",
        "title": "Sourcer",
        "body": "Documenter provenance, personne ressource, droits et contexte.",
        "state": "ready" if packs.get("packs") else "todo",
        "command": "seven baobab native --view packs",
    },
    {
        "key": "preserver",
        "title": "Préserver",
        "body": "Garder les contenus local-first, lisibles et exportables.",
        "state": "ready",
        "command": "seven baobab native --view datasets",
    },
    {
        "key": "transmettre",
        "title": "Transmettre",
        "body": "Partager seulement après consentement et relecture locale.",
        "state": "guided",
        "command": "seven baobab native --view story",
    },
]
priority_by_ambiance = {
    "calme": "comprendre",
    "apprentissage": "transmettre",
    "terrain": "collecter",
    "scene": "ecouter",
}
priority = priority_by_ambiance.get(ambiance, "comprendre")
next_item = next((item for item in directions if item["key"] == priority), directions[0])
payload = {
    "schema": "sevenos.baobab.compass.v1",
    "date": date.today().isoformat(),
    "ambiance": ambiance,
    "immersion": region,
    "country_focus": country,
    "today_note": str(today_note) if today_note else "",
    "directions": directions,
    "next": next_item,
    "principles": [
        "source before sharing",
        "draft before publication",
        "community review before authority",
        "local-first before cloud",
        "context before aesthetics",
    ],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Compass")
    print("==============")
    print(f"Ambiance: {ambiance}")
    print(f"Immersion: {region.get('name_fr') or region.get('name_en') or 'Baobab'}")
    if country:
        print(f"Pays focus: {country}")
    print(f"Prochain geste: {next_item['title']} · {next_item['body']}")
    print()
    for item in directions:
        marker = "OK" if item["state"] == "ready" else ".." if item["state"] == "todo" else "->"
        print(f"[{marker}] {item['title']}: {item['body']}")
    print()
    print("Principes:")
    for principle in payload["principles"]:
        print(f"- {principle}")
PY
}

print_today() {
  bootstrap_baobab >/dev/null
  IMMERSIONS_JSON="$IMMERSIONS_JSON" BAOBAB_NATIVE_SETTINGS="$BAOBAB_NATIVE_SETTINGS" JOURNAL_DIR="$BAOBAB_WORKSPACE/Rituels du jour" BAOBAB_DATA="$BAOBAB_DATA" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from datetime import date
from pathlib import Path

settings_path = Path(os.environ["BAOBAB_NATIVE_SETTINGS"])
settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
immersions_path = Path(os.environ["IMMERSIONS_JSON"])
immersions = json.loads(immersions_path.read_text(encoding="utf-8")) if immersions_path.exists() else {"regions": []}
regions = immersions.get("regions", [])
focus_id = settings.get("immersion_focus") or (regions[0].get("id") if regions else "")
region = next((item for item in regions if item.get("id") == focus_id), regions[0] if regions else {})
rituals = region.get("daily_rituals_fr") or region.get("daily_rituals_en") or ["Choisir un pays, lire une fiche et créer une note en brouillon."]
ritual = rituals[date.today().toordinal() % len(rituals)]
country = settings.get("country_focus", "")
journal_dir = Path(os.environ["JOURNAL_DIR"])
today_note = next(iter(sorted(journal_dir.glob(f"{date.today().isoformat()}-rituel-baobab*.md"))), None) if journal_dir.exists() else None
data = Path(os.environ["BAOBAB_DATA"])
datasets = json.loads((data / "offline/datasets.json").read_text(encoding="utf-8")) if (data / "offline/datasets.json").exists() else {"sources": []}
packs = json.loads((data / "packs/manifest.json").read_text(encoding="utf-8")) if (data / "packs/manifest.json").exists() else {"packs": []}
steps = [
    {"label": "Immersion choisie", "done": bool(region), "value": region.get("name_fr") or region.get("name_en") or "Baobab"},
    {"label": "Pays focus", "done": bool(country), "value": country or "à choisir"},
    {"label": "Note du jour", "done": today_note is not None, "value": str(today_note) if today_note else "non créée"},
    {"label": "Sources locales", "done": bool(datasets.get("sources")), "value": f"{len(datasets.get('sources', []))} source(s)"},
    {"label": "Packs culturels", "done": bool(packs.get("packs")), "value": f"{len(packs.get('packs', []))} pack(s)"},
]
done = sum(1 for item in steps if item["done"])
route_score = round(done / max(len(steps), 1) * 100)
ambiance = settings.get("ambiance", "calme")
compass_next = {
    "calme": ("Comprendre", "Lire le contexte avant de classer ou transmettre.", "seven baobab native --view immersions"),
    "apprentissage": ("Transmettre", "Partager un parcours d'apprentissage avec contexte et prudence.", "seven baobab native --view languages"),
    "terrain": ("Collecter", "Créer un brouillon avec source, droits et consentement.", "seven baobab native --view collect"),
    "scene": ("Écouter", "Passer par le son, le récit, la scène ou le musée.", "seven baobab sound"),
}.get(ambiance, ("Comprendre", "Lire le contexte avant de classer ou transmettre.", "seven baobab native --view immersions"))
if not country:
    compass_next = ("Relier", "Choisir un pays focus pour relier territoire, langue, son et source.", "seven baobab native --view explore")
elif today_note is None:
    compass_next = ("Collecter", "Créer la note du jour comme brouillon local.", "seven baobab native --view journal")
payload = {
    "schema": "sevenos.baobab.today.v1",
    "date": date.today().isoformat(),
    "ambiance": ambiance,
    "immersion": region,
    "country_focus": country,
    "ritual": ritual,
    "today_note": str(today_note) if today_note else "",
    "route": {"score": route_score, "done": done, "total": len(steps), "steps": steps},
    "next": {"title": compass_next[0], "body": compass_next[1], "command": compass_next[2]},
    "quick_actions": [
        {"title": "Créer la note", "command": "seven baobab native --view journal"},
        {"title": "Explorer", "command": "seven baobab native --view explore"},
        {"title": "Collecter", "command": "seven baobab native --view collect"},
        {"title": "Écouter", "command": "seven baobab sound"},
    ],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Aujourd'hui")
    print("==================")
    print(f"Date: {payload['date']}")
    print(f"Ambiance: {ambiance}")
    print(f"Immersion: {region.get('name_fr') or region.get('name_en') or 'Baobab'}")
    if country:
        print(f"Pays focus: {country}")
    print(f"Rituel: {ritual}")
    print(f"Route: {done}/{len(steps)} ({route_score}%)")
    print(f"Prochain geste: {compass_next[0]} · {compass_next[1]}")
    print()
    print("Actions:")
    for item in payload["quick_actions"]:
        print(f"- {item['title']}: {item['command']}")
PY
}

print_session() {
  bootstrap_baobab >/dev/null
  IMMERSIONS_JSON="$IMMERSIONS_JSON" BAOBAB_NATIVE_SETTINGS="$BAOBAB_NATIVE_SETTINGS" BAOBAB_TRAIL="$BAOBAB_TRAIL" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from datetime import date
from pathlib import Path

settings_path = Path(os.environ["BAOBAB_NATIVE_SETTINGS"])
settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
immersions_path = Path(os.environ["IMMERSIONS_JSON"])
immersions = json.loads(immersions_path.read_text(encoding="utf-8")) if immersions_path.exists() else {"regions": []}
regions = immersions.get("regions", [])
focus_id = settings.get("immersion_focus") or (regions[0].get("id") if regions else "")
region = next((item for item in regions if item.get("id") == focus_id), regions[0] if regions else {})
ambiance = settings.get("ambiance", "calme")
country = settings.get("country_focus", "")
trail_path = Path(os.environ["BAOBAB_TRAIL"])
trail_count = 0
if trail_path.exists():
    trail_count = sum(1 for line in trail_path.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip())

templates = {
    "calme": {
        "title": "Séance calme",
        "duration": 24,
        "intent": "Lire lentement, écouter sans surcharge et garder une trace personnelle.",
        "phases": [
            ("Ouverture", 3, "Respirer, regarder l'immersion active et choisir une intention.", "seven baobab native --view entry"),
            ("Lecture", 8, "Lire une fiche patrimoine ou une immersion sans changer de contexte.", "seven baobab native --view heritage"),
            ("Écoute", 5, "Écouter un son local ou ouvrir le module Sound.", "seven baobab sound"),
            ("Trace", 5, "Ajouter un mémo court ou créer la note rituelle.", "seven baobab native --view trail"),
            ("Clôture", 3, "Relire la boussole avant de partager ou d'archiver.", "seven baobab native --view compass"),
        ],
    },
    "apprentissage": {
        "title": "Séance d'apprentissage",
        "duration": 32,
        "intent": "Relier langue, pays, patrimoine et transmission claire.",
        "phases": [
            ("Orientation", 4, "Choisir l'immersion et le pays focus.", "seven baobab native --view immersions"),
            ("Langues", 8, "Explorer une langue, un mot ou une expression.", "seven baobab native --view languages"),
            ("Patrimoine", 8, "Lire un contenu sourcé lié au pays ou à la région.", "seven baobab native --view heritage"),
            ("Synthèse", 8, "Créer une trace ou une note pédagogique.", "seven baobab native --view trail"),
            ("Transmission", 4, "Vérifier contexte, source et prudence.", "seven baobab native --view compass"),
        ],
    },
    "terrain": {
        "title": "Séance terrain",
        "duration": 36,
        "intent": "Préparer une collecte responsable avec source, accord et relecture.",
        "phases": [
            ("Préparation", 5, "Définir pays, personne ressource, source ou sujet.", "seven baobab native --view explore"),
            ("Brouillon", 10, "Créer une collecte sans prétendre à une vérité publique.", "seven baobab native --view collect"),
            ("Consentement", 7, "Vérifier droits, accord, contexte et limites.", "seven baobab native --view packs"),
            ("Trace", 7, "Ajouter un mémo local sur ce qui reste à vérifier.", "seven baobab native --view trail"),
            ("Relecture", 7, "Passer par la boussole et préparer la suite.", "seven baobab native --view compass"),
        ],
    },
    "scene": {
        "title": "Séance scène",
        "duration": 30,
        "intent": "Écouter, raconter, créer et présenter sans perdre le contexte.",
        "phases": [
            ("Accordage", 4, "Choisir un son, un récit ou une scène.", "seven baobab sound"),
            ("Récit", 8, "Lire ou préparer une histoire contextualisée.", "seven baobab native --view story"),
            ("Objet", 6, "Relier le récit à un objet, une image ou une archive.", "seven baobab native --view museum"),
            ("Création", 8, "Créer une trace, un texte, un croquis ou un plan.", "seven baobab native --view trail"),
            ("Partage prudent", 4, "Vérifier source, consentement et public visé.", "seven baobab native --view compass"),
        ],
    },
}
session = templates.get(ambiance, templates["calme"])
phases = [
    {"title": title, "minutes": minutes, "body": body, "command": command}
    for title, minutes, body, command in session["phases"]
]
payload = {
    "schema": "sevenos.baobab.session.v1",
    "date": date.today().isoformat(),
    "ambiance": ambiance,
    "title": session["title"],
    "duration_minutes": session["duration"],
    "intent": session["intent"],
    "immersion": region,
    "country_focus": country,
    "trail_count": trail_count,
    "phases": phases,
    "start_command": "seven baobab native --view session",
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print(payload["title"])
    print("=" * len(payload["title"]))
    print(f"Durée: {payload['duration_minutes']} min")
    print(f"Ambiance: {ambiance}")
    print(f"Immersion: {region.get('name_fr') or region.get('name_en') or 'Baobab'}")
    if country:
        print(f"Pays focus: {country}")
    print(payload["intent"])
    print()
    for item in phases:
        print(f"- {item['title']} · {item['minutes']} min")
        print(f"  {item['body']}")
        print(f"  {item['command']}")
PY
}

append_trail_event() {
  local kind="${1:-note}"
  local title="${2:-Trace Baobab}"
  local body="${3:-}"
  mkdir -p "$(dirname "$BAOBAB_TRAIL")"
  BAOBAB_TRAIL="$BAOBAB_TRAIL" KIND="$kind" TITLE="$title" BODY="$body" BAOBAB_NATIVE_SETTINGS="$BAOBAB_NATIVE_SETTINGS" python - <<'PY'
import json
import os
from datetime import datetime
from pathlib import Path

trail = Path(os.environ["BAOBAB_TRAIL"])
settings_path = Path(os.environ["BAOBAB_NATIVE_SETTINGS"])
settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
event = {
    "schema": "sevenos.baobab.trail.event.v1",
    "time": datetime.now().isoformat(timespec="seconds"),
    "kind": os.environ.get("KIND", "note"),
    "title": os.environ.get("TITLE", "Trace Baobab"),
    "body": os.environ.get("BODY", ""),
    "ambiance": settings.get("ambiance", "calme"),
    "immersion_focus": settings.get("immersion_focus", ""),
    "country_focus": settings.get("country_focus", ""),
}
trail.parent.mkdir(parents=True, exist_ok=True)
with trail.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(event, ensure_ascii=False) + "\n")
PY
}

print_trail() {
  bootstrap_baobab >/dev/null
  BAOBAB_TRAIL="$BAOBAB_TRAIL" BAOBAB_WORKSPACE="$BAOBAB_WORKSPACE" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

trail = Path(os.environ["BAOBAB_TRAIL"])
events = []
if trail.exists():
    for line in trail.read_text(encoding="utf-8", errors="ignore").splitlines():
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            events.append(item)
events = events[-80:]
payload = {
    "schema": "sevenos.baobab.trail.v1",
    "state": "ready",
    "path": str(trail),
    "workspace": os.environ["BAOBAB_WORKSPACE"],
    "count": len(events),
    "events": list(reversed(events[-24:])),
    "suggested_commands": [
        "seven baobab remember J'ai écouté une archive orale",
        "seven baobab native --view trail",
        "seven baobab journal",
    ],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Trace")
    print("============")
    print(f"Journal local: {trail}")
    print(f"Événements: {len(events)}")
    if not events:
        print()
        print("Aucune trace pour l'instant.")
        print("Ajoutez une trace avec: seven baobab remember J'ai lu une fiche sur le balafon")
    for item in payload["events"][:20]:
        body = item.get("body", "")
        suffix = f" · {body}" if body else ""
        print(f"- {item.get('time', '')} · {item.get('title', 'Trace')}{suffix}")
PY
}

remember_trail() {
  local body="${1:-}"
  if [[ -z "$body" ]]; then
    log_error "Usage: seven baobab remember TEXT"
    return 2
  fi
  append_trail_event "memoire" "Mémoire ajoutée" "$body"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    print_trail
  else
    printf 'Trace Baobab ajoutée.\n'
    printf 'Voir: seven baobab trail\n'
  fi
}

print_shell() {
  bootstrap_baobab >/dev/null
  BAOBAB_CONFIG="$BAOBAB_CONFIG" BAOBAB_BIN="$BAOBAB_BIN" BAOBAB_APP_MANIFEST="$BAOBAB_APP_MANIFEST" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

config = Path(os.environ["BAOBAB_CONFIG"])
shell_path = config / "shell/baobab-shell.json"
waybar_config = config / "waybar/config.jsonc"
waybar_style = config / "waybar/style.css"
apps_path = Path(os.environ["BAOBAB_APP_MANIFEST"])
apps = []
app_state = "ready"
if apps_path.exists():
    try:
        apps = json.loads(apps_path.read_text(encoding="utf-8")).get("apps", [])
    except Exception as exc:
        app_state = f"manifest-refreshing: {exc}"
payload = {
    "schema": "sevenos.baobab.shell.status.v1",
    "state": "ready" if shell_path.exists() and waybar_config.exists() and waybar_style.exists() else "attention",
    "surface": "espace d'immersion culturelle",
    "waybar": {
        "launcher": str(Path(os.environ["BAOBAB_BIN"]) / "baobab-waybar"),
        "config": str(waybar_config),
        "style": str(waybar_style),
        "modules": ["Baobab Today", "Entrée", "Boussole", "Rituel", "Carnet de route", "Sessions", "Ambiance", "Trace", "Sound", "Langue", "IA locale"],
    },
    "launchpad": {
        "filter": "baobab",
        "category": "Culture",
    },
    "hyprland": {
        "profile": "hyprland/lua/profiles/baobab.lua",
        "workspaces": ["Racines", "Mémoire", "Scène", "Terrain"],
    },
    "apps_state": app_state,
    "apps": apps,
    "commands": {
        "open": "seven baobab open",
        "entry": "seven baobab native --view entry",
        "veillee": "seven baobab native --view veillee",
        "today": "seven baobab today",
        "session": "seven baobab session",
        "sessions": "seven baobab native --view sessions",
        "carnet": "seven baobab native --view carnet",
        "constellation": "seven baobab native --view constellation",
        "media": "seven baobab native --view media",
        "waybar": str(Path(os.environ["BAOBAB_BIN"]) / "baobab-waybar"),
        "launchpad": "seven-apps",
        "route": "seven baobab route",
        "ritual": "seven baobab ritual",
        "ambiance": "seven baobab ambiance",
        "compass": "seven baobab compass",
        "trail": "seven baobab trail",
        "remember": "seven baobab remember Texte de mémoire",
    },
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Shell")
    print("============")
    print(f"État: {payload['state']}")
    print("Surface: espace d'immersion culturelle")
    print(f"Waybar: {payload['waybar']['launcher']}")
    print("Modules: " + ", ".join(payload["waybar"]["modules"]))
    print("Launchpad: filtre Baobab")
    print("Workspaces: " + ", ".join(payload["hyprland"]["workspaces"]))
    print("Apps dédiées:")
    for app in payload["apps"]:
        print(f"- {app.get('title')}: {app.get('command')}")
PY
}

write_baobab_profile_configs() {
  mkdir -p \
    "$BAOBAB_CONFIG"/{bin,fonts,mpv,waybar,eww,meilisearch,ollama,piper,argos,syncthing,kolibri,kiwix,services,shell,soundscape,store} \
    "$BAOBAB_DESKTOP_DIR" \
    "$BAOBAB_DATA"/{sound,ai-memory} \
    "$BAOBAB_PROFILE_DATA"/{objects,exports,meilisearch,ollama/models,piper/voices,argos/packages,kolibri,node} \
    "$BAOBAB_PROFILE_CACHE"/{thumbnails,search,audio,meilisearch,ollama,piper,argos} \
    "$BAOBAB_PROFILE_CONFIG/config-root/fontconfig/conf.d" \
    "$BAOBAB_PROFILE_DATA/data-root" \
    "$BAOBAB_PROFILE_CACHE/cache-root"

  cat > "$BAOBAB_ENV" <<EOF
# SevenOS Baobab profile-owned runtime environment
SEVENOS_ACTIVE_PROFILE=baobab
SEVENOS_BAOBAB_CONFIG=$BAOBAB_CONFIG
SEVENOS_BAOBAB_DATA=$BAOBAB_DATA
SEVENOS_BAOBAB_CACHE=$BAOBAB_CACHE
SEVENOS_BAOBAB_WORKSPACE=$BAOBAB_WORKSPACE
XDG_CONFIG_HOME=$BAOBAB_PROFILE_CONFIG/config-root
XDG_DATA_HOME=$BAOBAB_PROFILE_DATA/data-root
XDG_CACHE_HOME=$BAOBAB_PROFILE_CACHE/cache-root
BAOBAB_NODE=$BAOBAB_NODE
MPV_HOME=$BAOBAB_CONFIG/mpv
MEILI_DB_PATH=$BAOBAB_PROFILE_DATA/meilisearch
OLLAMA_MODELS=$BAOBAB_PROFILE_DATA/ollama/models
PIPER_VOICE_DIR=$BAOBAB_PROFILE_DATA/piper/voices
ARGOS_PACKAGES_DIR=$BAOBAB_PROFILE_DATA/argos/packages
KOLIBRI_HOME=$BAOBAB_PROFILE_DATA/kolibri
SYNCTHING_HOME=$BAOBAB_CONFIG/syncthing
PATH=$BAOBAB_BIN:\$PATH
EOF

  cat > "$BAOBAB_CONFIG/fonts/fonts.conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Symbols</family>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Sans</family>
    </prefer>
  </alias>
  <alias>
    <family>Baobab Sans</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Symbols</family>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
</fontconfig>
EOF
  cp "$BAOBAB_CONFIG/fonts/fonts.conf" "$BAOBAB_PROFILE_CONFIG/config-root/fontconfig/conf.d/70-baobab-fonts.conf"

  cat > "$BAOBAB_BIN/baobab-run" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
source "$BAOBAB_ENV"
exec "\$@"
EOF

  cat > "$BAOBAB_BIN/baobab-sound" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
source "$BAOBAB_ENV"
library="\${1:-$BAOBAB_WORKSPACE/Sound}"
mkdir -p "\$library" "$BAOBAB_DATA/sound"
if ! command -v mpv >/dev/null 2>&1; then
  printf 'Baobab Sound requires mpv.\\n' >&2
  exit 127
fi
mapfile -t files < <(find "\$library" "$BAOBAB_DATA/sound" -maxdepth 1 -type f \\( -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.flac' -o -iname '*.wav' -o -iname '*.m4a' -o -iname '*.opus' \\) 2>/dev/null | sort)
if [[ "\${#files[@]}" -eq 0 ]]; then
  printf 'Baobab Sound library: %s\\n' "\$library"
  printf 'Add local audio files to this folder.\\n'
  exit 0
fi
exec mpv --config-dir="$BAOBAB_CONFIG/mpv" "\${files[@]}"
EOF

  cat > "$BAOBAB_BIN/baobab-searchd" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
source "$BAOBAB_ENV"
if ! command -v meilisearch >/dev/null 2>&1; then
  printf 'Meilisearch is not available.\\n' >&2
  exit 127
fi
exec meilisearch --config-file-path "$BAOBAB_CONFIG/meilisearch/config.toml"
EOF

  cat > "$BAOBAB_BIN/baobab-ai" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
source "$BAOBAB_ENV"
if ! command -v ollama >/dev/null 2>&1; then
  printf 'Ollama is not available.\\n' >&2
  exit 127
fi
exec ollama "\$@"
EOF

  cat > "$BAOBAB_BIN/baobab-narrate" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
source "$BAOBAB_ENV"
model="\${SEVENOS_BAOBAB_PIPER_MODEL:-}"
piper_bin=""
if command -v piper >/dev/null 2>&1; then
  piper_bin="$(command -v piper)"
elif [[ -x /opt/piper-tts/piper ]]; then
  piper_bin="/opt/piper-tts/piper"
fi
if [[ -n "\$piper_bin" && -n "\$model" ]]; then
  exec "\$piper_bin" --model "\$model" "\$@"
fi
if command -v espeak-ng >/dev/null 2>&1; then
  exec espeak-ng -v fr "\$@"
fi
printf 'No Baobab narration engine is available. Install Piper or espeak-ng.\\n' >&2
exit 127
EOF

  cat > "$BAOBAB_BIN/baobab-widget" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
source "$BAOBAB_ENV"
if ! command -v eww >/dev/null 2>&1; then
  printf 'Eww is not available.\\n' >&2
  exit 127
fi
exec eww --force-wayland -c "$BAOBAB_CONFIG/eww" open "\${1:-baobab-memory}"
EOF

  cat > "$BAOBAB_BIN/baobab-waybar" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
source "$BAOBAB_ENV"
if ! command -v waybar >/dev/null 2>&1; then
  printf 'Waybar is not available.\\n' >&2
  exit 127
fi
exec waybar -c "$BAOBAB_CONFIG/waybar/config.jsonc" -s "$BAOBAB_CONFIG/waybar/style.css"
EOF

  chmod +x "$BAOBAB_BIN"/baobab-{run,sound,searchd,ai,narrate,widget,waybar}

  cat > "$BAOBAB_CONFIG/mpv/mpv.conf" <<'EOF'
# Baobab Sound - profile-owned MPV config
profile=baobab
save-position-on-quit=yes
resume-playback=yes
volume=70
audio-display=no
force-window=immediate
term-status-msg=Baobab Sound: ${media-title}
EOF

  cat > "$BAOBAB_CONFIG/soundscape/soundscape.json" <<EOF
{
  "schema": "sevenos.baobab.soundscape.v1",
  "profile": "baobab",
  "mode": "subtle",
  "player": "mpv",
  "config": "$BAOBAB_CONFIG/mpv/mpv.conf",
  "library": "$BAOBAB_WORKSPACE/Sound",
  "policy": "local files first; online radio is explicit and cacheable"
}
EOF

  cat > "$BAOBAB_CONFIG/meilisearch/config.toml" <<EOF
# Baobab local search config
db_path = "$BAOBAB_PROFILE_DATA/meilisearch"
http_addr = "127.0.0.1:7701"
env = "development"
no_analytics = true
EOF

  cat > "$BAOBAB_CONFIG/ollama/Modelfile.baobab" <<'EOF'
# Baobab AI profile prompt seed. Model selection stays local and user-owned.
SYSTEM """
Tu es Seven Baobab AI, un guide culturel calme, prudent et éducatif.
Tu expliques les cultures africaines avec respect, sources, contexte, et sans
inventer de validation communautaire. Tu privilégies le français d'abord.
"""
EOF

  cat > "$BAOBAB_CONFIG/piper/narration.json" <<EOF
{
  "schema": "sevenos.baobab.narration.v1",
  "engine": "piper",
  "fallback": "espeak-ng",
  "voices": "$BAOBAB_PROFILE_DATA/piper/voices",
  "language_priority": ["fr", "local", "en"],
  "policy": "offline voice only; source text remains local"
}
EOF

  cat > "$BAOBAB_CONFIG/argos/translation.json" <<EOF
{
  "schema": "sevenos.baobab.translation.v1",
  "engine": "argos-translate",
  "fallback": "translate-shell",
  "packages": "$BAOBAB_PROFILE_DATA/argos/packages",
  "policy": "offline translation packs; local speaker validation required for teaching content"
}
EOF

  cat > "$BAOBAB_CONFIG/syncthing/readme.txt" <<EOF
Baobab Syncthing config root.
Use only for explicit community sync folders; never sync hidden profile config by default.
EOF

  cat > "$BAOBAB_CONFIG/waybar/config.jsonc" <<EOF
{
  "schema": "sevenos.baobab.waybar.v1",
  "profile": "baobab",
  "layer": "top",
  "position": "top",
  "height": 38,
  "spacing": 10,
  "margin-top": 10,
  "margin-left": 18,
  "margin-right": 18,
  "modules-left": ["custom/baobab", "custom/entry", "custom/compass", "custom/ritual", "hyprland/workspaces"],
  "modules-center": ["custom/route"],
  "modules-right": ["custom/ambiance", "custom/sound", "custom/language", "custom/ai", "custom/wifi", "custom/bluetooth", "pulseaudio", "battery", "clock"],
  "custom/baobab": {
    "format": "󰣇 Baobab",
    "tooltip": "Baobab OS - espace d'immersion culturelle",
    "on-click": "seven baobab native --view today",
    "on-click-right": "$BAOBAB_BIN/baobab-widget",
    "on-click-middle": "seven baobab native --view immersions"
  },
  "custom/entry": {
    "exec": "seven baobab trail --json | python -c 'import json,sys; d=json.load(sys.stdin); n=d.get(\"count\",0); print(json.dumps({\"text\": \"Entrée · \"+str(n)+\" traces\", \"tooltip\": \"Entrée Baobab: région, pays, trace, transmission\", \"class\": \"entry\"}, ensure_ascii=False))'",
    "return-type": "json",
    "interval": 60,
    "tooltip": true,
    "on-click": "seven baobab native --view entry",
    "on-click-right": "seven baobab native --view trail"
  },
  "custom/compass": {
    "exec": "seven baobab compass --json | python -c 'import json,sys; d=json.load(sys.stdin); n=d.get(\"next\",{}); print(json.dumps({\"text\": \"Boussole · \"+str(n.get(\"title\", \"Baobab\")), \"tooltip\": str(n.get(\"body\", \"\")), \"class\": str(d.get(\"ambiance\", \"calme\"))}, ensure_ascii=False))'",
    "return-type": "json",
    "interval": 120,
    "tooltip": true,
    "on-click": "seven baobab native --view compass",
    "on-click-right": "seven baobab compass"
  },
  "custom/ritual": {
    "exec": "seven baobab ritual --json | python -c 'import json,sys; d=json.load(sys.stdin); text=\"Rituel · \"+str(d.get(\"ritual\", \"Baobab\"))[:42]; print(json.dumps({\"text\": text, \"tooltip\": str(d.get(\"ritual\", \"\")), \"class\": \"ritual\"}, ensure_ascii=False))'",
    "return-type": "json",
    "interval": 3600,
    "tooltip": true,
    "on-click": "seven baobab native --view journal",
    "on-click-right": "seven baobab native --view immersions"
  },
  "custom/route": {
    "exec": "seven baobab route --json | python -c 'import json,sys; d=json.load(sys.stdin); text=\"Carnet de route · \"+str(d.get(\"done\",0))+\"/\"+str(d.get(\"total\",0))+\" · \"+str(d.get(\"score\",0))+\"%\"; tip=\"\\n\".join([(\"OK\" if i.get(\"done\") else \"..\")+\" \"+str(i.get(\"label\"))+\": \"+str(i.get(\"value\")) for i in d.get(\"steps\", [])]); print(json.dumps({\"text\": text, \"tooltip\": tip, \"class\": \"route\"}, ensure_ascii=False))'",
    "return-type": "json",
    "interval": 300,
    "tooltip": true,
    "on-click": "seven baobab open",
    "on-click-right": "seven baobab route"
  },
  "custom/ambiance": {
    "exec": "seven baobab ambiance --json | python -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({\"text\": str(d.get(\"waybar\", \"Ambiance\")), \"tooltip\": str(d.get(\"subtitle\", \"Baobab\")), \"class\": str(d.get(\"current\", \"calme\"))}, ensure_ascii=False))'",
    "return-type": "json",
    "interval": 30,
    "tooltip": true,
    "on-click": "seven baobab native --view preferences",
    "on-click-right": "seven baobab ambiance"
  },
  "custom/language": {
    "exec": "seven-waybar-language",
    "return-type": "json",
    "interval": 30,
    "tooltip": true,
    "on-click": "seven-language menu",
    "on-click-right": "seven-settings general"
  },
  "custom/sound": {
    "exec": "python -c 'import json, pathlib; roots=[pathlib.Path(\"$BAOBAB_WORKSPACE/Sound\"), pathlib.Path(\"$BAOBAB_DATA/sound\")]; n=sum(1 for root in roots if root.exists() for p in root.iterdir() if p.suffix.lower() in {\".mp3\",\".ogg\",\".flac\",\".wav\",\".m4a\",\".opus\"}); print(json.dumps({\"text\": str(n)+\" sons\", \"tooltip\": \"Baobab Sound\", \"class\": \"sound\"}, ensure_ascii=False))'",
    "return-type": "json",
    "interval": 30,
    "tooltip": "Baobab Sound - sons, contes, instruments et archives audio",
    "on-click": "$BAOBAB_BIN/baobab-sound",
    "on-click-right": "seven baobab native --view modules"
  },
  "custom/ai": {
    "exec": "python -c 'import json, shutil; ok=bool(shutil.which(\"ollama\") or shutil.which(\"llama-cli\")); print(json.dumps({\"text\": \"IA locale\" if ok else \"IA prête\", \"tooltip\": \"Seven Baobab AI local\", \"class\": \"ready\" if ok else \"planned\"}, ensure_ascii=False))'",
    "return-type": "json",
    "interval": 300,
    "tooltip": "Seven Baobab AI local"
  },
  "custom/wifi": {
    "exec": "seven-waybar-status wifi",
    "return-type": "json",
    "interval": 5,
    "tooltip": true,
    "on-click": "seven-waybar-action network",
    "on-click-right": "seven-quick-settings wifi",
    "on-click-middle": "seven-wifi toggle"
  },
  "custom/bluetooth": {
    "exec": "seven-waybar-status bluetooth",
    "return-type": "json",
    "interval": 5,
    "tooltip": true,
    "on-click": "seven-waybar-action bluetooth",
    "on-click-right": "seven-quick-settings bluetooth",
    "on-click-middle": "seven-bluetooth toggle"
  },
  "pulseaudio": {
    "format": "{volume}%",
    "format-muted": "muet",
    "tooltip": false,
    "on-click": "seven-waybar-action audio",
    "on-click-right": "seven-quick-settings audio",
    "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
    "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    "on-click-middle": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
  },
  "battery": {
    "format": "{capacity}%",
    "states": {"warning": 30, "critical": 15},
    "on-click": "seven-waybar-action battery",
    "on-click-right": "seven-quick-settings power"
  },
  "clock": {
    "format": "{:%H:%M}",
    "tooltip-format": "{:%A %d %B %Y}",
    "on-click": "seven-waybar-action clock",
    "on-click-right": "seven-quick-settings time"
  }
}
EOF

  cat > "$BAOBAB_CONFIG/waybar/style.css" <<'EOF'
* {
  border: none;
  border-radius: 0;
  font-family: "Noto Sans", "Noto Sans Symbols", "Noto Color Emoji", sans-serif;
  font-size: 12px;
  font-weight: 500;
  min-height: 0;
}

window#waybar {
  background: rgba(6, 10, 8, 0.76);
  color: #f4ead8;
  border: 1px solid rgba(139, 170, 123, 0.20);
  border-radius: 18px;
}

#custom-baobab,
#custom-entry,
#custom-compass,
#custom-ritual,
#custom-route,
#custom-ambiance,
#custom-language,
#custom-sound,
#custom-ai,
#custom-wifi,
#custom-bluetooth,
#workspaces,
#pulseaudio,
#battery,
#clock {
  background: rgba(18, 27, 21, 0.70);
  color: #d8ccb5;
  border: 1px solid rgba(216, 204, 181, 0.12);
  border-radius: 14px;
  margin: 5px 3px;
  padding: 0 11px;
}

#custom-baobab {
  color: #f4ead8;
  background: linear-gradient(135deg, rgba(49, 94, 77, 0.70), rgba(36, 60, 99, 0.44));
  border-color: rgba(139, 170, 123, 0.42);
  padding: 0 16px;
}

#custom-entry {
  color: #f4ead8;
  background: rgba(26, 42, 37, 0.62);
  border-color: rgba(139, 170, 123, 0.28);
  min-width: 118px;
}

#custom-entry:hover {
  color: #c89b63;
  background: rgba(31, 43, 33, 0.94);
}

#custom-compass {
  color: #f4ead8;
  background: rgba(34, 46, 32, 0.56);
  border-color: rgba(139, 170, 123, 0.32);
  min-width: 120px;
}

#custom-compass:hover {
  color: #c89b63;
  background: rgba(31, 43, 33, 0.94);
}

#custom-ritual {
  color: #f4ead8;
  background: rgba(91, 67, 38, 0.48);
  border-color: rgba(200, 155, 99, 0.34);
  min-width: 220px;
}

#custom-route {
  color: #f4ead8;
  background: rgba(28, 48, 39, 0.72);
  border-color: rgba(139, 170, 123, 0.35);
  min-width: 210px;
}

#custom-ambiance {
  color: #f4ead8;
  min-width: 126px;
}

#custom-ambiance.calme {
  color: #8baa7b;
}

#custom-ambiance.apprentissage {
  color: #6aaed6;
}

#custom-ambiance.terrain {
  color: #c89b63;
}

#custom-ambiance.scene {
  color: #b78fe8;
}

#custom-ritual:hover,
#custom-route:hover {
  color: #c89b63;
  background: rgba(31, 43, 33, 0.92);
}

#custom-language {
  color: #8baa7b;
}

#custom-sound,
#pulseaudio {
  color: #d8ccb5;
}

#custom-ai {
  color: #cbb9ef;
}

#custom-wifi.connected,
#custom-bluetooth.connected,
#custom-bluetooth.on {
  color: #8baa7b;
}

#custom-wifi.idle,
#custom-bluetooth.off {
  color: #c89b63;
}

#custom-wifi.missing,
#custom-bluetooth.missing,
#custom-wifi.off {
  color: #e07a5f;
}

#custom-wifi:hover,
#custom-bluetooth:hover,
#pulseaudio:hover,
#battery:hover,
#clock:hover,
#custom-sound:hover,
#custom-ai:hover {
  border-color: rgba(200, 155, 99, 0.42);
  background: rgba(16, 23, 19, 0.95);
}

#workspaces button {
  color: #b9c4a5;
  background: transparent;
  border-radius: 8px;
  margin: 3px 1px;
  padding: 0 8px;
}

#workspaces button.active {
  color: #f4ead8;
  background: rgba(49, 94, 77, 0.58);
  border: 1px solid rgba(200, 155, 99, 0.30);
}

#workspaces button:hover {
  background: rgba(139, 170, 123, 0.22);
}

#battery.warning {
  color: #e0b15f;
}

#battery.critical {
  color: #e07a5f;
}
EOF

  cat > "$BAOBAB_CONFIG/eww/baobab.yuck" <<'EOF'
; Baobab profile-owned Eww widgets
; Native-first shell widgets for the Baobab cultural mini OS.

(defpoll baobab_status :interval "10m"
  "seven baobab capability-doctor --json | python -c 'import json,sys; d=json.load(sys.stdin); print(str(d.get(\"score\",0))+\"% prêt\")'")

(defpoll baobab_tools :interval "10m"
  "seven baobab tool-doctor --json | python -c 'import json,sys; d=json.load(sys.stdin); print(str(d.get(\"immersive_score\",0))+\"% immersif\")'")

(defpoll baobab_sound :interval "30s"
  "find \"$HOME/Baobab/Sound\" \"$HOME/.local/share/sevenos/profiles/baobab/baobab/sound\" -maxdepth 1 -type f 2>/dev/null | wc -l | awk '{print $1\" sons\"}'")

(defwindow baobab-memory
  :monitor 0
  :geometry (geometry :x "2%" :y "6%" :width "380px" :height "210px")
  :stacking "fg"
  :exclusive false
  (box :class "baobab-memory" :orientation "v" :space-evenly false
    (label :class "eyebrow" :xalign 0 :text "BAOBAB OS")
    (label :class "title" :xalign 0 :text "Arbre de connaissance")
    (label :class "body" :xalign 0 :wrap true :text "Mémoire vivante, transmission calme, création locale et apprentissage hors ligne.")
    (box :orientation "h" :space-evenly false
      (label :class "chip" :text baobab_status)
      (label :class "chip" :text baobab_tools)
      (label :class "chip" :text baobab_sound))))
EOF

  cat > "$BAOBAB_CONFIG/eww/baobab.scss" <<'EOF'
.baobab-memory {
  background: #101713;
  color: #f4ead8;
  border: 1px solid rgba(139, 170, 123, .28);
  border-radius: 8px;
  padding: 18px;
}
.eyebrow {
  color: #8baa7b;
  font-size: 12px;
  font-weight: 700;
}
.title {
  color: #f4ead8;
  font-size: 24px;
  font-weight: 600;
}
.body {
  color: #d8ccb5;
  font-size: 14px;
}
.chip {
  background: #121915;
  border: 1px solid rgba(200, 155, 99, .24);
  border-radius: 8px;
  color: #c89b63;
  padding: 7px 9px;
  margin-right: 8px;
}
EOF
  cp "$BAOBAB_CONFIG/eww/baobab.yuck" "$BAOBAB_CONFIG/eww/eww.yuck"
  cp "$BAOBAB_CONFIG/eww/baobab.scss" "$BAOBAB_CONFIG/eww/eww.scss"

  cat > "$BAOBAB_CONFIG/shell/baobab-shell.json" <<EOF
{
  "schema": "sevenos.baobab.shell.v1",
  "home": "arbre de connaissance",
  "surface": "espace d'immersion culturelle",
  "widgets": ["entry", "veillee", "session", "sessions", "carnet", "constellation", "media", "today", "compass", "ritual", "route", "ambiance", "trail", "memory", "language", "sound", "country", "collection"],
  "launchpad_filter": "baobab",
  "world": "Racines, Tronc, Branches, Feuilles, Collecte, Archives",
  "ritual": "seven baobab ritual",
  "entry": "seven baobab native --view entry",
  "veillee": "seven baobab native --view veillee",
  "session": "seven baobab session",
  "sessions": "seven baobab native --view sessions",
  "carnet": "seven baobab native --view carnet",
  "constellation": "seven baobab native --view constellation",
  "media": "seven baobab native --view media",
  "trail": "seven baobab trail",
  "today": "seven baobab today",
  "route": "seven baobab route",
  "ambiance": "seven baobab ambiance",
  "compass": "seven baobab compass",
  "config_roots": {
    "waybar": "$BAOBAB_CONFIG/waybar",
    "eww": "$BAOBAB_CONFIG/eww",
    "mpv": "$BAOBAB_CONFIG/mpv"
  },
  "launchers": {
    "native": "seven-baobab-native",
    "veillee": "seven-baobab-native --view veillee",
    "carnet": "seven-baobab-native --view carnet",
    "constellation": "seven-baobab-native --view constellation",
    "media": "seven-baobab-native --view media",
    "memory_widget": "$BAOBAB_BIN/baobab-widget",
    "sound": "$BAOBAB_BIN/baobab-sound"
  }
}
EOF

  cat > "$BAOBAB_CONFIG/store/sources.json" <<EOF
{
  "schema": "sevenos.baobab.store-sources.v1",
  "profile": "baobab",
  "sources": ["repo", "flatpak", "aur-optional", "pipx-external"],
  "policy": "show cultural roles first; backend names only in technical details"
}
EOF

  cat > "$BAOBAB_CAPABILITIES" <<EOF
{
  "schema": "sevenos.baobab.capabilities.v1",
  "profile": "baobab",
  "goals": [
    "valoriser les cultures africaines",
    "fonctionner localement et hors ligne",
    "créer une expérience légère, immersive et intelligente"
  ],
  "principle": "Les outils servent la culture; ils ne remplacent pas l'identité Baobab.",
  "domains": [
    {
      "key": "system_interface",
      "title": "Base système et interface",
      "purpose": "Composer une expérience Wayland fluide avec panneaux, widgets et notifications culturelles.",
      "tools": ["Hyprland", "Waybar", "Eww", "SwayNC"],
      "offline": true,
      "public_surface": "Baobab Shell, barre culturelle, widgets proverbes/langues/son"
    },
    {
      "key": "african_identity",
      "title": "Identité culturelle africaine",
      "purpose": "Installer une identité subtile: typographie, palettes dynamiques, sons et ambiance enracinée.",
      "tools": ["Noto Fonts", "Pywal", "PipeWire"],
      "offline": true,
      "public_surface": "thèmes Baobab, soundscape, polices larges, wallpapers culturels"
    },
    {
      "key": "local_content",
      "title": "Contenus culturels locaux",
      "purpose": "Stocker et rechercher proverbes, langues, récits, recettes, textiles, cartes et patrimoine.",
      "tools": ["SQLite", "Meilisearch", "Leaflet"],
      "offline": true,
      "public_surface": "Recherche, Sources, Explorer Afrique, packs culturels"
    },
    {
      "key": "local_ai",
      "title": "Intelligence artificielle locale",
      "purpose": "Aider sans internet: guide culturel, narration, traduction, tuteur et recommandations.",
      "tools": ["Ollama", "llama.cpp", "Open WebUI", "Piper", "Argos Translate"],
      "offline": true,
      "public_surface": "Seven Baobab AI, narration, traduction et apprentissage"
    },
    {
      "key": "education",
      "title": "Éducation et transmission",
      "purpose": "Lire, enseigner et transmettre dans les écoles, familles et zones à faible connectivité.",
      "tools": ["Foliate", "Kiwix", "Kolibri"],
      "offline": true,
      "public_surface": "Bibliothèque, mode école, encyclopédies offline, parcours pédagogiques"
    },
    {
      "key": "media_heritage",
      "title": "Média et patrimoine africain",
      "purpose": "Écouter musiques, radios, instruments, contes audio et archives multimédias.",
      "tools": ["MPV", "Tauon Music Box", "Radio Browser API"],
      "offline": "hybrid",
      "public_surface": "Baobab Sound, playlists locales, radio explicite et cacheable"
    },
    {
      "key": "cultural_store",
      "title": "Baobab Store",
      "purpose": "Présenter logiciels, contenus, packs et sources sans jargon backend.",
      "tools": ["PackageKit", "Flatpak"],
      "offline": "hybrid",
      "public_surface": "Store culturel, sources d'apps et packs Baobab"
    },
    {
      "key": "community_sync",
      "title": "Synchronisation locale et communautaire",
      "purpose": "Partager volontairement packs et médias entre familles, écoles et communautés.",
      "tools": ["Syncthing", "Nextcloud"],
      "offline": "local-network",
      "public_surface": "sync locale, cloud communautaire, partage explicite"
    },
    {
      "key": "creator_tools",
      "title": "Création artisanale et numérique",
      "purpose": "Permettre aux créateurs de produire images, objets 3D, vidéos, supports pédagogiques.",
      "tools": ["Krita", "Blender", "Kdenlive"],
      "offline": true,
      "public_surface": "atelier créatif, musée, textile, vidéo d'archives"
    },
    {
      "key": "living_difference",
      "title": "Différence Baobab",
      "purpose": "Faire de Baobab un écosystème culturel vivant, pas Linux avec un thème africain.",
      "tools": ["contenus locaux", "langues africaines", "sons naturels", "validation communautaire", "transmission"],
      "offline": true,
      "public_surface": "Arbre de connaissance, Collecte, Packs, Récits, Communauté"
    }
  ]
}
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-os.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab OS
Comment=Open the Baobab cultural mini OS
Exec=$ROOT_DIR/bin/seven baobab open
Icon=seven-baobab
Terminal=false
Categories=Education;Culture;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-collect.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Collecte
Comment=Create a sourced cultural draft inside Baobab
Exec=env SEVENOS_ROOT=$ROOT_DIR $ROOT_DIR/bin/seven-baobab-native --view collect
Icon=seven-baobab
Terminal=false
Categories=Education;Culture;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-immersions.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Immersions
Comment=Enter Baobab through regions, languages, routes, sounds and memory
Exec=env SEVENOS_ROOT=$ROOT_DIR $ROOT_DIR/bin/seven-baobab-native --view immersions
Icon=seven-baobab
Terminal=false
Categories=Education;Culture;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-journal.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Journal
Comment=Open the daily ritual journal and local cultural notes
Exec=env SEVENOS_ROOT=$ROOT_DIR $ROOT_DIR/bin/seven-baobab-native --view journal
Icon=seven-baobab
Terminal=false
Categories=Education;Culture;Office;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-packs.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Packs
Comment=Prepare cultural packs, source review and community collection workflows
Exec=env SEVENOS_ROOT=$ROOT_DIR $ROOT_DIR/bin/seven-baobab-native --view packs
Icon=seven-baobab
Terminal=false
Categories=Education;Culture;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-explore.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Explorer
Comment=Explore countries, heritage and living cultural memory
Exec=$ROOT_DIR/bin/seven baobab explore
Icon=seven-baobab
Terminal=false
Categories=Education;Culture;Maps;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-sound.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Sound
Comment=Play local cultural audio with Baobab's profile audio configuration
Exec=$ROOT_DIR/bin/seven baobab sound
Icon=seven-baobab
Terminal=false
Categories=Audio;Music;Culture;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-media.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Médiathèque
Comment=Browse local Baobab sounds, images, videos and cultural documents
Exec=env SEVENOS_ROOT=$ROOT_DIR $ROOT_DIR/bin/seven-baobab-native --view media
Icon=seven-baobab
Terminal=false
Categories=AudioVideo;Graphics;Education;Culture;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_DESKTOP_DIR/seven-baobab-sessions.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Baobab Sessions
Comment=Open local Baobab workshop and fieldwork session folders
Exec=env SEVENOS_ROOT=$ROOT_DIR $ROOT_DIR/bin/seven-baobab-native --view sessions
Icon=seven-baobab
Terminal=false
Categories=Education;Culture;Office;SevenOS;
StartupNotify=true
X-SevenOS-Profile=baobab
X-SevenOS-Isolated=true
EOF

  cat > "$BAOBAB_APP_MANIFEST" <<EOF
{
  "schema": "sevenos.baobab.apps.v1",
  "profile": "baobab",
  "desktop_dir": "$BAOBAB_DESKTOP_DIR",
  "policy": "Baobab app launchers are profile-owned; global launchers are only active projections.",
  "apps": [
    {"id": "seven-baobab-os", "title": "Baobab OS", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-os.desktop", "command": "seven baobab open"},
    {"id": "seven-baobab-collect", "title": "Baobab Collecte", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-collect.desktop", "command": "seven-baobab-native --view collect"},
    {"id": "seven-baobab-immersions", "title": "Baobab Immersions", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-immersions.desktop", "command": "seven-baobab-native --view immersions"},
    {"id": "seven-baobab-journal", "title": "Baobab Journal", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-journal.desktop", "command": "seven-baobab-native --view journal"},
    {"id": "seven-baobab-packs", "title": "Baobab Packs", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-packs.desktop", "command": "seven-baobab-native --view packs"},
    {"id": "seven-baobab-explore", "title": "Baobab Explorer", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-explore.desktop", "command": "seven baobab explore"},
    {"id": "seven-baobab-sound", "title": "Baobab Sound", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-sound.desktop", "command": "seven baobab sound"},
    {"id": "seven-baobab-media", "title": "Baobab Médiathèque", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-media.desktop", "command": "seven-baobab-native --view media"},
    {"id": "seven-baobab-sessions", "title": "Baobab Sessions", "desktop": "$BAOBAB_DESKTOP_DIR/seven-baobab-sessions.desktop", "command": "seven-baobab-native --view sessions"}
  ]
}
EOF

  if [[ ! -s "$BAOBAB_PROFILE_UI" ]]; then
    cat > "$BAOBAB_PROFILE_UI" <<EOF
{
  "schema": "sevenos.profile-ui.v1",
  "key": "baobab",
  "title": "Baobab",
  "surface": "arbre de connaissance",
  "tone": "calme, culturel, éducatif, premium",
  "primary_language": "fr",
  "accent": "baobab",
  "home": {
    "metaphor": "Racines, Tronc, Branches, Feuilles, Collecte, Archives",
    "open": "seven baobab open",
    "explore": "seven baobab explore",
    "launchpad_filter": "baobab"
  },
  "home_screen": {
    "launchpad_filter": "baobab",
    "primary_surface": "seven baobab native --view today",
    "secondary_surface": "seven baobab native --view immersions",
    "daily_surface": "seven baobab native --view journal"
  },
  "shell": {
    "waybar": "$BAOBAB_BIN/baobab-waybar",
    "launchpad_world": "baobab",
    "dock_policy": "culture-first"
  },
  "config_policy": "profile-owned"
}
EOF
  fi

  if [[ ! -s "$BAOBAB_NATIVE_SETTINGS" ]]; then
    cat > "$BAOBAB_NATIVE_SETTINGS" <<'EOF'
{
  "schema": "sevenos.baobab.native-settings.v1",
  "language": "fr",
  "immersion_focus": "sahel",
  "country_focus": "",
  "ambiance": "calme"
}
EOF
  fi

  if [[ ! -s "$BAOBAB_SESSION" ]]; then
    cat > "$BAOBAB_SESSION" <<EOF
{
  "schema": "sevenos.profile-session.v1",
  "profile": "baobab",
  "recent_apps": [],
  "recent_paths": ["$BAOBAB_WORKSPACE"],
  "pinned_objects": [],
  "tasks": [],
  "mood": "mémoire vivante",
  "updated_by": "seven baobab apply-config"
}
EOF
  fi

  if [[ ! -s "$BAOBAB_PASSAGE" ]]; then
    cat > "$BAOBAB_PASSAGE" <<'EOF'
{
  "schema": "sevenos.profile-passage.v1",
  "profile": "baobab",
  "enter": "Tu entres dans Baobab: mémoire culturelle, transmission et création enracinée.",
  "leave": "Tu quittes Baobab: les contenus culturels restent dans leur espace protégé.",
  "boundary": "Baobab partage seulement les objets explicitement envoyés par Seven Bridge."
}
EOF
  fi

  if [[ ! -s "$BAOBAB_WALLPAPER_STATE" ]]; then
    {
      printf 'profile\tbaobab\n'
      printf 'mode\tprofile-default\n'
      printf 'value\tbaobab-rooted-technology\n'
      printf 'active\t%s\n' "$HOME/.local/share/sevenos/wallpapers/wallpaper-sevenos-active.png"
      printf 'profile_active\t%s\n' "$HOME/.local/share/sevenos/wallpapers/profiles/baobab/wallpaper-active.png"
    } > "$BAOBAB_WALLPAPER_STATE"
  fi

  cat > "$BAOBAB_RUNTIME" <<EOF
{
  "schema": "sevenos.baobab.runtime.v1",
  "profile": "baobab",
  "state": "ready",
  "config_root": "$BAOBAB_CONFIG",
  "data_root": "$BAOBAB_DATA",
  "cache_root": "$BAOBAB_CACHE",
  "workspace": "$BAOBAB_WORKSPACE",
  "env": "$BAOBAB_ENV",
  "services": {
    "meilisearch": "$BAOBAB_CONFIG/meilisearch/config.toml",
    "ollama": "$BAOBAB_CONFIG/ollama/Modelfile.baobab",
    "soundscape": "$BAOBAB_CONFIG/soundscape/soundscape.json",
    "syncthing": "$BAOBAB_CONFIG/syncthing"
  },
  "launchers": {
    "run": "$BAOBAB_BIN/baobab-run",
    "sound": "$BAOBAB_BIN/baobab-sound",
    "search": "$BAOBAB_BIN/baobab-searchd",
    "ai": "$BAOBAB_BIN/baobab-ai",
    "narrate": "$BAOBAB_BIN/baobab-narrate"
  },
  "strict_rule": "Baobab services must use Baobab profile-owned config/data/cache roots."
}
EOF

  cat > "$BAOBAB_CONFIG_MANIFEST" <<EOF
{
  "schema": "sevenos.baobab.config-manifest.v1",
  "profile": "baobab",
  "roots": {
    "profile_config": "$BAOBAB_PROFILE_CONFIG",
    "profile_data": "$BAOBAB_PROFILE_DATA",
    "profile_cache": "$BAOBAB_PROFILE_CACHE",
    "baobab_config": "$BAOBAB_CONFIG",
    "baobab_data": "$BAOBAB_DATA",
    "baobab_cache": "$BAOBAB_CACHE"
  },
  "files": {
    "env": "$BAOBAB_ENV",
    "run": "$BAOBAB_BIN/baobab-run",
    "sound_launcher": "$BAOBAB_BIN/baobab-sound",
    "search_launcher": "$BAOBAB_BIN/baobab-searchd",
    "ai_launcher": "$BAOBAB_BIN/baobab-ai",
    "narration_launcher": "$BAOBAB_BIN/baobab-narrate",
    "apps": "$BAOBAB_APP_MANIFEST",
    "capabilities": "$BAOBAB_CAPABILITIES",
    "runtime": "$BAOBAB_RUNTIME",
    "mpv": "$BAOBAB_CONFIG/mpv/mpv.conf",
    "waybar": "$BAOBAB_CONFIG/waybar/config.jsonc",
    "eww": "$BAOBAB_CONFIG/eww/baobab.yuck",
    "shell": "$BAOBAB_CONFIG/shell/baobab-shell.json",
    "soundscape": "$BAOBAB_CONFIG/soundscape/soundscape.json",
    "store": "$BAOBAB_CONFIG/store/sources.json"
  },
  "legacy": {
    "config": "$BAOBAB_LEGACY_CONFIG",
    "data": "$BAOBAB_LEGACY_DATA",
    "cache": "$BAOBAB_LEGACY_CACHE",
        "status": "read-only migration source"
  },
  "profile_files": {
    "profile_ui": "$BAOBAB_PROFILE_UI",
    "session": "$BAOBAB_SESSION",
    "passage": "$BAOBAB_PASSAGE",
    "wallpaper_state": "$BAOBAB_WALLPAPER_STATE"
  }
}
EOF
}

print_languages() {
  bootstrap_baobab >/dev/null
  LANGUAGES_JSON="$LANGUAGES_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["LANGUAGES_JSON"])
payload = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"schema": "sevenos.baobab.languages.v1", "languages": []}
languages = payload.get("languages", [])
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Languages")
    print("================")
    print(payload.get("curation_note", ""))
    for item in languages:
        regions = ", ".join(item.get("regions", []))
        phrases = item.get("phrases", [])
        print(f"- {item.get('name_fr') or item.get('name_en')} · {regions}")
        print(f"  Famille: {item.get('family', 'unknown')} · Validation: {item.get('validation', 'needs-local-speaker')} · Phrases starter: {len(phrases)}")
PY
}

scaffold_pack() {
  local raw_name="${1:-}" pack_name pack_dir pack_file
  if [[ -z "$raw_name" ]]; then
    log_error "Missing pack name."
    return 1
  fi
  bootstrap_baobab >/dev/null
  pack_name="$(safe_pack_name "$raw_name")"
  if [[ -z "$pack_name" ]]; then
    log_error "Invalid pack name: $raw_name"
    return 1
  fi
  pack_dir="$PACKS_DIR/$pack_name"
  pack_file="$pack_dir/pack.json"
  mkdir -p "$pack_dir/media" "$pack_dir/sources"
  if [[ ! -s "$pack_file" ]]; then
    PACK_NAME="$pack_name" PACK_FILE="$pack_file" python - <<'PY'
import json
import os
from pathlib import Path

pack_name = os.environ["PACK_NAME"]
pack = {
    "schema": "sevenos.baobab.pack.v1",
    "name": pack_name,
    "title": pack_name.replace("-", " ").title(),
    "description": "Local Baobab cultural pack. Add sourced, community-approved records before import.",
    "curator": "local",
    "license": "custom-local",
    "source_notes": "Document sources in sources/ before publishing or sharing.",
    "community_review": "not-reviewed",
    "records": [
        {
            "id": f"{pack_name}-example",
            "module": "heritage",
            "title": "Example Cultural Record",
            "kind": "note",
            "region": "local",
            "summary": "Replace this with sourced local heritage, language, story, sound, food, fashion, wisdom or map content.",
            "tags": ["draft", "local", "needs-source"],
            "source": "sources/README.md",
            "license": "custom-local",
            "curator": "local",
	            "confidence": "draft",
	            "language": "und",
	            "country": "local",
	            "cultural_protocol": {
	                "sensitivity": "unknown",
	                "access": "local-first",
	                "protocols": ["CARE", "source-context-consent", "community-review-before-publication"],
	                "publication": "draft-local"
	            }
	        }
    ],
}
Path(os.environ["PACK_FILE"]).write_text(json.dumps(pack, indent=2) + "\n", encoding="utf-8")
PY
  fi
  normalize_packs_metadata
  if [[ ! -s "$pack_dir/sources/README.md" ]]; then
    cat > "$pack_dir/sources/README.md" <<'EOF'
# Baobab Pack Sources

Add source notes, permissions, interviews, archive references or community
validation notes here before sharing this pack.
EOF
  fi
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '{"schema":"sevenos.baobab.pack.scaffold.v1","name":%s,"path":%s,"pack":%s}\n' \
      "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$pack_name")" \
      "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$pack_dir")" \
      "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$pack_file")"
  else
    printf 'Baobab pack scaffold ready: %s\n' "$pack_file"
  fi
}

list_packs() {
  bootstrap_baobab >/dev/null
  PACKS_DIR="$PACKS_DIR" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
packs = []
for pack_file in sorted(packs_dir.glob("*/pack.json")):
    try:
        data = json.loads(pack_file.read_text(encoding="utf-8"))
    except Exception:
        data = {"name": pack_file.parent.name, "title": pack_file.parent.name, "records": []}
    packs.append({
        "name": data.get("name", pack_file.parent.name),
        "title": data.get("title", pack_file.parent.name),
        "path": str(pack_file),
        "records": len(data.get("records", [])),
    })

if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps({"schema": "sevenos.baobab.packs.v1", "count": len(packs), "packs": packs}, indent=2))
else:
    print("Baobab Packs")
    print("============")
    if not packs:
        print("No local packs yet. Create one with: seven baobab scaffold-pack my-culture-pack")
    for pack in packs:
        print(f"- {pack['title']} ({pack['name']})")
        print(f"  {pack['records']} records · {pack['path']}")
PY
}

seed_curated_packs() {
  if [[ "${BAOBAB_SKIP_BOOTSTRAP:-0}" != "1" ]]; then
    bootstrap_baobab >/dev/null
  fi
  PACKS_DIR="$PACKS_DIR" CONTENT_INDEX="$CONTENT_INDEX" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
catalog_path = Path(os.environ["CONTENT_INDEX"])
packs_dir.mkdir(parents=True, exist_ok=True)

packs = [
    {
        "name": "burkina-food",
        "title": "Burkina Food Starter Pack",
        "description": "Première base sourcée pour la cuisine burkinabè: plats, gestes, contextes et pistes de collecte familiale.",
        "curator": "SevenOS Baobab",
        "license": "CC-BY-SA-4.0-metadata",
        "source_notes": "Starter pack: sources publiques et placeholders de collecte locale. À compléter par interviews, photos et permissions communautaires.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/burkina-food.md": "# Sources - Burkina Food\n\n- Burkina Faso official/tourism and public cultural references for cuisine overview.\n- Future local validation: interviews, family recipes, author permissions and regional variants.\n"
        },
        "records": [
            {
                "id": "burkina-food-to-riz-gras",
                "module": "food",
                "title": "Cuisine burkinabè: tô, riz gras et mémoire familiale",
                "kind": "food-starter",
                "region": "west-africa",
                "summary": "Pack de départ pour documenter les plats quotidiens et festifs du Burkina Faso, avec priorité aux recettes familiales sourcées, aux gestes de préparation et aux variantes régionales.",
                "tags": ["food", "burkina-faso", "recipe", "family-memory", "needs-community-validation"],
                "source": "sources/burkina-food.md",
                "license": "CC-BY-SA-4.0-metadata",
                "curator": "SevenOS Baobab",
	                "confidence": "starter",
	                "language": "fr",
	                "country": "Burkina Faso",
	                "cultural_protocol": {
	                    "sensitivity": "family",
	                    "access": "local-first",
	                    "protocols": ["CARE", "source-context-consent", "family-review-before-publication"],
	                    "publication": "draft-local"
	                }
	            }
        ],
    },
    {
        "name": "mandingue-sound",
        "title": "Mandingue Sound Starter Pack",
        "description": "Base sonore pour balafon, Sosso-Bala, transmission orale, instruments et apprentissage musical.",
        "curator": "SevenOS Baobab / UNESCO ICH metadata",
        "license": "UNESCO metadata; verify media rights before redistribution",
        "source_notes": "Sources UNESCO ICH locales et URLs publiques. Les médias doivent être vérifiés avant redistribution.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/mandingue-sound.md": "# Sources - Mandingue Sound\n\n- UNESCO ICH RL 02131: Balafon and Kolintang practices linked to Mali, Burkina Faso and Côte d'Ivoire.\n- UNESCO ICH RL 00009: Cultural space of Sosso-Bala.\n- Future local validation: musicians, griots, instrument makers and permissions for audio.\n"
        },
        "records": [
            {
                "id": "mandingue-sound-balafon-sosso-bala",
                "module": "sound",
                "title": "Balafon et espace culturel mandingue",
                "kind": "sound-heritage",
                "region": "west-africa",
                "summary": "Point d'entrée sonore pour relier balafon, transmission orale, épopées, apprentissage musical et futures pistes audio locales.",
                "tags": ["sound", "balafon", "mandingue", "oral-tradition", "instrument"],
                "source": "sources/mandingue-sound.md",
                "license": "UNESCO metadata; verify media rights before redistribution",
                "curator": "SevenOS Baobab / UNESCO ICH metadata",
	                "confidence": "starter",
	                "language": "fr",
	                "country": "Mali; Burkina Faso; Ivory Coast; Guinea",
	                "cultural_protocol": {
	                    "sensitivity": "community",
	                    "access": "local-first",
	                    "protocols": ["CARE", "source-context-consent", "community-review-before-publication", "media-rights-required"],
	                    "publication": "draft-local"
	                }
	            }
        ],
    },
    {
        "name": "faso-danfani-fashion",
        "title": "Faso Danfani Fashion Starter Pack",
        "description": "Atelier de départ pour documenter Faso Danfani, tissage, designers, créateurs et pont ElegantStyle.",
        "curator": "SevenOS Baobab",
        "license": "CC-BY-SA-4.0-metadata",
        "source_notes": "Starter pack: à valider par sources burkinabè, tisserands, stylistes et autorisations d'images.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/faso-danfani-fashion.md": "# Sources - Faso Danfani Fashion\n\n- Starter research notes for Faso Danfani and Burkinabè textile documentation.\n- Future local validation: tisserands, stylistes, coopératives, photos autorisées et récits de fabrication.\n"
        },
        "records": [
            {
                "id": "faso-danfani-fashion-atelier",
                "module": "fashion",
                "title": "Faso Danfani: atelier textile et création contemporaine",
                "kind": "fashion-starter",
                "region": "west-africa",
                "summary": "Pack de départ pour relier tissage burkinabè, styles contemporains, fiches créateurs et futur essayage culturel dans ElegantStyle.",
                "tags": ["fashion", "textile", "faso-danfani", "burkina-faso", "creator"],
                "source": "sources/faso-danfani-fashion.md",
                "license": "CC-BY-SA-4.0-metadata",
                "curator": "SevenOS Baobab",
	                "confidence": "starter",
	                "language": "fr",
	                "country": "Burkina Faso",
	                "cultural_protocol": {
	                    "sensitivity": "community",
	                    "access": "local-first",
	                    "protocols": ["CARE", "source-context-consent", "creator-permission-required"],
	                    "publication": "draft-local"
	                }
	            }
        ],
    },
    {
        "name": "sahel-oral-memory",
        "title": "Sahel Oral Memory Starter Pack",
        "description": "Veillées, proverbes, récits de migration, arbres de parenté et transmission orale sahélienne.",
        "curator": "SevenOS Baobab",
        "license": "CC-BY-SA-4.0-metadata",
        "source_notes": "Starter pack: métadonnées et pistes de collecte. Les récits doivent rester privés tant que la personne, la famille ou la communauté n'a pas validé la publication.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/sahel-oral-memory.md": "# Sources - Sahel Oral Memory\n\n- CARE principles for governance and community benefit.\n- Local Contexts labels for cultural authority and sharing expectations.\n- Future local validation: conteurs, familles, détenteurs de récits, traductions et droits audio.\n"
        },
        "records": [
            {
                "id": "sahel-oral-memory-veillee",
                "module": "story",
                "title": "Veillée: récit, silence et transmission",
                "kind": "story-workflow",
                "region": "sahel",
                "summary": "Parcours de collecte pour enregistrer une veillée sans extraire le récit de son contexte: personne ressource, moment, langue, audience autorisée et limites de partage.",
                "tags": ["story", "oral-memory", "sahel", "consent", "family-review"],
                "source": "sources/sahel-oral-memory.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "fr",
                "country": "pan-sahel",
                "cultural_protocol": {
                    "sensitivity": "family",
                    "access": "local-first",
                    "protocols": ["CARE", "source-context-consent", "family-review-before-publication", "audio-rights-required"],
                    "publication": "draft-local"
                }
            },
            {
                "id": "sahel-oral-memory-proverbes",
                "module": "wisdom",
                "title": "Proverbes: contexte avant citation",
                "kind": "wisdom-workflow",
                "region": "sahel",
                "summary": "Modèle pour documenter un proverbe avec langue, contexte d'usage, variantes, personne ressource et niveau de partage autorisé.",
                "tags": ["wisdom", "proverb", "language", "context", "needs-local-speaker"],
                "source": "sources/sahel-oral-memory.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "und",
                "country": "pan-sahel",
                "cultural_protocol": {
                    "sensitivity": "community",
                    "access": "local-first",
                    "protocols": ["CARE", "source-context-consent", "community-review-before-publication"],
                    "publication": "draft-local"
                }
            }
        ],
    },
    {
        "name": "swahili-coast-routes",
        "title": "Swahili Coast Routes Starter Pack",
        "description": "Langue swahili, routes côtières, cuisine, manuscrits, ports et mémoire de l'océan Indien.",
        "curator": "SevenOS Baobab / public heritage metadata",
        "license": "CC-BY-SA-4.0-metadata",
        "source_notes": "Starter pack: utiliser CLDR pour les locales, sources patrimoniales publiques pour les lieux, validation locale pour phrases et récits.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/swahili-coast-routes.md": "# Sources - Swahili Coast Routes\n\n- Unicode CLDR for locale and writing-system orientation.\n- Public heritage references for coastal history and Indian Ocean routes.\n- Future local validation: locuteurs swahili, guides, cuisiniers, chercheurs, archives familiales.\n"
        },
        "records": [
            {
                "id": "swahili-coast-language-route",
                "module": "languages",
                "title": "Swahili: langue-pont de la côte",
                "kind": "language-route",
                "region": "east-africa",
                "summary": "Base de parcours pour relier expressions validées, audio de prononciation, variantes régionales et lieux de mémoire de la côte swahilie.",
                "tags": ["swahili", "language", "coast", "audio-needed", "cldr"],
                "source": "sources/swahili-coast-routes.md",
                "license": "CC-BY-SA-4.0-metadata",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "sw",
                "country": "Kenya; Tanzania; Uganda; Rwanda; Burundi; DRC",
                "cultural_protocol": {
                    "sensitivity": "public",
                    "access": "source-first",
                    "protocols": ["CLDR", "source-context-consent", "local-speaker-validation"],
                    "publication": "draft-local"
                }
            },
            {
                "id": "swahili-coast-food-memory",
                "module": "food",
                "title": "Cuisine côtière: gestes, épices et mémoire familiale",
                "kind": "food-route",
                "region": "east-africa",
                "summary": "Parcours pour documenter une recette sans la réduire à une fiche: origine familiale, variantes, saison, droits photo et récit du geste.",
                "tags": ["food", "coast", "family-memory", "recipe", "media-rights"],
                "source": "sources/swahili-coast-routes.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "sw",
                "country": "Kenya; Tanzania",
                "cultural_protocol": {
                    "sensitivity": "family",
                    "access": "local-first",
                    "protocols": ["CARE", "source-context-consent", "family-review-before-publication"],
                    "publication": "draft-local"
                }
            }
        ],
    },
    {
        "name": "great-lakes-drums",
        "title": "Great Lakes Sound & Museum Starter Pack",
        "description": "Tambours, cérémonies publiques, ateliers de facture, musée local et droits audio/vidéo.",
        "curator": "SevenOS Baobab",
        "license": "CC-BY-SA-4.0-metadata",
        "source_notes": "Starter pack: les pratiques rituelles ou cérémonielles doivent être classées au minimum communautaires jusqu'à validation explicite.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/great-lakes-drums.md": "# Sources - Great Lakes Drums\n\n- UNESCO ICH DataHub for public intangible heritage metadata where applicable.\n- Local Contexts labels for culturally specific access and reuse expectations.\n- Future local validation: praticiens, ateliers, musiciens, autorités culturelles et droits audio/vidéo.\n"
        },
        "records": [
            {
                "id": "great-lakes-drums-sound-rights",
                "module": "sound",
                "title": "Tambours: son, contexte et droits",
                "kind": "sound-workflow",
                "region": "great-lakes",
                "summary": "Workflow pour différencier démonstration publique, pratique d'apprentissage, cérémonie et contenu à accès restreint.",
                "tags": ["sound", "drums", "ceremony", "media-rights", "community-review"],
                "source": "sources/great-lakes-drums.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "und",
                "country": "Burundi; Rwanda; Uganda; DRC; Tanzania",
                "cultural_protocol": {
                    "sensitivity": "community",
                    "access": "local-first",
                    "protocols": ["CARE", "source-context-consent", "community-review-before-publication", "media-rights-required"],
                    "publication": "draft-local"
                }
            },
            {
                "id": "great-lakes-drums-museum-object",
                "module": "museum",
                "title": "Objet sonore: fiche musée locale",
                "kind": "museum-template",
                "region": "great-lakes",
                "summary": "Fiche pour documenter un instrument avec fabricant, matière, usage, statut de reproduction photo et lien vers récit sonore validé.",
                "tags": ["museum", "object", "instrument", "photo-rights", "archive"],
                "source": "sources/great-lakes-drums.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "fr",
                "country": "great-lakes",
                "cultural_protocol": {
                    "sensitivity": "community",
                    "access": "local-first",
                    "protocols": ["CARE", "source-context-consent", "creator-permission-required", "community-review-before-publication"],
                    "publication": "draft-local"
                }
            }
        ],
    },
    {
        "name": "horn-manuscripts-coffee",
        "title": "Horn Manuscripts & Coffee Starter Pack",
        "description": "Manuscrits, alphabets, café, hospitalité, archives familiales et niveaux de confidentialité.",
        "curator": "SevenOS Baobab",
        "license": "CC-BY-SA-4.0-metadata",
        "source_notes": "Starter pack: aucune image de manuscrit, rituel ou document familial ne doit être publiée sans source, droits et autorité claire.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/horn-manuscripts-coffee.md": "# Sources - Horn Manuscripts & Coffee\n\n- Unicode CLDR for locale orientation where applicable.\n- CARE and Local Contexts for cultural governance and rights.\n- Future local validation: familles, archivistes, chercheurs, praticiens, locuteurs et détenteurs d'objets.\n"
        },
        "records": [
            {
                "id": "horn-manuscripts-archive-protocol",
                "module": "heritage",
                "title": "Manuscrits et archives: protocole avant image",
                "kind": "archive-protocol",
                "region": "horn-of-africa",
                "summary": "Parcours pour décrire une archive sans publier l'image: propriétaire, autorité, langue, date approximative, interdits, niveau de diffusion.",
                "tags": ["archive", "manuscript", "rights", "sensitive", "metadata-only"],
                "source": "sources/horn-manuscripts-coffee.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "und",
                "country": "Ethiopia; Eritrea; Somalia; Djibouti",
                "cultural_protocol": {
                    "sensitivity": "sacred-restricted",
                    "access": "local-only",
                    "protocols": ["CARE", "source-context-consent", "authority-to-control", "restricted-content-review"],
                    "publication": "local-protected"
                }
            },
            {
                "id": "horn-coffee-hospitality",
                "module": "food",
                "title": "Café, hospitalité et récit familial",
                "kind": "food-ritual-workflow",
                "region": "horn-of-africa",
                "summary": "Fiche de collecte pour documenter gestes, mots, objets, invités, photos autorisées et contexte familial d'une préparation de café.",
                "tags": ["food", "coffee", "hospitality", "family-memory", "photo-rights"],
                "source": "sources/horn-manuscripts-coffee.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "und",
                "country": "Ethiopia; Eritrea",
                "cultural_protocol": {
                    "sensitivity": "family",
                    "access": "local-first",
                    "protocols": ["CARE", "source-context-consent", "family-review-before-publication"],
                    "publication": "draft-local"
                }
            }
        ],
    },
    {
        "name": "kongo-atlantic-memory",
        "title": "Kongo Atlantic Memory Starter Pack",
        "description": "Mémoires atlantiques, langues kongo, objets, lignages, musique et archives de transmission.",
        "curator": "SevenOS Baobab",
        "license": "CC-BY-SA-4.0-metadata",
        "source_notes": "Starter pack: privilégier les récits validés, éviter les généralisations et classer les contenus familiaux/communautaires avec prudence.",
        "community_review": "starter-review-needed",
        "sources": {
            "sources/kongo-atlantic-memory.md": "# Sources - Kongo Atlantic Memory\n\n- CARE principles for collective benefit and authority to control.\n- Local Contexts labels to clarify culturally specific access and use.\n- Future local validation: familles, chercheurs, artistes, associations, locuteurs et archives locales.\n"
        },
        "records": [
            {
                "id": "kongo-atlantic-memory-map",
                "module": "explore",
                "title": "Carte sensible: lieux, routes et mémoire",
                "kind": "map-workflow",
                "region": "central-africa-atlantic",
                "summary": "Modèle de carte qui sépare lieu public, lieu familial, lieu de mémoire sensible et point non publiable.",
                "tags": ["map", "memory", "atlantic", "sensitive-place", "review-needed"],
                "source": "sources/kongo-atlantic-memory.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "fr",
                "country": "Angola; Congo; DRC; Gabon",
                "cultural_protocol": {
                    "sensitivity": "community",
                    "access": "local-first",
                    "protocols": ["CARE", "source-context-consent", "community-review-before-publication", "location-sensitivity-review"],
                    "publication": "draft-local"
                }
            },
            {
                "id": "kongo-atlantic-memory-language",
                "module": "languages",
                "title": "Langues kongo: variantes et locuteurs",
                "kind": "language-workflow",
                "region": "central-africa-atlantic",
                "summary": "Base pour collecter variantes, prononciation, familles de mots et contexte d'usage avec validation par locuteurs.",
                "tags": ["language", "kongo", "variants", "audio-needed", "local-speaker"],
                "source": "sources/kongo-atlantic-memory.md",
                "license": "custom-local",
                "curator": "SevenOS Baobab",
                "confidence": "starter",
                "language": "kg",
                "country": "Angola; Congo; DRC; Gabon",
                "cultural_protocol": {
                    "sensitivity": "community",
                    "access": "local-first",
                    "protocols": ["CLDR", "CARE", "source-context-consent", "local-speaker-validation"],
                    "publication": "draft-local"
                }
            }
        ],
    },
]

catalog = json.loads(catalog_path.read_text(encoding="utf-8")) if catalog_path.exists() else {"schema": "sevenos.baobab.catalog.v1", "records": [], "packs": []}
records = catalog.setdefault("records", [])
existing = {item.get("id") for item in records}
catalog_packs = catalog.setdefault("packs", [])
created = []
imported = []

for pack in packs:
    pack_dir = packs_dir / pack["name"]
    sources = pack.pop("sources")
    pack_dir.mkdir(parents=True, exist_ok=True)
    (pack_dir / "sources").mkdir(exist_ok=True)
    for relative, content in sources.items():
        path = pack_dir / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            path.write_text(content, encoding="utf-8")
    payload = {"schema": "sevenos.baobab.pack.v1", **pack}
    pack_file = pack_dir / "pack.json"
    pack_file.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    created.append(str(pack_file))
    if pack["name"] not in catalog_packs:
        catalog_packs.append(pack["name"])
    for record in pack["records"]:
        if record["id"] not in existing:
            item = dict(record)
            item["source_pack"] = pack["name"]
            records.append(item)
            existing.add(record["id"])
            imported.append(record["id"])

catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
payload = {
    "schema": "sevenos.baobab.seed-packs.v1",
    "created": created,
    "imported": imported,
    "packs": [pack["name"] for pack in packs],
    "catalog": str(catalog_path),
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab curated starter packs ready")
    print("==================================")
    print(f"Packs: {', '.join(payload['packs'])}")
    print(f"Imported records: {len(imported)}")
PY
  sync_database
  write_village_html
  write_heritage_html
  write_museum_html
  write_story_html
  write_explore_html
}

enrich_packs() {
  bootstrap_baobab >/dev/null
  PACKS_DIR="$PACKS_DIR" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
updated = []
created_files = []

common_files = {
    "interviews/interview-template.md": """# Entretien culturel Baobab

## Personne rencontrée
- Nom ou pseudonyme:
- Communauté / lieu:
- Langue(s):
- Contact optionnel:

## Consentement
- La personne accepte-t-elle l'archivage local ? oui/non
- La personne accepte-t-elle la diffusion publique ? oui/non
- Restrictions:

## Récit
- Sujet:
- Transcription:
- Notes de contexte:

## Validation
- Validateur local:
- Date:
""",
	    "consent/consent-template.md": """# Consentement et droits

Ce fichier doit documenter l'autorisation avant d'ajouter une interview, une photo,
un son, une recette familiale ou une fiche créateur dans Baobab.

- Pack:
- Élément:
- Auteur / détenteur:
- Usage autorisé:
- Usage interdit:
- Licence:
- Sensibilité: public / familial / communautaire / sacré-réservé / à clarifier
- Publication: locale seulement / partage communautaire / public / ne pas publier
- Date:
- Signature ou validation locale:
""",
    "media/media-manifest.json": """{
  "schema": "sevenos.baobab.media-manifest.v1",
  "items": []
}
""",
	    "validation/community-review.md": """# Validation communautaire

## Checklist
- [ ] Source identifiée
- [ ] Permission documentée
- [ ] Niveau de sensibilité choisi
- [ ] Publication autorisée ou refusée explicitement
- [ ] Langue et pays renseignés
- [ ] Contexte culturel relu
- [ ] Média vérifié avant diffusion
- [ ] Validateur local noté

## Notes

""",
}

module_files = {
    "food": {
        "recipes/recipe-template.md": """# Recette Baobab

- Nom du plat:
- Pays / région:
- Langue locale:
- Personne source:
- Occasion:
- Ingrédients:
- Étapes:
- Variantes:
- Histoire familiale:
- Permission:
"""
    },
    "sound": {
        "audio/audio-manifest.json": """{
  "schema": "sevenos.baobab.audio-manifest.v1",
  "items": []
}
""",
        "audio/recording-notes.md": """# Notes audio Baobab

- Instrument / chant / récit:
- Interprète ou source:
- Lieu:
- Date:
- Langue:
- Permission:
- Restrictions:
"""
    },
    "fashion": {
        "creators/creator-template.md": """# Créateur / textile Baobab

- Nom:
- Pays / région:
- Textile / technique:
- Histoire:
- Photos autorisées:
- Conditions d'utilisation:
- Lien ElegantStyle:
"""
    },
}

for pack_file in sorted(packs_dir.glob("*/pack.json")):
    try:
        pack = json.loads(pack_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    pack_dir = pack_file.parent
    modules = {record.get("module") for record in pack.get("records", [])}
    for relative, content in common_files.items():
        path = pack_dir / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            path.write_text(content, encoding="utf-8")
            created_files.append(str(path))
    for module in modules:
        for relative, content in module_files.get(module, {}).items():
            path = pack_dir / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists():
                path.write_text(content, encoding="utf-8")
                created_files.append(str(path))
    pack["living_status"] = "collection-ready"
    pack["governance"] = {
        "principles": ["CARE", "Local Contexts inspired protocol awareness"],
        "sensitivity_required": True,
        "default_publication": "draft-local",
        "sacred_or_restricted": "do-not-publish",
    }
    pack["evidence"] = {
        "interviews": "interviews/",
        "consent": "consent/",
        "media_manifest": "media/media-manifest.json",
        "community_review": "validation/community-review.md",
    }
    if "food" in modules:
        pack["evidence"]["recipes"] = "recipes/"
    if "sound" in modules:
        pack["evidence"]["audio_manifest"] = "audio/audio-manifest.json"
    if "fashion" in modules:
        pack["evidence"]["creators"] = "creators/"
    pack_file.write_text(json.dumps(pack, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    updated.append(pack.get("name", pack_dir.name))

payload = {
    "schema": "sevenos.baobab.enrich-packs.v1",
    "updated": updated,
    "created_files": created_files,
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab living collection workflow ready")
    print("=======================================")
    print(f"Packs updated: {len(updated)}")
    print(f"Files created: {len(created_files)}")
PY
}

evidence_packs() {
  enrich_packs >/dev/null
  PACKS_DIR="$PACKS_DIR" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
created = []
updated = []

for pack_file in sorted(packs_dir.glob("*/pack.json")):
    try:
        pack = json.loads(pack_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    pack_dir = pack_file.parent
    pack_name = pack.get("name", pack_dir.name)
    modules = sorted({record.get("module", "heritage") for record in pack.get("records", [])})
    records = pack.get("records", [])

    public_note = pack_dir / "interviews/public-source-note.md"
    public_note.parent.mkdir(parents=True, exist_ok=True)
    source_lines = [
        "# Source publique / note documentaire",
        "",
        "Cette note n'est pas une interview communautaire.",
        "Elle documente uniquement les sources publiques et les limites de publication",
        "pour sortir le pack de l'état vide sans prétendre à une validation terrain.",
        "",
        f"- Pack: {pack_name}",
        f"- Modules: {', '.join(modules)}",
        f"- Statut: public-source-only",
        "",
        "## Enregistrements",
    ]
    for record in records:
        source_lines.append(f"- {record.get('id')}: {record.get('title')} · source: {record.get('source')} · sensibilité: {(record.get('cultural_protocol') or {}).get('sensitivity', 'unknown')}")
    public_note.write_text("\n".join(source_lines) + "\n", encoding="utf-8")
    created.append(str(public_note))

    rights_note = pack_dir / "consent/public-source-rights.md"
    rights_note.parent.mkdir(parents=True, exist_ok=True)
    rights_note.write_text(
        "# Droits et limites - sources publiques\n\n"
        "Ce fichier ne remplace pas un consentement communautaire.\n"
        "Il indique que Baobab peut utiliser les métadonnées publiques du pack pour l'orientation locale,\n"
        "mais que les médias, voix, photos, recettes familiales, rites et contenus sensibles restent bloqués\n"
        "jusqu'à consentement et relecture locale.\n\n"
        f"- Pack: {pack_name}\n"
        f"- Licence métadonnées: {pack.get('license', 'custom-local')}\n"
        "- Publication par défaut: locale / brouillon\n"
        "- Validation communautaire: non acquise\n",
        encoding="utf-8",
    )
    created.append(str(rights_note))

    media_manifest = pack_dir / "media/media-manifest.json"
    media_manifest.parent.mkdir(parents=True, exist_ok=True)
    items = []
    for record in records:
        protocol = record.get("cultural_protocol") or {}
        items.append({
            "id": f"{record.get('id')}-metadata",
            "kind": "metadata",
            "record": record.get("id"),
            "path": record.get("source", "sources/README.md"),
            "rights": record.get("license", pack.get("license", "custom-local")),
            "status": "public-source" if protocol.get("sensitivity") == "public" else "local-protected-metadata",
            "publication": protocol.get("publication", "draft-local"),
        })
    media_manifest.write_text(json.dumps({"schema": "sevenos.baobab.media-manifest.v1", "items": items}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    created.append(str(media_manifest))

    if "food" in modules:
        recipe_note = pack_dir / "recipes/public-source-recipe-note.md"
        recipe_note.parent.mkdir(parents=True, exist_ok=True)
        recipe_note.write_text(
            "# Note cuisine - source publique\n\n"
            "Cette note ne remplace pas une recette familiale validée.\n"
            "Elle sert à préparer le parcours cuisine avec sources, droits, variantes et entretien futur.\n\n"
            f"- Pack: {pack_name}\n"
            "- Statut: public-source-only\n",
            encoding="utf-8",
        )
        created.append(str(recipe_note))

    if "sound" in modules:
        audio_note = pack_dir / "audio/public-source-audio-note.md"
        audio_note.parent.mkdir(parents=True, exist_ok=True)
        audio_note.write_text(
            "# Note sonore - source publique\n\n"
            "Cette note ne remplace pas un enregistrement autorisé.\n"
            "Elle prépare le contexte sonore, les droits, les interprètes à contacter et les restrictions.\n\n"
            f"- Pack: {pack_name}\n"
            "- Statut: public-source-only\n",
            encoding="utf-8",
        )
        audio_manifest = pack_dir / "audio/audio-manifest.json"
        audio_manifest.write_text(json.dumps({
            "schema": "sevenos.baobab.audio-manifest.v1",
            "items": [
                {
                    "id": f"{pack_name}-public-source-audio-note",
                    "kind": "audio-metadata",
                    "path": "audio/public-source-audio-note.md",
                    "rights": "metadata-only",
                    "status": "public-source",
                }
            ],
        }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        created.extend([str(audio_note), str(audio_manifest)])

    if "fashion" in modules:
        creator_note = pack_dir / "creators/public-source-creator-note.md"
        creator_note.parent.mkdir(parents=True, exist_ok=True)
        creator_note.write_text(
            "# Note créateur / textile - source publique\n\n"
            "Cette note ne remplace pas une autorisation de créateur, d'atelier ou de coopérative.\n"
            "Elle prépare les droits photo, les conditions d'usage et les personnes ressources.\n\n"
            f"- Pack: {pack_name}\n"
            "- Statut: public-source-only\n",
            encoding="utf-8",
        )
        created.append(str(creator_note))

    review = pack_dir / "validation/community-review.md"
    review.parent.mkdir(parents=True, exist_ok=True)
    review_text = review.read_text(encoding="utf-8") if review.exists() else "# Validation communautaire\n\n"
    marker = "## Public source evidence kit"
    if marker not in review_text:
        review_text += (
            "\n## Public source evidence kit\n"
            "- [x] Source publique ou note documentaire créée\n"
            "- [x] Sensibilité culturelle renseignée par enregistrement\n"
            "- [x] Politique local-first appliquée\n"
            "- [x] Manifest média-métadonnées créé\n"
            "- [ ] Interview communautaire réelle ajoutée\n"
            "- [ ] Consentement réel ajouté\n"
            "- [ ] Relecture locale signée ou nommée\n"
        )
    review.write_text(review_text, encoding="utf-8")
    created.append(str(review))

    pack["evidence_state"] = "public-source-ready"
    pack["evidence_note"] = "Public-source documentation exists; community validation still requires real fieldwork."
    pack["evidence"] = pack.get("evidence") or {}
    pack["evidence"].update({
        "public_source_note": "interviews/public-source-note.md",
        "public_source_rights": "consent/public-source-rights.md",
        "media_manifest": "media/media-manifest.json",
        "community_review": "validation/community-review.md",
    })
    pack_file.write_text(json.dumps(pack, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    updated.append(pack_name)

payload = {
    "schema": "sevenos.baobab.evidence-packs.v1",
    "state": "ready",
    "updated": updated,
    "created": sorted(set(created)),
    "meaning": {
        "public_source_ready": "The pack is no longer empty: it has source notes, rights limits, metadata manifests and protocol review.",
        "not_community_validated": "This does not claim real interviews, consent, media rights or community validation.",
        "next": "Replace public-source notes with real fieldwork when a community, family, creator or speaker validates it.",
    },
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab public-source evidence kits ready")
    print("=======================================")
    print(f"Packs updated: {len(updated)}")
    print("Community validation is still separate and must come from real fieldwork.")
PY
}

sample_fieldwork() {
  enrich_packs >/dev/null
  PACKS_DIR="$PACKS_DIR" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
created = []

samples = {
    "burkina-food": {
        "interviews/sample-field-note.md": "# EXEMPLE - Entretien cuisine\n\nCeci est un exemple de collecte, pas une vraie interview.\n\n- Sujet: mémoire familiale autour du tô et du riz gras\n- Statut: sample\n- À remplacer par: entretien réel + consentement signé/localement validé\n",
        "consent/sample-consent.md": "# EXEMPLE - Consentement\n\nCeci est un exemple non valide juridiquement.\n\n- Usage autorisé: démonstration locale\n- Statut: sample\n",
        "recipes/sample-recipe.md": "# EXEMPLE - Recette à remplacer\n\n- Nom du plat: Exemple de fiche cuisine\n- Pays / région: Burkina Faso\n- Ingrédients: à compléter avec une vraie source\n- Étapes: à compléter\n- Histoire familiale: à collecter\n- Permission: sample uniquement\n",
        "media/media-manifest.json": {
            "schema": "sevenos.baobab.media-manifest.v1",
            "items": [
                {"id": "sample-burkina-food-note", "kind": "note", "path": "recipes/sample-recipe.md", "rights": "sample-only", "status": "sample"}
            ],
        },
    },
    "mandingue-sound": {
        "interviews/sample-field-note.md": "# EXEMPLE - Entretien sonore\n\nCeci est un exemple de collecte, pas une vraie interview.\n\n- Sujet: transmission du balafon\n- Statut: sample\n- À remplacer par: musicien, griot, facteur d'instrument ou archive autorisée\n",
        "consent/sample-consent.md": "# EXEMPLE - Consentement audio\n\nCeci est un exemple non valide juridiquement.\n\n- Usage autorisé: démonstration locale\n- Statut: sample\n",
        "audio/recording-sample-note.md": "# EXEMPLE - Note d'enregistrement\n\n- Instrument / chant / récit: balafon\n- Interprète ou source: à collecter\n- Permission: sample uniquement\n",
        "audio/audio-manifest.json": {
            "schema": "sevenos.baobab.audio-manifest.v1",
            "items": [
                {"id": "sample-mandingue-sound-note", "kind": "note", "path": "audio/recording-sample-note.md", "rights": "sample-only", "status": "sample"}
            ],
        },
        "media/media-manifest.json": {
            "schema": "sevenos.baobab.media-manifest.v1",
            "items": [
                {"id": "sample-mandingue-sound-note", "kind": "audio-note", "path": "audio/recording-sample-note.md", "rights": "sample-only", "status": "sample"}
            ],
        },
    },
    "faso-danfani-fashion": {
        "interviews/sample-field-note.md": "# EXEMPLE - Entretien textile\n\nCeci est un exemple de collecte, pas une vraie interview.\n\n- Sujet: Faso Danfani, tissage, création contemporaine\n- Statut: sample\n- À remplacer par: tisserand, styliste, coopérative ou source autorisée\n",
        "consent/sample-consent.md": "# EXEMPLE - Consentement image/textile\n\nCeci est un exemple non valide juridiquement.\n\n- Usage autorisé: démonstration locale\n- Statut: sample\n",
        "creators/sample-creator.md": "# EXEMPLE - Fiche créateur à remplacer\n\n- Nom: Exemple\n- Pays / région: Burkina Faso\n- Textile / technique: Faso Danfani\n- Photos autorisées: non, sample\n- Conditions d'utilisation: à définir\n",
        "media/media-manifest.json": {
            "schema": "sevenos.baobab.media-manifest.v1",
            "items": [
                {"id": "sample-faso-danfani-creator", "kind": "creator-note", "path": "creators/sample-creator.md", "rights": "sample-only", "status": "sample"}
            ],
        },
    },
}

for pack_name, files in samples.items():
    pack_dir = packs_dir / pack_name
    if not pack_dir.exists():
        continue
    review = pack_dir / "validation/community-review.md"
    if review.exists():
        text = review.read_text(encoding="utf-8")
        if "Sample demo only" not in text:
            text += "\n## Sample demo only\n- [x] Démonstration marquée sample, à remplacer par validation réelle.\n"
            review.write_text(text, encoding="utf-8")
            created.append(str(review))
    for relative, content in files.items():
        path = pack_dir / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, dict):
            path.write_text(json.dumps(content, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        elif not path.exists():
            path.write_text(content, encoding="utf-8")
        created.append(str(path))

payload = {
    "schema": "sevenos.baobab.sample-fieldwork.v1",
    "created": sorted(set(created)),
    "note": "Sample files are explicitly marked sample-only and must be replaced by real interviews, permissions and media.",
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab sample fieldwork created")
    print("===============================")
    print("Sample-only files were created. Replace them with real interviews, consent and media.")
    print(f"Files: {len(payload['created'])}")
PY
}

audit_packs() {
  bootstrap_baobab >/dev/null
  PACKS_DIR="$PACKS_DIR" BAOBAB_CATALOG="$CONTENT_INDEX" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

packs_dir = Path(os.environ["PACKS_DIR"])
catalog_path = Path(os.environ["BAOBAB_CATALOG"])
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
catalog_ids = {item.get("id") for item in catalog.get("records", [])}
catalog_by_id = {item.get("id"): item for item in catalog.get("records", [])}
valid_modules = {"heritage", "story", "sound", "explore", "museum", "languages", "fashion", "food", "wisdom", "market"}
confidence_levels = {"draft", "starter", "low", "medium", "high", "community-validated"}
pack_required = {"schema", "name", "title", "description", "curator", "license", "source_notes", "records"}
record_required = {"id", "module", "title", "kind", "region", "summary", "tags", "source", "license", "curator", "confidence", "language", "country"}
evidence_paths = ("interviews", "consent", "media_manifest", "community_review")
valid_sensitivity = {"public", "family", "community", "sacred-restricted", "unknown"}
reports = []
errors = 0
warnings = 0
seen = set()

for pack_file in sorted(packs_dir.glob("*/pack.json")):
    pack_errors = []
    pack_warnings = []
    try:
        pack = json.loads(pack_file.read_text(encoding="utf-8"))
    except Exception as exc:
        reports.append({"name": pack_file.parent.name, "path": str(pack_file), "score": 0, "errors": [f"invalid json: {exc}"], "warnings": [], "records": 0})
        errors += 1
        continue

    missing_pack = sorted(field for field in pack_required if not pack.get(field))
    if missing_pack:
        pack_errors.append(f"missing pack fields: {', '.join(missing_pack)}")
    if pack.get("schema") != "sevenos.baobab.pack.v1":
        pack_errors.append("invalid schema")
    evidence = pack.get("evidence") or {}
    living_checks = 0
    living_ready = 0
    if not evidence:
        pack_warnings.append("missing living evidence workflow: run seven baobab enrich-packs")
    for key in evidence_paths:
        living_checks += 1
        value = evidence.get(key)
        if not value:
            pack_warnings.append(f"missing evidence field: {key}")
            continue
        target = pack_file.parent / value
        if target.exists():
            living_ready += 1
        else:
            pack_warnings.append(f"evidence path missing: {value}")
    modules = {record.get("module") for record in pack.get("records", [])}
    collection_checks = []
    collection_ready = 0
    sample_count = 0
    public_source_count = 0
    real_collection_ready = 0

    interview_files = [path for path in (pack_file.parent / "interviews").glob("*.md") if path.name != "interview-template.md"]
    sample_count += sum(1 for path in interview_files if "sample" in path.name.lower())
    public_source_count += sum(1 for path in interview_files if "public-source" in path.name.lower())
    collection_checks.append("interviews")
    collection_ready += 1 if interview_files else 0
    real_collection_ready += 1 if any("sample" not in path.name.lower() and "public-source" not in path.name.lower() for path in interview_files) else 0

    consent_files = [path for path in (pack_file.parent / "consent").glob("*.md") if path.name != "consent-template.md"]
    sample_count += sum(1 for path in consent_files if "sample" in path.name.lower())
    public_source_count += sum(1 for path in consent_files if "public-source" in path.name.lower())
    collection_checks.append("consent")
    collection_ready += 1 if consent_files else 0
    real_collection_ready += 1 if any("sample" not in path.name.lower() and "public-source" not in path.name.lower() for path in consent_files) else 0

    media_manifest = pack_file.parent / "media/media-manifest.json"
    media_items = []
    if media_manifest.exists():
        try:
            media_items = json.loads(media_manifest.read_text(encoding="utf-8")).get("items", [])
        except Exception:
            media_items = []
    collection_checks.append("media")
    collection_ready += 1 if media_items else 0
    sample_count += sum(1 for item in media_items if item.get("status") == "sample" or item.get("rights") == "sample-only")
    public_source_count += sum(1 for item in media_items if str(item.get("status", "")).startswith("public-source") or str(item.get("status", "")).startswith("local-protected"))
    real_collection_ready += 1 if any(item.get("status") not in {"sample", "public-source", "local-protected-metadata"} and item.get("rights") != "sample-only" for item in media_items) else 0

    review_file = pack_file.parent / "validation/community-review.md"
    review_text = review_file.read_text(encoding="utf-8").lower() if review_file.exists() else ""
    attestations = []
    for attestation_file in (pack_file.parent / "validation/attestations").glob("*.json"):
        if attestation_file.name == "attestation-template.json":
            continue
        try:
            payload = json.loads(attestation_file.read_text(encoding="utf-8"))
        except Exception:
            continue
        validator = payload.get("validator") or {}
        statements = payload.get("statements") or {}
        if (
            payload.get("record_id")
            and validator.get("display_name")
            and validator.get("role")
            and payload.get("decision") in {"validated-local", "validated-community", "do-not-publish", "revise"}
            and payload.get("date")
            and payload.get("local_signature")
            and all(statements.get(key) is True for key in ("source_reviewed", "context_reviewed", "rights_reviewed", "publication_reviewed"))
        ):
            attestations.append(payload)
    collection_checks.append("community_review")
    collection_ready += 1 if "- [x]" in review_text else 0
    public_source_count += 1 if "public source evidence kit" in review_text else 0
    real_collection_ready += 1 if attestations else 0

    if "food" in modules:
        recipe_files = [path for path in (pack_file.parent / "recipes").glob("*.md") if path.name != "recipe-template.md"]
        sample_count += sum(1 for path in recipe_files if "sample" in path.name.lower())
        collection_checks.append("recipes")
        collection_ready += 1 if recipe_files else 0
        real_collection_ready += 1 if any("sample" not in path.name.lower() and "public-source" not in path.name.lower() for path in recipe_files) else 0
    if "sound" in modules:
        audio_manifest = pack_file.parent / "audio/audio-manifest.json"
        audio_items = []
        if audio_manifest.exists():
            try:
                audio_items = json.loads(audio_manifest.read_text(encoding="utf-8")).get("items", [])
            except Exception:
                audio_items = []
        audio_files = []
        for suffix in ("*.mp3", "*.ogg", "*.flac", "*.wav", "*.m4a"):
            audio_files.extend((pack_file.parent / "audio").glob(suffix))
        collection_checks.append("audio")
        collection_ready += 1 if audio_items or audio_files else 0
        sample_count += sum(1 for item in audio_items if item.get("status") == "sample" or item.get("rights") == "sample-only")
        public_source_count += sum(1 for item in audio_items if str(item.get("status", "")).startswith("public-source") or str(item.get("status", "")).startswith("local-protected"))
        real_collection_ready += 1 if audio_files or any(item.get("status") not in {"sample", "public-source", "local-protected-metadata"} and item.get("rights") != "sample-only" for item in audio_items) else 0
    if "fashion" in modules:
        creator_files = [path for path in (pack_file.parent / "creators").glob("*.md") if path.name != "creator-template.md"]
        sample_count += sum(1 for path in creator_files if "sample" in path.name.lower())
        collection_checks.append("creators")
        collection_ready += 1 if creator_files else 0
        real_collection_ready += 1 if any("sample" not in path.name.lower() and "public-source" not in path.name.lower() for path in creator_files) else 0

    for index, record in enumerate(pack.get("records", [])):
        rid = record.get("id") or f"record[{index}]"
        missing_record = sorted(field for field in record_required if not record.get(field))
        if missing_record:
            pack_errors.append(f"{rid}: missing fields: {', '.join(missing_record)}")
        if record.get("module") not in valid_modules:
            pack_errors.append(f"{rid}: invalid module {record.get('module')}")
        if record.get("confidence") not in confidence_levels:
            pack_errors.append(f"{rid}: invalid confidence {record.get('confidence')}")
        if rid in seen:
            pack_errors.append(f"{rid}: duplicate id across packs")
        seen.add(rid)
        catalog_record = catalog_by_id.get(rid, {})
        if rid in catalog_ids and catalog_record.get("source_pack") not in {"", None, pack.get("name")}:
            pack_warnings.append(f"{rid}: already present in catalog")
        tags = record.get("tags") or []
        if record.get("confidence") == "draft":
            pack_warnings.append(f"{rid}: draft confidence")
        if isinstance(tags, list) and "needs-source" in tags:
            pack_warnings.append(f"{rid}: needs source validation")
        source = record.get("source", "")
        if source.startswith("sources/") and not (pack_file.parent / source).exists():
            pack_warnings.append(f"{rid}: source file not found: {source}")
        if record.get("country") in {"local", "pan-african", "unknown"} and record.get("confidence") not in {"draft", "starter"}:
            pack_warnings.append(f"{rid}: high-confidence records should name a specific country or scope")
        protocol = record.get("cultural_protocol") or {}
        if not protocol:
            pack_warnings.append(f"{rid}: missing cultural protocol")
        elif protocol.get("sensitivity", "unknown") not in valid_sensitivity:
            pack_errors.append(f"{rid}: invalid sensitivity {protocol.get('sensitivity')}")
        elif protocol.get("sensitivity") in {"family", "community", "sacred-restricted", "unknown"} and protocol.get("publication") == "public":
            pack_errors.append(f"{rid}: sensitive material cannot be public by default")

    pack_error_count = len(pack_errors)
    pack_warning_count = len(pack_warnings)
    errors += pack_error_count
    warnings += pack_warning_count
    score = max(0, 100 - pack_error_count * 25 - pack_warning_count * 5)
    living_score = round((living_ready / living_checks) * 100) if living_checks else 0
    collection_score = round((collection_ready / len(collection_checks)) * 100) if collection_checks else 0
    community_validation_score = round((real_collection_ready / len(collection_checks)) * 100) if collection_checks else 0
    if collection_score == 0:
        collection_status = "empty"
    elif collection_score < 100:
        collection_status = "partial"
    else:
        collection_status = "field-ready" if community_validation_score >= 100 else "public-source-ready"
    if sample_count and collection_score:
        fieldwork_state = "sample-only"
    elif public_source_count and not community_validation_score:
        fieldwork_state = "public-source-only"
    else:
        fieldwork_state = collection_status
    reports.append({
        "name": pack.get("name", pack_file.parent.name),
        "path": str(pack_file),
        "score": score,
        "living_score": living_score,
        "living_status": pack.get("living_status", "not-ready"),
        "collection_score": collection_score,
        "community_validation_score": community_validation_score,
        "collection_status": collection_status,
        "collection_checks": collection_checks,
        "sample_count": sample_count,
        "public_source_count": public_source_count,
        "attestation_count": len(attestations),
        "fieldwork_state": fieldwork_state,
        "records": len(pack.get("records", [])),
        "errors": pack_errors,
        "warnings": pack_warnings,
    })

overall = max(0, 100 - errors * 20 - warnings * 3)
payload = {
    "schema": "sevenos.baobab.pack-audit.v1",
    "state": "pass" if errors == 0 else "fail",
    "score": overall,
    "packs": reports,
    "errors": errors,
    "warnings": warnings,
    "rules": {
        "required_pack_fields": sorted(pack_required),
        "required_record_fields": sorted(record_required),
        "confidence_levels": sorted(confidence_levels),
        "living_evidence_fields": list(evidence_paths),
	        "collection_fields": ["interviews", "consent", "media", "community_review", "recipes", "audio", "creators"],
	        "sensitivity_levels": sorted(valid_sensitivity),
	    },
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2))
else:
    print("Baobab Pack Audit")
    print("=================")
    print(f"State: {payload['state']}")
    print(f"Score: {payload['score']}%")
    print(f"Errors: {errors}")
    print(f"Warnings: {warnings}")
    print()
    for report in reports:
        print(f"- {report['name']}: {report['score']}% · workflow {report['living_score']}% · collection {report['collection_score']}% ({report['records']} records)")
        for item in report["errors"]:
            print(f"  ERROR: {item}")
        for item in report["warnings"][:6]:
            print(f"  WARN: {item}")
PY
}

import_pack() {
  local target="${1:-}" pack_file
  if [[ -z "$target" ]]; then
    log_error "Missing pack path."
    return 1
  fi
  bootstrap_baobab >/dev/null
  if [[ -d "$target" ]]; then
    pack_file="$target/pack.json"
  else
    pack_file="$target"
  fi
  if [[ ! -s "$pack_file" ]]; then
    log_error "Pack file not found: $pack_file"
    return 1
  fi
  BAOBAB_CATALOG="$CONTENT_INDEX" PACK_FILE="$pack_file" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sys
from pathlib import Path

catalog_path = Path(os.environ["BAOBAB_CATALOG"])
pack_path = Path(os.environ["PACK_FILE"])
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
pack = json.loads(pack_path.read_text(encoding="utf-8"))

if pack.get("schema") != "sevenos.baobab.pack.v1":
    print(f"Invalid Baobab pack schema: {pack_path}", file=sys.stderr)
    sys.exit(1)

valid_modules = {"heritage", "story", "sound", "explore", "museum", "languages", "fashion", "food", "wisdom", "market"}
required_record_fields = {"id", "module", "title", "kind", "region", "summary", "tags", "source", "license", "curator", "confidence", "language", "country"}
confidence_levels = {"draft", "starter", "low", "medium", "high", "community-validated"}
existing = {item.get("id") for item in catalog.get("records", [])}
added = []
skipped = []
for record in pack.get("records", []):
    record_id = record.get("id")
    module = record.get("module")
    missing = [field for field in sorted(required_record_fields) if not record.get(field)]
    if missing or module not in valid_modules or record.get("confidence") not in confidence_levels:
        skipped.append(record_id or "<missing-id>")
        continue
    if record_id in existing:
        skipped.append(record_id)
        continue
    item = dict(record)
    item["source_pack"] = pack.get("name", pack_path.parent.name)
    catalog.setdefault("records", []).append(item)
    existing.add(record_id)
    added.append(record_id)

packs = catalog.setdefault("packs", [])
pack_name = pack.get("name", pack_path.parent.name)
if pack_name not in packs:
    packs.append(pack_name)
catalog_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")

payload = {
    "schema": "sevenos.baobab.pack.import.v1",
    "pack": pack_name,
    "added": added,
    "skipped": skipped,
    "catalog": str(catalog_path),
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2))
else:
    print(f"Imported Baobab pack: {pack_name}")
    print(f"Added: {len(added)}")
    print(f"Skipped: {len(skipped)}")
PY
  sync_database
  write_village_html
}

write_village_html() {
  BAOBAB_MANIFEST="$MANIFEST" BAOBAB_CATALOG="$CONTENT_INDEX" COUNTRIES_JSON="$COUNTRIES_JSON" UNESCO_JSON="$UNESCO_JSON" BAOBAB_HTML="$VILLAGE_HTML" python - <<'PY'
import html
import json
import os
from pathlib import Path

manifest = json.loads(Path(os.environ["BAOBAB_MANIFEST"]).read_text(encoding="utf-8"))
catalog = json.loads(Path(os.environ["BAOBAB_CATALOG"]).read_text(encoding="utf-8"))
countries_payload = json.loads(Path(os.environ["COUNTRIES_JSON"]).read_text(encoding="utf-8")) if Path(os.environ["COUNTRIES_JSON"]).exists() else {"countries": []}
unesco_payload = json.loads(Path(os.environ["UNESCO_JSON"]).read_text(encoding="utf-8")) if Path(os.environ["UNESCO_JSON"]).exists() else {"items": []}
cards = []
for place in manifest.get("village", []):
    action = {
        "home": "#daily",
        "heritage": "../Heritage/index.html",
        "wisdom": "../Story%20Engine/index.html",
        "sound": "#heritage",
        "market": "#daily",
        "fashion": "#daily",
        "explore": "../Explore/index.html",
        "food": "#daily",
        "museum": "../Museum%203D/index.html",
    }.get(place["module"], "#daily")
    cards.append(
        f"<a class=\"place\" href=\"{action}\"><span>{html.escape(place['module'])}</span><h2>{html.escape(place['place'])}</h2><p>{html.escape(place['role'])}</p></a>"
    )
records = []
for item in catalog.get("records", []):
    records.append(
        f"<li><b>{html.escape(item['title'])}</b><small>{html.escape(item['module'])} · {html.escape(item['kind'])}</small><p>{html.escape(item['summary'])}</p></li>"
    )
countries = countries_payload.get("countries", [])
unesco_items = unesco_payload.get("items", [])
featured_countries = countries[:8]
featured_unesco = sorted(unesco_items, key=lambda item: item.get("year", ""), reverse=True)[:6]
country_tiles = "".join(
    f"<a class=\"mini\" href=\"../Explore/index.html\"><strong>{html.escape(item.get('flag', ''))} {html.escape(item.get('name', 'Unknown'))}</strong><span>{html.escape(item.get('capital', ''))}</span></a>"
    for item in featured_countries
)
heritage_tiles = "".join(
    f"<a class=\"heritage\" href=\"../Heritage/index.html\"><i>{html.escape(item.get('type_acronym', 'ICH'))}</i><div><strong>{html.escape((item.get('title_en') or item.get('title_fr') or 'Untitled')[:86])}</strong><span>{html.escape(', '.join(item.get('countries', [])))} · {html.escape(item.get('year', ''))}</span></div></a>"
    for item in featured_unesco
)
content = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Baobab Cultural Mini OS</title>
  <style>
    :root {{
      color-scheme: dark;
      --soil:#26170f; --bark:#5b341f; --leaf:#7fb069; --gold:#e6b85c; --sand:#f2d7a0; --ember:#c56b34;
      font-family: Inter, ui-sans-serif, system-ui, sans-serif;
    }}
    * {{ box-sizing: border-box; }}
    body {{ margin:0; color:#fff6df; background: radial-gradient(circle at 18% 8%, rgba(230,184,92,.22), transparent 30%), radial-gradient(circle at 80% 12%, rgba(127,176,105,.16), transparent 28%), linear-gradient(135deg, #120b08, #26170f 48%, #102116); }}
    main {{ max-width: 1240px; margin: 0 auto; padding: 34px 22px 56px; }}
    header {{ min-height: 38vh; display: grid; align-content: end; padding-bottom: 24px; }}
    .topnav {{ display:flex; flex-wrap:wrap; gap:9px; margin-bottom:24px; }}
    .topnav a {{ color:#fff6df; text-decoration:none; min-height:36px; display:inline-flex; align-items:center; padding:8px 11px; border-radius:8px; border:1px solid rgba(242,215,160,.20); background:rgba(255,246,223,.07); }}
    .topnav a.active, .topnav a:hover {{ border-color:rgba(230,184,92,.72); background:rgba(230,184,92,.18); }}
    h1 {{ font-size: clamp(2.3rem, 6vw, 5.6rem); line-height: .95; margin:0; letter-spacing: 0; }}
    header p {{ max-width: 760px; font-size: 1.08rem; color: #f8e6bd; }}
    .actions {{ display:flex; flex-wrap:wrap; gap:10px; margin-top:20px; }}
    .button {{ display:inline-flex; align-items:center; min-height:42px; padding:10px 14px; border-radius:8px; border:1px solid rgba(242,215,160,.24); color:#fff6df; text-decoration:none; background:rgba(255,246,223,.08); }}
    .button.primary {{ background:rgba(230,184,92,.22); border-color:rgba(230,184,92,.62); }}
    .stats {{ display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:12px; margin:6px 0 24px; }}
    .stat {{ padding:14px; border-radius:8px; border:1px solid rgba(242,215,160,.18); background:rgba(18,11,8,.52); }}
    .stat strong {{ display:block; font-size:1.8rem; }}
    .stat span {{ color:#f2d7a0; }}
    .grid {{ display:grid; grid-template-columns: repeat(auto-fit, minmax(210px,1fr)); gap:14px; }}
    .place, section {{ border:1px solid rgba(242,215,160,.20); background: rgba(18,11,8,.58); border-radius:8px; }}
    .place {{ display:block; color:#fff6df; text-decoration:none; padding:18px; min-height: 160px; transition:transform .18s ease, border-color .18s ease, background .18s ease; }}
    .place:hover {{ transform:translateY(-3px); border-color:rgba(230,184,92,.56); background:rgba(38,23,15,.78); }}
    .place span {{ color: var(--gold); font-size:.78rem; text-transform: uppercase; }}
    h2 {{ margin:.45rem 0; font-size:1.18rem; }}
    p {{ color:#ead8b6; line-height:1.52; }}
    section {{ margin-top:22px; padding:22px; }}
    .section-head {{ display:flex; justify-content:space-between; gap:14px; align-items:end; margin-bottom:12px; }}
    .section-head h2 {{ margin:0; }}
    .section-head p {{ margin:0; max-width:600px; }}
    ul {{ display:grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap:12px; padding:0; list-style:none; }}
    li {{ padding:14px; border-left:3px solid var(--leaf); background: rgba(255,246,223,.06); border-radius:6px; }}
    small {{ display:block; color:var(--gold); margin-top:4px; }}
    .mini-grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(170px,1fr)); gap:10px; }}
    .mini {{ display:block; text-decoration:none; color:#fff6df; padding:13px; border-radius:8px; border:1px solid rgba(242,215,160,.16); background:rgba(255,246,223,.06); }}
    .mini span {{ display:block; color:var(--gold); margin-top:4px; }}
    .heritage-grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:12px; }}
    .heritage {{ display:grid; grid-template-columns:84px minmax(0,1fr); gap:12px; align-items:center; color:#fff6df; text-decoration:none; padding:10px; border-radius:8px; border:1px solid rgba(242,215,160,.16); background:rgba(255,246,223,.06); }}
    .heritage i {{ display:grid; place-items:center; width:84px; height:74px; border-radius:6px; background:radial-gradient(circle at 35% 30%, rgba(230,184,92,.55), transparent 34%), linear-gradient(135deg, rgba(127,176,105,.42), rgba(197,107,52,.34)); color:#fff6df; font-style:normal; font-weight:600; }}
    .heritage span {{ display:block; color:#e6b85c; margin-top:5px; }}
    @media (max-width:760px) {{ .stats {{ grid-template-columns:1fr; }} .section-head {{ display:block; }} }}
  </style>
</head>
<body>
  <main>
    <nav class="topnav">
      <a class="active" href="../Village/index.html">Village</a>
      <a href="../Heritage/index.html">Heritage</a>
      <a href="../Explore/index.html">Explore</a>
      <a href="../Museum%203D/index.html">Museum</a>
      <a href="../Story%20Engine/index.html">Story</a>
    </nav>
    <header>
      <h1>Baobab Cultural Mini OS</h1>
      <p>{html.escape(manifest.get('vision', 'African cultural digital ecosystem.'))}</p>
      <nav class="actions">
        <a class="button primary" href="../Explore/index.html">Explore Africa</a>
        <a class="button" href="../Heritage/index.html">Heritage</a>
        <a class="button" href="../Museum%203D/index.html">Museum</a>
        <a class="button" href="../Story%20Engine/index.html">Story Mode</a>
      </nav>
    </header>
    <div class="stats">
      <div class="stat"><strong>{len(countries)}</strong><span>African countries offline</span></div>
      <div class="stat"><strong>{len(unesco_items)}</strong><span>UNESCO ICH entries</span></div>
      <div class="stat"><strong>{len(catalog.get('records', []))}</strong><span>Baobab modules seeded</span></div>
    </div>
    <div class="grid">{''.join(cards)}</div>
    <section id="daily">
      <div class="section-head">
        <h2>Start Here</h2>
        <p>Simple visual doors into Baobab for families, schools, creators and visitors.</p>
      </div>
      <div class="mini-grid">{country_tiles}</div>
    </section>
    <section id="heritage">
      <div class="section-head">
        <h2>Heritage Highlights</h2>
        <p>African-linked UNESCO intangible cultural heritage, mirrored locally for offline discovery.</p>
      </div>
      <div class="heritage-grid">{heritage_tiles}</div>
    </section>
    <section>
      <h2>Offline Starter Catalog</h2>
      <ul>{''.join(records)}</ul>
    </section>
  </main>
</body>
</html>
"""
Path(os.environ["BAOBAB_HTML"]).parent.mkdir(parents=True, exist_ok=True)
Path(os.environ["BAOBAB_HTML"]).write_text(content, encoding="utf-8")
PY
}

write_heritage_html() {
  UNESCO_JSON="$UNESCO_JSON" BAOBAB_HTML="$HERITAGE_HTML" python - <<'PY'
import html
import json
import os
from collections import Counter
from pathlib import Path

payload = json.loads(Path(os.environ["UNESCO_JSON"]).read_text(encoding="utf-8")) if Path(os.environ["UNESCO_JSON"]).exists() else {"items": []}
items = payload.get("items", [])
items_json = json.dumps(items, ensure_ascii=True)
by_country = Counter(country for item in items for country in item.get("countries", []))
country_chips = "".join(f"<button data-country=\"{html.escape(country, quote=True)}\">{html.escape(country)} <span>{count}</span></button>" for country, count in by_country.most_common(18))
cards = []
for item in sorted(items, key=lambda entry: entry.get("year", ""), reverse=True)[:60]:
    title = item.get("title_en") or item.get("title_fr") or "Untitled"
    countries = ", ".join(item.get("countries", []))
    summary = item.get("summary_en") or item.get("summary_fr") or ""
    concepts = ", ".join(item.get("concepts", [])[:3])
    cards.append(
        f"<article data-search=\"{html.escape((title + ' ' + countries + ' ' + ' '.join(item.get('concepts', []))).lower(), quote=True)}\" data-countries=\"{html.escape(countries, quote=True)}\">"
        f"<div class=\"visual\"><strong>{html.escape(item.get('type_acronym', 'ICH'))}</strong><span>{html.escape(item.get('year', ''))}</span></div>"
        f"<div><span>{html.escape(countries)} · {html.escape(concepts)}</span><h2>{html.escape(title)}</h2><p>{html.escape(summary[:260])}</p></div>"
        "</article>"
    )

content = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Baobab Heritage</title>
  <style>
    :root {{ color-scheme:dark; --soil:#160d08; --gold:#e6b85c; --sand:#f2d7a0; --leaf:#7fb069; --water:#74a7c8; font-family:Inter, ui-sans-serif, system-ui, sans-serif; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; color:#fff6df; background:radial-gradient(circle at 20% 0%, rgba(230,184,92,.18), transparent 28%), linear-gradient(135deg,#07130d,#160d08 58%,#26170f); }}
    main {{ max-width:1260px; margin:0 auto; padding:32px 20px 54px; }}
    header {{ min-height:26vh; display:grid; align-content:end; padding-bottom:20px; }}
    nav {{ display:flex; flex-wrap:wrap; gap:9px; margin-bottom:24px; }}
    nav a {{ color:#fff6df; text-decoration:none; min-height:36px; display:inline-flex; align-items:center; padding:8px 11px; border-radius:8px; border:1px solid rgba(242,215,160,.20); background:rgba(255,246,223,.07); }}
    nav a.active, nav a:hover {{ border-color:rgba(230,184,92,.72); background:rgba(230,184,92,.18); }}
    h1 {{ font-size:clamp(2.3rem,6vw,5.2rem); line-height:.95; margin:0; letter-spacing:0; }}
    header p {{ color:#f2d7a0; max-width:780px; line-height:1.55; }}
    .toolbar {{ position:sticky; top:0; z-index:3; display:grid; gap:12px; padding:14px 0; background:linear-gradient(180deg, rgba(7,19,13,.96), rgba(7,19,13,.74)); }}
    input {{ width:100%; min-height:44px; padding:10px 13px; border-radius:8px; border:1px solid rgba(242,215,160,.24); color:#fff6df; background:rgba(18,11,8,.72); outline:none; }}
    .chips {{ display:flex; gap:8px; overflow:auto; padding-bottom:4px; }}
    button {{ white-space:nowrap; min-height:36px; border-radius:8px; border:1px solid rgba(242,215,160,.20); background:rgba(255,246,223,.07); color:#fff6df; padding:8px 11px; cursor:pointer; }}
    button.active, button:hover {{ border-color:rgba(230,184,92,.72); background:rgba(230,184,92,.18); }}
    button span {{ color:#e6b85c; }}
    .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:14px; margin-top:18px; }}
    article {{ overflow:hidden; border-radius:8px; border:1px solid rgba(242,215,160,.18); background:rgba(18,11,8,.66); }}
    .visual {{ min-height:150px; display:grid; place-items:center; align-content:center; gap:7px; background:radial-gradient(circle at 30% 22%, rgba(230,184,92,.48), transparent 28%), radial-gradient(circle at 80% 20%, rgba(116,167,200,.25), transparent 25%), linear-gradient(135deg, rgba(127,176,105,.38), rgba(197,107,52,.32)); }}
    .visual strong {{ font-size:2rem; }}
    .visual span {{ color:#fff6df; opacity:.82; }}
    article div {{ padding:15px; }}
    article span {{ color:var(--gold); font-size:.82rem; }}
    h2 {{ margin:7px 0 9px; font-size:1.12rem; line-height:1.2; }}
    article p {{ color:#ead8b6; line-height:1.48; margin:0; }}
    .empty {{ display:none; padding:20px; border:1px solid rgba(242,215,160,.18); border-radius:8px; color:#f2d7a0; background:rgba(18,11,8,.56); }}
    @media (max-width:760px) {{ .visual {{ min-height:130px; }} }}
  </style>
</head>
<body>
  <main>
    <nav>
      <a href="../Village/index.html">Village</a>
      <a class="active" href="../Heritage/index.html">Heritage</a>
      <a href="../Explore/index.html">Explore</a>
      <a href="../Museum%203D/index.html">Museum</a>
      <a href="../Story%20Engine/index.html">Story</a>
    </nav>
    <header>
      <h1>Baobab Heritage</h1>
      <p>A visual offline gallery of African-linked UNESCO intangible cultural heritage. Built from the local Baobab database for public exploration, classrooms and cultural discovery.</p>
    </header>
    <section class="toolbar">
      <input id="search" type="search" placeholder="Search heritage, country, music, ritual, craft, story...">
      <div class="chips"><button class="active" data-country="">All <span>{len(items)}</span></button>{country_chips}</div>
    </section>
    <section class="grid" id="grid">{''.join(cards)}</section>
    <p class="empty" id="empty">No visible heritage item matches this filter.</p>
  </main>
  <script>
    const items = {items_json};
    const cards = [...document.querySelectorAll('article')];
    const search = document.getElementById('search');
    const empty = document.getElementById('empty');
    let country = '';
    function applyFilter() {{
      const q = search.value.trim().toLowerCase();
      let visible = 0;
      cards.forEach(card => {{
        const text = card.dataset.search || '';
        const countries = card.dataset.countries || '';
        const ok = (!q || text.includes(q)) && (!country || countries.includes(country));
        card.style.display = ok ? '' : 'none';
        if (ok) visible += 1;
      }});
      empty.style.display = visible ? 'none' : 'block';
    }}
    document.querySelectorAll('[data-country]').forEach(button => button.addEventListener('click', () => {{
      country = button.dataset.country;
      document.querySelectorAll('[data-country]').forEach(item => item.classList.toggle('active', item === button));
      applyFilter();
    }}));
    search.addEventListener('input', applyFilter);
  </script>
</body>
</html>
"""
Path(os.environ["BAOBAB_HTML"]).parent.mkdir(parents=True, exist_ok=True)
Path(os.environ["BAOBAB_HTML"]).write_text(content, encoding="utf-8")
PY
}

write_museum_html() {
  BAOBAB_CATALOG="$CONTENT_INDEX" BAOBAB_HTML="$MUSEUM_HTML" python - <<'PY'
import html
import json
import os
from pathlib import Path

catalog = json.loads(Path(os.environ["BAOBAB_CATALOG"]).read_text(encoding="utf-8"))
records = catalog.get("records", [])
scene_records = records[:18]
items_json = json.dumps(scene_records, ensure_ascii=True)
list_items = []
for item in scene_records:
    list_items.append(
        f"<li data-module=\"{html.escape(item.get('module', ''))}\"><b>{html.escape(item.get('title', 'Untitled'))}</b><span>{html.escape(item.get('module', 'unknown'))} / {html.escape(item.get('region', 'unknown'))}</span><p>{html.escape(item.get('summary', ''))}</p></li>"
    )

content = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Baobab Museum 3D</title>
  <style>
    :root {{ color-scheme: dark; --soil:#160d08; --earth:#4f2c19; --gold:#e6b85c; --leaf:#7fb069; --sand:#f2d7a0; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }}
    * {{ box-sizing: border-box; }}
    body {{ margin:0; min-height:100vh; background:#120b08; color:#fff6df; overflow:hidden; }}
    canvas {{ position:fixed; inset:0; width:100vw; height:100vh; display:block; background: radial-gradient(circle at 50% 38%, rgba(230,184,92,.16), transparent 34%), linear-gradient(180deg, #07130d, #160d08 62%, #2b180e); }}
    aside {{ position:fixed; right:18px; top:18px; bottom:18px; width:min(390px, calc(100vw - 36px)); overflow:auto; padding:18px; border:1px solid rgba(242,215,160,.22); border-radius:8px; background:rgba(18,11,8,.70); backdrop-filter:none; }}
    nav {{ display:flex; flex-wrap:wrap; gap:8px; margin-bottom:14px; }}
    nav a {{ color:#fff6df; text-decoration:none; min-height:34px; display:inline-flex; align-items:center; padding:7px 10px; border-radius:8px; border:1px solid rgba(242,215,160,.20); background:rgba(255,246,223,.07); }}
    nav a.active, nav a:hover {{ border-color:rgba(230,184,92,.72); background:rgba(230,184,92,.18); }}
    h1 {{ margin:0; font-size:1.55rem; letter-spacing:0; }}
    .sub {{ color:#f4d997; margin:.35rem 0 1rem; line-height:1.45; }}
    ul {{ list-style:none; padding:0; margin:0; display:grid; gap:10px; }}
    li {{ border-left:3px solid var(--leaf); background:rgba(255,246,223,.07); border-radius:6px; padding:12px; }}
    li b {{ display:block; }}
    li span {{ display:block; color:var(--gold); font-size:.78rem; margin-top:3px; text-transform:uppercase; }}
    li p {{ margin:.55rem 0 0; color:#ead8b6; line-height:1.45; }}
    .hint {{ position:fixed; left:18px; bottom:18px; padding:10px 12px; border-radius:6px; background:rgba(18,11,8,.72); color:#f4d997; border:1px solid rgba(242,215,160,.18); }}
    @media (max-width: 760px) {{ aside {{ top:auto; max-height:48vh; }} .hint {{ display:none; }} }}
  </style>
</head>
<body>
  <canvas id="scene" aria-label="Baobab museum animated scene"></canvas>
  <aside>
    <nav>
      <a href="../Village/index.html">Village</a>
      <a href="../Heritage/index.html">Heritage</a>
      <a href="../Explore/index.html">Explore</a>
      <a class="active" href="../Museum%203D/index.html">Museum</a>
      <a href="../Story%20Engine/index.html">Story</a>
    </nav>
    <h1>Baobab Museum 3D</h1>
    <p class="sub">Offline cultural scene generated from the local Baobab catalog. Each object is a record ready to become a real 3D artifact, archive, story or sound.</p>
    <ul>{''.join(list_items)}</ul>
  </aside>
  <div class="hint">Move the pointer to shift the gallery. Generated locally from <code>baobab.sqlite</code>.</div>
  <script>
    const records = {items_json};
    const canvas = document.getElementById('scene');
    const ctx = canvas.getContext('2d');
    const colors = {{ heritage:'#e6b85c', story:'#c56b34', sound:'#7fb069', explore:'#74a7c8', museum:'#d89b6a', languages:'#a8d7a0', fashion:'#d36f8d', food:'#f2a65a', wisdom:'#c9b8ff', market:'#93d6c5' }};
    let w = 0, h = 0, mx = .5, my = .5, t = 0;
    function resize() {{ w = canvas.width = innerWidth * devicePixelRatio; h = canvas.height = innerHeight * devicePixelRatio; ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0); w = innerWidth; h = innerHeight; }}
    addEventListener('resize', resize); resize();
    addEventListener('pointermove', e => {{ mx = e.clientX / Math.max(1, innerWidth); my = e.clientY / Math.max(1, innerHeight); }});
    function drawTree() {{
      const cx = w * .33 + (mx - .5) * 28;
      const base = h * .74;
      ctx.save();
      ctx.translate(cx, base);
      ctx.fillStyle = '#3f2417';
      ctx.beginPath();
      ctx.moveTo(-34, 0); ctx.bezierCurveTo(-18, -110, -22, -210, 0, -300); ctx.bezierCurveTo(28, -210, 22, -112, 42, 0); ctx.close(); ctx.fill();
      ctx.strokeStyle = 'rgba(242,215,160,.22)'; ctx.lineWidth = 3;
      for (let i=0;i<9;i++) {{ const a = -2.8 + i * .7; ctx.beginPath(); ctx.moveTo(0, -245); ctx.quadraticCurveTo(Math.cos(a)*130, -285 + Math.sin(a)*52, Math.cos(a)*220, -205 + Math.sin(a)*70); ctx.stroke(); }}
      ctx.fillStyle = 'rgba(127,176,105,.42)';
      for (let i=0;i<44;i++) {{ const a=i*.7+t*.001; const r=80+(i%7)*22; ctx.beginPath(); ctx.arc(Math.cos(a)*r, -235+Math.sin(a*1.3)*72, 18+(i%5), 0, Math.PI*2); ctx.fill(); }}
      ctx.restore();
    }}
    function drawArtifacts() {{
      const cx = w * .45 + (mx - .5) * 80;
      const cy = h * .56 + (my - .5) * 44;
      const count = Math.max(records.length, 1);
      records.forEach((item, i) => {{
        const angle = (i / count) * Math.PI * 2 + t * .00035;
        const depth = .55 + .45 * (Math.sin(angle) * .5 + .5);
        const x = cx + Math.cos(angle) * w * .25;
        const y = cy + Math.sin(angle) * h * .16;
        const size = 34 + depth * 34;
        ctx.save();
        ctx.globalAlpha = .55 + depth * .45;
        ctx.translate(x, y);
        ctx.fillStyle = colors[item.module] || '#e6b85c';
        ctx.strokeStyle = 'rgba(255,246,223,.62)';
        ctx.lineWidth = 1.3;
        ctx.beginPath();
        for (let p=0;p<6;p++) {{ const a = Math.PI/6 + p*Math.PI/3; const rr = p%2 ? size*.62 : size; const px=Math.cos(a)*rr; const py=Math.sin(a)*rr; if (p===0) ctx.moveTo(px, py); else ctx.lineTo(px, py); }}
        ctx.closePath(); ctx.fill(); ctx.stroke();
        ctx.fillStyle = '#fff6df'; ctx.font = '600 12px system-ui'; ctx.textAlign = 'center';
        const title = (item.title || item.module || 'record').slice(0, 22);
        ctx.fillText(title, 0, size + 20);
        ctx.restore();
      }});
    }}
    function drawGround() {{
      ctx.strokeStyle = 'rgba(230,184,92,.18)';
      for (let i=0;i<16;i++) {{ const y = h*.72 + i*18; ctx.beginPath(); ctx.moveTo(0, y); ctx.quadraticCurveTo(w*.5, y + Math.sin(t*.001+i)*18, w, y + 4); ctx.stroke(); }}
    }}
    function frame(now) {{ t = now; ctx.clearRect(0,0,w,h); drawGround(); drawTree(); drawArtifacts(); requestAnimationFrame(frame); }}
    requestAnimationFrame(frame);
  </script>
</body>
</html>
"""
Path(os.environ["BAOBAB_HTML"]).parent.mkdir(parents=True, exist_ok=True)
Path(os.environ["BAOBAB_HTML"]).write_text(content, encoding="utf-8")
PY
}

write_story_html() {
  BAOBAB_CATALOG="$CONTENT_INDEX" BAOBAB_HTML="$STORY_HTML" python - <<'PY'
import html
import json
import os
from pathlib import Path

catalog = json.loads(Path(os.environ["BAOBAB_CATALOG"]).read_text(encoding="utf-8"))
records = catalog.get("records", [])
story_records = [item for item in records if item.get("module") in {"heritage", "story", "wisdom", "languages", "food"}] or records
slides = []
buttons = []
for index, item in enumerate(story_records[:12]):
    title = html.escape(item.get("title", "Untitled"))
    module = html.escape(item.get("module", "record"))
    region = html.escape(item.get("region", "unknown"))
    summary = html.escape(item.get("summary", ""))
    active = " active" if index == 0 else ""
    slides.append(f"<section class=\"slide{active}\" data-index=\"{index}\"><p class=\"eyebrow\">{module} / {region}</p><h2>{title}</h2><p>{summary}</p></section>")
    buttons.append(f"<button data-index=\"{index}\" class=\"{'active' if index == 0 else ''}\">{index + 1}</button>")

content = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Baobab Story Mode</title>
  <style>
    :root {{ color-scheme: dark; --night:#100906; --ember:#c56b34; --gold:#e6b85c; --sand:#f2d7a0; --leaf:#7fb069; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; min-height:100vh; color:#fff6df; background: radial-gradient(circle at 50% 72%, rgba(197,107,52,.24), transparent 22%), linear-gradient(180deg, #07130d, #100906 58%, #2a160d); overflow:hidden; }}
    main {{ min-height:100vh; display:grid; grid-template-columns:minmax(0,1fr) 330px; gap:22px; padding:28px; }}
    .stage {{ position:relative; border:1px solid rgba(242,215,160,.18); border-radius:8px; overflow:hidden; background:rgba(16,9,6,.44); }}
    .fire {{ position:absolute; left:50%; bottom:8%; width:190px; height:190px; transform:translateX(-50%); filter: blur(.2px); }}
    .flame {{ position:absolute; bottom:0; left:50%; width:34px; height:118px; transform-origin:bottom center; border-radius:48% 52% 46% 54%; background:linear-gradient(#f9e2af,#c56b34 58%, transparent); opacity:.78; animation:flicker 1.8s infinite ease-in-out; }}
    .flame:nth-child(2) {{ animation-delay:.25s; transform:translateX(-38px) rotate(-12deg); height:92px; }}
    .flame:nth-child(3) {{ animation-delay:.5s; transform:translateX(28px) rotate(14deg); height:104px; }}
    @keyframes flicker {{ 0%,100% {{ transform:translateX(-50%) scaleY(.96) rotate(-2deg); opacity:.62; }} 50% {{ transform:translateX(-50%) scaleY(1.14) rotate(4deg); opacity:.92; }} }}
    .slide {{ position:absolute; inset:0; display:grid; align-content:center; max-width:820px; padding:clamp(26px,7vw,86px); opacity:0; transform:translateY(18px); transition:.36s ease; }}
    .slide.active {{ opacity:1; transform:translateY(0); }}
    .eyebrow {{ color:var(--gold); text-transform:uppercase; font-size:.82rem; letter-spacing:.08em; }}
    h1 {{ margin:0 0 10px; font-size:1.55rem; }}
    nav {{ display:flex; flex-wrap:wrap; gap:8px; margin-bottom:14px; }}
    nav a {{ color:#fff6df; text-decoration:none; min-height:34px; display:inline-flex; align-items:center; padding:7px 10px; border-radius:8px; border:1px solid rgba(242,215,160,.20); background:rgba(255,246,223,.07); }}
    nav a.active, nav a:hover {{ border-color:rgba(230,184,92,.72); background:rgba(230,184,92,.18); }}
    h2 {{ font-size:clamp(2.1rem,6vw,5rem); line-height:.96; margin:.2rem 0 1rem; letter-spacing:0; }}
    .slide p:not(.eyebrow) {{ color:#f3dfbb; font-size:1.08rem; line-height:1.62; max-width:740px; }}
    aside {{ border:1px solid rgba(242,215,160,.18); border-radius:8px; padding:18px; background:rgba(16,9,6,.68); overflow:auto; }}
    .controls {{ display:flex; gap:8px; flex-wrap:wrap; margin:16px 0; }}
    button {{ border:1px solid rgba(242,215,160,.26); color:#fff6df; background:rgba(255,246,223,.08); border-radius:6px; padding:8px 11px; cursor:pointer; }}
    button.active, button:hover {{ background:rgba(230,184,92,.24); border-color:var(--gold); }}
    .note {{ color:#ead8b6; line-height:1.5; }}
    .prompt {{ margin-top:16px; padding:12px; border-left:3px solid var(--leaf); background:rgba(255,246,223,.06); border-radius:6px; color:#f2d7a0; }}
    @media (max-width: 860px) {{ body {{ overflow:auto; }} main {{ grid-template-columns:1fr; }} .stage {{ min-height:68vh; }} }}
  </style>
</head>
<body>
  <main>
    <div class="stage">
      {''.join(slides)}
      <div class="fire"><i class="flame"></i><i class="flame"></i><i class="flame"></i></div>
    </div>
    <aside>
      <nav>
        <a href="../Village/index.html">Village</a>
        <a href="../Heritage/index.html">Heritage</a>
        <a href="../Explore/index.html">Explore</a>
        <a href="../Museum%203D/index.html">Museum</a>
        <a class="active" href="../Story%20Engine/index.html">Story</a>
      </nav>
      <h1>Baobab Story Mode</h1>
      <p class="note">Offline narration surface generated from the Baobab catalog. It can later connect Piper voices, Ollama explanations and Argos translation without changing the content model.</p>
      <div class="controls">{''.join(buttons)}</div>
      <button id="next">Next story</button>
      <div class="prompt">Narrator prompt: read slowly, name the source, preserve context, and invite the learner to ask elders or local curators.</div>
    </aside>
  </main>
  <script>
    const slides = [...document.querySelectorAll('.slide')];
    const buttons = [...document.querySelectorAll('[data-index]')];
    let active = 0;
    function show(index) {{
      active = (index + slides.length) % slides.length;
      slides.forEach((slide, i) => slide.classList.toggle('active', i === active));
      buttons.forEach((button, i) => button.classList.toggle('active', i === active));
    }}
    buttons.forEach(button => button.addEventListener('click', () => show(Number(button.dataset.index))));
    document.getElementById('next').addEventListener('click', () => show(active + 1));
    addEventListener('keydown', event => {{ if (event.key === 'ArrowRight') show(active + 1); if (event.key === 'ArrowLeft') show(active - 1); }});
  </script>
</body>
</html>
"""
Path(os.environ["BAOBAB_HTML"]).parent.mkdir(parents=True, exist_ok=True)
Path(os.environ["BAOBAB_HTML"]).write_text(content, encoding="utf-8")
PY
}

write_explore_html() {
  BAOBAB_CATALOG="$CONTENT_INDEX" COUNTRIES_JSON="$COUNTRIES_JSON" BAOBAB_HTML="$EXPLORE_HTML" python - <<'PY'
import html
import json
import os
from collections import Counter
from pathlib import Path

catalog = json.loads(Path(os.environ["BAOBAB_CATALOG"]).read_text(encoding="utf-8"))
countries_payload = json.loads(Path(os.environ["COUNTRIES_JSON"]).read_text(encoding="utf-8"))
records = catalog.get("records", [])
countries = countries_payload.get("countries", [])
unesco_path = Path(os.environ["BAOBAB_CATALOG"]).parent / "heritage" / "african-unesco-ich.json"
unesco_items = []
if unesco_path.exists():
    unesco_items = json.loads(unesco_path.read_text(encoding="utf-8")).get("items", [])
items_json = json.dumps(records, ensure_ascii=True)
countries_json = json.dumps(countries, ensure_ascii=True)
unesco_json = json.dumps(unesco_items[:80], ensure_ascii=True)
module_counts = Counter(item.get("module", "unknown") for item in records)
region_counts = Counter(item.get("region", "unknown") for item in records)
module_rows = "".join(f"<li><b>{html.escape(k)}</b><span>{v}</span></li>" for k, v in sorted(module_counts.items()))
region_rows = "".join(f"<li><b>{html.escape(k)}</b><span>{v}</span></li>" for k, v in sorted(region_counts.items()))
unesco_rows = "".join(
    f"<li class=\"record\"><b>{html.escape((item.get('title_en') or item.get('title_fr') or 'Untitled')[:92])}</b><span>{html.escape(', '.join(item.get('countries', [])))} · {html.escape(item.get('year', ''))}</span></li>"
    for item in unesco_items[:10]
)
country_rows = "".join(
    f"<li class=\"country\" data-name=\"{html.escape(item.get('name', ''), quote=True)}\"><b>{html.escape(item.get('flag', ''))} {html.escape(item.get('name', 'Unknown'))}</b><span>{html.escape(item.get('capital', ''))}</span></li>"
    for item in countries
)

content = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Baobab Explore Africa</title>
  <style>
    :root {{ color-scheme: dark; --night:#07130d; --soil:#20110a; --gold:#e6b85c; --sand:#f2d7a0; --leaf:#7fb069; --water:#74a7c8; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; min-height:100vh; background:linear-gradient(135deg,#07130d,#20110a 62%,#102116); color:#fff6df; }}
    main {{ min-height:100vh; display:grid; grid-template-columns:minmax(0,1fr) 360px; gap:18px; padding:22px; }}
    .map {{ position:relative; min-height:calc(100vh - 44px); border:1px solid rgba(242,215,160,.18); border-radius:8px; overflow:hidden; background:radial-gradient(circle at 42% 42%, rgba(230,184,92,.12), transparent 34%), rgba(7,19,13,.66); }}
    canvas {{ width:100%; height:100%; display:block; }}
    aside {{ border:1px solid rgba(242,215,160,.18); border-radius:8px; padding:18px; background:rgba(18,11,8,.70); overflow:auto; max-height:calc(100vh - 44px); }}
    nav {{ display:flex; flex-wrap:wrap; gap:8px; margin-bottom:14px; }}
    nav a {{ color:#fff6df; text-decoration:none; min-height:34px; display:inline-flex; align-items:center; padding:7px 10px; border-radius:8px; border:1px solid rgba(242,215,160,.20); background:rgba(255,246,223,.07); }}
    nav a.active, nav a:hover {{ border-color:rgba(230,184,92,.72); background:rgba(230,184,92,.18); }}
    h1 {{ margin:0 0 8px; font-size:1.55rem; letter-spacing:0; }}
    p {{ color:#ead8b6; line-height:1.48; }}
    h2 {{ font-size:1rem; margin:18px 0 8px; color:var(--gold); }}
    input {{ width:100%; min-height:38px; padding:9px 11px; border-radius:6px; border:1px solid rgba(242,215,160,.22); background:rgba(7,19,13,.72); color:#fff6df; outline:none; }}
    input:focus {{ border-color:rgba(230,184,92,.72); }}
    ul {{ list-style:none; padding:0; margin:0; display:grid; gap:8px; }}
    li {{ display:flex; justify-content:space-between; gap:12px; padding:10px; border-radius:6px; background:rgba(255,246,223,.07); border-left:3px solid var(--leaf); }}
    li span {{ color:var(--gold); }}
    .country {{ border-left-color:var(--water); cursor:pointer; }}
    .country.active {{ background:rgba(116,167,200,.18); border-color:rgba(116,167,200,.9); }}
    .detail {{ margin:14px 0 0; padding:12px; border-radius:6px; background:rgba(255,246,223,.07); border:1px solid rgba(242,215,160,.16); }}
    .detail strong {{ display:block; font-size:1.2rem; }}
    .detail span {{ display:block; margin-top:6px; color:#e6b85c; }}
    .detail ul {{ margin-top:10px; }}
    .detail li {{ display:block; border-left-color:var(--gold); }}
    .detail li small {{ display:block; color:#f2d7a0; margin-top:4px; }}
    .record {{ display:block; }}
    .record b, .record span {{ display:block; }}
    .record p {{ margin:7px 0 0; }}
    .hint {{ position:absolute; left:18px; bottom:18px; padding:10px 12px; border-radius:6px; background:rgba(18,11,8,.72); color:#f4d997; border:1px solid rgba(242,215,160,.18); }}
    @media (max-width: 880px) {{ main {{ grid-template-columns:1fr; }} .map {{ min-height:58vh; }} aside {{ max-height:none; }} }}
  </style>
</head>
<body>
  <main>
    <section class="map">
      <canvas id="map"></canvas>
      <div class="hint">Offline cultural map prototype. Points come from the local Baobab catalog.</div>
    </section>
    <aside>
      <nav>
        <a href="../Village/index.html">Village</a>
        <a href="../Heritage/index.html">Heritage</a>
        <a class="active" href="../Explore/index.html">Explore</a>
        <a href="../Museum%203D/index.html">Museum</a>
        <a href="../Story%20Engine/index.html">Story</a>
      </nav>
      <h1>Explore Africa</h1>
      <p>Local-first cultural exploration surface. It uses the embedded Africa country index today and prepares the future MapLibre/GeoJSON layer.</p>
      <input id="countrySearch" type="search" placeholder="Search a country or capital">
      <div id="countryDetail" class="detail"></div>
      <h2>Countries</h2>
      <ul id="countryList">{country_rows}</ul>
      <h2>Modules</h2>
      <ul>{module_rows}</ul>
      <h2>UNESCO ICH</h2>
      <ul>{unesco_rows}</ul>
      <h2>Regions</h2>
      <ul>{region_rows}</ul>
      <h2>Records</h2>
      <ul id="records"></ul>
    </aside>
  </main>
  <script>
    const records = {items_json};
    const countries = {countries_json};
    const unesco = {unesco_json};
    const canvas = document.getElementById('map');
    const ctx = canvas.getContext('2d');
    const colors = {{ heritage:'#e6b85c', story:'#c56b34', sound:'#7fb069', explore:'#74a7c8', museum:'#d89b6a', languages:'#a8d7a0', fashion:'#d36f8d', food:'#f2a65a', wisdom:'#c9b8ff', market:'#93d6c5' }};
    let w=0,h=0,t=0,selectedCountry=0;
    function resize() {{ const r=canvas.getBoundingClientRect(); w=canvas.width=r.width*devicePixelRatio; h=canvas.height=r.height*devicePixelRatio; ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0); w=r.width; h=r.height; }}
    addEventListener('resize', resize); resize();
    function africaPath() {{
      const sx=w*.42, sy=h*.12, k=Math.min(w,h)*.00115;
      const pts=[[0,0],[75,18],[116,86],[94,145],[133,207],[92,304],[63,430],[-4,490],[-34,382],[-97,310],[-82,220],[-137,148],[-98,70],[-38,42]];
      ctx.beginPath(); pts.forEach(([x,y],i)=>{{ const px=sx+x/k*.001, py=sy+y/k*.001; if(i===0)ctx.moveTo(px,py); else ctx.lineTo(px,py); }}); ctx.closePath();
    }}
    function draw() {{
      t += .01; ctx.clearRect(0,0,w,h);
      ctx.strokeStyle='rgba(242,215,160,.08)'; ctx.lineWidth=1;
      for(let i=0;i<16;i++){{ ctx.beginPath(); ctx.moveTo(0,h*(i/16)); ctx.lineTo(w,h*(i/16)+Math.sin(t+i)*10); ctx.stroke(); }}
      ctx.fillStyle='rgba(230,184,92,.18)'; ctx.strokeStyle='rgba(242,215,160,.42)'; ctx.lineWidth=2; africaPath(); ctx.fill(); ctx.stroke();
      countries.forEach((item,i)=>{{ const a=i*.54; const ring=.16+(i%5)*.035; const rx=w*.42+Math.cos(a)*w*ring; const ry=h*.43+Math.sin(a*1.37)*h*(ring+.04); ctx.fillStyle=i===selectedCountry?'#e6b85c':(i%2?'#74a7c8':'#7fb069'); ctx.beginPath(); ctx.arc(rx,ry,i===selectedCountry?6:3.2,0,Math.PI*2); ctx.fill(); }});
      unesco.forEach((item,i)=>{{ const a=i*.34+t*.03; const rx=w*.42+Math.cos(a)*w*.22; const ry=h*.43+Math.sin(a*1.1)*h*.30; ctx.fillStyle='rgba(230,184,92,.42)'; ctx.fillRect(rx-2,ry-2,4,4); }});
      records.forEach((item,i)=>{{ const a=i*2.399+t*.08; const rx=w*.42+Math.cos(a)*w*.18+(i%3)*22; const ry=h*.42+Math.sin(a*1.2)*h*.26; ctx.fillStyle=colors[item.module]||'#e6b85c'; ctx.beginPath(); ctx.arc(rx,ry,7+(i%4),0,Math.PI*2); ctx.fill(); ctx.strokeStyle='rgba(255,246,223,.5)'; ctx.stroke(); }});
      requestAnimationFrame(draw);
    }}
    draw();
    function renderCountry(index) {{
      selectedCountry = Math.max(0, Math.min(index, countries.length - 1));
      const item = countries[selectedCountry] || {{}};
      const related = unesco.filter(entry => (entry.countries || []).includes(item.name)).slice(0, 5);
      const heritageList = related.length ? `<ul>${{related.map(entry => `<li><b>${{entry.title_en || entry.title_fr || 'Untitled'}}</b><small>${{entry.year || ''}} · ${{entry.type_acronym || 'ICH'}}</small></li>`).join('')}}</ul>` : '<span>No UNESCO ICH item in the local index yet.</span>';
      document.getElementById('countryDetail').innerHTML = `<strong>${{item.flag||''}} ${{item.name||'Select a country'}}</strong><span>Capital: ${{item.capital||'Unknown'}}</span><span>Population: ${{Number(item.population||0).toLocaleString()}}</span><span>Heritage items: ${{related.length}}</span>${{heritageList}}`;
      document.querySelectorAll('.country').forEach((row,i)=>row.classList.toggle('active', i===selectedCountry));
    }}
    document.querySelectorAll('.country').forEach((row,index)=>row.addEventListener('click',()=>renderCountry(index)));
    document.getElementById('countrySearch').addEventListener('input', event => {{
      const q = event.target.value.toLowerCase();
      document.querySelectorAll('.country').forEach((row,index) => {{
        const item = countries[index] || {{}};
        const match = !q || `${{item.name}} ${{item.capital}}`.toLowerCase().includes(q);
        row.style.display = match ? 'flex' : 'none';
      }});
    }});
    renderCountry(0);
    document.getElementById('records').innerHTML = records.slice(0,12).map(item => `<li class="record"><b>${{item.title||'Untitled'}}</b><span>${{item.module||'record'}} / ${{item.region||'unknown'}}</span><p>${{item.summary||''}}</p></li>`).join('');
  </script>
</body>
</html>
"""
Path(os.environ["BAOBAB_HTML"]).parent.mkdir(parents=True, exist_ok=True)
Path(os.environ["BAOBAB_HTML"]).write_text(content, encoding="utf-8")
PY
}

sync_database() {
  write_seed_catalog
  normalize_catalog_metadata
  normalize_packs_metadata
  sync_countries
  sync_unesco
  sync_datasets
  BAOBAB_CATALOG="$CONTENT_INDEX" BAOBAB_DB="$BAOBAB_DB" COUNTRIES_JSON="$COUNTRIES_JSON" UNESCO_JSON="$UNESCO_JSON" DATASETS_JSON="$DATASETS_JSON" python - <<'PY'
import json
import os
import sqlite3
from pathlib import Path

catalog_path = Path(os.environ["BAOBAB_CATALOG"])
countries_path = Path(os.environ["COUNTRIES_JSON"])
unesco_path = Path(os.environ["UNESCO_JSON"])
datasets_path = Path(os.environ["DATASETS_JSON"])
db_path = Path(os.environ["BAOBAB_DB"])
data = json.loads(catalog_path.read_text(encoding="utf-8"))
countries_data = json.loads(countries_path.read_text(encoding="utf-8"))
unesco_data = json.loads(unesco_path.read_text(encoding="utf-8"))
datasets_data = json.loads(datasets_path.read_text(encoding="utf-8")) if datasets_path.exists() else {"sources": []}
db_path.parent.mkdir(parents=True, exist_ok=True)

with sqlite3.connect(db_path) as conn:
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA user_version=1")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS records (
            id TEXT PRIMARY KEY,
            module TEXT NOT NULL,
            title TEXT NOT NULL,
            kind TEXT,
            region TEXT,
            summary TEXT NOT NULL,
            tags TEXT NOT NULL,
            source_pack TEXT,
            source TEXT,
            license TEXT,
            curator TEXT,
            confidence TEXT,
            language TEXT,
            country TEXT,
            payload TEXT NOT NULL
        )
        """
    )
    columns = {row[1] for row in conn.execute("PRAGMA table_info(records)")}
    for name in ("license", "curator", "confidence", "language", "country"):
        if name not in columns:
            conn.execute(f"ALTER TABLE records ADD COLUMN {name} TEXT")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_records_module ON records(module)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_records_region ON records(region)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_records_confidence ON records(confidence)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_records_country ON records(country)")
    conn.execute("DELETE FROM records")
    for item in data.get("records", []):
        conn.execute(
            """
            INSERT OR REPLACE INTO records
            (id, module, title, kind, region, summary, tags, source_pack, source, license, curator, confidence, language, country, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                item.get("id", ""),
                item.get("module", ""),
                item.get("title", ""),
                item.get("kind", ""),
                item.get("region", ""),
                item.get("summary", ""),
                json.dumps(item.get("tags", []), ensure_ascii=True),
                item.get("source_pack", ""),
                item.get("source", ""),
                item.get("license", ""),
                item.get("curator", ""),
                item.get("confidence", ""),
                item.get("language", ""),
                item.get("country", ""),
                json.dumps(item, ensure_ascii=True),
            ),
        )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS countries (
            name TEXT PRIMARY KEY,
            flag TEXT,
            capital TEXT,
            population INTEGER,
            source TEXT,
            license TEXT,
            confidence TEXT,
            language TEXT,
            payload TEXT NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_countries_capital ON countries(capital)")
    conn.execute("DELETE FROM countries")
    for item in countries_data.get("countries", []):
        conn.execute(
            """
            INSERT OR REPLACE INTO countries
            (name, flag, capital, population, source, license, confidence, language, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                item.get("name", ""),
                item.get("flag", ""),
                item.get("capital", ""),
                item.get("population", 0),
                item.get("source", ""),
                item.get("license", ""),
                item.get("confidence", ""),
                item.get("language", ""),
                json.dumps(item, ensure_ascii=True),
            ),
        )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS unesco_ich (
            id TEXT PRIMARY KEY,
            ref TEXT,
            year TEXT,
            title_en TEXT,
            title_fr TEXT,
            summary_en TEXT,
            summary_fr TEXT,
            type_acronym TEXT,
            countries TEXT,
            country_codes TEXT,
            concepts TEXT,
            url_en TEXT,
            url_fr TEXT,
            main_image TEXT,
            source TEXT,
            license TEXT,
            curator TEXT,
            confidence TEXT,
            payload TEXT NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_unesco_year ON unesco_ich(year)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_unesco_type ON unesco_ich(type_acronym)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_unesco_countries ON unesco_ich(countries)")
    conn.execute("DELETE FROM unesco_ich")
    for item in unesco_data.get("items", []):
        conn.execute(
            """
            INSERT OR REPLACE INTO unesco_ich
            (id, ref, year, title_en, title_fr, summary_en, summary_fr, type_acronym, countries, country_codes, concepts, url_en, url_fr, main_image, source, license, curator, confidence, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                item.get("id", ""),
                item.get("ref", ""),
                item.get("year", ""),
                item.get("title_en", ""),
                item.get("title_fr", ""),
                item.get("summary_en", ""),
                item.get("summary_fr", ""),
                item.get("type_acronym", ""),
                json.dumps(item.get("countries", []), ensure_ascii=True),
                json.dumps(item.get("country_codes", []), ensure_ascii=True),
                json.dumps(item.get("concepts", []), ensure_ascii=True),
                item.get("url_en", ""),
                item.get("url_fr", ""),
                item.get("main_image", ""),
                item.get("source", ""),
                item.get("license", ""),
                item.get("curator", ""),
                item.get("confidence", ""),
                json.dumps(item, ensure_ascii=True),
            ),
        )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS datasets (
            name TEXT PRIMARY KEY,
            path TEXT,
            kind TEXT,
            size INTEGER,
            rows INTEGER,
            fields TEXT,
            role TEXT,
            payload TEXT NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_datasets_kind ON datasets(kind)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_baobab_datasets_role ON datasets(role)")
    conn.execute("DELETE FROM datasets")
    for item in datasets_data.get("sources", []):
        conn.execute(
            """
            INSERT OR REPLACE INTO datasets
            (name, path, kind, size, rows, fields, role, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                item.get("name", ""),
                item.get("path", ""),
                item.get("kind", ""),
                item.get("size", 0),
                item.get("rows", 0),
                json.dumps(item.get("fields", []), ensure_ascii=True),
                item.get("role", ""),
                json.dumps(item, ensure_ascii=True),
            ),
        )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('schema', 'sevenos.baobab.sqlite.v1')")
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('catalog', ?)", (str(catalog_path),))
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('record_count', ?)", (str(len(data.get("records", []))),))
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('countries', ?)", (str(countries_path),))
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('country_count', ?)", (str(len(countries_data.get("countries", []))),))
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('unesco_ich', ?)", (str(unesco_path),))
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('unesco_ich_count', ?)", (str(len(unesco_data.get("items", []))),))
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('datasets', ?)", (str(datasets_path),))
    conn.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('datasets_count', ?)", (str(len(datasets_data.get("sources", []))),))
PY
}

bootstrap_baobab() {
  local module title dir_name
  migrate_legacy_state
  mkdir -p "$BAOBAB_PROFILE_CONFIG" "$BAOBAB_PROFILE_DATA" "$BAOBAB_PROFILE_CACHE" "$BAOBAB_CONFIG" "$BAOBAB_DATA" "$BAOBAB_CACHE/media" "$BAOBAB_CACHE/maps" "$BAOBAB_WORKSPACE" "$PACKS_DIR"
  while IFS=$'\t' read -r module title _rest; do
    dir_name="${title#Baobab }"
    dir_name="${dir_name#African }"
    mkdir -p "$BAOBAB_DATA/$module" "$BAOBAB_WORKSPACE/$dir_name"
  done < <(module_rows)
  mkdir -p "$BAOBAB_DATA/ai-memory" "$BAOBAB_DATA/offline" "$BAOBAB_WORKSPACE/Village"
  local manifest_tmp
  manifest_tmp="$(mktemp "$MANIFEST.tmp.XXXXXX")"
  baobab_json > "$manifest_tmp"
  mv "$manifest_tmp" "$MANIFEST"
  write_seed_catalog
  if ! find "$PACKS_DIR" -mindepth 2 -maxdepth 2 -name pack.json -print -quit | grep -q .; then
    BAOBAB_SKIP_BOOTSTRAP=1 seed_curated_packs >/dev/null || true
  fi
  sync_database
  write_village_html
  write_heritage_html
  write_museum_html
  write_story_html
	  write_explore_html
	  sync_languages
	  sync_immersions
	  sync_protocols
	  write_baobab_profile_configs
  cat > "$BAOBAB_WORKSPACE/README.md" <<'EOF'
# Baobab Cultural Mini OS

This workspace is the local home for Baobab: African heritage, languages,
stories, sound, food, fashion, wisdom, maps, museum objects and community memory.

Start with:

```bash
seven baobab
seven baobab modules
seven profile activate baobab
```
EOF
}

print_status() {
  local payload
  payload="$(baobab_json)"
  BAOBAB_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["BAOBAB_JSON"])
print("Baobab Cultural Mini OS")
print("=======================")
print(f"State: {data.get('state')}")
print(f"Score: {data.get('score')}%")
print(f"Tagline: {data.get('tagline')}")
print()
print("Village:")
for place in data.get("village", [])[:6]:
    print(f"- {place['place']}: {place['role']}")
print()
print("Next:")
if data.get("state") != "ready":
    print("- seven baobab bootstrap")
print("- seven profile activate baobab")
print("- seven baobab modules")
PY
}

print_plan() {
  cat <<'EOF'
Baobab Plan
===========

1. Bootstrap offline directories, manifest and workspace.
2. Promote Baobab from profile to cultural mini OS contract.
3. Build Baobab Village as the home surface: tree, library, market, stage, map, kitchen and atelier.
4. Add Heritage DB with stories, proverbs, timelines, books and oral traditions.
5. Add Seven Baobab AI as local cultural guide, narrator and language tutor.
6. Add offline media/map cache and low-bandwidth sync.
7. Connect Fashion to ElegantStyle and cultural creator marketplace.
8. Treat tools as capabilities: culture, offline, AI, education, media, sync and creation.
EOF
}

print_modules() {
  module_rows | awk -F '\t' 'BEGIN { print "Baobab Modules"; print "=============="; print "" } { printf "%-12s %s\n  %s\n  tags: %s · state: %s\n\n", $1, $2, $3, $4, $5 }'
}

print_integrations() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    INTEGRATION_ROWS="$(integration_rows)" python - <<'PY'
import json
import os

items = []
for raw in os.environ["INTEGRATION_ROWS"].splitlines():
    group, key, title, role, source, phase, mode = raw.split("\t")
    items.append({"group": group, "key": key, "title": title, "role": role, "source": source, "phase": phase, "mode": mode})
print(json.dumps({"schema": "sevenos.baobab.integrations.v1", "count": len(items), "integrations": items}, indent=2))
PY
  else
    integration_rows | awk -F '\t' 'BEGIN { print "Baobab Open Source Integrations"; print "================================"; print "" } { printf "%-10s %-16s %s\n  %s\n  source: %s\n  phase: %s · mode: %s\n\n", $1, $2, $3, $4, $5, $6, $7 }'
  fi
}

print_engines() {
  ENGINE_ROWS="$(engine_rows)" SEVENOS_ROOT="$ROOT_DIR" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import shutil
from pathlib import Path

items = []
for raw in os.environ["ENGINE_ROWS"].splitlines():
    key, group, command, package, priority, role = raw.split("\t")
    if command.startswith("bin/"):
        path = Path(os.environ["SEVENOS_ROOT"], command)
        resolved = str(path)
        available = path.exists()
    elif key == "sqlite":
        resolved = "python sqlite3"
        available = True
    else:
        resolved = shutil.which(command) or ""
        available = bool(resolved)
    items.append({
        "key": key,
        "group": group,
        "command": command,
        "package": package,
        "priority": priority,
        "role": role,
        "state": "available" if available else "missing",
        "resolved": resolved,
    })

critical = [item for item in items if item["priority"] in {"critical", "important"}]
critical_ready = sum(1 for item in critical if item["state"] == "available")
available = sum(1 for item in items if item["state"] == "available")
score = round((critical_ready / len(critical)) * 100) if critical else 100
immersive_score = round((available / len(items)) * 100) if items else 100
missing_optional = [item for item in items if item["state"] == "missing" and item["priority"] == "optional"]
payload = {
    "schema": "sevenos.baobab.engines.v1",
    "state": "ready" if score == 100 else "needs-core-engines",
    "immersive_state": "complete" if immersive_score == 100 else "needs-immersive-engines",
    "score": score,
    "immersive_score": immersive_score,
    "available": available,
    "total": len(items),
    "engines": items,
    "next": [
        f"Install or connect {item['key']} ({item['package']})"
        for item in items
        if item["state"] == "missing" and item["priority"] in {"critical", "important"}
    ],
    "immersive_next": [
        f"Install or connect {item['key']} ({item['package']}) for {item['group'].lower()}"
        for item in missing_optional
    ],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2))
else:
    print("Baobab Engines")
    print("==============")
    print(f"State: {payload['state']}")
    print(f"Core score: {score}%")
    print(f"Immersive score: {immersive_score}%")
    print(f"Available: {available}/{len(items)}")
    print()
    for item in items:
        mark = "OK" if item["state"] == "available" else "MISS"
        print(f"- {mark} {item['key']} ({item['group']})")
        print(f"  {item['role']}")
        if item["state"] == "missing":
            print(f"  package: {item['package']}")
    if payload["immersive_next"]:
        print()
        print("Immersive next:")
        for item in payload["immersive_next"]:
            print(f"- {item}")
PY
}

print_tools() {
  TOOL_ROWS="$(tool_rows)" SEVENOS_ROOT="$ROOT_DIR" BAOBAB_NODE="$BAOBAB_NODE" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import shutil
from pathlib import Path


def available(probe):
    kind, _, value = probe.partition(":")
    if kind == "command":
        resolved = shutil.which(value) or ""
        return ("available" if resolved else "missing", resolved)
    if kind == "command-any":
        for command in [part.strip() for part in value.split(",") if part.strip()]:
            resolved = shutil.which(command) or ""
            if resolved:
                return ("available", resolved)
        return ("missing", value)
    if kind == "path":
        path = Path(value)
        return ("available" if path.exists() else "missing", str(path))
    if kind == "file":
        path = Path(os.environ["SEVENOS_ROOT"], value)
        return ("available" if path.exists() else "missing", str(path))
    if kind == "file-env":
        env_name, _, suffix = value.partition("/")
        base = Path(os.environ.get(env_name, ""))
        path = base / suffix if suffix else base
        return ("available" if path.exists() else "missing", str(path))
    if kind == "python":
        try:
            __import__(value)
            return ("available", f"python:{value}")
        except Exception:
            return ("missing", f"python:{value}")
    if kind == "contract":
        return ("planned", value)
    return ("missing", value)


items = []
for raw in os.environ["TOOL_ROWS"].splitlines():
    group, key, title, package, probe, priority, role = raw.split("\t")
    state, resolved = available(probe)
    items.append({
        "group": group,
        "key": key,
        "title": title,
        "package": package,
        "probe": probe,
        "priority": priority,
        "role": role,
        "state": state,
        "resolved": resolved,
    })

groups = {}
for item in items:
    groups.setdefault(item["group"], []).append(item)
summary = {}
for group, group_items in sorted(groups.items()):
    core = [item for item in group_items if item["priority"] == "core"]
    core_ready = sum(1 for item in core if item["state"] == "available")
    available_count = sum(1 for item in group_items if item["state"] == "available")
    summary[group] = {
        "available": available_count,
        "total": len(group_items),
        "core_available": core_ready,
        "core_total": len(core),
        "state": "ready" if not core or core_ready == len(core) else "needs-core-tool",
    }
core_items = [item for item in items if item["priority"] == "core"]
core_ready = sum(1 for item in core_items if item["state"] == "available")
available_count = sum(1 for item in items if item["state"] == "available")
payload = {
    "schema": "sevenos.baobab.tools.v1",
    "state": "ready" if core_ready == len(core_items) else "needs-core-tools",
    "score": round(core_ready / len(core_items) * 100) if core_items else 100,
    "immersive_score": round(available_count / len(items) * 100) if items else 100,
    "summary": summary,
    "tools": items,
    "next": [
        {"title": item["title"], "package": item["package"], "reason": item["role"]}
        for item in items
        if item["state"] == "missing" and item["priority"] == "core"
    ],
    "optional_next": [
        {"title": item["title"], "package": item["package"], "group": item["group"]}
        for item in items
        if item["state"] == "missing" and item["priority"] == "optional"
    ],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Tools")
    print("============")
    print(f"State: {payload['state']}")
    print(f"Core score: {payload['score']}%")
    print(f"Immersive score: {payload['immersive_score']}%")
    print()
    for group, group_items in groups.items():
        info = summary[group]
        print(f"{group}: {info['available']}/{info['total']} · {info['state']}")
        for item in group_items:
            mark = "OK" if item["state"] == "available" else "PLAN" if item["state"] == "planned" else "MISS"
            print(f"- {mark} {item['title']} ({item['package']})")
            print(f"  {item['role']}")
        print()
    if payload["next"]:
        print("Core next:")
        for item in payload["next"]:
            print(f"- {item['title']}: {item['package']}")
PY
}

tool_doctor() {
  local payload
  payload="$(JSON_OUTPUT=1 print_tools)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '%s\n' "$payload"
  else
    BAOBAB_TOOLS="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["BAOBAB_TOOLS"])
print(f"Baobab tool doctor: {data['state']} ({data['score']}% core, {data['immersive_score']}% immersive)")
for item in data.get("next", []):
    print(f"- Core missing: {item['title']} ({item['package']})")
if not data.get("next"):
    print("- Core tools are ready. Optional immersive engines can be added progressively.")
PY
  fi
}

config_json() {
  bootstrap_baobab >/dev/null
  cat "$BAOBAB_CONFIG_MANIFEST"
}

runtime_json() {
  bootstrap_baobab >/dev/null
  cat "$BAOBAB_RUNTIME"
}

config_doctor_json() {
  bootstrap_baobab >/dev/null
  BAOBAB_CONFIG_MANIFEST="$BAOBAB_CONFIG_MANIFEST" \
  BAOBAB_RUNTIME="$BAOBAB_RUNTIME" \
  BAOBAB_ENV="$BAOBAB_ENV" \
  BAOBAB_PROFILE_CONFIG="$BAOBAB_PROFILE_CONFIG" \
  BAOBAB_PROFILE_DATA="$BAOBAB_PROFILE_DATA" \
  BAOBAB_PROFILE_CACHE="$BAOBAB_PROFILE_CACHE" \
  BAOBAB_CONFIG="$BAOBAB_CONFIG" \
  BAOBAB_DATA="$BAOBAB_DATA" \
  BAOBAB_CACHE="$BAOBAB_CACHE" \
  BAOBAB_PROFILE_UI="$BAOBAB_PROFILE_UI" \
  BAOBAB_SESSION="$BAOBAB_SESSION" \
  BAOBAB_PASSAGE="$BAOBAB_PASSAGE" \
  BAOBAB_WALLPAPER_STATE="$BAOBAB_WALLPAPER_STATE" \
  python - <<'PY'
import json
import os
from pathlib import Path

required = {
    "config_manifest": Path(os.environ["BAOBAB_CONFIG_MANIFEST"]),
    "runtime": Path(os.environ["BAOBAB_RUNTIME"]),
    "env": Path(os.environ["BAOBAB_ENV"]),
    "run": Path(os.environ["BAOBAB_CONFIG"]) / "bin/baobab-run",
    "sound_launcher": Path(os.environ["BAOBAB_CONFIG"]) / "bin/baobab-sound",
    "search_launcher": Path(os.environ["BAOBAB_CONFIG"]) / "bin/baobab-searchd",
    "ai_launcher": Path(os.environ["BAOBAB_CONFIG"]) / "bin/baobab-ai",
    "narration_launcher": Path(os.environ["BAOBAB_CONFIG"]) / "bin/baobab-narrate",
    "apps": Path(os.environ["BAOBAB_CONFIG"]) / "apps.json",
    "capabilities": Path(os.environ["BAOBAB_CONFIG"]) / "capabilities.json",
    "mpv": Path(os.environ["BAOBAB_CONFIG"]) / "mpv/mpv.conf",
    "waybar": Path(os.environ["BAOBAB_CONFIG"]) / "waybar/config.jsonc",
    "eww": Path(os.environ["BAOBAB_CONFIG"]) / "eww/baobab.yuck",
    "shell": Path(os.environ["BAOBAB_CONFIG"]) / "shell/baobab-shell.json",
    "soundscape": Path(os.environ["BAOBAB_CONFIG"]) / "soundscape/soundscape.json",
    "store": Path(os.environ["BAOBAB_CONFIG"]) / "store/sources.json",
    "profile_ui": Path(os.environ["BAOBAB_PROFILE_UI"]),
    "session": Path(os.environ["BAOBAB_SESSION"]),
    "passage": Path(os.environ["BAOBAB_PASSAGE"]),
    "wallpaper_state": Path(os.environ["BAOBAB_WALLPAPER_STATE"]),
}
roots = {
    "profile_config": Path(os.environ["BAOBAB_PROFILE_CONFIG"]),
    "profile_data": Path(os.environ["BAOBAB_PROFILE_DATA"]),
    "profile_cache": Path(os.environ["BAOBAB_PROFILE_CACHE"]),
    "baobab_config": Path(os.environ["BAOBAB_CONFIG"]),
    "baobab_data": Path(os.environ["BAOBAB_DATA"]),
    "baobab_cache": Path(os.environ["BAOBAB_CACHE"]),
}
issues = []
for key, path in required.items():
    if not path.exists() or path.stat().st_size == 0:
        issues.append({"key": key, "severity": "high", "detail": f"missing file: {path}"})
for key, path in roots.items():
    if not path.is_dir():
        issues.append({"key": key, "severity": "high", "detail": f"missing root: {path}"})
bad_roots = []
for key, path in {**required, **roots}.items():
    text = str(path)
    if "/sevenos/baobab" in text and "/profiles/baobab/" not in text:
        bad_roots.append({"key": key, "path": text})
if bad_roots:
    issues.append({"key": "legacy-global-root", "severity": "critical", "detail": "Baobab path outside profile-owned root", "paths": bad_roots})
score = 100 - len([i for i in issues if i["severity"] == "high"]) * 8 - len([i for i in issues if i["severity"] == "critical"]) * 25
score = max(0, score)
print(json.dumps({
    "schema": "sevenos.baobab.config-doctor.v1",
    "state": "ready" if not issues else "needs-config-fix",
    "score": score,
    "issues": issues,
    "roots": {key: str(value) for key, value in roots.items()},
    "required": {key: str(value) for key, value in required.items()},
    "rule": "Baobab config, data and cache are profile-owned under sevenos/profiles/baobab.",
}, indent=2, ensure_ascii=False))
PY
}

print_config() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    config_json
  else
    CONFIG_PAYLOAD="$(config_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["CONFIG_PAYLOAD"])
print("Baobab Config")
print("=============")
for key, value in data.get("roots", {}).items():
    print(f"{key}: {value}")
print()
print("Files:")
for key, value in data.get("files", {}).items():
    print(f"- {key}: {value}")
PY
  fi
}

print_runtime() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    runtime_json
  else
    RUNTIME_PAYLOAD="$(runtime_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["RUNTIME_PAYLOAD"])
print("Baobab Runtime")
print("==============")
print(f"state: {data.get('state')}")
print(f"config: {data.get('config_root')}")
print(f"data:   {data.get('data_root')}")
print(f"cache:  {data.get('cache_root')}")
print(f"env:    {data.get('env')}")
PY
  fi
}

print_config_doctor() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    config_doctor_json
  else
    CONFIG_DOCTOR_PAYLOAD="$(config_doctor_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["CONFIG_DOCTOR_PAYLOAD"])
print(f"Baobab config doctor: {data.get('state')} ({data.get('score')}%)")
for item in data.get("issues", []):
    print(f"- {item.get('key')}: {item.get('detail')}")
PY
  fi
}

service_doctor_json() {
  bootstrap_baobab >/dev/null
  BAOBAB_RUNTIME="$BAOBAB_RUNTIME" BAOBAB_ENV="$BAOBAB_ENV" BAOBAB_BIN="$BAOBAB_BIN" BAOBAB_CONFIG="$BAOBAB_CONFIG" BAOBAB_DATA="$BAOBAB_DATA" BAOBAB_WORKSPACE="$BAOBAB_WORKSPACE" python - <<'PY'
import json
import os
import shutil
from pathlib import Path

launchers = {
    "run": Path(os.environ["BAOBAB_BIN"]) / "baobab-run",
    "sound": Path(os.environ["BAOBAB_BIN"]) / "baobab-sound",
    "search": Path(os.environ["BAOBAB_BIN"]) / "baobab-searchd",
    "ai": Path(os.environ["BAOBAB_BIN"]) / "baobab-ai",
    "narrate": Path(os.environ["BAOBAB_BIN"]) / "baobab-narrate",
}
services = [
    {"key": "sound", "command": "mpv", "launcher": str(launchers["sound"]), "state": "ready" if shutil.which("mpv") else "missing-tool", "autostart": False},
    {"key": "search", "command": "meilisearch", "launcher": str(launchers["search"]), "state": "ready" if shutil.which("meilisearch") else "optional-missing", "autostart": False},
    {"key": "ai", "command": "ollama", "launcher": str(launchers["ai"]), "state": "ready" if shutil.which("ollama") else "optional-missing", "autostart": False},
    {"key": "narration", "command": "piper/espeak-ng", "launcher": str(launchers["narrate"]), "state": "ready" if shutil.which("piper") or Path("/opt/piper-tts/piper").exists() or shutil.which("espeak-ng") else "optional-missing", "autostart": False},
    {"key": "translation", "command": "argos-translate/trans", "launcher": "", "state": "ready" if shutil.which("argos-translate") or shutil.which("trans") else "optional-missing", "autostart": False},
]
issues = []
for key, path in launchers.items():
    if not path.exists():
        issues.append({"key": key, "severity": "high", "detail": f"missing launcher: {path}"})
    elif not os.access(path, os.X_OK):
        issues.append({"key": key, "severity": "high", "detail": f"launcher is not executable: {path}"})
if not Path(os.environ["BAOBAB_ENV"]).exists():
    issues.append({"key": "env", "severity": "high", "detail": f"missing env: {os.environ['BAOBAB_ENV']}"})
score = max(0, 100 - len(issues) * 12)
print(json.dumps({
    "schema": "sevenos.baobab.service-doctor.v1",
    "state": "ready" if not issues else "needs-service-config",
    "score": score,
    "issues": issues,
    "policy": "Baobab prepares services with profile-owned launchers, but starts them only on explicit user action.",
    "launchers": {key: str(path) for key, path in launchers.items()},
    "services": services,
    "sound_library": str(Path(os.environ["BAOBAB_WORKSPACE"]) / "Sound"),
    "local_sound_data": str(Path(os.environ["BAOBAB_DATA"]) / "sound"),
}, indent=2, ensure_ascii=False))
PY
}

print_service_doctor() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    service_doctor_json
  else
    SERVICE_PAYLOAD="$(service_doctor_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["SERVICE_PAYLOAD"])
print(f"Baobab service doctor: {data.get('state')} ({data.get('score')}%)")
for service in data.get("services", []):
    print(f"- {service.get('key')}: {service.get('state')} · {service.get('launcher') or service.get('command')}")
for item in data.get("issues", []):
    print(f"! {item.get('key')}: {item.get('detail')}")
PY
  fi
}

app_doctor_json() {
  bootstrap_baobab >/dev/null
  BAOBAB_APP_MANIFEST="$BAOBAB_APP_MANIFEST" BAOBAB_DESKTOP_DIR="$BAOBAB_DESKTOP_DIR" python - <<'PY'
import json
import os
from pathlib import Path

manifest_path = Path(os.environ["BAOBAB_APP_MANIFEST"])
desktop_dir = Path(os.environ["BAOBAB_DESKTOP_DIR"])
issues = []
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except Exception as exc:
    manifest = {"apps": []}
    issues.append({"key": "manifest", "severity": "high", "detail": f"cannot read app manifest: {exc}"})
if not desktop_dir.is_dir():
    issues.append({"key": "desktop-dir", "severity": "high", "detail": f"missing desktop dir: {desktop_dir}"})
apps = []
for app in manifest.get("apps", []):
    desktop = Path(app.get("desktop", ""))
    text = desktop.read_text(encoding="utf-8") if desktop.exists() else ""
    state = "ready"
    app_issues = []
    if not desktop.exists():
        state = "missing"
        app_issues.append("missing desktop file")
    if text and "X-SevenOS-Profile=baobab" not in text:
        state = "needs-fix"
        app_issues.append("missing profile marker")
    if text and "X-SevenOS-Isolated=true" not in text:
        state = "needs-fix"
        app_issues.append("missing isolation marker")
    if text and "/sevenos/baobab" in text and "/profiles/baobab/" not in text:
        state = "needs-fix"
        app_issues.append("legacy global path")
    if app_issues:
        issues.append({"key": app.get("id", "app"), "severity": "high", "detail": "; ".join(app_issues)})
    apps.append({**app, "state": state, "issues": app_issues})
score = max(0, 100 - len(issues) * 10)
print(json.dumps({
    "schema": "sevenos.baobab.app-doctor.v1",
    "state": "ready" if not issues else "needs-app-fix",
    "score": score,
    "issues": issues,
    "manifest": str(manifest_path),
    "desktop_dir": str(desktop_dir),
    "apps": apps,
    "policy": "Baobab visible applications are declared in the Baobab profile data root.",
}, indent=2, ensure_ascii=False))
PY
}

print_app_doctor() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    app_doctor_json
  else
    APP_PAYLOAD="$(app_doctor_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["APP_PAYLOAD"])
print(f"Baobab app doctor: {data.get('state')} ({data.get('score')}%)")
print(f"desktop dir: {data.get('desktop_dir')}")
for app in data.get("apps", []):
    print(f"- {app.get('title')}: {app.get('state')} · {app.get('desktop')}")
for item in data.get("issues", []):
    print(f"! {item.get('key')}: {item.get('detail')}")
PY
  fi
}

capabilities_json() {
  bootstrap_baobab >/dev/null
  cat "$BAOBAB_CAPABILITIES"
}

capability_doctor_json() {
  bootstrap_baobab >/dev/null
  CAPABILITIES_PAYLOAD="$(capabilities_json)" TOOLS_PAYLOAD="$(JSON_OUTPUT=1 print_tools)" CONTENT_INDEX="$CONTENT_INDEX" LANGUAGES_JSON="$LANGUAGES_JSON" PACKS_DIR="$PACKS_DIR" BAOBAB_APP_MANIFEST="$BAOBAB_APP_MANIFEST" python - <<'PY'
import json
import os
import shutil
from pathlib import Path

caps = json.loads(os.environ["CAPABILITIES_PAYLOAD"])
tools = json.loads(os.environ["TOOLS_PAYLOAD"])
tool_by_title = {item.get("title"): item for item in tools.get("tools", [])}
tool_by_key = {item.get("key"): item for item in tools.get("tools", [])}

def cultural_experience_score():
    checks = []
    content = Path(os.environ["CONTENT_INDEX"])
    languages = Path(os.environ["LANGUAGES_JSON"])
    packs = Path(os.environ["PACKS_DIR"])
    apps = Path(os.environ["BAOBAB_APP_MANIFEST"])
    checks.append(content.exists() and content.stat().st_size > 0)
    checks.append(languages.exists() and languages.stat().st_size > 0)
    checks.append(packs.is_dir() and any(packs.glob("*/pack.json")))
    checks.append(apps.exists() and apps.stat().st_size > 0)
    checks.append(True)  # Arbre de connaissance and Collecte are native Baobab surfaces.
    return round(sum(1 for item in checks if item) / len(checks) * 100)

def fallback_ready(tool):
    if tool == "Piper":
        return bool(shutil.which("piper") or Path("/opt/piper-tts/piper").exists() or shutil.which("espeak-ng"))
    if tool == "Argos Translate":
        return bool(shutil.which("argos-translate") or shutil.which("trans"))
    if tool == "Open WebUI":
        # Open WebUI is a heavy lab UI and its AUR package can conflict with
        # the active Node runtime. Baobab AI remains operational when Ollama is
        # present, so the capability should not be blocked by this optional UI.
        return bool(shutil.which("ollama"))
    if tool == "Radio Browser API":
        return True
    if tool in {"contenus locaux", "langues africaines", "sons naturels", "validation communautaire", "transmission"}:
        return cultural_experience_score() >= 60
    return False

domains = []
issues = []
for domain in caps.get("domains", []):
    if domain.get("key") == "living_difference":
        score = cultural_experience_score()
        domains.append({
            "key": domain.get("key"),
            "title": domain.get("title"),
            "purpose": domain.get("purpose"),
            "public_surface": domain.get("public_surface"),
            "offline": domain.get("offline"),
            "score": score,
            "state": "ready" if score >= 80 else "partial",
            "ready": score,
            "total": 100,
            "missing": [] if score >= 80 else ["contenus communautaires validés"],
            "planned": [],
        })
        continue
    ready = 0
    total = 0
    missing = []
    planned = []
    for tool in domain.get("tools", []):
        total += 1
        key = tool.lower().replace(" ", "-").replace(".", "-")
        item = tool_by_title.get(tool) or tool_by_key.get(key)
        if item and item.get("state") == "available":
            ready += 1
        elif fallback_ready(tool):
            ready += 1
        elif item and item.get("state") == "planned":
            planned.append(tool)
        else:
            missing.append(tool)
    score = round((ready / total) * 100) if total else 100
    state = "ready" if score == 100 else "partial" if ready else "planned"
    if domain.get("key") in {"system_interface", "african_identity", "local_content"} and score < 50:
        issues.append({"key": domain.get("key"), "severity": "medium", "detail": f"{domain.get('title')} below 50%"})
    domains.append({
        "key": domain.get("key"),
        "title": domain.get("title"),
        "purpose": domain.get("purpose"),
        "public_surface": domain.get("public_surface"),
        "offline": domain.get("offline"),
        "score": score,
        "state": state,
        "ready": ready,
        "total": total,
        "missing": missing,
        "planned": planned,
    })
overall = round(sum(item["score"] for item in domains) / len(domains)) if domains else 100
print(json.dumps({
    "schema": "sevenos.baobab.capability-doctor.v1",
    "state": "ready" if not issues else "ready-with-gaps",
    "score": overall,
    "issues": issues,
    "goals": caps.get("goals", []),
    "principle": caps.get("principle", ""),
    "domains": domains,
}, indent=2, ensure_ascii=False))
PY
}

print_capabilities() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    capabilities_json
  else
    CAPABILITIES_PAYLOAD="$(capabilities_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["CAPABILITIES_PAYLOAD"])
print("Baobab Capabilities")
print("===================")
for goal in data.get("goals", []):
    print(f"- {goal}")
print()
for domain in data.get("domains", []):
    print(f"{domain.get('title')}")
    print(f"  {domain.get('purpose')}")
    print(f"  Outils: {', '.join(domain.get('tools', []))}")
    print(f"  Surface: {domain.get('public_surface')}")
PY
  fi
}

print_capability_doctor() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    capability_doctor_json
  else
    CAPABILITY_PAYLOAD="$(capability_doctor_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["CAPABILITY_PAYLOAD"])
print(f"Baobab capability doctor: {data.get('state')} ({data.get('score')}%)")
for domain in data.get("domains", []):
    print(f"- {domain.get('title')}: {domain.get('score')}% · {domain.get('state')}")
    if domain.get("missing"):
        print(f"  À connecter: {', '.join(domain['missing'][:5])}")
PY
  fi
}

open_sound() {
  bootstrap_baobab >/dev/null
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    SOUND_DOCTOR="$(service_doctor_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["SOUND_DOCTOR"])
print(json.dumps({
    "schema": "sevenos.baobab.sound.v1",
    "state": "ready",
    "launcher": data.get("launchers", {}).get("sound", ""),
    "library": data.get("sound_library", ""),
    "local_data": data.get("local_sound_data", ""),
    "policy": "local files first; Baobab Sound uses the Baobab profile MPV config",
}, indent=2, ensure_ascii=False))
PY
  else
    "$BAOBAB_BIN/baobab-sound"
  fi
}

apply_config() {
  bootstrap_baobab >/dev/null
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    CONFIG_PAYLOAD="$(config_doctor_json)" SERVICE_PAYLOAD="$(service_doctor_json)" APP_PAYLOAD="$(app_doctor_json)" python - <<'PY'
import json, os
config = json.loads(os.environ["CONFIG_PAYLOAD"])
services = json.loads(os.environ["SERVICE_PAYLOAD"])
apps = json.loads(os.environ["APP_PAYLOAD"])
print(json.dumps({
    "schema": "sevenos.baobab.apply-config.v1",
    "state": "ready" if config.get("state") == "ready" and services.get("state") == "ready" and apps.get("state") == "ready" else "needs-attention",
    "config": config,
    "services": services,
    "apps": apps,
}, indent=2, ensure_ascii=False))
PY
  else
    print_config_doctor
    print_service_doctor
    print_app_doctor
  fi
}

install_core() {
  local packages_json packages_string
  packages_json="$(python - "$ROOT_DIR/scripts/packages-culture.txt" <<'PY'
import json
import sys
from pathlib import Path

packages = []
for raw in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    raw = raw.split("#", 1)[0].strip()
    if raw:
        packages.append(raw)
print(json.dumps(packages))
PY
)"
  packages_string="$(PACKAGES_JSON="$packages_json" python -c 'import json,os; print(" ".join(json.loads(os.environ["PACKAGES_JSON"])))')"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    PACKAGES_JSON="$packages_json" python - <<'PY'
import json
import os

packages = json.loads(os.environ["PACKAGES_JSON"])
print(json.dumps({
    "schema": "sevenos.baobab.install-core.v1",
    "packages": packages,
    "command": "seven baobab install-core",
    "fallback": "sudo pacman -S --needed " + " ".join(packages),
    "requires_admin": True,
}, indent=2))
PY
  fi

  if ! command -v pacman >/dev/null 2>&1; then
    log_error "pacman is required to install Baobab core packages."
    return 1
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    log_error "sudo is required to install Baobab core packages."
    return 1
  fi
  if ! sudo -n true >/dev/null 2>&1; then
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      return 3
    fi
    log_warn "Admin password is required, but this session cannot provide it."
    log_info "Run in a local terminal: sudo pacman -S --needed $packages_string"
    log_info "Equivalent SevenOS route: ./install.sh culture --yes"
    return 3
  fi
  "$ROOT_DIR/install.sh" culture --yes
}

install_optional() {
  local json_output="$JSON_OUTPUT"
  local pacman_file="$ROOT_DIR/scripts/packages-culture-optional.txt"
  local aur_file="$ROOT_DIR/scripts/packages-culture-aur.txt"
  local language_lab_file="$ROOT_DIR/scripts/packages-culture-language-lab.txt"
  local has_helper=0
  command -v paru >/dev/null 2>&1 || command -v yay >/dev/null 2>&1 && has_helper=1
  bootstrap_baobab >/dev/null

  if [[ "$json_output" -eq 1 ]]; then
    PACMAN_FILE="$pacman_file" AUR_FILE="$aur_file" LANGUAGE_LAB_FILE="$language_lab_file" HAS_HELPER="$has_helper" BAOBAB_NODE="$BAOBAB_NODE" BAOBAB_PROFILE_DATA="$BAOBAB_PROFILE_DATA" python - <<'PY'
import json
import os
from pathlib import Path

def packages(path):
    items = []
    seen = set()
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        raw = raw.split("#", 1)[0].strip()
        if raw and raw not in seen:
            items.append(raw)
            seen.add(raw)
    return items

print(json.dumps({
    "schema": "sevenos.baobab.install-optional.v1",
    "pacman": packages(os.environ["PACMAN_FILE"]),
    "aur": packages(os.environ["AUR_FILE"]),
    "language_lab": packages(os.environ["LANGUAGE_LAB_FILE"]),
    "aur_helper_ready": os.environ["HAS_HELPER"] == "1",
    "commands": {
        "pacman": "sudo pacman -S --needed " + " ".join(packages(os.environ["PACMAN_FILE"])),
        "aur": "yay -S --needed " + " ".join(packages(os.environ["AUR_FILE"])),
        "language_lab": "yay -S --needed " + " ".join(packages(os.environ["LANGUAGE_LAB_FILE"])),
        "leaflet": "npm install --prefix " + os.environ["BAOBAB_NODE"] + " leaflet",
        "helpers": "./install.sh aur-helpers --yes",
        "kolibri": "pipx install kolibri",
        "open_webui_lab": "python -m venv " + os.environ["BAOBAB_PROFILE_DATA"] + "/open-webui-venv && " + os.environ["BAOBAB_PROFILE_DATA"] + "/open-webui-venv/bin/pip install open-webui",
    },
    "notes": [
        "Kiwix Desktop and Nextcloud are installed from official Arch repositories.",
        "Leaflet is installed inside the Baobab profile data root with npm, not globally.",
        "Kolibri is tracked as a pipx/external education route, not a pacman/AUR package here.",
        "Open WebUI is kept outside the default AUR route because it can pull nodejs-lts and conflict with the SevenOS nodejs runtime.",
        "Argos Translate is tracked as a language lab route because its Python/spaCy chain can be fragile on rolling Python releases; translate-shell remains the immediate fallback.",
        "Use the open_webui_lab command only for a dedicated Baobab AI lab, or prefer Ollama directly.",
        "Install optional engines only when Baobab needs AI, offline education or larger search."
    ],
}, indent=2))
PY
    return 0
  fi

  log_info "Installing Baobab optional repo packages."
  install_package_file "$pacman_file"
  if command -v npm >/dev/null 2>&1; then
    log_info "Installing Leaflet into Baobab profile data root."
    npm install --prefix "$BAOBAB_NODE" leaflet
  else
    log_warn "npm is missing; Leaflet local install skipped."
  fi
  log_info "Installing Baobab optional AUR/community packages when helper is available."
  install_aur_package_file "$aur_file" || log_warn "Baobab AUR optional packages were skipped."
  if ! command -v kolibri >/dev/null 2>&1; then
    log_info "Kolibri route: pipx install kolibri"
  fi
}

print_integration() {
  local wanted="${1:-}"
  if [[ -z "$wanted" ]]; then
    log_error "Missing integration name."
    return 1
  fi
  INTEGRATION_ROWS="$(integration_rows)" WANTED="$wanted" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sys

wanted = os.environ["WANTED"].lower()
for raw in os.environ["INTEGRATION_ROWS"].splitlines():
    group, key, title, role, source, phase, mode = raw.split("\t")
    if wanted in {group.lower(), key.lower()} or wanted in title.lower():
        payload = {"schema": "sevenos.baobab.integration.v1", "group": group, "key": key, "title": title, "role": role, "source": source, "phase": phase, "mode": mode}
        if os.environ.get("JSON_OUTPUT") == "1":
            print(json.dumps(payload, indent=2))
        else:
            print(title)
            print("=" * len(title))
            print(role)
            print(f"Group: {group}")
            print(f"Phase: {phase}")
            print(f"Mode: {mode}")
            print(f"Source: {source}")
        sys.exit(0)
sys.exit(1)
PY
}

print_roadmap() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    baobab_json
  else
    cat <<'EOF'
Baobab Integration Roadmap
==========================

Phase 1 - Shell and local core:
- AGS/Astal shell surfaces for Baobab Village, catalog, stats and packs.
- Three.js museum/village prototype fed by the local SQLite catalog.
- Foliate and Seven Reader as the reading lane.
- SQLite remains the default offline index.

Phase 2 - Cultural engines:
- Connect Arches/Dedalo-style heritage schemas through Baobab packs.
- Add Ollama, Piper and Argos as optional local AI, narration and translation engines.
- Evaluate Project NOMAD patterns for school/village offline bundles.
- Evaluate HyprPanel/Matshell patterns for richer cultural widgets.

Phase 3 - Immersive scale:
- Evaluate OpenAtlas, Collectionscope, eCorpus, CHER-Ob and Micromuseum patterns.
- Add Meilisearch when the local catalog outgrows SQLite search.
- Add Babylon.js only if richer 3D scenes need it beyond Three.js.
EOF
  fi
}

print_catalog() {
  bootstrap_baobab >/dev/null
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    cat "$CONTENT_INDEX"
  else
    BAOBAB_CATALOG="$CONTENT_INDEX" python - <<'PY'
import json
import os
from pathlib import Path

data = json.loads(Path(os.environ["BAOBAB_CATALOG"]).read_text(encoding="utf-8"))
print("Baobab Offline Catalog")
print("======================")
print(data.get("curation_note", ""))
print()
for item in data.get("records", []):
    print(f"- {item['title']} ({item['module']})")
    print(f"  {item['summary']}")
PY
  fi
}

print_countries() {
  bootstrap_baobab >/dev/null
  COUNTRIES_JSON="$COUNTRIES_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["COUNTRIES_JSON"]).read_text(encoding="utf-8"))
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Africa Countries")
    print("=======================")
    print(f"Countries: {payload.get('count', 0)}")
    print(f"Source: {payload.get('source', '')}")
    print()
    for item in payload.get("countries", []):
        population = item.get("population") or 0
        print(f"- {item.get('flag', '')} {item.get('name', 'Unknown')} - {item.get('capital', 'Unknown')} · {population:,}")
PY
}

print_country() {
  local query="${1:-}"
  if [[ -z "$query" ]]; then
    log_error "Missing country name."
    return 1
  fi
  bootstrap_baobab >/dev/null
  BAOBAB_DB="$BAOBAB_DB" QUERY="$query" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sqlite3
import sys
from pathlib import Path

query = os.environ["QUERY"].lower()
with sqlite3.connect(Path(os.environ["BAOBAB_DB"])) as conn:
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT payload FROM countries
        WHERE lower(name) LIKE ? OR lower(capital) LIKE ?
        ORDER BY name
        """,
        (f"%{query}%", f"%{query}%"),
    ).fetchall()
items = [json.loads(row["payload"]) for row in rows]
if not items:
    print(f"No Baobab country match: {query}", file=sys.stderr)
    sys.exit(1)
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps({"schema": "sevenos.baobab.country.v1", "query": query, "count": len(items), "countries": items}, indent=2, ensure_ascii=False))
else:
    print(f"Baobab Country: {query}")
    print("================" + "=" * len(query))
    for item in items:
        population = item.get("population") or 0
        print(f"- {item.get('flag', '')} {item.get('name', 'Unknown')}")
        print(f"  Capital: {item.get('capital', 'Unknown')}")
        print(f"  Population: {population:,}")
        print(f"  Confidence: {item.get('confidence', 'starter')}")
PY
}

print_unesco() {
  bootstrap_baobab >/dev/null
  UNESCO_JSON="$UNESCO_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import collections
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["UNESCO_JSON"]).read_text(encoding="utf-8"))
items = payload.get("items", [])
by_country = collections.Counter()
by_type = collections.Counter()
for item in items:
    by_type[item.get("type_acronym") or "unknown"] += 1
    for country in item.get("countries", []):
        by_country[country] += 1
summary = {
    "schema": "sevenos.baobab.unesco-ich.summary.v1",
    "source": payload.get("source"),
    "count": len(items),
    "top_countries": dict(by_country.most_common(12)),
    "types": dict(sorted(by_type.items())),
    "items": items[:40],
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(summary, indent=2, ensure_ascii=False))
else:
    print("Baobab UNESCO ICH")
    print("=================")
    print(f"African-linked entries: {len(items)}")
    print(f"Source: {payload.get('source', '')}")
    print()
    print("Top countries:")
    for country, count in by_country.most_common(10):
        print(f"- {country}: {count}")
    print()
    print("Recent sample:")
    for item in sorted(items, key=lambda entry: entry.get("year", ""), reverse=True)[:12]:
        title = item.get("title_en") or item.get("title_fr") or "Untitled"
        countries = ", ".join(item.get("countries", []))
        print(f"- {title} ({item.get('year', '')}, {countries})")
PY
}

search_catalog() {
  local query="${1:-}"
  if [[ -z "$query" ]]; then
    log_error "Missing search query."
    return 1
  fi
  bootstrap_baobab >/dev/null
  BAOBAB_DB="$BAOBAB_DB" QUERY="$query" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sqlite3
from pathlib import Path

query = os.environ["QUERY"].lower()
as_json = os.environ.get("JSON_OUTPUT") == "1"
matches = []
country_matches = []
unesco_matches = []
dataset_matches = []
with sqlite3.connect(Path(os.environ["BAOBAB_DB"])) as conn:
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT payload FROM records
        WHERE lower(id) LIKE ?
           OR lower(module) LIKE ?
           OR lower(title) LIKE ?
           OR lower(kind) LIKE ?
           OR lower(region) LIKE ?
           OR lower(summary) LIKE ?
           OR lower(tags) LIKE ?
        ORDER BY module, title
        """,
        tuple([f"%{query}%"] * 7),
    ).fetchall()
    country_rows = conn.execute(
        """
        SELECT payload FROM countries
        WHERE lower(name) LIKE ?
           OR lower(capital) LIKE ?
        ORDER BY name
        """,
        tuple([f"%{query}%"] * 2),
    ).fetchall()
    unesco_rows = conn.execute(
        """
        SELECT payload FROM unesco_ich
        WHERE lower(id) LIKE ?
           OR lower(ref) LIKE ?
           OR lower(year) LIKE ?
           OR lower(title_en) LIKE ?
           OR lower(title_fr) LIKE ?
           OR lower(summary_en) LIKE ?
           OR lower(summary_fr) LIKE ?
           OR lower(countries) LIKE ?
           OR lower(concepts) LIKE ?
        ORDER BY year DESC, title_en
        LIMIT 40
        """,
        tuple([f"%{query}%"] * 9),
    ).fetchall()
    dataset_rows = conn.execute(
        """
        SELECT payload FROM datasets
        WHERE lower(name) LIKE ?
           OR lower(path) LIKE ?
           OR lower(kind) LIKE ?
           OR lower(fields) LIKE ?
           OR lower(role) LIKE ?
        ORDER BY name
        """,
        tuple([f"%{query}%"] * 5),
    ).fetchall()
for row in rows:
    matches.append(json.loads(row["payload"]))
for row in country_rows:
    country_matches.append(json.loads(row["payload"]))
for row in unesco_rows:
    unesco_matches.append(json.loads(row["payload"]))
for row in dataset_rows:
    dataset_matches.append(json.loads(row["payload"]))

if as_json:
    print(json.dumps({"schema": "sevenos.baobab.search.v1", "engine": "sqlite", "query": query, "count": len(matches) + len(country_matches) + len(unesco_matches) + len(dataset_matches), "records": matches, "countries": country_matches, "unesco_ich": unesco_matches, "datasets": dataset_matches}, indent=2, ensure_ascii=False))
else:
    print(f"Baobab Search: {query}")
    print("================" + "=" * len(query))
    if not matches and not country_matches and not unesco_matches and not dataset_matches:
        print("No local catalog match yet.")
    for item in country_matches:
        print(f"- {item.get('flag', '')} {item.get('name', 'Unknown')} (country)")
        print(f"  Capital: {item.get('capital', 'Unknown')} · Population: {(item.get('population') or 0):,}")
    for item in matches:
        print(f"- {item['title']} ({item['module']})")
        print(f"  {item['summary']}")
    for item in unesco_matches[:12]:
        title = item.get("title_en") or item.get("title_fr") or "Untitled"
        print(f"- {title} (UNESCO ICH)")
        print(f"  {', '.join(item.get('countries', []))} · {item.get('year', '')}")
    for item in dataset_matches:
        print(f"- {item.get('name', 'dataset')} ({item.get('kind', 'data')} dataset)")
        print(f"  {item.get('rows', 0)} rows · {item.get('role', 'source-dataset')}")
PY
}

print_datasets() {
  bootstrap_baobab >/dev/null
  DATASETS_JSON="$DATASETS_JSON" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["DATASETS_JSON"]).read_text(encoding="utf-8"))
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2, ensure_ascii=False))
else:
    print("Baobab Datasets")
    print("===============")
    print(f"Sources: {payload.get('count', 0)}")
    print(f"Directory: {payload.get('source_dir', '')}")
    print()
    for item in payload.get("sources", []):
        fields = ", ".join(item.get("fields", [])[:8])
        print(f"- {item.get('name', 'dataset')} ({item.get('kind', 'data')})")
        print(f"  Rows: {item.get('rows', 0)} · Role: {item.get('role', 'source-dataset')}")
        if fields:
            print(f"  Fields: {fields}")
        if item.get("error"):
            print(f"  Error: {item['error']}")
PY
}

print_stats() {
  bootstrap_baobab >/dev/null
  BAOBAB_DB="$BAOBAB_DB" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sqlite3
from pathlib import Path

with sqlite3.connect(Path(os.environ["BAOBAB_DB"])) as conn:
    conn.row_factory = sqlite3.Row
    total = conn.execute("SELECT COUNT(*) AS value FROM records").fetchone()["value"]
    country_total = conn.execute("SELECT COUNT(*) AS value FROM countries").fetchone()["value"]
    unesco_total = conn.execute("SELECT COUNT(*) AS value FROM unesco_ich").fetchone()["value"]
    dataset_total = conn.execute("SELECT COUNT(*) AS value FROM datasets").fetchone()["value"]
    by_module = {row["module"]: row["count"] for row in conn.execute("SELECT module, COUNT(*) AS count FROM records GROUP BY module ORDER BY module")}
    by_region = {row["region"] or "unknown": row["count"] for row in conn.execute("SELECT region, COUNT(*) AS count FROM records GROUP BY region ORDER BY region")}
    by_confidence = {row["confidence"] or "unknown": row["count"] for row in conn.execute("SELECT confidence, COUNT(*) AS count FROM records GROUP BY confidence ORDER BY confidence")}
    by_country = {row["country"] or "unknown": row["count"] for row in conn.execute("SELECT country, COUNT(*) AS count FROM records GROUP BY country ORDER BY country")}
    packs = [row["value"] for row in conn.execute("SELECT value FROM meta WHERE key = 'schema'")]

payload = {
    "schema": "sevenos.baobab.stats.v1",
    "database": os.environ["BAOBAB_DB"],
    "records": total,
    "country_index": country_total,
    "unesco_ich": unesco_total,
    "datasets": dataset_total,
    "modules": by_module,
    "regions": by_region,
    "confidence": by_confidence,
    "countries": by_country,
    "sqlite_schema": packs[0] if packs else "unknown",
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2))
else:
    print("Baobab Stats")
    print("============")
    print(f"Records: {total}")
    print(f"Countries: {country_total}")
    print(f"UNESCO ICH: {unesco_total}")
    print(f"Datasets: {dataset_total}")
    print(f"Database: {payload['database']}")
    print()
    print("Modules:")
    for key, value in by_module.items():
        print(f"- {key}: {value}")
    print()
    print("Regions:")
    for key, value in by_region.items():
        print(f"- {key}: {value}")
    print()
    print("Confidence:")
    for key, value in by_confidence.items():
        print(f"- {key}: {value}")
PY
}

print_db_status() {
  bootstrap_baobab >/dev/null
  BAOBAB_DB="$BAOBAB_DB" BAOBAB_CATALOG="$CONTENT_INDEX" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
import json
import os
import sqlite3
from pathlib import Path

db_path = Path(os.environ["BAOBAB_DB"])
catalog_path = Path(os.environ["BAOBAB_CATALOG"])
with sqlite3.connect(db_path) as conn:
    conn.row_factory = sqlite3.Row
    count = conn.execute("SELECT COUNT(*) AS value FROM records").fetchone()["value"]
    country_count = conn.execute("SELECT COUNT(*) AS value FROM countries").fetchone()["value"]
    unesco_count = conn.execute("SELECT COUNT(*) AS value FROM unesco_ich").fetchone()["value"]
    dataset_count = conn.execute("SELECT COUNT(*) AS value FROM datasets").fetchone()["value"]
    user_version = conn.execute("PRAGMA user_version").fetchone()[0]
payload = {
    "schema": "sevenos.baobab.db.v1",
    "state": "ready" if db_path.exists() and count >= 1 else "empty",
    "path": str(db_path),
    "catalog": str(catalog_path),
    "records": count,
    "countries": country_count,
    "unesco_ich": unesco_count,
    "datasets": dataset_count,
    "user_version": user_version,
}
if os.environ.get("JSON_OUTPUT") == "1":
    print(json.dumps(payload, indent=2))
else:
    print("Baobab SQLite")
    print("=============")
    print(f"State: {payload['state']}")
    print(f"Records: {count}")
    print(f"Countries: {country_count}")
    print(f"UNESCO ICH: {unesco_count}")
    print(f"Datasets: {dataset_count}")
    print(f"Path: {db_path}")
PY
}

print_module() {
  local wanted="${1:-}"
  if [[ -z "$wanted" ]]; then
    log_error "Missing Baobab module name."
    return 1
  fi
  module_rows | awk -F '\t' -v wanted="$wanted" '$1 == wanted || tolower($2) ~ wanted {
    print $2
    print "================"
    print $3
    print "Tags: " $4
    print "State: " $5
    found=1
  } END { if (!found) exit 1 }' || {
    log_error "Unknown Baobab module: $wanted"
    return 1
  }
}

print_module_json() {
  local wanted="${1:-}"
  if [[ -z "$wanted" ]]; then
    log_error "Missing Baobab module name."
    return 1
  fi
  MODULE_ROWS="$(module_rows)" WANTED="$wanted" BAOBAB_DATA="$BAOBAB_DATA" BAOBAB_WORKSPACE="$BAOBAB_WORKSPACE" python - <<'PY'
import json
import os
import sys
from pathlib import Path

wanted = os.environ["WANTED"].lower()
for raw in os.environ["MODULE_ROWS"].splitlines():
    key, title, purpose, tags, state = raw.split("\t")
    if key == wanted or wanted in title.lower():
        print(json.dumps({
            "schema": "sevenos.baobab.module.v1",
            "key": key,
            "title": title,
            "purpose": purpose,
            "tags": tags.split(","),
            "state": state,
            "data_path": str(Path(os.environ["BAOBAB_DATA"]) / key),
            "workspace_path": str(Path(os.environ["BAOBAB_WORKSPACE"]) / title.replace("Baobab ", "").replace("African ", "")),
        }, indent=2))
        sys.exit(0)
sys.exit(1)
PY
}

doctor() {
  local payload state tools_json tools_state tools_score immersive_score
  payload="$(baobab_json)"
  state="$(BAOBAB_JSON="$payload" python -c 'import json,os; print(json.loads(os.environ["BAOBAB_JSON"]).get("state","unknown"))')"
  tools_json="$(JSON_OUTPUT=1 print_tools)"
  tools_state="$(BAOBAB_TOOLS="$tools_json" python -c 'import json,os; print(json.loads(os.environ["BAOBAB_TOOLS"]).get("state","unknown"))')"
  tools_score="$(BAOBAB_TOOLS="$tools_json" python -c 'import json,os; print(json.loads(os.environ["BAOBAB_TOOLS"]).get("score",0))')"
  immersive_score="$(BAOBAB_TOOLS="$tools_json" python -c 'import json,os; print(json.loads(os.environ["BAOBAB_TOOLS"]).get("immersive_score",0))')"
  print_status
  printf '\nBaobab tools: %s (%s%% core, %s%% immersive)\n' "$tools_state" "$tools_score" "$immersive_score"
  [[ "$state" == "ready" && "$tools_state" == "ready" ]]
}

doctor_json() {
  local payload tools_json config_json_payload service_json_payload app_json_payload capability_json_payload protocol_json_payload
  payload="$(baobab_json)"
  tools_json="$(JSON_OUTPUT=1 print_tools)"
  config_json_payload="$(config_doctor_json)"
  service_json_payload="$(service_doctor_json)"
  app_json_payload="$(app_doctor_json)"
  capability_json_payload="$(capability_doctor_json)"
  protocol_json_payload="$(JSON_OUTPUT=1 protocol_doctor)"
  BAOBAB_JSON="$payload" BAOBAB_TOOLS="$tools_json" BAOBAB_CONFIG_DOCTOR="$config_json_payload" BAOBAB_SERVICE_DOCTOR="$service_json_payload" BAOBAB_APP_DOCTOR="$app_json_payload" BAOBAB_CAPABILITY_DOCTOR="$capability_json_payload" BAOBAB_PROTOCOL_DOCTOR="$protocol_json_payload" python - <<'PY'
import json
import os

base = json.loads(os.environ["BAOBAB_JSON"])
tools = json.loads(os.environ["BAOBAB_TOOLS"])
config = json.loads(os.environ["BAOBAB_CONFIG_DOCTOR"])
services = json.loads(os.environ["BAOBAB_SERVICE_DOCTOR"])
apps = json.loads(os.environ["BAOBAB_APP_DOCTOR"])
capabilities = json.loads(os.environ["BAOBAB_CAPABILITY_DOCTOR"])
protocols = json.loads(os.environ["BAOBAB_PROTOCOL_DOCTOR"])
issues = []
if base.get("state") != "ready":
    issues.append({
        "area": "runtime",
        "severity": "high",
        "title": "Baobab bootstrap incomplete",
        "command": "seven baobab bootstrap",
    })
for item in tools.get("next", []):
    issues.append({
        "area": "tools",
        "severity": "medium",
        "title": f"Missing core tool: {item.get('title')}",
        "detail": item.get("reason", ""),
        "command": "seven profile install baobab",
    })
if config.get("state") != "ready":
    issues.append({
        "area": "config",
        "severity": "high",
        "title": "Baobab profile config is not fully isolated",
        "detail": config.get("rule", ""),
        "command": "seven baobab apply-config",
    })
if services.get("state") != "ready":
    issues.append({
        "area": "services",
        "severity": "medium",
        "title": "Baobab service launchers need attention",
        "detail": services.get("policy", ""),
        "command": "seven baobab apply-config",
    })
if apps.get("state") != "ready":
    issues.append({
        "area": "apps",
        "severity": "medium",
        "title": "Baobab app launchers need attention",
        "detail": apps.get("policy", ""),
        "command": "seven baobab apply-config",
    })
if protocols.get("state") != "pass":
    issues.append({
        "area": "protocols",
        "severity": "high",
        "title": "Baobab cultural protocols need attention",
        "detail": "Sensitive or unknown material must stay local-first until source, consent and local review are explicit.",
        "command": "seven baobab protocol-doctor",
    })
state = "ready" if not issues else "ready-with-actions" if base.get("state") == "ready" else "needs-bootstrap"
print(json.dumps({
    "schema": "sevenos.baobab.doctor.v1",
    "state": state,
    "base_state": base.get("state"),
    "tool_state": tools.get("state"),
    "config_state": config.get("state"),
    "service_state": services.get("state"),
    "app_state": apps.get("state"),
    "score": base.get("score", 0),
    "tool_score": tools.get("score", 0),
    "config_score": config.get("score", 0),
    "service_score": services.get("score", 0),
    "app_score": apps.get("score", 0),
    "capability_score": capabilities.get("score", 0),
    "protocol_score": protocols.get("score", 0),
    "immersive_score": tools.get("immersive_score", 0),
    "issues": issues,
    "next": issues[:8],
    "tools": tools,
    "config": config,
    "services": services,
    "apps": apps,
    "capabilities": capabilities,
    "protocols": protocols,
}, indent=2, ensure_ascii=False))
PY
}

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      baobab_json
    else
      print_status
    fi
    ;;
  json)
    baobab_json
    ;;
  plan)
    print_plan
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      doctor_json
    else
      doctor
    fi
    ;;
  bootstrap)
    bootstrap_baobab
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      baobab_json
    else
      printf 'Baobab workspace ready: %s\n' "$BAOBAB_WORKSPACE"
    fi
    ;;
  install-core)
    install_core
    ;;
  install-optional)
    install_optional
    ;;
  capabilities)
    print_capabilities
    ;;
  capability-doctor)
    print_capability_doctor
    ;;
  config)
    print_config
    ;;
  runtime)
    print_runtime
    ;;
  config-doctor)
    print_config_doctor
    ;;
  service-doctor)
    print_service_doctor
    ;;
  app-doctor)
    print_app_doctor
    ;;
  apply-config)
    apply_config
    ;;
  sound)
    open_sound
    ;;
  open)
    bootstrap_baobab
    if [[ -x "$ROOT_DIR/bin/seven-baobab-native" && -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
      "$ROOT_DIR/bin/seven-baobab-native" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
      xdg-open "$VILLAGE_HTML" >/dev/null 2>&1 || xdg-open "$BAOBAB_WORKSPACE" >/dev/null 2>&1 || true
    else
      printf '%s\n' "$VILLAGE_HTML"
    fi
    ;;
  native)
    bootstrap_baobab
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '{"schema":"sevenos.baobab.native.v1","path":%s}\n' "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$ROOT_DIR/bin/seven-baobab-native")"
    else
      if [[ -n "$VIEW_TARGET" && "$VIEW_TARGET" != "__next__" ]]; then
        "$ROOT_DIR/bin/seven-baobab-native" --view "$VIEW_TARGET"
      else
        "$ROOT_DIR/bin/seven-baobab-native"
      fi
    fi
    ;;
  village)
    bootstrap_baobab
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '{"schema":"sevenos.baobab.village.v1","path":%s}\n' "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$VILLAGE_HTML")"
    else
      printf '%s\n' "$VILLAGE_HTML"
    fi
    ;;
  heritage)
    bootstrap_baobab
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '{"schema":"sevenos.baobab.heritage.v1","path":%s}\n' "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$HERITAGE_HTML")"
    elif command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
      xdg-open "$HERITAGE_HTML" >/dev/null 2>&1 || printf '%s\n' "$HERITAGE_HTML"
    else
      printf '%s\n' "$HERITAGE_HTML"
    fi
    ;;
  museum)
    bootstrap_baobab
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '{"schema":"sevenos.baobab.museum.v1","path":%s}\n' "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$MUSEUM_HTML")"
    elif command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
      xdg-open "$MUSEUM_HTML" >/dev/null 2>&1 || printf '%s\n' "$MUSEUM_HTML"
    else
      printf '%s\n' "$MUSEUM_HTML"
    fi
    ;;
  story)
    bootstrap_baobab
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '{"schema":"sevenos.baobab.story.v1","path":%s}\n' "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$STORY_HTML")"
    elif command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
      xdg-open "$STORY_HTML" >/dev/null 2>&1 || printf '%s\n' "$STORY_HTML"
    else
      printf '%s\n' "$STORY_HTML"
    fi
    ;;
  explore)
    bootstrap_baobab
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '{"schema":"sevenos.baobab.explore.v1","native":%s,"fallback":%s}\n' \
        "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$ROOT_DIR/bin/seven-baobab-native")" \
        "$(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$EXPLORE_HTML")"
    elif [[ -x "$ROOT_DIR/bin/seven-baobab-native" && -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
      "$ROOT_DIR/bin/seven-baobab-native" --view explore >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
      xdg-open "$EXPLORE_HTML" >/dev/null 2>&1 || printf '%s\n' "$EXPLORE_HTML"
    else
      printf '%s\n' "$EXPLORE_HTML"
    fi
    ;;
  countries)
    print_countries
    ;;
  country)
    print_country "$COUNTRY_QUERY"
    ;;
  immersions)
    print_immersions
    ;;
  immersion)
    print_immersion "$COUNTRY_QUERY"
    ;;
  ritual)
    print_ritual
    ;;
  journal)
    print_journal
    ;;
  route)
    print_route
    ;;
  ambiance)
    print_ambiance "$COUNTRY_QUERY"
    ;;
  compass)
    print_compass
    ;;
  today)
    print_today
    ;;
  session)
    print_session
    ;;
  trail)
    print_trail
    ;;
  remember)
    remember_trail "$SEARCH_QUERY"
    ;;
  shell)
    print_shell
    ;;
  unesco)
    print_unesco
    ;;
  datasets)
    print_datasets
    ;;
  catalog)
    print_catalog
    ;;
  search)
    search_catalog "$SEARCH_QUERY"
    ;;
  stats)
    print_stats
    ;;
  db)
    print_db_status
    ;;
  engines)
    print_engines
    ;;
  tools)
    print_tools
    ;;
	  tool-doctor)
	    tool_doctor
	    ;;
	  languages)
	    print_languages
	    ;;
	  protocols)
	    print_protocols
	    ;;
	  protocol-doctor)
	    protocol_doctor
	    ;;
	  integrations)
    print_integrations
    ;;
  integration)
    print_integration "$MODULE_NAME" || {
      log_error "Unknown Baobab integration: $MODULE_NAME"
      exit 1
    }
    ;;
  roadmap)
    print_roadmap
    ;;
  packs)
    list_packs
    ;;
  audit-packs)
    audit_packs
    ;;
  seed-packs)
    seed_curated_packs
    ;;
  enrich-packs)
    enrich_packs
    ;;
  evidence-packs)
    evidence_packs
    ;;
  validation-kit)
    validation_kit
    ;;
  validation-doctor)
    validation_doctor
    ;;
  sample-fieldwork)
    sample_fieldwork
    ;;
  scaffold-pack)
    scaffold_pack "$PACK_TARGET"
    ;;
  import-pack)
    import_pack "$PACK_TARGET"
    ;;
  modules)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      baobab_json
    else
      print_modules
    fi
    ;;
  module)
    if [[ -z "$MODULE_NAME" ]]; then
      shift || true
      MODULE_NAME="${1:-}"
    fi
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      print_module_json "$MODULE_NAME" || {
        log_error "Unknown Baobab module: $MODULE_NAME"
        exit 1
      }
    else
      print_module "$MODULE_NAME"
    fi
    ;;
esac
