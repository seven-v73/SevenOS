# Seven Core

Seven Core is the foundation of the SevenOS System Experience Layer. It does
not replace Linux, Arch, systemd, PipeWire or Hyprland. It coordinates them so
SevenOS can feel like a coherent operating system instead of a set of scripts.

## Purpose

Seven Core owns the system-facing contracts that Seven Hub, Seven Shell, Seven
Server and future native services consume:

- unified machine state through `seven state --json`;
- prioritized decisions through `seven control --json`;
- local audit history through `seven events`;
- product health through `seven insights`;
- phase safety through `seven phase-gate --json`;
- future daemon orchestration through `seven-daemon`.

## SevenBus

SevenBus starts as a strict JSON event envelope written to the local user state
journal. The first implementation is intentionally simple and inspectable:

```text
~/.local/state/sevenos/events.jsonl
```

Later, the same envelope can move to a typed local IPC transport backed by
`seven-daemon`. This keeps the migration safe: UI code can use the same event
shape before and after the daemon becomes active.

## C Boundary

SevenOS uses C only where it belongs: the physical and nervous system layer.

```text
C = drivers, hardware communication, ultra-low-level IPC probes, power/input/audio adjacency
Rust = SevenDaemon, policy, orchestration, long-running safe runtime
TypeScript/GTK/Tauri = shell and user-facing control surfaces
```

The first C component is:

```bash
sevenbus-probe --json
```

It checks local Unix socket capabilities for future SevenBus IPC work. It does
not replace SevenDaemon and does not own product logic.

## Daemon Path

`seven-core/daemon` is a Rust scaffold for the future `seven-daemon`.

The first responsibility of the daemon is not to become a giant background
process. Its job is narrower:

1. supervise SevenOS event streams;
2. expose fast local status to shell surfaces;
3. coordinate profile, session, security and server events;
4. keep unsafe operations behind policy and confirmation.

The daemon is now launchable through:

```bash
seven-daemon --json
seven-daemon emit --source core --type event --message "SevenBus event"
seven-daemon serve
seven core install-service
seven core start
seven core logs
```

`seven events log` now prefers the Rust event writer when `seven-daemon` is
available, then falls back to the older Bash/Python writer. This is the intended
migration style for SevenOS: preserve working commands while moving the system
logic into a system language.

The current service is a user service:

```text
systemd/user/seven-daemon.service
```

It is also pulled into `sevenos-session.target`, so the SevenOS desktop session
can grow toward a coordinated runtime instead of independent autostart scripts.

## Current Commands

```bash
seven core
seven core status --json
seven core plan --json
seven core doctor
seven core bus --json
seven core install-service
seven core start
```

These commands are part of the B2-B3 transition. They make SevenOS more
autonomous without hiding Linux from advanced users.
