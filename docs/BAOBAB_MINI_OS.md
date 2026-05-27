# Baobab Cultural Mini OS

Baobab is the African cultural mini OS inside SevenOS. It is not a theme, not a
decorative skin and not only a reading profile. It is a living cultural
environment for heritage, learning, creation, transmission and preservation.

## Vision

Baobab should feel like using rooted technology: modern computing shaped by
memory, oral transmission, community validation, calm learning and cultural
continuity.

```text
SevenOS Core
  |
  +-- Baobab Runtime
        |
        +-- Heritage Engine
        +-- Seven Baobab AI
        +-- Story Engine
        +-- Soundscape Engine
        +-- Explore Africa
        +-- Museum 3D
        +-- Language Hub
        +-- Fashion Engine
        +-- Food Engine
        +-- Baobab Market
```

The goal is an immersive environment for African cultures, traditions,
languages, arts, music, history, architecture, cuisine, fashion, spirituality,
oral knowledge and community memory, without reducing African identity to
decorative patterns, folklore or postcard imagery.

## Art Direction

Baobab must be African in its thinking before it is African in its decoration.
The design direction is `Rooted Technology`: calm, premium, contemplative,
educational and modern.

Prefer:
- volcanic black, warm ivory, baobab green, textile indigo and restrained copper
  light;
- subtle root geometry, generous spacing and quiet depth;
- words and workflows around roots, branches, memory, oral transmission,
  community review and learning;
- an AI guide that feels calm, contextual and educational.

Avoid:
- safari, postcard Africa, animals and decorative clichés;
- red/green/yellow saturation;
- motif overload, wax everywhere or mask-heavy identity;
- aggressive cyberpunk, RGB futurism and noisy dashboards.

The cultural signal should come from micro details, names, sound, transitions,
source quality, community validation and interaction philosophy.

## Knowledge Tree

The native home surface is organized as an `Arbre de connaissance`. This is the
primary product metaphor for Baobab: not a dashboard, not a decorative village,
but a living structure for orientation, memory, relationships and transmission.

| Level | Role | Native Surface |
| --- | --- | --- |
| Racines | Orientation, sources, engines and system readiness | Recherche, Moteurs, Sources |
| Tronc | Central memory and narrated knowledge | Patrimoine, Modules, Récits |
| Branches | Countries, languages and cultural relationships | Explorer, Langues, Musée |
| Feuilles | Daily cultural uses | Son, Mode, Cuisine |
| Collecte | Living memory capture | Nouvelle collecte, Packs, Audit |
| Archives | Preservation and continuity | Patrimoine, Musée, Sources |

## Digital Village

| Place | Module | Role |
| --- | --- | --- |
| Racines | Home | Orientation, memory and daily continuity |
| Bibliothèque | Heritage | Books, archives, proverbs and oral traditions |
| Cercle | Wisdom | History, philosophy and elder knowledge |
| Écoute | Sound | Music, narration, radio, instruments and sound memory |
| Marché | Market | Creators, crafts, textiles, books and instruments |
| Atelier | Fashion | Traditional style, modern design and ElegantStyle bridge |
| Branches | Explore | Countries, languages, food, monuments and timelines |
| Cuisine | Food | Recipes, stories and regional gastronomy |
| Archives | Museum 3D | Objects, architecture, instruments and contextual collections |

## Runtime Layers

Kernel Layer:
- quiet CPU and IO profile;
- battery-friendly defaults;
- media/reading foreground priority;
- low background activity.

Runtime Layer:
- local heritage database;
- offline media and map cache;
- language dictionaries and learning packs;
- local AI memory and narration assets.

Experience Layer:
- Baobab Village home surface;
- African-first product philosophy;
- subtle organic transitions;
- soundscape-aware cultural focus.

Intelligence Layer:
- Seven Baobab AI as calm guide, narrator, language tutor and historian;
- local-first recommendations;
- explicit cultural context and source notes.

## Tool Strategy

Baobab tools serve three goals:

- valorize African cultures without turning the OS into decorative folklore;
- work locally and offline first;
- create a light, immersive and intelligent public experience.

Boundary with Atlas:

- Baobab owns culture, oral memory, African languages, storytelling, local
  heritage packs, cultural collections and community transmission.
- Atlas owns general documents, scan/OCR, PDF annotation, office files, maps,
  GPX, archives, references and trip/research navigation.
- Shared tools must have an explicit reason. Check the boundary with:

```bash
seven mini-boundaries
```

Core tools are kept small and essential:

| Area | Tools | Role |
| --- | --- | --- |
| Shell | Hyprland, Waybar | fluid Wayland base and cultural status bar |
| Identity | Noto Fonts, PipeWire | language coverage and audio foundation |
| Content | SQLite | local cultural database |
| Media | MPV | lightweight sound, video and narration playback |
| Reader | Seven Reader | native SevenOS reading lane |

