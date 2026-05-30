# SevenStore

SevenStore is the SevenOS AppCenter. It is not a thin graphical wrapper around
pacman. Its job is to turn Arch Linux software delivery into a trusted, visual,
profile-aware and mainstream experience.

The user should feel that they are browsing a polished commercial OS store, not
typing package names into a Linux frontend.

## Product Vision

SevenStore combines:

- official repository packages
- AUR community packages
- Flatpak sandboxed applications
- SevenOS profile bundles
- Windows Compatibility apps
- future SevenCloud recommendations

SevenStore must follow `docs/SEVENPKG_STRATEGY.md`: Equinox stays the stable
host, mini OS profiles receive domain apps, and SevenPkg remains the single
source of truth for install scope and source selection.

The store must make installation feel:

- safe
- reversible
- visual
- profile-aware
- clear about source and trust
- compatible with general-public expectations

## Architecture

```text
┌──────────────────────────────────────┐
│             SevenStore UI            │
│  Tauri + React + SevenOS glass UI    │
├──────────────────────────────────────┤
│      SevenPkg Strategy + Store API   │
│ search, metadata, install plans      │
├──────────────────────────────────────┤
│ Pacman │ AppStream │ AUR │ Flatpak │ Wine │
├──────────────────────────────────────┤
│              Arch Linux              │
└──────────────────────────────────────┘
```

The command contract starts with:

```bash
seven store
seven store home
seven store search blender
seven store search blender --json
seven store detail creation
seven store install creation
seven store install-app pacman blender --dry-run
seven store install-app flatpak org.blender.Blender --dry-run
```

## Seven Package Engine

The engine has adapters for each software source.

Before choosing an adapter, SevenStore must resolve the natural SevenOS domain:

```text
Blender   -> Studio Engine
Wireshark -> Shield Engine
Steam     -> Pulse Engine
VS Code   -> Forge Engine
Reader    -> Atlas or Baobab depending on content intent
```

If an app belongs to a mini OS, the default install target is that mini OS
rootfs, not Equinox. Equinox installs are for system components, core apps and
shared runtimes only.

### Pacman

Official repositories have the highest trust rank.

Search:

```bash
pacman -Ss <query>
```

Install plan:

```bash
seven store install-app pacman <package>
```

SevenStore must route privileged installs through its installer wrapper. The
wrapper prefers `pkexec` with a graphical Polkit agent and falls back to `sudo`
only when no user-session agent is active.

### AUR

AUR is a community source and must be presented as advanced.

Search uses the official AUR RPC API:

```text
https://aur.archlinux.org/rpc/?v=5&type=search&arg=<query>
```

SevenStore should display:

- votes
- popularity
- maintainer
- version
- community warning badge
- build helper requirement

Install plan:

```bash
paru -S --needed <package>
```

or:

```bash
yay -S --needed <package>
```

### Flatpak

Flatpak is preferred when sandboxing matters or when the app is stronger as a
desktop application than as a raw system package.

Search:

```bash
flatpak search <query>
```

Install plan:

```bash
flatpak install flathub <app-id>
```

Flatpak entries should expose permission controls through a future Seven
Permissions panel.

### Windows Compatibility

Windows apps should not be mixed silently with Linux apps. They appear under
the Windows Compatibility source and open app-first flows: Wine, Bottles,
Lutris and Proton first. Full Windows VM use is an advanced fallback, not a
SevenOS mini OS identity.

Install/run plan:

```bash
seven windows open
seven windows run <installer>
seven windows resolve photoshop
```

## Ranking Policy

Default result priority:

1. official pacman package
2. Flatpak sandboxed app
3. high-signal AUR package
4. Windows Compatibility app

SevenStore can override the priority when a profile explicitly prefers a source.
For example, Studio may prefer Flatpak for sandboxed creator apps, while Forge
may prefer official packages and SDK toolchains.

## Profile Collections

SevenStore is profile-aware. Each mini OS gets a curated store surface.

| Profile | Store Collection |
| --- | --- |
| Equinox | balanced daily essentials |
| Forge | editors, SDKs, containers, Git and local services |
| Shield | authorized audit, forensics, sandboxing and reporting |
| Studio | design, video, audio, 3D, capture and export |
| Forge DevOps | code, deploy, reverse proxy, containers, logs and endpoints |
| Pulse | Linux gaming, Proton, overlays, controllers and latency tools |
| Baobab | African heritage, languages, stories, sound, maps, fashion, food, wisdom and offline memory |
| Atlas | documents, OCR, maps, references, archives and research |

