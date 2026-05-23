# SevenOS Phase Gate

This checklist decides whether SevenOS is ready to move into a higher phase.

Run:

```bash
seven phase-gate
seven b3 status
seven b3 plan
seven b3 doctor
```

For Seven Hub, Seven Server or release automation:

```bash
seven phase-gate --json
seven b3 plan --json
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
- complete Forge DevOps/server profile: Go, Podman, Caddy
- complete Calamares installer profile and package path
- mature Seven Hub Native beyond the current GTK/libadwaita foundation
- prepare Seven Shell AGS/TypeScript without removing the stable fallback
- enable Flatpak/Flathub defaults for creative and Windows bridge apps
- start `seven-server` as a user service
- use `seven b3 apply --limit 8` as the safe preview path for the B2 -> B3 fixes
- commit generated project foundation cleanly

## Score Target

Before moving from foundation to public ISO work:

- readiness should be at least 85%
- Security should be at least 80%
- Deployment should be at least 80%
- required phase-gate checks must pass

For the B2 -> B3 productization gate, `seven b3 status` also tracks phase
targets:

| B3 phase | Minimum target |
|----------|----------------|
| Trust / Shield | 70% |
| Seven Server backend | 80% |
| Profiles | 70% |
| Seven Shell | 65% |
| Installer foundation | 50% |

B3 is satisfactory only when every target is met and no critical or high action
remains open. This keeps SevenOS from moving toward ISO work while the trust,
backend, profile or shell layers are still only partial.

## JSON Contract

`seven phase-gate --json` exposes:

- `decision`: `pass`, `warning` or `blocked`
- `gates`: readiness, experience, control plane, Shield, Server, installer,
  Windows Mode, profiles, software and stack discipline
- `next_commands`: the highest-impact commands to run before the next phase
- `identity.active_pack`: the current SevenOS accent pack

`seven b3 plan --json` complements the phase gate with an executable
consolidation sequence. It orders the blockers as:

1. trust and Shield
2. Seven Server backend
3. concrete profiles
4. Seven Shell AGS foundation
5. installer readiness

It also exposes `targets`, `phase_state`, `preflight`, `blocked_by` and
`phase_commands` so Seven Hub can show what is ready, what is blocked by sudo,
and which layer should be handled next.

For test machines, apply one layer at a time:

```bash
seven b3 apply --phase trust --limit 4
seven b3 apply --phase backend --limit 4
seven b3 apply --phase profiles --limit 4
```

Add `--apply --yes` only after reviewing the preview.

This contract is intentionally faster than the full human phase gate. It lets
Seven Hub show whether the system is ready for B3 without running every shell
check in the foreground.