Optional immersive tools expand Baobab when the machine and user need them:

| Area | Tools | Role |
| --- | --- | --- |
| Widgets | Eww, SwayNC | cultural widgets and elegant notifications |
| Dynamic identity | Pywal | palettes from cultural images and textiles |
| Search | Meilisearch | instant local search for large archives |
| AI | Ollama, llama.cpp, Open WebUI | local assistant, modest-machine inference and learning labs |
| Education | Foliate, Kiwix, Kolibri | books, encyclopedias and offline classes |
| Sound | Tauon Music Box, Radio Browser API | cultural music library and online radio route |
| Store | PackageKit, Flatpak | future public app/source layer without backend jargon |
| Sync | Syncthing, Nextcloud | local/community sharing without requiring a central cloud |
| Creation | Krita, Blender, Kdenlive | artisan, museum, video and educational production |

Inspect this contract with:

```bash
seven baobab tools
seven baobab tool-doctor
```

The goal is not to install everything by default. The goal is that Baobab knows
which tools belong to its cultural, educational, offline and community mission,
and can grow from a lightweight base to a richer cultural workstation.

Package manifests:

- `scripts/packages-culture.txt`: lightweight core;
- `scripts/packages-culture-optional.txt`: optional tools that should not be
  required for bootstrapping Baobab;
- `scripts/packages-culture-aur.txt`: AUR/community candidates such as Eww,
  Piper and llama.cpp. Open WebUI is kept as an explicit lab route because its
  AUR package can pull `nodejs-lts` and conflict with the active SevenOS
  `nodejs` runtime.
- `scripts/packages-culture-ai-lab.txt`: external AI lab candidates that should
  be installed deliberately, not as part of the default Baobab bootstrap.
- `scripts/packages-culture-language-lab.txt`: heavier language/translation
  candidates such as Argos Translate, separated from the default route because
  their Python dependency chain can be fragile on rolling releases.

Use `seven baobab install-core` to install the core package route. It requires
administrator rights because it delegates to the system package manager.

Use `seven baobab install-optional` only when you want the larger immersive
stack. It installs repo packages first, then uses `paru` or `yay` for AUR
candidates if available. Kolibri is handled as an external/pipx route:
`pipx install kolibri`.

Current install routes for the remaining immersive tools:

```bash
sudo pacman -S --needed kiwix-desktop nextcloud nextcloud-client
npm install --prefix ~/.local/share/sevenos/profiles/baobab/node leaflet
yay -S --needed eww piper-tts-bin llama.cpp
pipx install kolibri
```

Leaflet is intentionally installed inside Baobab's profile data root, not as a
global SevenOS dependency.

Open WebUI should be installed only for a dedicated Baobab AI lab, preferably
outside the default AUR transaction:

```bash
python -m venv ~/.local/share/sevenos/profiles/baobab/open-webui-venv
~/.local/share/sevenos/profiles/baobab/open-webui-venv/bin/pip install open-webui
```

Argos Translate is also a deliberate language-lab route for now. Baobab can use
`translate-shell` immediately through `trans`, while Argos remains available
when the target machine is ready for the heavier offline translation stack:

```bash
yay -S --needed argos-translate
```

## Offline-First

Baobab must remain useful in schools, villages and low-connectivity contexts.

```text
Cloud or community sync
  -> local cache
  -> SQLite heritage DB
  -> local media/map storage
  -> local AI/TTS/translation
```

Core content must open without internet. Sync is additive and should never be
required for daily learning.

## Commands

```bash
seven baobab
seven baobab bootstrap
seven baobab install-core
seven baobab install-optional
seven baobab capabilities
seven baobab capability-doctor
seven baobab native
seven baobab village
seven baobab heritage
seven baobab museum
seven baobab story
seven baobab explore
seven baobab countries
seven baobab country Burkina Faso
seven baobab unesco
seven baobab datasets
seven baobab catalog
seven baobab search wisdom
seven baobab stats
seven baobab db
seven baobab engines
seven baobab tools
seven baobab tool-doctor
seven baobab languages
seven baobab integrations
seven baobab integration ollama
seven baobab roadmap
seven baobab packs
seven baobab audit-packs
seven baobab seed-packs
seven baobab enrich-packs
seven baobab sample-fieldwork
seven baobab scaffold-pack local-heritage
seven baobab import-pack ~/.local/share/sevenos/profiles/baobab/baobab/packs/local-heritage/pack.json
seven baobab config
seven baobab runtime
seven baobab config-doctor
seven baobab service-doctor
seven baobab app-doctor
seven baobab apply-config
seven baobab sound
seven baobab modules
seven baobab module heritage
seven profile activate baobab
```

Machine-readable contract:

```bash
seven baobab --json
```

## Folder Layout

