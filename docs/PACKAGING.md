# SevenOS Packaging Strategy

SevenOS uses three package channels with clear boundaries.

## Official Pacman Repositories

Default for system packages, desktop components, profiles, ISO tooling, security tools, and VM tooling.

Package manifests live in:

```text
scripts/packages-*.txt
```

## Flatpak

Used for selected desktop applications that are better maintained or more available through Flathub.

Current Flatpak use:

- Bottles: `com.usebottles.bottles`

Recommended external download:

- Windows VirtIO driver ISO for Windows VM installs

SevenOS configures Flathub in the Windows compatibility layer.

## AUR Or Manual Packages

Optional only. SevenOS does not automate AUR installation yet.

Expected future candidates:

- DaVinci Resolve
- proprietary creative tools
- optional vendor-specific GPU utilities

## Rule

Core installation must remain usable with official repositories only. Flatpak is allowed for user apps. AUR must remain opt-in and documented.

## Test Machine Install Order

For a normal test machine, install in this order:

```bash
./install.sh base --yes
./install.sh dev --yes
./install.sh cybersecurity core --yes
./install.sh cybersecurity sandbox --yes
./install.sh windows --yes
./install.sh server --yes
seven phase-gate
```

Install larger profile groups only when the test machine is intended for that
workflow.
