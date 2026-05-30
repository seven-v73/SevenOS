# SevenOS Archiso

This directory contains the SevenOS live ISO profile.

The profile is SevenOS-first: it creates a bootable live environment, injects
the SevenOS repository into `/opt/SevenOS`, autologins into the branded
`SevenOS Live` Hyprland session, starts NetworkManager and opens the graphical
installer portal. The Arch-compatible base remains underneath, but the public
route is SevenOS UI, not an Arch command prompt.

## Build

From the repository root:

```bash
./install.sh iso-tools
./install.sh iso
```

Preview the build:

```bash
./install.sh iso --dry-run
```

The ISO is written to:

```text
out/iso/
```

Temporary build files are written to:

```text
out/archiso/
```

## Live Environment

Inside the ISO:

- hostname is `sevenos-live`
- repository is available at `/opt/SevenOS`
- user `seven` is created with passwordless sudo and live autologin
- SDDM opens the `SevenOS Live` Wayland session automatically
- TTY1 has a fallback autologin that starts the same SevenOS live session
- NetworkManager is enabled
- SSH is installed but not enabled by default
- `sevenos-live-ready` imports the live environment, prepares user folders,
  starts SevenOS user services, gives progress feedback and opens the
  graphical installer portal after Hyprland is ready
- `seven-installer live-status` reports the live first-screen state and the
  recent setup log, progress, network readiness, storage readiness,
  power/memory readiness and recommended next action without asking users to
  inspect shell internals
- the live status includes a public readiness summary for Hub/Helper surfaces:
  ready, attention or blocked, with short issue/action entries
- live status includes elapsed time and freshness metadata, so the Hub can show
  real progress and flag stale startup work as `live-helper-stale`
- live status exposes a startup `timeline`, allowing the Helper/Hub to animate
  pending, active, done, blocked and closed phases without parsing logs
- live status exposes localized public UI labels for the title, subtitle,
  progress text and primary action, matching the active system language
- the UI status also reports active/next timeline steps, completed step count
  and a confidence score for calm first-screen feedback
- the UI status provides localized compact cards for network, disks, memory
  and power, reduced to ok/attention/blocked for stable rendering
- the UI status includes `priority_card`, `can_continue` and `safety_level`,
  allowing the installer screen to choose a calm continue/review/blocked state
- the UI status includes a localized `user_message`, giving the user a clear
  headline and explanation before any destructive installation step
- the UI status exposes `primary_command` beside `primary_action_label`, so the
  native portal can show one contextual action for continue, retry, Wi-Fi or
  disk inspection
- the UI status exposes stable `secondary_actions` for detailed status, retry
  and disk inspection, giving the live session a calm recovery path
- the UI status exposes `attention_items`, a compact list of current issues or
  a clear "no blocker" state for the first installer screen
- motion hints include `pace_state` and `estimated_remaining_seconds`, so the
  installer screen can animate progress without promising exact install times
- every live startup attempt carries a short `session_id`, helping graphical
  surfaces ignore stale state after a retry
- the native SevenOS installer portal consumes the same live-status UI payload
  for its header, progress, startup timeline and readiness cards
- the installer portal refreshes live progress, active step, next step and
  priority hint in place, keeping the first screen calm during slower hardware
  or network preparation
- GNOME Disks is available in the live image for a graphical, non-destructive
  disk inspection route before launching destructive installer steps
- `seven-installer live-retry` resets and relaunches the live first-screen
  flow if the installer window was closed too early
- the live first-screen helper keeps a lightweight lock and tracks the launched
  installer process when possible, so duplicate windows and stale "ready" state
  are avoided
- the helper confirms the installer remains alive before marking the session
  ready; early exits become a visible `closed` state with a retry action
- stale live-start locks recover automatically, and the desktop "Installer
  Status" action uses a visible notification instead of invisible terminal
  output
- SevenOS Hyprland, Waybar, GTK, Qt, rofi, notifications and systemd user units are preseeded
- SevenOS CLI wrappers are installed in `/usr/local/bin` and `/home/seven/.local/bin`
- `sevenosctl` is still installed as a legacy compatibility helper
- `/etc/os-release` identifies the live system as SevenOS
- `seven ecosystem` exposes the innovation roadmap

## Current Scope

Implemented:

- Archiso profile
- package set
- live environment branding
- repository injection
- ISO build script
- SDDM autologin into SevenOS Live
- graphical first-run installer portal
- TTY fallback that starts the SevenOS session
- live first-screen feedback, user folder preparation and SevenOS user service startup
- persisted live first-screen status and retry command for Helper/Hub recovery

Still planned:

- Archinstall automation bridge for advanced/non-GUI paths
- hardware-specific package variants
- release signing and checksum workflow
