# SevenOS Design-First Stack

This document defines the modern design-first stack for SevenOS. It complements
the OS-stable stack by making visual quality, interaction details, backend
contracts and fluid logic part of the architecture instead of late polish.

The rule is:

```text
Design is not the skin of SevenOS.
Design is the way SevenOS explains, protects and moves.
```

## Product Direction

SevenOS should feel:

- calm before powerful
- detailed without being noisy
- native before decorative
- fast even when work is still running
- understandable before automatic
- fluid across Mini OS contexts
- consistent in light, dark, French and English

Every surface should make the user feel that SevenOS is one coherent operating
system, not a set of disconnected tools.

## Design-First Stack

| Layer | Stack | Role |
| --- | --- | --- |
| Design language | Seven Design Engine, tokens, profile accents, FR/EN copy, accessibility rules | shared visual and interaction identity |
| Component system | GTK/libadwaita patterns, AGS shell components, reusable CSS tokens, icon registry | consistent controls, panels, dialogs and status states |
| Motion system | SevenOS motion presets, Prism passage, reduced-motion contract | context changes, progress, feedback and continuity |
| Shell experience | AGS/TypeScript, Hyprland rules, Waybar fallback, native menus | dock, quick settings, launcher, notifications and profile context |
| Product apps | GTK/libadwaita first for OS control, Tauri where useful for transitional app surfaces | Hub, Settings, Store, Files, Notes, Reader and installer portal |
| Backend contracts | Rust services, stable JSON schemas, SQLite state, SevenBus events | predictable data for every visible state |
| Orchestration logic | Seven Core, action registry, profile runtime, control plans, confirmation gates | fluid workflows and safe automation |
| AI layer | Python model adapters behind SevenAI contracts | explanation, search, summaries and recommendations |
| Quality gates | interaction, layout, accessibility, performance, native fallback and public quality checks | design regressions caught before release |

## Detail System

SevenOS quality lives in details that repeat everywhere:

- one primary action per panel
- secondary actions that do not hide destructive behavior
- readable spacing and density for real work
- compact status chips with clear severity
- consistent icon positions and tooltips
- predictable keyboard focus
- skeleton/loading states for slow data
- empty states that offer the next useful action
- visible progress for long operations
- details/logs hidden until requested
- no raw terminal output in public workflows unless opened by the user

These details are product architecture. They are not optional styling.

## Backend For Fluid UI

Fluid UI requires a backend that can answer quickly and consistently.

Every public surface should read from stable contracts:

```text
Seven Hub / Shell / App
  -> Seven Platform API
  -> Seven Core state cache
  -> SevenBus event stream
  -> domain service or Linux backend
```

Backend rules:

- UI reads snapshots first, then subscribes to events.
- Long work starts a job and returns a job ID quickly.
- Jobs expose progress, current step, logs and final result.
- State is cached in SQLite or another structured local store.
- Human messages and machine states are separate fields.
- Failures include recovery actions.
- Sensitive actions require preview and confirmation.

The UI should never wait on a chain of scripts before it can draw its first
useful state.

## Fluid Logic Model

SevenOS workflows should follow this loop:

```text
Intent
  -> context
  -> plan
  -> preview
  -> confirm when needed
  -> execute as a job
  -> stream progress
  -> verify result
  -> offer recovery or next action
```

Examples:

| Workflow | Fluid behavior |
| --- | --- |
| Mini OS switch | prepare profile, show Prism passage, apply context, wait until ready, show new actions |
| Update | check, snapshot, show impact, install, refresh surfaces, verify rollback |
| App install | show source and size, install as job, expose progress, add app to launcher |
| Repair | detect, explain, preview fix, apply only needed changes, verify |
| Language/theme change | apply globally, reload surfaces, report any surface still stale |

The user should always know what SevenOS is doing and why.

## Design Tokens And Themes

SevenOS design should be token-driven:

- colors through `identity/tokens.css` and `identity/tokens-light.css`
- mode definitions through the Seven Design Engine
- profile accents through identity/profile contracts
- typography through shared roles, not random font sizes
- spacing through reusable scale values
- status colors through semantic tokens
- motion through named presets

Hard-coded colors, one-off shadows, inconsistent radius values and isolated CSS
themes should be treated as design debt.

## Component Priorities

Build these as reusable primitives before multiplying screens:

| Component | Required states |
| --- | --- |
| Action row | ready, running, blocked, warning, done |
| Status card | OK, PART, FAIL, unknown, loading |
| Job progress | queued, running, needs confirmation, failed, complete |
| Confirmation sheet | impact, scope, command/details, cancel, apply |
| Mini OS switcher | current, available, preparing, active, failed |
| Package/app item | installed, available, updating, removable, source warning |
| Settings row | value, changed, requires reload, requires privilege |
| Details drawer | logs, JSON, command, recovery action |

Every product surface should reuse these patterns instead of inventing local
variants.

## Native Surface Direction

SevenOS should favor native-feeling surfaces:

- GTK/libadwaita for system control apps where desktop integration matters
- AGS/TypeScript for shell panels, dock, quick settings and notifications
- Tauri for transitional or marketplace-style product apps when it speeds
  delivery without owning critical OS control
- Rofi only as fallback or emergency launcher
- terminal output only as detail, diagnostics or developer mode

The design-first rule is that a normal public workflow should remain inside a
SevenOS surface from start to finish.

## Backend Boundaries

The backend should be split by responsibility:

| Backend service | Owns |
| --- | --- |
| Seven Core | state, health, sessions, profiles, events and jobs |
| Seven Actions | action registry, permissions, preview and execution routes |
| Seven Package | app/package sources, install plans, progress and rollback hints |
| Seven Identity | language, theme, profile accents, accessibility and onboarding state |
| Seven Shell | panel state, dock state, notifications, widgets and context |
| SevenAI | explanations, recommendations, search and summaries |
| Shield | trust state, sandbox policy, audit and security warnings |

The frontend should not know whether a backend uses pacman, Flatpak, Hyprland,
systemd, libvirt or NetworkManager. It should know only the SevenOS contract.

## Performance Rules

Design-first does not mean heavy.

- first paint should use cached state
- shell surfaces should avoid blocking IO on open
- expensive checks run in background jobs
- profile changes stream status instead of freezing
- animations must respect reduced motion
- panels should remain usable during partial backend failure
- every public surface should have loading, stale and offline states

Fluidity is a runtime property, not just an animation style.

## Release Gates

A design-first SevenOS feature is not stable until it passes:

- interaction contract
- workflow contract
- layout and overflow checks
- accessibility checks
- native fallback contract
- performance/responsiveness check
- JSON contract validation
- public quality aggregate

Design regressions should block public release claims the same way broken
services do.

## Development Rule

When adding a feature, build in this order:

1. Name the user intent.
2. Define the machine contract.
3. Define states, errors, progress and recovery.
4. Build the backend job or service.
5. Build the reusable component.
6. Build the surface.
7. Add the gate.

This keeps SevenOS modern at the visible layer and stable at the backend layer:
beautiful because it is coherent, fluid because it has state, and autonomous
because the logic is owned by Seven Core instead of isolated scripts.
