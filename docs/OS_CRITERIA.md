# SevenOS OS Choice Criteria

Users do not choose an operating system because of internals first. They choose
one because it feels useful, reliable, compatible, fast, and aligned with their
work.

SevenOS tracks eight criteria. The deployment layer adds a ninth
product-readiness dimension for users who want their OS to become a local
server, deployment node or personal cloud.

## 1. Performance

User question:

> Is this fast on my machine?

SevenOS answer:

- Arch base
- Hyprland compositor
- lightweight Waybar/Rofi/Kitty stack
- clear readiness checks for RAM, CPU virtualization, GPU, and services

Signals:

- RAM footprint
- CPU usage
- boot path
- UI smoothness
- GPU readiness

## 2. UX/UI

User question:

> Is this pleasant to use?

SevenOS answer:

- Beyond the Desktop identity
- liquid glass desktop language
- Seven Hub control center
- Waybar status surfaces
- power menu, welcome flow, dashboard, notifications

Signals:

- consistent visual system
- clear navigation
- short focused menus
- lock/power/session polish

## 3. Software Compatibility

User question:

> Can I use my tools?

SevenOS answer:

- pacman through `sevenpkg`
- AUR through `paru`, when available
- Wine, Lutris, Bottles, QEMU, Virt Manager
- Windows Mode as a guided long-term workflow
- `seven windows status` as a compatibility readiness entrypoint

Signals:

- app layer installed
- libvirt ready
- Bottles available
- Windows VM readiness
- Windows Mode assistant available

## 4. Ease Of Use

User question:

> Is this approachable?

SevenOS answer:

- `seven welcome`
- `seven dashboard`
- `seven doctor`
- `seven profile status`
- `sevenpkg install studio`
- Seven Hub categories

Signals:

- simple commands
- dry-run support
- guided next steps
- actionable diagnostics

## 5. Security

User question:

> Can I trust this system?

SevenOS answer:

- Shield profile
- UFW hardening
- Firejail and Bubblewrap
- Cyber Lab presets
- BlackArch bridge kept optional

Signals:

- firewall readiness
- sandbox readiness
- group readiness
- cyber tool readiness

## 6. Customization

User question:

> Can I shape the system around me?

SevenOS answer:

- profile architecture
- Hyprland configs
- identity assets
- regional accent packs planned
- SevenOS naming system

Signals:

- theme installed
- profile status visible
- configuration is Git reproducible

## 7. Target Use

User question:

> Is this made for my work?

SevenOS answer:

- Forge for development
- Shield for cybersecurity
- Studio for creative production
- Horizon for cloud and networking
- Griot for knowledge and documentation
- Windows Mode for compatibility

Signals:

- profile installation status
- role-specific commands
- Seven Hub spaces

## 8. Ecosystem

User question:

> What is available around this OS?

SevenOS answer:

- `seven`
- `sevenpkg`
- Seven Hub
- Arch repositories
- optional AUR
- future SevenRepo and marketplace
- docs, strategy, vocabulary, installer path

Signals:

- CLI installed
- package manager ready
- docs present
- ISO/installer path present

## Product Goal

SevenOS should reduce forced compromise:

> Linux power, Windows compatibility, desktop-grade care, Ubuntu-like approachability,
> and a modern Beyond the Desktop identity.

This document is paired with:

```bash
seven readiness
seven readiness --json
seven readiness --record
seven phase-gate
seven improve
seven improve --apply --yes
seven improve security --apply --yes
./scripts/readiness.sh
./scripts/improve.sh
```

`seven readiness` measures the current machine against the criteria.
`seven readiness --record` stores score history under `out/readiness/`.
`seven improve` turns missing criteria into an actionable improvement plan.

Deployment-specific commands:

```bash
seven improve deployment
seven server status
seven deploy ./my-project
```
