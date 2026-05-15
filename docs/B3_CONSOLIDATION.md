# SevenOS B3 Consolidation

SevenOS B3 is the productization gate between a powerful post-install layer and
a coherent operating-system experience.

The goal is not to add more scripts. The goal is to make the core layers active:

```text
Linux Kernel / Arch base
  -> Seven Core
  -> SevenBus
  -> Seven Daemon Runtime
  -> Seven Shell
  -> Seven Hub
  -> Profiles / Ecosystem
```

## Command

Use `seven b3` as the single B2 -> B3 orchestrator:

```bash
seven b3 status
seven b3 plan
seven b3 plan --json
seven b3 doctor
```

Actions are preview-only by default:

```bash
seven b3 apply --phase trust --limit 4
seven b3 apply --phase backend --limit 4
seven b3 apply --phase profiles --limit 4
```

Execute only after reviewing the preview:

```bash
sudo -v
seven b3 apply --phase trust --apply --yes
```

If `sudo` is not active, B3 does not execute package/security/profile changes.
It marks those rows as blocked and continues with safe or manual rows. This
keeps the flow usable inside Seven Hub and on test machines where the user has
not unlocked administrator privileges yet.

## B3 Phases

| Phase | Role | Target |
|-------|------|--------|
| Trust | Shield, firewall, sandbox, cyber baseline | 70% |
| Backend | Seven Server user service and deployment dependencies | 80% |
| Profiles | Forge, Shield, Studio, Windows, Horizon as concrete modes | 70% |
| Shell | Seven Shell native foundation with stable fallback | 65% |
| Installer | Archinstall/Calamares/Archiso path prepared | 50% |

B3 is satisfactory when every target is met and no critical or high action
remains open.

## Current Interpretation

`seven b3 status` intentionally shows:

- score per phase;
- required target per phase;
- blockers such as missing sudo session;
- the next commands in the right order.

This prevents SevenOS from moving to ISO work while trust, backend, profiles or
shell are still decorative.

Seven Hub Native consumes the same contract and displays B3 as a dashboard
section. The Hub must never invent a separate roadmap for this phase; it should
render `seven b3 plan --json` and launch the same phase commands.

## Design Principle

B3 follows one rule:

```text
Every visible OS feature must map to a working system capability.
```

If a button, panel, profile or card cannot launch, install, repair, report state
or guide the user, it is not ready for B3.