```text
~/.config/sevenos/profiles/baobab/
  profile-ui.json
  session.json
  passage.json
  wallpaper-state
  baobab/
    env
    bin/baobab-run
    bin/baobab-sound
    bin/baobab-searchd
    bin/baobab-ai
    bin/baobab-narrate
    runtime.json
    config-manifest.json
    mpv/mpv.conf
    waybar/config.jsonc
    eww/baobab.yuck
    meilisearch/config.toml
    ollama/Modelfile.baobab
    piper/narration.json
    argos/translation.json
    capabilities.json
    apps.json

~/.local/share/sevenos/profiles/baobab/applications/
  seven-baobab-os.desktop
  seven-baobab-collect.desktop
  seven-baobab-explore.desktop
  seven-baobab-sound.desktop

~/.local/share/sevenos/profiles/baobab/baobab/
  catalog.json
  baobab.sqlite
  heritage/
    african-unesco-ich.json
  story/
  sound/
  explore/
    africa-countries.json
  museum/
  languages/
    african-languages.json
  fashion/
  food/
  wisdom/
  market/
  offline/
  ai-memory/
  packs/
  catalog.json
  baobab.sqlite

~/Baobab/
  Village/
    index.html
  Heritage/
    index.html
  Story Engine/
    index.html
  Sound/
  Explore/
    index.html
  Museum 3D/
    index.html
  Language Hub/
  Fashion/
  Food/
  Wisdom/
  Market/
```

Baobab treats global SevenOS files as projections only. The durable source of
truth for Baobab settings, service configs, wallpaper state, session memory and
runtime data lives under `sevenos/profiles/baobab`.

`seven baobab apply-config` materializes the profile-owned runtime. It prepares
launchers for local sound, search, AI and narration without auto-starting heavy
services. `seven baobab service-doctor` checks those launchers, and
`seven baobab sound` plays local audio through Baobab's own MPV configuration.
`seven baobab app-doctor` validates the Baobab-owned desktop entries, so public
launchers can be projected into SevenOS without making global files the source
of truth.

`seven baobab capabilities` is the product map for the tool strategy. It groups
Hyprland, Waybar, Eww, SwayNC, Noto, Pywal, SQLite, Meilisearch, Leaflet,
Ollama, llama.cpp, Open WebUI, Foliate, Kiwix, Kolibri, MPV, Tauon, PackageKit,
Flatpak, Syncthing, Nextcloud, Krita, Blender and Kdenlive into cultural
capabilities instead of presenting them as disconnected Linux packages.

## Starter Catalog

Bootstrap creates a local starter catalog at
`~/.local/share/sevenos/profiles/baobab/baobab/catalog.json` and a generated Village page at
`~/Baobab/Village/index.html`.

`seven baobab heritage` opens `~/Baobab/Heritage/index.html`, a public-facing
visual gallery generated from the local African-linked UNESCO ICH database.

`seven baobab native` opens the French-first GTK interface. This is the normal
public Baobab OS surface; the HTML pages remain offline exports and fallback
views.

The native interface also exposes:

- a global search surface for countries, UNESCO ICH, catalog records and local
  datasets;
- a country profile with heritage, languages, cuisine, music, fashion and story
  lanes;
- module workflows for Languages, Sound, Food, Fashion, Market, Wisdom, Museum
  and Explore;
- an immersive engine readiness view for narration, sound, AI, shell, search and
  translation engines;
- French-first preferences that prepare the future African-language i18n layer.

The starter catalog is intentionally metadata-first. It gives Baobab useful
offline structure immediately, while leaving factual cultural content to be
expanded with locally curated, source-backed packs.

Bootstrap also syncs the catalog into `baobab.sqlite`, so search and future
native UI views can query a local database without requiring network access.

`seven baobab museum` generates an offline Canvas scene at
`~/Baobab/Museum 3D/index.html`. It is a dependency-free prototype for the
future Three.js/OpenVGAL/eCorpus museum layer.

`seven baobab story` generates an offline fire-circle storytelling surface at
`~/Baobab/Story Engine/index.html`. It is ready to later attach Piper narration,
Ollama explanations and Argos translation while keeping the source-backed
catalog model unchanged.

`seven baobab explore` generates an offline cultural map prototype at
`~/Baobab/Explore/index.html`. It prepares the future MapLibre/GeoJSON layer
while remaining useful with only the local catalog and SQLite index.

`seven baobab countries` exposes the embedded Africa country index generated
from `identity/countries/africa.tsv`. Bootstrap stores it as
`~/.local/share/sevenos/profiles/baobab/baobab/explore/africa-countries.json` and mirrors it
into SQLite, so Explore has a stable offline geographic base before MapLibre is
introduced.

`seven baobab country <name>` opens a local country detail, and `seven baobab
search <query>` searches both cultural records and the country index.

