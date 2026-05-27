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
        +-- Cultural Immersions
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
| Immersions | Regional entry points and guided rituals | Sahel, Mandé, Swahili Coast, Great Lakes |
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
| Sound | Audacity, Tauon Music Box, Radio Browser API | oral recordings, cultural music library and online radio route |
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
seven baobab native --view entry
seven baobab native --view veillee
seven baobab native --view session
seven baobab native --view sessions
seven baobab native --view carnet
seven baobab native --view constellation
seven baobab native --view media
seven baobab village
seven baobab heritage
seven baobab museum
seven baobab story
seven baobab explore
seven baobab countries
seven baobab country Burkina Faso
seven baobab immersions
seven baobab immersion sahel
seven baobab today
seven baobab session
seven baobab ritual
seven baobab route
seven baobab ambiance
seven baobab compass
seven baobab trail
seven baobab remember "J'ai consulté une archive orale"
seven baobab shell
seven baobab journal
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
seven baobab protocols
seven baobab protocol-doctor
seven baobab validation-kit
seven baobab validation-doctor
seven baobab native --view protocols
seven baobab integrations
seven baobab integration ollama
seven baobab roadmap
seven baobab packs
seven baobab audit-packs
seven baobab seed-packs
seven baobab enrich-packs
seven baobab evidence-packs
seven baobab validation-kit
seven baobab validation-doctor
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
seven baobab native --view immersions
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

`seven baobab immersions` exposes the offline regional immersion layer. It is
designed as a cultural entry surface, not a map replacement and not a travel
planner. The initial routes cover Sahel, Mandé, Swahili Coast, Great Lakes,
Kongo Atlantic, Horn of Africa, Southern Africa and islands. Each route includes
a tone, related countries, cultural anchors and small daily rituals such as
reading a proverb, listening to local audio, connecting a language and creating
a draft collection note with source and consent.

The native command opens the immersive UI directly:

```bash
seven baobab native --view immersions
```

The native UI keeps a lightweight immersion focus. The focus appears on the
home surface, drives the daily ritual card, and lets a user jump from an
immersion to a related country before opening languages, sound or collection.
This keeps Baobab feeling like a living cultural workspace instead of a static
catalog.

`seven baobab ritual` prints the same daily ritual in the terminal, with
suggested next commands. `seven baobab route` shows the daily route progress:
immersion focus, country focus, note of the day, local sources and cultural
packs. In the native home surface, the ritual card can create a dated Markdown
note under `~/Baobab/Rituels du jour/`, ready for reading, listening, source
notes and responsible follow-up.

`seven baobab today` is the daily entry point. It gathers the current ambiance,
immersion, ritual, route progress, next recommended action and quick actions in
one place. The native app exposes the same view as `Aujourd'hui`, so Baobab
feels guided immediately instead of asking the user to know every command.

`seven baobab native --view entry` opens the Baobab passage view. It keeps the
experience intentionally simple: enter by a region, link a country, keep a
local trace, then prepare responsible transmission. This gives Baobab a
distinct rhythm from Equinox, Atlas or Studio.

`seven baobab native --view veillee` opens the slow Baobab presence surface.
It is designed for sessions where the user wants to read, listen, keep a
trace, connect a country or source, and then transmit carefully. It is not a
dashboard; it is the calmest Baobab ritual surface.

`seven baobab session` and `seven baobab native --view session` expose a guided
session plan. The phases adapt to the active ambiance: calm reading, learning,
fieldwork or stage. This makes Baobab feel like a cultural workspace with a
rhythm, not a generic app launcher.

`seven baobab native --view carnet` opens the cultural notebook. It gathers
ritual notes, local trail events and the active session into a readable memory
thread, with transmission guardrails kept visible.

`seven baobab native --view constellation` opens the relation map. Baobab sits
at the center, then immersion, country, languages, sound, traces, sources and
transmission orbit around it. This keeps the OS identity relational instead of
turning culture into disconnected cards.

