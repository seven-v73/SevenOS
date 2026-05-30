# SevenOS Packaging Strategy

SevenOS uses clear package channels and profile scopes. The full product
strategy for Equinox, SevenPkg and mini OS package engines lives in
`docs/SEVENPKG_STRATEGY.md`.

The short rule:

```text
Do not mix many distro package managers into the host.
Keep Equinox coherent.
Route domain apps through SevenPkg into the right mini OS.
Use extra engines only as explicit profile capabilities.
```

## SevenOS Component Packages

SevenOS is moving away from a visible Git-repo-only install flow. The
component boundaries are declared in:

```text
sevenos.dotinst
```

Generate local pacman package skeletons with:

```bash
seven manifest package-plan
seven manifest package-generate
seven manifest package-doctor
```

Generated output lives in:

```text
packaging/pacman/
```

Current target components:

- `sevenos-cli`
- `sevenos-branding`
- `sevenos-hyprland`
- `sevenos-hub`
- `sevenos-profiles`
- `sevenos-server`
- `sevenos-installer`

These PKGBUILDs are developer skeletons. They are meant to make package
boundaries concrete before publishing a real SevenOS repository.

## Official Pacman Repositories

Default for system packages, desktop components, profiles, ISO tooling,
security tools, Pulse gaming packages, Forge toolchains and most mini OS rootfs
installs.

Package manifests live in:

```text
scripts/packages-*.txt
```

## Flatpak

Used for selected desktop applications that are better maintained or more available through Flathub.

Current Flatpak use:

- Bottles: `com.usebottles.bottles`

SevenOS configures Flathub in the Windows compatibility layer for Bottles and
other app-first compatibility flows. Full Windows VM support is not a SevenOS
identity; it remains an advanced compatibility fallback only.

## AUR Or Manual Packages

AUR is optional and should be profile-scoped when possible. SevenPkg can prepare
private `paru` or `yay` helpers inside mini OS rootfs views, so AUR use in
Forge or Pulse does not become a global Equinox habit.

Expected future candidates:

- DaVinci Resolve
- proprietary creative tools
- optional vendor-specific GPU utilities

## Rule

Core installation must remain usable with official repositories only. Flatpak is
allowed for user apps. AUR must remain opt-in and documented. Nix or other lab
engines may be added only behind explicit profile actions, not as host defaults.

## Public Trust And Signing Policy

For a public beta, SevenOS must publish release artifacts with clear integrity
signals:

- ISO checksums next to every image;
- package repository metadata generated from the local SevenOS repo;
- release channel shown as `dev`, `testing` or `stable`;
- support bundles kept local-first and reviewed by the user before sharing;
- update reports written locally before and after `seven update`.

For large-scale production, checksums are not enough: SevenOS should add signed
ISO manifests and signed repository metadata before calling a build stable for
unattended public distribution.

## Test Machine Install Order

For a normal test machine, install in this order:

```bash
./install.sh base --yes
./install.sh dev --yes
./install.sh cybersecurity core --yes
./install.sh cybersecurity sandbox --yes
./install.sh windows --yes  # compatibility layer, not a mini OS identity
./install.sh server --yes
seven phase-gate
```

Install larger profile groups only when the test machine is intended for that
workflow.
