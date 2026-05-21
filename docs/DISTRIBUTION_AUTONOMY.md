# SevenOS Distribution Autonomy

SevenOS is allowed to use Arch, Hyprland, pacman, libvirt, Flatpak and systemd
as strong foundations. The product boundary is that normal users should operate
SevenOS through SevenOS surfaces and contracts first.

This document defines the line between:

- a visible Arch/Hyprland rice;
- a SevenOS daily-driver layer;
- a public SevenOS distribution.

## Autonomy Contract

Run:

```bash
seven autonomy
seven autonomy --json
seven autonomy doctor
seven platform
seven mask
seven dynamic
seven channel
```

The contract checks:

- SevenOS-first commands: `seven`, `sevenpkg`, SevenStore and Settings;
- action execution without opening terminals by default;
- release channel identity (`dev`, `testing`, `stable`) instead of raw Git as
  the only product state;
- SevenOS identity in shell, release files and live ISO branding;
- native surfaces: Hub, Settings, Store, Files, Reader and mini OS centers;
- mini OS runtime manifests with strict HOME/cache/data/workspace boundaries;
- SevenDaemon service path for future policy execution;
- installer and release freeze gates.
- dynamic profile/theme/wallpaper/compositor adaptation.

## Public Mask Contract

`seven mask` is the product-facing masking contract. It does not pretend that
SevenOS has no backend; it checks whether normal launchers, portals and system
identity files say SevenOS first.

The contract validates:

- SevenOS platform facade availability;
- release channel vocabulary;
- installer portal status;
- native action execution;
- public `.desktop` launcher names;
- boot, issue, MOTD and release identity;
- SevenStore / `sevenpkg` as the software surface.

This is the practical line between “Arch tools visible everywhere” and “SevenOS
as the primary operating system experience”.

## Dynamic OS Contract

`seven dynamic` is the user-facing contract for a living SevenOS desktop. It is
an alias for the adaptive UI contract, but with product vocabulary that normal
surfaces can expose.

It checks that these signals move together:

- active mini OS profile;
- `profile-ui.json` as the UI bus;
- semantic context and switch suggestions;
- Waybar/Profile Center/Hub actions;
- theme runtime;
- wallpaper-derived palette;
- Hyprland dynamic compositor accents.

This is what prevents SevenOS from feeling like a static theme. A profile change
must have visible runtime consequences across shell, launchers, settings,
terminal, wallpaper and window behavior.

## Masking Policy

SevenOS should not hide its technical base from developers, but it should hide
implementation details from normal workflows.

| User intention | SevenOS surface | Backend detail |
| --- | --- | --- |
| Install an app | SevenStore / `seven store` | pacman, Flatpak, AUR helper |
| Change display | SevenOS Settings | Hyprland monitor config |
| Change workspace mode | Smart Window System | Hyprland dispatch/windowrule |
| Switch mini OS | Profile Center / Waybar | LAPA runtime, services, shims |
| Run Windows app | Windows Bridge | Wine, Bottles, libvirt, QEMU |
| Diagnose OS | Seven Doctor / Hub | shell scripts, systemctl, journalctl |

## Platform Facade

`seven platform` is the public vocabulary map. It is what user-facing surfaces
should show before backend names:

- SevenOS Software -> pacman, Flatpak, AUR helpers
- Seven Smart Window System -> Hyprland, Wayland, generated config
- SevenOS Session -> systemd user services
- SevenOS Mini OS Runtime -> LAPA, cgroups, shims, profile roots
- SevenOS Installer -> Calamares profile, Archiso, Archinstall planner
- Seven Core -> SevenDaemon, JSON bus, shell contracts
- Windows Bridge -> Wine, Bottles, libvirt, QEMU/KVM

## Action Runner

`seven-action-runner` is the default bridge for UI actions that do not need a
visible terminal. It writes logs under:

```text
~/.local/state/sevenos/actions/
```

and uses notifications for start/success/failure. Interactive or debugging
actions can still request a terminal explicitly.

## Public Release Gate

`seven channel` is the user-facing release channel contract:

- `dev`: active local development;
- `testing`: candidate work suitable for wider testing;
- `stable`: only valid when the public release gates are actually ready.

This does not create a Git commit or fake a release. It gives Hub, Settings and
Doctor a stable product vocabulary while `seven release` remains the stricter
gate for public ISO readiness.

For the graphical installer, `seven installer runtime --json` separates the
Calamares profile from the Calamares runtime package. This keeps the release
gate honest on plain Arch hosts: SevenOS can validate its profile and live ISO
entrypoint while still reporting that the ISO build environment must provide
Calamares from a trusted downstream repository or AUR build.

SevenOS becomes a public distribution only when:

- `seven release doctor` is public-release-ready;
- `seven autonomy doctor` passes at distribution-layer level;
- the repository is frozen/committed;
- the graphical ISO installer path is present;
- default user workflows do not expose raw Arch/Hyprland commands first.

Until then, SevenOS can be a stable daily driver while still being honest about
its base.
