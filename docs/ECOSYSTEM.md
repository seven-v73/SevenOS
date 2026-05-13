# SevenOS Ecosystem Architecture

SevenOS is evolving from a Linux distribution layer into an all-in-one operating
ecosystem: desktop, development workstation, security lab, Windows bridge,
deployment node, personal cloud and intelligent automation surface.

The rule is simple:

> A module may be visionary, but the CLI must stay honest about its maturity.

## Ecosystem Modules

| Module | Purpose | Phase | Status |
| --- | --- | --- | --- |
| SevenAI | native system assistant and automation brain | 4 | planned |
| SevenCloud | personal backup, config sync and restore | 5 | planned |
| SevenStore | marketplace for apps, profiles, themes and modules | 5 | planned |
| SevenBox | rootless containers and sandboxed app runtime | 4 | preview |
| SevenShield Pro | advanced protection, scans and intrusion signals | 4 | planned |
| Adaptive UI | profile-aware desktop behavior and visual modes | 4 | preview |
| Windows Integration | guided VM, Wine, Bottles and future app integration | 2-4 | preview |
| SevenDoctor | auto-repair and guided remediation | 3-4 | preview |
| Advanced Profiles | Learn, Enterprise, Gaming, Cloud, AI Lab | 4 | planned |
| SevenIdentity | user identity, cultural accents, permissions and environment | 5 | planned |
| SevenCluster | multi-machine local cluster and resource sharing | 5 | planned |
| SevenFlow | no-code automation rules for system workflows | 5 | planned |

## Current Foundation

Already present:

- `seven` system controller
- `sevenpkg` package and meta-package layer
- Seven Hub categorized control center
- Forge, Shield, Studio, Horizon, Griot and Baobab vocabulary
- Windows Mode helpers
- `seven-server` local API foundation
- `seven-deploy` deployment planner
- readiness and phase-gate scorecards
- African first identity layer

## Phase Discipline

### Phase 4: Intelligent OS Preview

The next innovation phase should focus on:

- `seven ecosystem` visibility
- SevenDoctor repair suggestions
- SevenBox rootless container UX
- Adaptive UI profile status
- SevenAI interface contract, without hardcoding one provider

### Phase 5: Connected Ecosystem

Later:

- SevenCloud backups and restore
- SevenStore module registry
- SevenIdentity and regional accent packs
- SevenFlow automation engine
- SevenCluster personal/private compute mesh

## Safety Rules

- AI must never run privileged commands without explicit confirmation.
- Cloud sync must be opt-in and encrypted.
- Marketplace packages must declare source, permissions and trust level.
- Container execution should default to rootless mode.
- Remote API must stay local-only until auth, TLS and audit logs exist.
- Auto-repair should explain every change before applying it.

## Commands

```bash
seven ecosystem
seven ecosystem roadmap
seven ecosystem doctor
seven repair
seven doctor fix
seven phase-gate
seven readiness
```

Future commands:

```bash
seven ai "explain this error"
seven cloud backup
seven store search blender
seven box run app --sandbox
seven flow list
seven identity status
```