`seven baobab native --view media` opens the living media library. It scans
Baobab-owned sound folders, local packs and the workspace for audio, images,
videos, PDFs and EPUBs, then exposes them without leaving the Baobab surface.
The goal is to make cultural material feel collected, reachable and contextual
instead of hidden in file paths.
The same surface is projected as `Baobab Médiathèque` in the Baobab Launchpad
after `seven baobab bootstrap`, so media discovery works from the desktop as
well as from the native Baobab app.
The native view includes search and type filters for sounds, images, videos and
documents, keeping Baobab usable when a local cultural collection grows.

The Baobab home surface exposes a `Chemin Baobab` strip: Entrée, Veillée,
Séance, Carnet, Médiathèque and Boussole. This gives users a stable cultural
workflow instead of a generic list of tools.
The native sidebar also keeps an `État Baobab` panel visible: active immersion,
country focus, ambiance, trace count and the next recommended gesture. This is
the persistent cultural compass for the mini OS.
The same panel exposes ambiance-aware quick gestures: calm sessions surface
reading and veillée, learning surfaces languages and guided session, fieldwork
surfaces collection and country focus, and stage mode surfaces Sound and Museum.
Baobab also exposes a `Carte de transmission`: a compact summary of immersion,
country focus, ambiance, ritual, next gesture and sharing guardrails. It can be
copied to the clipboard or turned into a local ritual note, helping users move
from discovery to responsible transmission without leaving the flow.
The same card can create a local `Sessions Baobab/` folder with a transmission
note, respect checklist and media drop zone. This gives classes, workshops and
fieldwork a concrete local workspace without forcing a separate project tool.
`seven baobab native --view sessions` lists those session folders, counts their
media, shows whether card/checklist are present and opens the folder, card or
media area directly.
Focus changes are live: choosing an immersion, a country or a reading language
refreshes the relevant native views, records a private Baobab trace and keeps
the user inside the cultural flow instead of forcing them to close and reopen
the app.

`seven baobab shell` reports the dedicated Baobab shell identity: Baobab Waybar,
Launchpad Baobab category, Racines/Mémoire/Scène/Terrain workspace model,
ritual/route widgets and profile-owned app launchers. This is the contract that
keeps Baobab from feeling like a generic desktop with a cultural theme.

`seven baobab ambiance` controls the public rhythm of Baobab without moving
data: `calme` for reading and quiet memory, `apprentissage` for language and
heritage learning, `terrain` for responsible collection, and `scene` for sound,
story, museum and creation. The same state appears in the Baobab Waybar and in
the native Preferences page.

`seven baobab compass` exposes the responsible-use compass: understand, link,
listen, collect, source, preserve and transmit. It is both a terminal contract
and a native page, so Baobab keeps guiding the user even when they are not in
the main home screen.

`seven baobab trail` shows Baobab's private local living trace. It records
important user gestures such as selected ambiance, immersion focus, country
focus, created ritual notes and explicit `seven baobab remember ...` memos.
The trail is stored under the Baobab profile data path and is designed as a
continuity aid, not as telemetry.

When Baobab is active, the visible shell should no longer read like a generic
SevenOS workspace. The Baobab Waybar exposes the tree mark, daily ritual,
route progress, sound, language and local AI status. Launchpad opens on the
Baobab category and highlights the cultural apps first: Immersions, Journal,
Packs, Explorer, Sound and Collecte. Hyprland describes the workspace model as
Racines, Mémoire, Scène and Terrain so the user moves through cultural intent
instead of technical windows.

