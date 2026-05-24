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
- data boundary: strict launches can use per-profile config/HOME/cache/data roots
- package view: SevenOS exposes a per-profile `PATH` over the global pacman store
- rootfs boundary: optional per-profile rootfs targets can hold independent package installations
- identity state: wallpaper and other user-facing mini OS preferences are stored per profile

This avoids pretending pacman is per-profile while still preventing profile
pollution in the user experience.

## Runtime Files

Activation writes:

- `~/.config/sevenos/profile-isolation.json`
- `~/.config/sevenos/profile-isolation.env`
- `~/.config/sevenos/profiles/<profile>/`
- `~/.config/sevenos/profiles/<profile>/experience.json`
- `~/.config/sevenos/profiles/<profile>/profile-ui.json`
- `~/.config/sevenos/profiles/<profile>/theme.conf`
- `~/.config/sevenos/profiles/<profile>/wallpaper-state`
- `~/.config/sevenos/profiles/<profile>/session.json`
- `~/.config/sevenos/profiles/<profile>/passage.json`
- `~/.config/sevenos/active-packages.txt`
- `~/.config/sevenos/inactive-packages.json`
- `~/.config/sevenos/profile-services.json`
- `~/.local/share/sevenos/profile-shims/`
- `~/.local/share/sevenos/profile-package-views/<profile>/bin/`
- `~/.local/share/sevenos/profile-rootfs/<profile>/rootfs/`
- `~/.local/share/sevenos/profile-rootfs-manifests/<profile>.json`
- `~/.local/share/sevenos/bridge/<profile>/bridge-inbox.jsonl`
- `~/.local/share/sevenos/bridge/<profile>/bridge-outbox.jsonl`
- `~/.local/share/sevenos/objects/`
- `~/.local/share/sevenos/profile-containers/<profile>/{home,cache,data}`
- `~/.local/share/sevenos/wallpapers/profiles/<profile>/`
- `~/.local/share/sevenos/profile-overlays/<profile>/{upper,work,merged}`

Seven Terminal sources `profile-isolation.env` and prepends the shim directory.
It also prepends the active `SEVENOS_PACKAGE_VIEW`, so commands that belong to
another mini OS are hidden or routed before the host system can expose them.

## Commands

```bash
seven profile isolation status
seven profile isolation plan equinox forge shield --json
seven profile isolation apply equinox --yes
seven-profile-run docker ps
seven-profile-run --profile shield --container nmap --version
seven-profile-run --profile forge --container --workspace . npm test
seven-profile-run --profile forge --container --workspace-profile sh
seven-profile-run --profile shield --ephemeral sh
seven profile-rootfs status
seven profile-rootfs audit all
seven profile-rootfs seal all --apply --yes
seven profile-rootfs verify all
seven profile-rootfs prepare forge --apply --yes
seven profile-rootfs build forge --apply --yes
seven profile exec forge --rootfs sh
seven profile exec shield --rootfs --isolation strict sh
seven profile exec shield --rootfs --isolation strict --seal-required sh
seven profile exec studio --container krita
seven bridge status
seven bridge doctor
seven bridge graph
seven bridge relations
seven bridge switch --to baobab
seven bridge session --profile forge
seven bridge remember --profile baobab --app "seven baobab open" --mood "calm collection"
seven bridge send --from baobab --to studio --kind textile ~/Baobab/Heritage/reference.png
```

## Strict Profile Launches

`seven-profile-run --container` is the practical bridge between Arch's global
package store and SevenOS mini OS autonomy.

In this mode:

