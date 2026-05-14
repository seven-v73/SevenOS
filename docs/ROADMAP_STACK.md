# SevenOS Stack Roadmap

This document turns the current strategic choices into implementation order.

## Now: 0-6 Months

| Need | Choice | SevenOS Status |
| --- | --- | --- |
| Real installer | Calamares + Archinstall bridge | scaffold |
| Real GUI | Tauri | scaffold |
| Mainstream apps | Flatpak + Flathub | bridge scaffold |
| Windows access | Bottles Flatpak + Wine/KVM | preview |
| Automated checks | GitHub Actions | scaffold |

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
| Configuration state | Ansible + Chezmoi | move from scripts to idempotent state |
| Image builds | mkosi | later companion to Archiso |

## Later: Team Required

| Need | Choice | Notes |
| --- | --- | --- |
| Real package manager backend | libalpm bindings | beyond wrapper stage |
| Enterprise MAC | SELinux | high complexity |
| Server monitoring | Prometheus/Grafana | for Seven Server/Cloud phase |

## Rule

SevenOS should not add a major technology just because it is impressive. It
must unlock one of these:

- users can install SevenOS
- users can control SevenOS visually
- users can get apps easily
- users can run Windows workflows
- contributors can build/test reproducibly