If `identity/baobab_db/africanUnesco.csv` is present, bootstrap filters it
against the embedded Africa country index and generates
`~/.local/share/sevenos/profiles/baobab/baobab/heritage/african-unesco-ich.json`.
`seven baobab unesco` summarizes those African-linked UNESCO intangible
cultural heritage entries, and SQLite mirrors them in `unesco_ich` for offline
search.

`seven baobab datasets` inventories every CSV, TSV and JSON file placed in
`identity/baobab_db/`, records its fields and row count, writes
`~/.local/share/sevenos/profiles/baobab/baobab/offline/datasets.json`, and mirrors the result
into SQLite. This is the generic lane for future Baobab sources: languages,
recipes, music, fashion, oral history, artisan catalogs and community archives.

## Cultural Packs

Baobab packs are local JSON bundles with records for any Baobab module:
heritage, story, sound, explore, museum, languages, fashion, food, wisdom or
market.

```bash
seven baobab seed-packs
seven baobab enrich-packs
seven baobab sample-fieldwork
seven baobab scaffold-pack local-heritage
seven baobab import-pack ~/.local/share/sevenos/profiles/baobab/baobab/packs/local-heritage/pack.json
seven baobab search local
```

`seven baobab seed-packs` creates and imports three starter packs for the public
Baobab experience: `burkina-food`, `mandingue-sound` and
`faso-danfani-fashion`. They are not final community validation; they keep
source files beside the records so local curators can add interviews, photos,
permissions and review notes.

`seven baobab enrich-packs` prepares the living-heritage workflow inside each
pack: interview templates, consent notes, media manifests and community review
checklists. `seven baobab audit-packs` then reports both provenance quality and
workflow readiness.

The audit also separates workflow readiness from real field collection. A pack
can be `collection-ready` while still having `collection_score: 0` until real
interviews, consent files, media manifest items, reviewed checklist items,
recipes, audio or creator notes are added.

`seven baobab sample-fieldwork` creates sample-only files to demonstrate the
collection pipeline. Those files are explicitly marked `sample-only`; they are
useful for testing the UI and audit, but must be replaced before claiming real
community validation.

Each pack includes a `sources/` directory. Factual cultural material should be
documented there before being shared, taught or synced.

The native Baobab app also exposes `Collecte`, a French-first assistant for
creating a draft interview, recipe, audio note, photo note, textile/creator note
or proverb. It writes the content into the selected pack, creates a consent file
and updates the media manifest as `status: draft`; validation remains manual and
community-led.

Pack records must carry provenance fields:

```text
source, license, curator, confidence, language, country
```

Confidence levels are intentionally explicit:

```text
draft, starter, low, medium, high, community-validated
```

## African Languages

Baobab ships a small starter language index generated into:

```text
~/.local/share/sevenos/profiles/baobab/baobab/languages/african-languages.json
```

Inspect it with:

```bash
seven baobab languages
seven baobab languages --json
```

The starter list includes Mooré, Dioula, Bambara, Wolof, Swahili and Yoruba.
Entries are deliberately marked `needs-local-speaker` so the UI can begin as a
public learning surface without pretending that unreviewed phrases are validated
teaching material.

`seven baobab audit-packs` checks those fields and reports draft records,
missing source files, duplicate IDs and invalid confidence levels.

## Open Source Engine Strategy

Baobab should assemble proven engines instead of rebuilding every layer from
zero.

```bash
seven baobab engines
seven baobab integrations
seven baobab integration arches
seven baobab roadmap
```

Current integration groups:

| Group | Candidates | Baobab use |
| --- | --- | --- |
| Shell | AGS, Astal, Matshell, HyprPanel, HighBar | Baobab Shell, widgets, dashboard, launcher |
| Heritage | Arches, Dedalo, OpenAtlas, Collectionscope | cultural inventory, archives, historical relationships |
| Museum | OpenVGAL, eCorpus, CHER-Ob, Micromuseum | 3D exhibitions, annotations, collection views |
| 3D | Three.js, Babylon.js | village, map and museum scenes |
| Offline | SQLite, Project NOMAD, Meilisearch | local knowledge, school/village bundles, search |
| AI | Ollama, Piper, Argos Translate | guide, narration, local translation |
| Reader | Foliate | ebooks and immersive reading |

## Long-Term Stack

| Domain | Candidate |
| --- | --- |
| UI shell | AGS/Astal or Tauri |
| Local DB | SQLite |
| Search | Meilisearch or SQLite FTS |
| AI | Ollama |
| Embeddings | BGE |
| Vector DB | ChromaDB |
| Voice | Piper TTS |
| Translation | Argos Translate |
| 3D | Three.js |
| Maps | MapLibre + offline GeoJSON |
| Media | MPV/VLC backend |

Baobab becomes complete when launching it feels less like changing settings and
more like entering a cultural place.
