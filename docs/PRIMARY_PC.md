# SevenOS Primary PC Gate

SevenOS can be tested aggressively on a secondary machine, but a primary PC
needs a stricter path. The goal is not only to install packages; it is to make
the OS layer supervised, repairable and understandable after reboot.

## Minimum Gate

Before replacing an existing daily OS, aim for:

- readiness: `>= 90%`
- Shield/security: `>= 70%`
- role profiles: `>= 70%`
- Windows Mode: `complete` or consciously accepted as `vm-ready`
- Seven Server: `RUN`
- Seven Core services: daemon and observer installed/running
- installer foundation: at least Archinstall/plan tooling available

Check it with:

```bash
seven daily
seven daily --json | python -m json.tool
seven phase-gate --json | python -m json.tool
```

## One-Command Consolidation

On the test machine that should become your main workstation:

```bash
sudo -v
seven daily apply --yes
seven daily
```

Equivalent installer entrypoint:

```bash
sudo -v
./install.sh daily-driver --yes
seven daily
```

This path performs:

- protected user-state backup;
- CLI, theme, session and wallpaper runtime refresh;
- Seven Hub installation;
- Shield/security consolidation;
- Forge, Shield, Studio, Windows, Horizon and Baobab profile completion;
- Windows app compatibility setup;
- Seven Server and deployment foundation;
- installer tooling foundation;
- Seven Core daemon and context observer service installation/start;
- profile workspace bootstrap;
- post-install checks.

## Manual Recovery Checks

If something feels incomplete after reboot:

```bash
seven hub
seven-control-center open
seven session status --json | python -m json.tool
seven core health --json | python -m json.tool
seven-wallpaper status
seven flatpak status --json | python -m json.tool
seven windows resolve photoshop --json | python -m json.tool
seven shield status --json | python -m json.tool
seven profile plan --json | python -m json.tool
```

The native Hub is the preferred control surface. The lightweight web control
center is only a fallback, but it must still show the primary-PC gate, Shield,
Windows Mode, Server runtime and quick repair actions.

## Stop Conditions

Do not move the machine to primary use if:

- `seven daily` still says `not-ready`;
- UFW or Firejail are missing;
- the active desktop has no SevenOS session services;
- `seven profile plan` still shows critical profile gaps;
- you have no recovery/reinstall path documented for the machine.

## Product Rule

SevenOS should become a primary OS only when the user can recover, inspect and
repair the system through `seven`, Seven Hub and documented gates, not by
remembering scattered Arch commands.
