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
seven about
seven lifecycle
seven update
seven recovery
seven product
seven foundations
seven autonomy
seven autonomy --json
seven autonomy doctor
seven platform
seven mask
seven dynamic
seven surfaces
seven routes
seven distribution
seven channel
```

The contract checks:

- public About/edition identity via `seven about`;
- public lifecycle/maintenance routes via `seven lifecycle`;
- SevenOS-first update state via `seven update`;
- SevenOS-first recovery state via `seven recovery`;
- compact public product facade via `seven product`;
- SevenOS-owned foundation routes via `seven foundations`;
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
- public native surfaces for normal-user workflows.
- user-intent routes that keep workflows SevenOS-first.

## About Contract

`seven about` is the user-facing identity surface. It is the contract that Hub,
Settings and the installer should use before showing technical backend details.

It exposes:

- SevenOS name, edition and tagline;
- active mini OS and workspace;
- release channel and commit;
- daily-driver/public-release state;
- SevenOS product layers;
- technical foundations for advanced users.

This turns “what system am I running?” into a SevenOS answer instead of a raw
Arch/Hyprland answer.

## Lifecycle Contract

`seven lifecycle` is the SevenOS maintenance surface. It maps the boring but
essential OS lifecycle to SevenOS routes:

- update apps and system -> SevenStore / `sevenpkg`;
- inspect/apply updates -> `seven update`;
- repair the OS -> Seven Doctor / `seven repair`;
- protect/recover user state -> `seven recovery`;
- check release readiness -> `seven distribution`;
- prepare installer/recovery -> `seven installer release`.

This is how SevenOS avoids becoming “Arch commands with a theme” during normal
maintenance. Advanced users can still inspect pacman, systemd, git and logs,
but the product path starts with SevenOS language and SevenOS actions.

## Product Facade

`seven product` is the compact public snapshot for native surfaces. It bundles
the signals that Hub, Settings, Welcome and installer screens need most:

- About identity and active mini OS;
- lifecycle/maintenance state;
- distribution gate;
- native surfaces;
- user routes;
- public masking;
- dynamic desktop state.

The goal is performance and clarity: UI surfaces can read one product contract
instead of re-implementing the product logic or exposing backend checks directly.

## Foundations Contract

`seven foundations` is the ownership map between SevenOS product surfaces and
the technical projects underneath them.

It keeps this distinction explicit:

- SevenOS Identity over release files, issue files and branding assets;
- SevenOS Software over pacman, Flatpak and AUR helpers;
- Seven Smart Window System over Hyprland, Wayland and generated compositor
  configuration;
- SevenOS Shell over Waybar, Rofi and native GTK surfaces;
- SevenOS Mini OS Runtime over LAPA, cgroups, profile roots and sandbox tools;
- Shield, Windows Bridge, Installer and Lifecycle over their low-level
  backends.

The contract does not hide attribution from advanced users. It simply gives Hub,
Settings, Welcome and Doctor a SevenOS-first route for every foundation before a
normal user has to see backend commands.

## Distribution Contract

`seven distribution` is the top-level product gate. It does not replace the
lower contracts; it reads them and gives Hub, Settings, Doctor and release tools
one clear answer:

- `daily-driver-distribution`: SevenOS is coherent enough for daily use;
- `public-release-candidate`: all distribution and release gates are clean;
- `distribution-foundation`: the core layer exists, but key gates are partial;
- `development-layer`: SevenOS is still visibly a development workspace.

It aggregates:

- `seven foundations`;
- `seven autonomy`;
- `seven platform`;
- `seven mask`;
- `seven dynamic`;
- `seven surfaces`;
- `seven routes`;
- `seven channel`;
- `seven installer release`;
- `seven installer runtime`;
- `seven release doctor`.

This is the single gate that prevents SevenOS from presenting itself as a
public release while the installer runtime, release freeze or graphical ISO path
still need work.

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

## Public Surfaces Contract

`seven surfaces` checks the visible product layer: Hub, Settings, Launchpad,
Spotlight, Quick Settings, Files, Store, Reader, Terminal, Profile Center, Mini
OS Center, Shield Center, Windows Bridge, Doctor, notifications and window
controls.

The goal is simple: each common workflow needs a SevenOS-native entrance before
the user ever has to know about Rofi, Hyprland, pacman, libvirt, systemctl or
raw shell scripts.

## User Routes Contract

`seven routes` maps human intentions to SevenOS actions and surfaces:

- install software -> SevenStore;
- change settings -> Settings;
- search -> Spotlight;
- switch mini OS -> Profile Center;
- manage Windows compatibility -> Windows Bridge;
- repair the system -> Seven Doctor;
- control windows -> Seven Smart Window System.

This is the autonomy layer above command names. The user should not need to know
which backend tool is responsible; SevenOS owns the route and exposes the
backend only as implementation detail.

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
- `seven distribution doctor` is public-release-candidate;
- `seven autonomy doctor` passes at distribution-layer level;
- the repository is frozen/committed;
- the graphical ISO installer path is present;
- default user workflows do not expose raw Arch/Hyprland commands first.

Until then, SevenOS can be a stable daily driver while still being honest about
its base.
