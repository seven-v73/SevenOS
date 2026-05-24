# SevenOS Product Strategy

SevenOS should grow like an ecosystem, not like a pile of features.

## Market Gap

Current Linux distributions tend to specialize:

- Arch focuses on minimalism and control.
- Ubuntu focuses on mainstream simplicity.
- Fedora focuses on innovation and enterprise proximity.
- Debian focuses on stability.
- Kali focuses on cybersecurity.
- Garuda focuses on gaming and visual energy.
- EndeavourOS simplifies Arch installation.

SevenOS enters a different space: a culturally grounded Linux ecosystem for
modern productivity, creation, cybersecurity, Windows integration, deployment,
and future AI-assisted personal cloud workflows.

## Strategic Position

SevenOS should be:

- simple like Ubuntu
- powerful like Arch
- open like Linux
- polished like a premium desktop
- modular like a professional toolkit
- culturally distinct without becoming ornamental

## Phases

### Phase 1: Foundations

- SevenOS route on top of an Arch-compatible foundation
- Seven Smart Window System foundation
- package manifests
- basic profiles
- Git reproducibility

### Phase 2: Seven Layer

- `seven`
- `sevenpkg`
- SevenOS meta-packages
- Seven Hub control center
- profile status and basic automation

### Phase 3: ISO And Installer

- Archiso live profile
- branded live environment
- install planner
- installer workflow
- Calamares graphical installer profile
- Archinstall automation bridge

### Phase 4: Distribution Polish

- Seven Hub Tauri native GUI
- Flatpak/Flathub application bridge
- release signing
- checksum workflow
- hardware validation
- ISO release channel
- default apps and recovery tools
- SevenDoctor guided repair suggestions
- SevenBox rootless container workflow
- SevenAI provider-neutral command contract
- Adaptive UI signals by active workflow

### Phase 5: Ecosystem

- SevenRepo
- marketplace
- regional accent packs
- cloud and sync services
- plugin system
- SevenCloud backup and restore
- SevenStore trust policy
- SevenIdentity profiles
- SevenFlow automation
- SevenCluster private compute mesh

## Product Rules

- Every feature belongs to a documented architecture layer.
- Every user-facing feature must be reachable from `seven` or Seven Hub.
- Do not expose raw complexity when SevenOS can give it a better name.
- Do not hide Linux power from users who need it.
- Keep the default system clean and daily-use friendly.
- Make advanced layers explicit and reversible.
- Build UX around workflows, not package lists.

## Workflow Families

| SevenOS Name | Purpose |
| --- | --- |
| Forge | development and engineering |
| Shield | cybersecurity and hardening |
| Studio | creative production |
| Forge DevOps | development, cloud, network, and infrastructure |
| Griot | documentation, learning, and knowledge |
| Baobab | African cultural OS for heritage, languages, stories, sound, map, fashion, food, wisdom and offline memory |
| Windows Bridge | complete Windows VM-first compatibility with Wine/Bottles fallback |
| Pulse | Linux gaming, Proton, latency, overlays, and performance |
| SevenAI | system assistant and automation contract |
| SevenCloud | backup, restore, and machine sync |
| SevenStore | apps, themes, profiles, and modules |
| SevenBox | rootless container runtime UX |
| SevenFlow | no-code system automation |

## Near-Term Priorities

1. Turn the install path into a Calamares-driven graphical flow.
2. Move Seven Hub toward a native Tauri GUI without breaking CLI truth.
3. Make Flatpak/Flathub and Bottles first-class app bridges.
4. Turn `sevenpkg` meta-packages into clear user journeys.
5. Improve Windows Mode from helper scripts into a guided workflow.
6. Complete ISO installer planning into a real install path.
7. Keep design QA strict so SevenOS remains coherent as it grows.
8. Use `seven ecosystem` to keep innovation modules visible and honest.

## OS Choice Criteria

SevenOS tracks the eight criteria users use when choosing an OS:

- performance
- UX/UI
- software compatibility
- ease of use
- security
- customization
- target use
- ecosystem

The living scorecard is:

```bash
seven readiness
seven improve
./scripts/readiness.sh
./scripts/improve.sh
```

See `docs/OS_CRITERIA.md`.
See also `docs/ECOSYSTEM.md`.
See also `docs/ARCHITECTURE.md`.
