# SevenOS Fluid And Autonomous Architecture

This document records the guiding philosophy for making SevenOS feel fluid,
autonomous and coherent as a complete digital ecosystem.

## Vision

SevenOS is a modular computing platform built from a shared foundation,
Seven Core, and several specialized environments called Mini OS profiles.

The goal is not to create a simple Linux distribution. The goal is to create a
unified ecosystem where the user moves naturally between work, creation,
exploration, culture, security and gaming without feeling that they changed
systems.

SevenOS is centered on:

- the human
- knowledge
- creation
- exploration
- digital autonomy

The fundamental rule is:

```text
One user
  -> one identity
  -> one system
  -> several worlds
```

The user never changes operating system. The user only changes context.

## Global Layer Model

SevenOS should evolve around this long-term stack:

```text
Seven Worlds
  Equinox, Forge, Pulse, Baobab, Studio, Shield, Atlas

Seven Applications
  Store, Files, Browser, Terminal, AI, Settings, Vault

Seven Platform API
  typed APIs, action registry, permissions, package workflow

Seven Services
  package, AI, sync, vault, search, resource and session services

Seven Core
  identity, sessions, permissions, settings, resources and orchestration

Linux Foundation
  kernel, drivers, systemd, Wayland, PipeWire, filesystems and packages
```

SevenOS keeps Linux as the foundation, but makes Linux progressively less
visible to the normal user through a coherent SevenOS-owned experience layer.

## Seven Core

Seven Core is the heart of the system. It coordinates Linux instead of
replacing it.

It owns:

- users and identity
- permissions and trust
- security posture
- storage and protected state
- sessions and workspaces
- profiles and context switching
- CPU, RAM, GPU, battery and performance policy

Core service directions:

| Service | Command direction | Responsibility |
| --- | --- | --- |
| Identity Service | `seven-id` | accounts, profiles, sync and authentication |
| Session Service | `seven-session` | login, logout, workspaces and session restore |
| Permission Service | `seven-permission` | app permissions, privacy and trust decisions |
| Settings Service | `seven-settings` | themes, languages, hardware, AI and preferences |
| Resource Manager | `seven-resource` | CPU, RAM, GPU, battery and foreground priority |

## Seven Services

Seven Services are the permanent system services that make SevenOS autonomous.

| Service | Command direction | Role |
| --- | --- | --- |
| Seven Package | `sevenpkgd` | universal package workflow over pacman, Flatpak, Nix, AppImage and future sources |
| Seven AI | `seven-ai` | assistant, search, summaries, automation and recommendations |
| Seven Sync | `seven-sync` | settings, projects and preference synchronization |
| Seven Vault | `seven-vault` | encryption, archives, secrets and protected user data |
| Seven Search | `seven-search` | global index for files, apps, content and web references |

The services should expose machine-readable contracts first, so Seven Hub,
Seven Shell and future native apps can remain fast without parsing human text.

## Seven Platform API

Applications should speak through SevenOS APIs instead of calling unrelated
backends directly.

Preferred long-term technologies:

- Rust for core services and long-running runtime components
- gRPC or a similarly typed local API for service boundaries
- Protocol Buffers or stable JSON schemas for machine contracts

Example:

```text
Seven Store
  -> Seven Package API
  -> pacman / Flatpak / Nix / AppImage / future Seven repositories
```

This makes SevenOS feel like one product even when the backend remains open and
Linux-compatible.

## Seven Data Layer

SevenOS data should stay structured and portable.

| Layer | Direction | Data |
| --- | --- | --- |
| Local | SQLite | settings, projects, history, app state and indexes |
| Cloud | PostgreSQL or equivalent | sync, backups, identity and shared state |
| Cache | Redis or equivalent | fast runtime cache for future server/cloud workflows |

The local-first layer remains the default. Cloud sync is an extension, not a
requirement for the system to work.

## User Filesystem

The user home should make SevenOS workflows easy to understand:

```text
/home/seven
  Projects
  Knowledge
  Media
  Worlds
  Vault
  Archive
  Workspace
```

