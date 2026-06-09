# SevenOS Real Design Start

This document turns the Prism Flow identity into the first concrete design work
for SevenOS.

The goal is to stop designing SevenOS as a themed desktop and start designing
it as a coherent operating system.

## Source Direction

The current source documents are:

- `identity/PRISM_FLOW_CHARTER.md`
- `identity/CHARTER.md`
- `docs/DESIGN_FIRST_STACK.md`
- `docs/OS_STABLE_STACK.md`
- `docs/SYSTEM_LANGUAGE_STACK.md`
- `docs/FLUID_AUTONOMOUS_ARCHITECTURE.md`

## First Product Shape

SevenOS should first be designed around four real surfaces:

| Surface | Role | Design target |
| --- | --- | --- |
| Prism Bar | system context, intent entry, status and trust | replaces generic top-bar language |
| Context Rail | apps, Mini OS facets, running jobs and pinned workflows | replaces dock-clone language |
| Seven Hub | control center, repair, profiles, actions and quality | becomes the main OS cockpit |
| Prism Passage | Mini OS transition and readiness | makes context switching visible |

Everything else should inherit from these surfaces instead of inventing local
styles.

## First Component Set

Build these primitives before redesigning every screen:

| Component | Purpose |
| --- | --- |
| Mini OS Facet Button | shows profile identity, readiness and active state |
| Status Rail | compact OK/PART/FAIL/RUN/READY/MISS state strip |
| Job Progress | shows queued/running/failed/complete backend work |
| Action Row | preview, run, details and recovery for one action |
| Confirmation Sheet | impact, scope, privilege and apply/cancel |
| Details Drawer | logs, JSON, command and diagnostics |
| Recovery Banner | failure explanation and next safe action |
| Trust Badge | Shield/firewall/sandbox/audit signal |

Each component must consume a real SevenOS contract or job state.

## First Backend Contracts

The real design should be backed by these contracts:

```text
seven state --json
seven actions --json
seven shell status --json
seven profile status --json
seven control --json
seven events --json
seven health doctor --json
```

For every visible action, SevenOS should expose:

- intent
- state
- impact
- progress
- details
- recovery
- writer

## First Visual Rules

- Use Prism Mineral tokens before legacy blue/violet/cyan aliases.
- Use Inter/Noto/JetBrains typography roles.
- Keep radius compact and precise.
- Use Signal Gold for identity/attention, not constant blue glow.
- Use profile accents as facets, not unrelated themes.
- Avoid oversized translucent cards.
- Avoid describing any SevenOS surface as macOS-style.
- Prefer Context Rail, Prism Bar and Prism Passage vocabulary.

## First Implementation Loop

For each feature:

```text
name user intent
  -> define machine contract
  -> define component state
  -> connect backend job or snapshot
  -> render Prism Flow component
  -> add quality gate
```

This is the beginning of real SevenOS design: backend state and visual language
evolving together.

## Immediate Next Work

1. Redesign current Waybar terminology and CSS toward Prism Bar.
2. Redesign Seven Dock terminology toward Context Rail.
3. Add a shared component vocabulary to Hub and native surfaces.
4. Replace remaining SF/macOS references with Prism Flow language.
5. Make Seven Hub show state, jobs and recovery through reusable components.
6. Keep old scripts and renderers only as compatibility paths while the
   design-first backend contracts mature.