The store must recommend by profile without polluting other profiles. A profile
collection is a curated path, not a forced global install.

## Trust Badges

Every result should show trust information before installation.

| Badge | Meaning |
| --- | --- |
| OFFICIAL | official repository package |
| FLATPAK | Flatpak source |
| SANDBOXED | sandboxed app/runtime |
| AUR | community build recipe |
| COMMUNITY | non-official maintainer |
| VERIFIED | curated by SevenOS |
| PROFILE | part of a SevenOS mini OS bundle |
| COMPAT | Windows compatibility flow |
| AI OPTIMIZED | recommended by SevenAI for current profile/context |

## UI/UX Direction

SevenStore should look like a premium app discovery surface.

Inspirations:

- macOS App Store
- Steam
- Microsoft Store
- GNOME Software
- Arc Browser
- SevenOS Control Center

### Layout

```text
┌────────────────────────────────────────────┐
│ TopBar: logo, profile, search, downloads   │
├──────────────┬─────────────────────────────┤
│ Sidebar      │ Home / Discover / Detail    │
│ icon-first   │ visual cards and app pages   │
├──────────────┴─────────────────────────────┤
│ Floating Download Dock                     │
└────────────────────────────────────────────┘
```

### TopBar

The TopBar should be translucent, softly blurred and compact.

It contains:

- SevenStore logo
- active profile badge
- semantic search field
- downloads icon
- updates icon
- account/settings icon

### Sidebar

Sidebar sections:

- Home
- Discover
- Installed
- Updates
- Categories
- Profiles
- Library
- Permissions
- VM Apps
- AI Picks

The sidebar is icon-first with short labels and soft hover motion.

### Home

The home page is discovery-first, closer to Netflix/Steam/App Store than a
package list.

Sections:

- Featured
- Trending
- Recommended
- Profile Essentials
- Creator Tools
- Gaming
- Security
- Cloud
- African Culture

### Native AppCenter Quality Pass

The native SevenStore surface must stay usable for a non-technical user:

- active navigation state is always visible;
- the home screen shows catalog health, installed library, sandbox state and recent activity;
- cards show source, availability and trust before installation;
- source guidance explains System, Sandboxed, Community and Mini OS installs in plain language;
- the home page explains the natural flow: discover, review, install;
- search results summarize best match, source counts and active Mini OS ranking;
- app detail pages expose a decision panel for source, trust and install scope before technical metadata;
- profile-aware recommendations adapt to the active Mini OS;
- installation actions queue into a visible review panel before execution;
- the detail panel explains source, permissions, install scope and Mini OS association.

SevenStore should never feel like a raw package frontend. It is the reference
place to discover, install, repair and understand software on SevenOS.

### Cards

Cards are screenshot-first and restrained.

Card content:

- screenshot or visual banner
- icon
- name
- one-line purpose
- badges
- source
- install/update button

Cards use:

- 8px radius
- soft border
- deep graphite glass surface
- cyan/indigo accent glow
- hover scale no larger than 1.02
- transform/opacity animations only

### App Detail Page

An app page contains:

- hero screenshot/video
- install/update button
- source and trust badges
- permissions
- dependencies
- profile recommendations
- reviews or quality metadata
- screenshots carousel
- related apps

For AUR apps, the detail page must show community trust metadata clearly before
installing.

### Floating Download Dock

Installation should not be a modal wall.

Use a floating dock:

```text
Installing Blender...
████████░░ 80%
resolving dependencies · verifying package · 2 min left
```

States:

- queued
- resolving dependencies
- installing
- verifying
- done
- needs attention

## Motion

Animations should feel alive but calm:

- page open: fade + slide
- card hover: subtle lift and glow
- install progress: pulse/wave
- download dock: dynamic island-style expansion

Avoid:

- aggressive neon
- large bouncing motion
- layout-shifting hover effects
- dense Linux package tables as the primary UI

## Future Native App Stack

Recommended implementation:

| Layer | Technology |
| --- | --- |
| Desktop shell | Tauri |
| Frontend | React + TypeScript |
| Styling | SevenOS tokens + Tailwind |
| Motion | transform/opacity animation library |
| Backend | Rust |
| Metadata cache | SQLite |
| Source adapters | pacman, AppStream, AUR RPC, Flatpak, Windows Compatibility |
| Auth | polkit/pkexec or SevenOS package daemon |

## Product Rule

SevenStore must always answer three questions before installation:

1. What is this app?
2. Where does it come from?
3. What will it change on my system?

If the UI cannot answer those questions clearly, the install button should not
be primary.