The native `Journal` view lists those ritual notes, opens them directly and
keeps an empty state when no note has been created yet. `seven baobab journal`
lists the same notes from the terminal with their Markdown folder, so the
practice stays reachable even outside the graphical surface. This makes Baobab
feel like a daily cultural practice rather than a static cultural catalog.

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
seven baobab evidence-packs
seven baobab sample-fieldwork
seven baobab scaffold-pack local-heritage
seven baobab import-pack ~/.local/share/sevenos/profiles/baobab/baobab/packs/local-heritage/pack.json
seven baobab search local
```

`seven baobab seed-packs` creates and imports protocol-aware starter packs for
the public Baobab experience:

- `burkina-food`;
- `mandingue-sound`;
- `faso-danfani-fashion`;
- `sahel-oral-memory`;
- `swahili-coast-routes`;
- `great-lakes-drums`;
- `horn-manuscripts-coffee`;
- `kongo-atlantic-memory`.

They are not final community validation; they keep source files beside the
records so local curators can add interviews, photos, permissions, audio rights,
speaker reviews and community review notes.

`seven baobab enrich-packs` prepares the living-heritage workflow inside each
pack: interview templates, consent notes, media manifests and community review
checklists. `seven baobab audit-packs` then reports both provenance quality and
workflow readiness.

`seven baobab evidence-packs` fills each pack with a public-source evidence kit:
source notes, rights limits, metadata manifests and protocol checklists. This
removes the empty-pack experience without pretending that the pack is community
validated. The audit then reports:

- `collection_score`: operational evidence available locally;
- `community_validation_score`: real interviews, consent, media rights and
  local review;
- `fieldwork_state`: `public-source-only`, `sample-only`, `partial` or
  `field-ready`.

The audit separates workflow readiness from real field collection. A pack can be
`public-source-ready` while still having `community_validation_score: 0` until
real interviews, consent files, media manifest items, reviewed checklist items,
recipes, audio or creator notes are added.

`seven baobab validation-kit` creates the real validation workflow:

- `validation/validators.json` for local speakers, protocol stewards, creators,
  family reviewers, practitioners and archivists;
- one `validation-request.json` per pack;
- one attestation template per pack in `validation/attestations/`;
- a validation board at
  `~/.local/share/sevenos/profiles/baobab/baobab/validation/board.json`.

`seven baobab validation-doctor` checks registered validators, required roles,
pending requests and completed attestations. This is inspired by community
record/protocol-steward models such as Mukurtu and by the W3C verifiable
credentials data model, but it stays local/offline by default. A record becomes
community-validated only when a real attestation is completed by a real person
or group with local authority.

`seven baobab sample-fieldwork` creates sample-only files to demonstrate the
collection pipeline. Those files are explicitly marked `sample-only`; they are
useful for testing the UI and audit, but must be replaced before claiming real
community validation.

Each pack includes a `sources/` directory. Factual cultural material should be
documented there before being shared, taught or synced.

Baobab also ships a protocol layer generated into:

```text
~/.local/share/sevenos/profiles/baobab/baobab/protocols/cultural-protocols.json
```

Inspect it with:

```bash
seven baobab protocols
seven baobab protocol-doctor
seven baobab native --view protocols
```

The protocol layer is inspired by open governance references: UNESCO DataHub for
intangible heritage metadata, Unicode CLDR for language/locale engineering, Local
Contexts for protocol-aware Traditional Knowledge and Biocultural labels, and the
CARE principles for Indigenous data governance. Baobab does not copy protected
Local Contexts label icons or treat public metadata as permission to republish
media.

Every pack record should carry a `cultural_protocol` block:

```json
{
  "sensitivity": "unknown",
  "access": "local-first",
  "protocols": ["CARE", "source-context-consent"],
  "publication": "draft-local"
}
```

Sensitivity levels are intentionally conservative:

```text
public, family, community, sacred-restricted, unknown
```

Unknown, family, community and sacred/restricted material stays local-first until
authority, consent, rights and local review are explicit. Sacred or restricted
material should not be published by default.

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

The starter list includes Mooré, Dioula, Bambara, Wolof, Swahili, Yoruba,
Hausa, Amharic, Somali, Zulu, Xhosa, Kinyarwanda and Malagasy. Each entry
tracks script, keyboard direction, CLDR orientation, audio status and starter
validation tasks. Entries are deliberately marked `needs-local-speaker` so the
UI can begin as a public learning surface without pretending that unreviewed
phrases are validated teaching material.

Baobab uses Unicode CLDR as a software-locale reference, but CLDR is not a
substitute for local speakers. The publication workflow is:

```text
collect-source -> speaker-review -> tone-and-orthography-review -> audio-consent -> community-publication-decision
```

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