These names express the SevenOS model: create, learn, preserve, switch context
and keep protected material separate.

## Seven Identity

Seven ID is the central account and identity direction.

It should provide:

- single sign-on inside SevenOS surfaces
- profile continuity
- sync preferences
- backup identity
- future cloud and device continuity

Comparable public references are Apple ID, Microsoft Account and Google
Account, but Seven ID should remain local-first and sovereignty-aware.

## Seven Applications

Seven applications are the visible product surfaces of the platform.

### Seven Store

Official catalog for:

- applications
- extensions
- Mini OS profiles
- themes
- AI modules

Command direction:

```bash
seven install vscode
```

### Seven Files

Official file manager direction.

Expected capabilities:

- tabs
- tags
- versioning
- compression
- Vault integration
- cloud/sync integration

### Seven Browser

Possible product name: Seven Explorer.

Expected role:

- web
- documents
- AI-assisted reading
- research and knowledge navigation

### Seven Terminal

Product direction: Seven Shell.

Preferred technology direction:

- Rust for native shell/runtime components
- Nushell-compatible ideas for structured command output where useful

Expected commands:

```bash
seven install
seven update
seven world
seven sync
```

## Seven Worlds

Seven Worlds are the core conceptual layer. In the current SevenOS vocabulary,
they map to Mini OS profiles.

```text
Equinox -> hub, balance, organization and daily digital life
Forge   -> software development, Git, containers and DevOps
Pulse   -> gaming, performance, Steam, Lutris and capture
Shield  -> cybersecurity, audit, sandboxing and trust
Studio  -> video, image, audio, design and creative production
Baobab  -> culture, heritage, languages, memory and transmission
Atlas   -> exploration, maps, geography, research, documents and knowledge
```

Atlas is the exploration and knowledge Mini OS. Nexus is not the current Mini
OS name and should not be used as the primary SevenOS profile.

## Seven AI Ecosystem

SevenAI should become an ecosystem, not only a chatbot.

| Module | Role |
| --- | --- |
| Seven Assistant | main system assistant |
| Seven Vision | image, video and document analysis |
| Seven Learn | personalized learning |
| Seven Knowledge Graph | links user, project, place, culture and knowledge |

SevenAI should help the user understand the system, automate careful actions,
summarize information and recommend next steps while keeping confirmation
boundaries for risky operations.

## Security

The long-term security model is Zero Trust:

- every component is sandboxed where possible
- sensitive actions are isolated
- permissions are visible and reviewable
- suspicious activity can be surfaced by Shield
- protected data goes through Vault

Seven Vault should provide strong encryption for archives, secrets and protected
user data. Seven Shield should analyze malware risk, permissions and suspicious
activity without turning the whole OS into a noisy security dashboard.

## Development Direction

Preferred implementation directions:

| Area | Technologies |
| --- | --- |
| System | Rust |
| Services | Rust, Go where appropriate |
| Frontend | React, TypeScript for prototypes and app surfaces |
| Desktop | Tauri for prototypes, native Linux surfaces for final OS control |

Bash remains useful as glue and compatibility. Stateful, long-running behavior
should migrate toward typed services and daemon-owned contracts.

## Seven Cloud

Seven Cloud is the future extension of the local-first OS:

```text
Seven Cloud
  Sync
  Backup
  Identity
  AI
  Store
```

The cloud layer should enhance continuity without making the local machine
dependent on remote infrastructure.

## Long-Term Phases

```text
Phase 1 -> Linux + Seven UI
Phase 2 -> Linux + Seven Services
Phase 3 -> Linux + Seven Core
Phase 4 -> Linux becomes mostly invisible
Phase 5 -> complete SevenOS platform ecosystem
```

The final objective is for SevenOS to no longer be perceived as a Linux
distribution, but as a complete digital ecosystem comparable in coherence to
macOS, Android or ChromeOS, while preserving Linux freedom and power.

## Guiding Line

```text
Understand, create, transmit.
```

This is the operating philosophy behind SevenOS fluidity and autonomy.
