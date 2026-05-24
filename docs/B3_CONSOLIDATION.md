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

## New Machine Install

For a fresh machine, keep the public install path simple:

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
chmod +x install.sh bootstrap.sh profiles/*.sh
seven new
```

If `seven` is not installed yet, use the repository entrypoint:

```bash
./install.sh new-device --yes
```

This applies the ergonomic baseline automatically: desktop packages, CLI, Hub,
fonts, theme, visual layer, mini OS requirements, workspaces, profile isolation,
rootfs metadata, Windows Bridge preparation and post-install checks.

Optional full setup:

```bash
seven new --optional
seven new --optional --rootfs
```

Windows Bridge first run:

```bash
seven windows setup
seven windows setup --iso ~/Downloads/Win11.iso
```

After installation, check the machine:

```bash
seven post-install
seven doctor
seven profile-rootfs verify all
```

Before pushing the repository:

```bash
seven pre-push
```

Use `seven pre-push full` only for a long release audit.

Do not run `sudo ./install.sh ...`. SevenOS asks for administrator privileges
internally only when a step needs them.

## B3 Command

Use `seven b3` for developer consolidation after the machine is installed:

```bash
seven b3 status
seven b3 plan
seven b3 doctor
```

## B3 Phases

| Phase | Role | Target |
|-------|------|--------|
| Trust | Shield, firewall, sandbox, cyber baseline | 70% |
| Backend | Seven Server user service and deployment dependencies | 80% |
| Profiles | Forge DevOps, Shield, Studio, Windows and Pulse as concrete modes | 70% |
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
