# SevenOS Profile Isolation

SevenOS uses a global Arch/pacman package store, but profile capabilities are
not globally active by default.

The rule is:

> Installed does not mean active.

## Model

SevenOS separates three layers:

- package availability: pacman/Flatpak can install tools globally
- profile activation: only the selected LAPA runtime exposes its capabilities
- execution policy: SevenOS commands run through profile-aware slices and shims

This avoids pretending pacman is per-profile while still preventing profile
pollution in the user experience.

## Runtime Files

Activation writes:

- `~/.config/sevenos/profile-isolation.json`
- `~/.config/sevenos/profile-isolation.env`
- `~/.config/sevenos/active-packages.txt`
- `~/.config/sevenos/inactive-packages.json`
- `~/.config/sevenos/profile-services.json`
- `~/.local/share/sevenos/profile-shims/`

Seven Terminal sources `profile-isolation.env` and prepends the shim directory.

## Commands

```bash
seven profile isolation status
seven profile isolation plan equinox forge shield --json
seven profile isolation apply equinox --yes
seven-profile-run docker ps
```

## Service Policy

Services are owned by profiles. For example:

- Forge owns `docker.service`, `postgresql.service`, `valkey.service`
- Horizon owns `caddy.service`
- Windows owns `libvirtd.service`, `virtqemud.service`, `virtlogd.service`
- Pulse owns `gamemoded.service`

When a profile is inactive, SevenOS writes the quieting plan and attempts
non-interactive service disablement with `sudo -n`. If admin credentials are not
available, the required commands remain recorded in
`profile-isolation.json`.

## Guarantee

SevenOS does not uninstall packages when switching profiles. Instead it prevents
the inactive profile from being exposed as an active capability through:

- active package allowlists
- inactive package ownership records
- profile-aware app shims
- systemd user slices
- service quieting policy

This is the practical LAPA-compatible isolation boundary for an Arch-based OS.
