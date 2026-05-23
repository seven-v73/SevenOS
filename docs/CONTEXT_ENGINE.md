# SevenOS Context Engine

SevenOS is a context-aware Linux platform.

The kernel sees processes, PIDs, threads and CPU time. SevenOS should understand
human workflow context:

```text
PID + CPU + RAM + windows + profile
  -> Context Graph
  -> Human Intent
  -> Scheduler / Shell / Hub decisions
```

## What It Solves

Linux CFS is technically excellent, but it does not know that:

- VS Code + terminal + Docker + browser docs means a Forge development session;
- Blender + Krita + PipeWire + OBS means a Studio creation session;
- Wireshark + nmap + Firejail means a Shield audit;
- QEMU + Virt Manager + Bottles means Windows Mode.

Seven Context Engine turns raw system signals into semantic state.

## Architecture

```text
Applications
  -> Seven Context Engine
  -> Seven Core
  -> Seven Scheduler
  -> Linux CFS Scheduler
```

It does not replace the scheduler. It tells SevenOS what is likely important.

## Context Graph

The first contract is:

```bash
seven context status
seven context status --json
seven context graph
seven context graph --json
seven context plan
seven context emit
```

`seven context --json` exposes `sevenos.context.v1`.

The graph contains:

- process nodes;
- window nodes when Hyprland state is available;
- parent-child process relationships;
- detected contexts;
- confidence scores;
- recommended profile/scheduler actions.

`status --json` intentionally keeps graph nodes empty and exposes only counts.
This keeps `seven state --json` small enough for Hub, Shell and Seven Server.
`graph --json` is the detailed inspection command.

`emit` writes the current semantic context into SevenBus as a typed local event:

```text
source: context
type: context
payload.schema: sevenos.context-event.v1
```

This is the bridge between on-demand inspection and the future SevenDaemon
observation loop.

SevenDaemon now exposes the first runtime bridge:

```bash
seven core observe --json
seven core install-observer
seven core start-observer
```

It asks `seven-daemon` to record one context observation through the same
SevenBus payload. This is still a single observation, not a continuous watcher,
but it moves the responsibility toward the runtime layer.

The supervised observer service is:

```text
systemd/user/seven-context-observer.service
```

It runs `seven-daemon observe-loop` with `SEVENOS_CONTEXT_INTERVAL=60` and is
wired into `sevenos-session.target`. This gives SevenOS its first continuous
semantic signal loop while staying local-only and reversible.

## Contexts

| Context | Intent | Scheduler group |
|---------|--------|-----------------|
| Baobab System | system maintenance | baobab |
| Forge Environment | development | forge |
| Studio Session | creative production | studio |
| Shield Audit | cybersecurity | shield |
| Windows Mode | compatibility | windows |
| Forge DevOps | software development and deployment | forge |
| Streaming Context | streaming | studio |

## Future Signals

SevenBus should eventually emit:

- `window_opened`;
- `workspace_changed`;
- `audio_started`;
- `vm_started`;
- `battery_low`;
- `gpu_pressure`;
- `foreground_app_changed`;
- `profile_activated`.

SevenDaemon should then own the stable observation loop, while `seven context`
remains the public contract for Hub, Shell, Scheduler and SevenAI.

## Semantic Scheduling

SevenOS should not ask Linux to optimize anonymous PIDs in isolation. It should
first answer a product question:

```text
What is the user actually doing right now?
```

The answer becomes a context group:

```text
Human workflow
  -> Context group
  -> Seven Scheduler policy
  -> Linux CFS hints
```

Examples:

- VS Code + terminal + Docker + docs browser -> Forge context;
- Blender + Krita + PipeWire + OBS -> Studio context;
- QEMU + Bottles + Virt Manager -> Windows context;
- Wireshark + nmap + Firejail -> Shield context.

This is the core SevenOS distinction: Linux remains the stable kernel layer, but
SevenOS adds human intent above it.

## Rule

SevenOS must not automate opaque resource changes just because it detects a
context. It should explain what it detected, expose confidence, and let the
policy layer act visibly.
