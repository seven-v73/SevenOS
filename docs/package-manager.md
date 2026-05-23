# SevenOS Package Manager

SevenOS uses two complementary commands:

- `seven` is the system controller.
- `sevenpkg` is the package and application manager.

This keeps system operations separate from software installation.

The vocabulary and product rules for these commands live in:

- `docs/VISION.md`
- `docs/PRODUCT_STRATEGY.md`
- `docs/VOCABULARY.md`

## seven

`seven` orchestrates SevenOS profiles, security, VM helpers, status checks, and
high-level automation.

Examples:

```bash
seven update
seven doctor
seven status
seven hub
seven profile forge
seven profile shield
seven profile studio
seven shield enable
seven shield audit
seven vm start windows
```

## sevenpkg

`sevenpkg` is a SevenOS layer over:

- `pacman`
- `paru`, when available
- SevenOS meta-packages
- future SevenRepo packages

Examples:

```bash
sevenpkg install blender
sevenpkg remove blender
sevenpkg update
sevenpkg search blender
sevenpkg info forge
sevenpkg meta
sevenpkg status
sevenpkg plan
sevenpkg plan --json
sevenpkg sources
```

Preview any command:

```bash
sevenpkg --dry-run install blender
seven --dry-run profile shield
```

## Meta-Packages

SevenOS meta-packages are declared in `sevenpkg/metapackages.json`.

Current meta-packages:

| Name | Role |
| --- | --- |
| `equinox` | balanced general SevenOS mini OS |
| `forge` | DevOps mini OS for code, toolchains, containers, services and deploys |
| `shield` | cybersecurity mini OS for authorized audit, forensics and sandboxing |
| `studio` | creator mini OS for logo, video, audio, 3D and design tools |
| `windows` | Windows Bridge mini OS for VM-first compatibility with Wine/Bottles fallback |
| `baobab` | African cultural mini OS for heritage, languages, stories, sound, map, fashion, food, wisdom and offline memory |
| `pulse` | Linux gaming mini OS for Proton, low latency, overlays and performance |
| `griot` | documentation and knowledge toolkit |

Examples:

```bash
sevenpkg install forge
sevenpkg install shield
sevenpkg install studio
sevenpkg install windows
sevenpkg install pulse
sevenpkg install griot
sevenpkg status
sevenpkg plan
sevenpkg info shield
```

## Software Plan

`sevenpkg plan --json` is the machine-readable software readiness contract for
Seven Hub, Seven Server and the Control Plane.

It combines:

- SevenOS meta-package completeness
- pacman availability
- optional `paru` / AUR availability
- Flatpak and Flathub readiness
- default Flatpak app gaps

Human preview:

```bash
sevenpkg plan
```

Machine contract:

```bash
sevenpkg plan --json
```

SevenOS uses this plan to guide app installation without making users reason
about pacman, AUR, Flatpak or future SevenRepo internals.

Install multiple ordinary packages:

```bash
sevenpkg install nmap hashcat wireshark-qt
sevenpkg remove nmap hashcat
```

Pass profile-specific arguments to a SevenOS meta-package:

```bash
sevenpkg install shield core
sevenpkg install shield sandbox
```

## Sources

`sevenpkg install <package>` uses source `auto` by default:

1. checks official Arch repositories through `pacman`
2. checks AUR through `paru` when installed
3. reports a clear miss if neither source has the package

Force a source:

```bash
sevenpkg install blender --source pacman
sevenpkg install visual-studio-code-bin --source aur
```

`sevenrepo` is reserved for the future SevenOS repository.