- pacman packages still come from the host system
- `HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and `XDG_DATA_HOME` point to the selected mini OS
- the real project/work directory is not mounted unless `--workspace PATH` is
  explicitly passed
- the command runs in a systemd user scope for the active runtime slice
- bubblewrap exposes system files read-only where possible
- Wayland/DBus runtime access is passed through for graphical apps

Use `seven-profile-run --profile <profile> --json` to inspect the exact runtime
boundary before launching an app.

Use `seven-profile-run --profile <profile> --manifest` when a SevenOS surface
needs the complete mini OS runtime contract: profile roots, default workspace,
environment variables, strict shell command, workspace shell command and
ephemeral shell command.

When a command needs a project directory, use `--workspace PATH`. SevenOS mounts
that directory at `/workspace` inside the strict runtime and starts the command
there. This keeps the real home directory private while still allowing Forge,
Studio or Shield tools to work on an explicit project/case folder.

Use `--workspace-profile` when you want the default workspace of the selected
mini OS: `~/Forge`, `~/ShieldLab`, `~/Studio`, `~/Baobab`, `~/WindowsMode`,
`~/Pulse` or `~/SevenOS`. SevenOS creates the folder if it does not exist.

## External Folders

Some folders are intentionally outside every mini OS workspace. Grant them
explicitly instead of weakening isolation:

```bash
seven profile grant-folder forge /home/seven/Code/OS/SevenOS --name SevenOS --rw
seven profile folders forge
seven profile open-folder forge /home/seven/Code/OS/SevenOS
```

Granted folders are mounted in strict profile containers under:

```text
/external/<name>
```

They remain outside the mini OS by default. The grant only says that the chosen
mini OS may access that folder when launched through `seven-profile-run`.

Use `--ephemeral` for a disposable strict session. SevenOS creates temporary
config/HOME/cache/data roots, runs the command, then removes them after the command
exits. Explicit workspaces mounted with `--workspace` or `--workspace-profile`
are not deleted.

## Profile Package Views And RootFS

SevenOS now has two package boundaries:

- **profile package view**: a per-mini-OS `bin` directory that exposes only the
  commands owned by the active mini OS. This is active by default and still uses
  host pacman binaries physically.
- **profile rootfs**: a per-mini-OS root filesystem target under
  `~/.local/share/sevenos/profile-rootfs/<profile>/rootfs`. Once built, it can
  run commands with `seven profile exec <profile> --rootfs <command>`.

Preparing a rootfs is safe and creates directories, manifests and package
lists. Building it needs `pacstrap` and root privileges because it installs a
real Arch package set into the profile rootfs:

```bash
seven profile-rootfs prepare forge --apply --yes
seven profile-rootfs build forge --apply --yes
seven profile exec forge --rootfs sh
```

Until a profile rootfs contains `/usr/bin`, `--rootfs` refuses to launch and
prints the build command instead of silently falling back to the host.

Runtime rootfs sessions are mounted read-only by default. Profile HOME, cache
and data stay writable through their own profile mounts, but `/usr`, `/etc`,
`/var/lib/pacman` and the rest of the mini OS rootfs cannot be changed by a
normal app launch. This keeps a built mini OS stable after sealing.

Writable rootfs access is an explicit maintenance operation:

```bash
seven profile exec forge --rootfs-writable sh
seven profile-rootfs verify all
seven profile-rootfs seal all --apply --yes
```

Use it only for intentional package/rootfs maintenance, then verify and reseal
so SevenOS can detect drift again on the next launch.

## Automatic Mini OS Requirements

Each mini OS owns package manifests in `profiles/catalog.json`. SevenOS exposes
a single requirements route so users do not have to search package names
manually:

```bash
seven profile requirements forge
seven profile requirements forge --apply --yes
seven profile requirements all --json
seven profile requirements studio --optional --apply --yes
```

When a command is launched through `seven profile exec <profile> ...` and the
command is not visible in that mini OS package view, SevenOS automatically runs
the required profile installer, refreshes the profile isolation/package view,
and retries resolution. Set `SEVENOS_PROFILE_REQUIREMENTS_AUTO=0` to disable
that automatic repair path.

## Runtime Isolation Modes

`seven-profile-run` supports three declared modes:

- `balanced`: daily graphical mode. It keeps the profile HOME/cache/data/rootfs
  boundary, but shares runtime sockets, host GPU/dev and network so normal apps
  can draw windows, play audio and access the session.
- `strict`: hardened namespace mode. It disables network, exposes a minimal
  `/dev`, removes the host runtime directory and blocks DBus/session sockets by
  default. This is the default posture for Shield-style commands.
- `independent`: native mini OS mode. It forces the profile rootfs path,
  verifies the seal, mounts the rootfs read-only, and keeps HOME/cache/data
  profile-scoped. It does not use a VM.

Examples:

```bash
seven profile exec forge --rootfs --isolation balanced sh
seven profile exec forge --independent sh
seven profile exec shield --rootfs --isolation strict sh
seven profile exec pulse --container --isolation strict sh
seven profile-rootfs audit all --json
seven profile-rootfs seal all --apply --yes
seven profile-rootfs verify all --json
```

`strict` is the closest non-VM boundary currently available: it still shares the
host kernel, but it no longer shares the normal network namespace, DBus/runtime
sockets or host GPU devices.

## Native Independent Mini OS Boundaries

SevenOS mini OS profiles are intended to be independent without becoming VMs.
The native independent path is:

```bash
seven profile-rootfs status
seven profile-rootfs audit all
seven profile-rootfs seal all --apply --yes
seven profile exec forge --independent sh
```

This gives each mini OS its own command surface, rootfs, HOME, cache, data,
workspace policy, systemd scope and seal checks while keeping the SevenOS shell
fluid and native. The kernel, compositor, GPU and some host services remain
shared by design.

Windows Bridge is the exception: Windows compatibility may use libvirt/QEMU
because Windows itself is not a native SevenOS mini OS.

The practical boundary levels are now:

- **package view**: filtered command surface on the shared host.
- **container/rootfs**: separate HOME/cache/data, profile package view, optional
  sealed read-only rootfs, shared kernel.
- **independent**: sealed read-only profile rootfs plus profile HOME/cache/data
  by default, no VM.
- **strict rootfs**: no host network namespace, no DBus/runtime socket, minimal
  `/dev`, shared kernel.

## RootFS Seals

After building rootfs profiles, SevenOS can write a lightweight local seal for
each mini OS:

```bash
seven profile-rootfs seal all --apply --yes
seven profile-rootfs verify all
```

The seal records the profile marker, `os-release` hash and a package database
fingerprint. It is not a remote attestation system, but it gives SevenOS a fast
way to detect rootfs drift or accidental modification before opening a mini OS.

When `seven-profile-run --rootfs` starts a sealed rootfs, it verifies the seal
before execution. In `strict` mode the seal is required; if the package
fingerprint or OS marker has drifted, SevenOS refuses to launch and asks you to
run:

```bash
seven profile-rootfs verify all
seven profile-rootfs seal all --apply --yes
```

## Profile Wallpaper State

`seven-wallpaper set IMAGE` is profile-scoped by default. If Baobab is active,
the image is saved under:

```text
~/.local/share/sevenos/wallpapers/profiles/baobab/wallpaper-custom.png
~/.config/sevenos/profiles/baobab/wallpaper-state
```

Switching to Forge, Shield, Studio, Windows, Pulse or Equinox restores that
mini OS wallpaper state instead of overwriting Baobab. The global
`wallpaper-sevenos-active.png` remains only the current Hyprpaper projection.

## Profile Experience State

Each mini OS has an experience manifest:

```bash
seven profile experience baobab
seven profile experience forge --json
```

The manifest records the mini OS workspace, config root, theme file, wallpaper
state, session memory, passage language, accent colors and communication rule.
SevenOS surfaces can read the active projection from
`~/.config/sevenos/profile-ui.json`, while each mini OS keeps its own durable
copy in:

```text
~/.config/sevenos/profiles/<profile>/profile-ui.json
~/.config/sevenos/profiles/<profile>/experience.json
~/.config/sevenos/profiles/<profile>/session.json
~/.config/sevenos/profiles/<profile>/passage.json
```

This lets mini OSes feel like different OS environments while still using the
same SevenOS event bus and explicit capability collaboration layer.

## SevenOS Bridge

Profiles do not silently read each other's config, home, cache or data roots.
When one mini OS needs to hand work to another, it creates a declared SevenOS
object:

```bash
seven bridge send --from baobab --to studio --kind textile ~/Baobab/Heritage/faso-danfani.png
seven bridge inbox --profile studio
seven bridge objects
```

The bridge writes:

- an object manifest under `~/.local/share/sevenos/objects/<id>.json`
- a message in the source outbox
- a message in the destination inbox
- a recent object entry in the source `session.json`

This is the communication rule: configs stay isolated, objects travel with
origin, owner, rights, kind, status and next actions.

The bridge also exposes a readiness gate:

```bash
seven bridge doctor
```

The gate checks that each mini OS has its profile config, theme, wallpaper
state, `profile-ui.json`, experience manifest, session memory, passage manifest
and inbox/outbox. It is the fast answer to: "are the mini OSes really separate
and still able to talk?"

Session memory is profile-owned:

```bash
seven bridge remember --profile studio --path ~/Studio/References --task "Prepare Baobab textile board"
seven bridge session --profile studio
```

This stores recent apps, paths, objects, pinned objects, tasks and ambience in
`~/.config/sevenos/profiles/<profile>/session.json`.

## Passage Mode

Each mini OS owns a small passage manifest:

```text
~/.config/sevenos/profiles/<profile>/passage.json
```

It describes the entry phrase, exit phrase, intended motion and subtle sound
identity for future switcher animations. For example Baobab enters through the
knowledge tree, Forge through the workbench, Shield through the authorized lab
and Studio through the creative atelier.

The switcher contract is available before applying a profile switch:

```bash
seven bridge switch --from baobab --to forge
seven bridge switch --to studio --apply
```

Without `--apply`, SevenOS writes the passage preview to:

```text
~/.local/share/sevenos/bridge/switcher.json
```

Future native surfaces can use this JSON to show a calm transition instead of a
plain profile menu.

## Service Policy

Services are owned by profiles. For example:

- Forge DevOps owns `docker.service`, `postgresql.service`, `valkey.service` and `caddy.service`
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
- optional bubblewrap execution with profile-owned config/HOME/cache/data
- profile-scoped wallpaper and user-facing identity state
- service quieting policy

This is the practical LAPA-compatible isolation boundary for an Arch-based OS.
