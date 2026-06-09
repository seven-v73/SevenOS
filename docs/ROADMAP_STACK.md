# SevenOS Stack Roadmap

This document turns the current strategic choices into implementation order.
The OS-stable target stack is defined in `docs/OS_STABLE_STACK.md`.

## Now: 0-6 Months

| Need | Choice | SevenOS Status |
| --- | --- | --- |
| Real installer | Calamares + Archinstall bridge | scaffold |
| Real GUI | Native Hub contracts, GTK/libadwaita target, Tauri only as transitional app shell | scaffold |
| Mainstream apps | Flatpak + Flathub | bridge scaffold |
| Windows access | Bottles Flatpak + Wine/KVM | preview |
| Automated checks | GitHub Actions | scaffold |
| Stable runtime | `seven-daemon`, SevenBus, JSON contracts, systemd user services | active foundation |

Commands:

```bash
seven installer doctor
seven hub-gui doctor
seven flatpak status
seven phase-gate
```

## Next: 6-12 Months

| Need | Choice | Notes |
| --- | --- | --- |
| Windows integrated display | Looking Glass | advanced GPU/VM path |
| Security by default | AppArmor | simpler than SELinux for first release |
| Configuration state | Seven Core state + declarative config; Ansible/Chezmoi only as migration helpers | move from scripts to idempotent state |
| Image builds | mkosi | later companion to Archiso |
| Package boundaries | pacman package components | replace `/opt/SevenOS` as public release path |

## Later: Team Required

| Need | Choice | Notes |
| --- | --- | --- |
| Real package manager backend | libalpm bindings | beyond wrapper stage |
| Enterprise MAC | SELinux | high complexity |
| Server monitoring | Prometheus/Grafana | for Seven Server/Cloud phase |
| Typed service API | gRPC/Protobuf or equivalent | when JSON contracts are stable enough |

## Rule

SevenOS should not add a major technology just because it is impressive. It
must unlock one of these:

- users can install SevenOS
- users can control SevenOS visually
- users can get apps easily
- users can run Windows workflows
- contributors can build/test reproducibly

It must also move SevenOS away from scripts as product ownership. Scripts are
allowed for bootstrap, compatibility and release checks; stable OS behavior
belongs to services, APIs, packages and native surfaces.
