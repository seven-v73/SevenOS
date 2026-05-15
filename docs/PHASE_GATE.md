# SevenOS Phase Gate

This checklist decides whether SevenOS is ready to move into a higher phase.

Run:

```bash
seven phase-gate
```

For Seven Hub, Seven Server or release automation:

```bash
seven phase-gate --json
```

or:

```bash
./scripts/phase-gate.sh
```

Before pushing, also follow `docs/PRE_PUSH.md`.
Before installing on a test machine, follow `docs/TEST_MACHINE.md`.

## Required Checks

- `./scripts/check.sh`
- `./scripts/ux-check.sh`
- `./scripts/readiness.sh --json`
- `./scripts/installer-stack.sh doctor`
- `./seven-hub/gui-stack.sh doctor`
- `seven-deploy` dry-run planning

Any failure blocks the next phase.

## Advisory Checks

- server dependency doctor
- readiness score
- Git worktree state

Warnings do not block development, but they should be resolved before a release
ISO or public announcement.

## Current Consolidation Priorities

The machine can move forward technically, but the strongest improvements before
a public phase are:

- install and activate Shield basics: UFW, Firejail, Bubblewrap
- complete Windows compatibility: Wine, Bottles, Lutris, KVM
- complete Horizon/server profile: Go, Podman, Caddy
- complete Calamares installer profile and package path
- mature Seven Hub Native beyond the current GTK/libadwaita foundation
- prepare Seven Shell AGS/TypeScript without removing the stable fallback
- enable Flatpak/Flathub defaults for creative and Windows bridge apps
- start `seven-server` as a user service
- commit generated project foundation cleanly

## Score Target

Before moving from foundation to public ISO work:

- readiness should be at least 85%
- Security should be at least 80%
- Deployment should be at least 80%
- required phase-gate checks must pass

## JSON Contract

`seven phase-gate --json` exposes:

- `decision`: `pass`, `warning` or `blocked`
- `gates`: readiness, experience, control plane, Shield, Server, installer,
  Windows Mode, profiles, software and stack discipline
- `next_commands`: the highest-impact commands to run before the next phase
- `identity.active_pack`: the current African first accent pack

This contract is intentionally faster than the full human phase gate. It lets
Seven Hub show whether the system is ready for B3 without running every shell
check in the foreground.
