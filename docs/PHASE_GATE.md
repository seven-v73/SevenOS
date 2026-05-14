# SevenOS Phase Gate

This checklist decides whether SevenOS is ready to move into a higher phase.

Run:

```bash
seven phase-gate
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
- mature Seven Hub Tauri GUI beyond scaffold
- enable Flatpak/Flathub defaults for creative and Windows bridge apps
- start `seven-server` as a user service
- commit generated project foundation cleanly

## Score Target

Before moving from foundation to public ISO work:

- readiness should be at least 85%
- Security should be at least 80%
- Deployment should be at least 80%
- required phase-gate checks must pass
