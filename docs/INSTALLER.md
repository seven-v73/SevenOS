# SevenOS Installer Direction

SevenOS currently provides a live ISO foundation, post-install setup and
installer planning. The final public disk installer is still a productization
target, not something that should be presented as finished.

For testing before the standalone installer is ready, use the SevenOS route on
top of an Arch-compatible foundation:

```text
docs/TEST_MACHINE.md
```

The current ISO is a graphical SevenOS live environment. It contains the
SevenOS repository at:

```text
/opt/SevenOS
```

On boot, the ISO should not drop the user into an Arch prompt. The expected
public path is:

1. SDDM autologins as the live `seven` user.
2. The `SevenOS Live` Wayland session starts Hyprland.
3. NetworkManager is enabled immediately.
4. SevenOS user configs and command wrappers are already present.
5. `sevenos-live-ready` imports the session environment, prepares user
   folders, starts SevenOS user services, shows progress feedback and opens the
   graphical installer portal.

The boot entries are intentionally quiet and splash-first:

```text
quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false
```

This does not remove the Arch-compatible foundation. It masks low-level boot
noise from the normal public path so the first visible experience is SevenOS.

The live initramfs must also use `mkinitcpio-archiso` hooks. Without those
hooks, the kernel behaves like a normal installed system and waits for
`/dev/gpt-auto-root`; that is a broken ISO boot path, not an installer step.

If SDDM fails, TTY1 autologins to `seven` and starts the same SevenOS live
session as a recovery fallback. This keeps the ISO usable without asking a
normal user to understand the Arch live command shell.

Calamares uses the standard `shellprocess` module for SevenOS finalization.
That matters because the ISO can rely on a module shipped by Calamares instead
of requiring a custom plugin package before the graphical installer can run.

The first screen should feel alive but calm: network preparation, installer
opening and recovery hints are reported through native notifications and the
live-ready log at `~/.cache/sevenos/live-ready.log`.

For diagnostics or a manual retry from the live session:

```bash
seven-installer live-status
seven-installer live-status --json
seven-installer live-notify
seven-installer live-reset
seven-installer live-retry
seven-installer open
```

`live-status` reads the persisted first-screen state from
`~/.local/state/sevenos/live-status.json`, so the Hub or Helper can show the
current step, progress percentage, network readiness, storage readiness and
power/memory readiness plus the recommended next action without scraping shell
output. It also exposes a public `readiness` summary so graphical surfaces can
show "ready", "attention" or "blocked" without reimplementing installer logic.
The status includes elapsed time and freshness metadata; if progress stops
updating during startup, SevenOS can surface the issue as `live-helper-stale`
and offer a retry instead of leaving the first screen motionless.
It also exposes a `timeline` array for graphical surfaces. Each live startup
step is marked as `pending`, `active`, `done`, `blocked` or `closed`, so the
installer card can animate a real sequence instead of guessing from a single
percentage.
For the public UI, `live-status --json` also includes localized `ui` labels:
title, subtitle, progress text and primary action label. That keeps the Helper,
Hub or installer card aligned with the active system language without each
surface rebuilding its own wording.
The same `ui` block exposes `active_step`, `next_step`, step counts and a
simple confidence score. This lets the first-screen card stay calm and useful:
show what SevenOS is doing now, what comes next, and whether the current state
is trustworthy enough to continue.
It also provides compact `status_cards` for network, disks, memory and power.
Those cards are localized and already reduced to `ok`, `attention` or
`blocked`, so graphical surfaces can render stable status tiles without
duplicating hardware-readiness logic.
For decision-making, the same block includes `priority_card`, `can_continue`
and `safety_level`. A public UI can therefore highlight the one thing that
matters most and decide whether to show a calm continue button, a review state
or a blocked state.
It also includes a localized `user_message` with a headline, body and tone.
This is the user-facing decision layer: the screen says clearly whether
SevenOS is ready, recommends a review, or waits for a required action.
The `primary_command` travels with `primary_action_label`, so the native portal
can expose one contextual button: open the installer, retry the live flow,
connect Wi-Fi or inspect disks depending on the current state.
The UI block also provides `secondary_actions` for calm recovery: detailed
status, retry and disk inspection. These actions are intentionally stable so a
new user always has a safe way to understand or recover the live session.
`attention_items` gives the same screen a short, readable list of what matters
now. If nothing blocks the flow, it reports that no blocking issue was found;
if something is wrong, it names the first few issues without requiring log
reading.
For motion and pacing, `ui` also exposes `pace_state` and
`estimated_remaining_seconds`. These values are intentionally soft hints for
animation and copy, not strict install-time promises.
Each live startup attempt also carries a short `session_id`. Graphical
surfaces can use it to ignore stale state from a previous retry and keep
animations tied to the current live-start attempt.

The native SevenOS installer portal consumes this same `live-status` contract:
its header, progress bar and live readiness cards come from the public UI
payload instead of duplicating separate status logic.
It also renders the live `timeline` directly, so the first graphical screen
shows the actual SevenOS startup sequence: session, environment, network,
storage, services and installer portal. This keeps the user oriented during
slower boots without exposing Arch shell details.
The same screen refreshes the live progress, active step, next step and
priority hint every few seconds. The installer therefore feels responsive
during hardware detection or network warm-up without spawning extra windows.
Its main status card uses `user_message`, so the first thing the user reads is
the SevenOS decision, not an internal status code.
Its primary button follows `primary_command`, keeping the next action in one
stable place instead of scattering recovery and install actions across the UI.
Secondary recovery buttons stay beside it, giving access to status, retry and
disk inspection without turning the first screen into a troubleshooting page.
The summary also renders `attention_items`, so the user sees the real concerns
in one compact line before touching disk operations.

The live-ready helper also uses a lightweight lock and stores the installer
process id when possible. That prevents duplicate installer windows during
session startup and lets `live-status` report when the portal was launched but
has since been closed.

After launching the portal, the helper waits briefly for the installer window
to stay alive before marking the first screen as ready. If it closes too early,
SevenOS records `state: closed`, shows a native notification and recommends
`seven-installer live-retry` instead of leaving the user with a silent failure.

The lock is self-healing: if a live startup is interrupted, a stale lock older
than the short startup window is cleared automatically. The desktop action
"Installer Status" uses `live-notify`, so it produces visible feedback even
when launched from a graphical menu without a terminal.

The current installer implementation is a non-destructive planning and script
generation flow:

```bash
seven installer status --json
seven installer plan
seven installer plan --json
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
```

`seven installer plan --json` is the machine-readable contract consumed by
Seven Hub, Seven Server and the Control Plane. It tracks Archinstall,
Calamares, Archiso and ISO build readiness before SevenOS becomes a public
installable distribution.

## Calamares ISO Runtime

SevenOS now separates the Calamares profile from the package source used by the
live ISO. The profile, branding and launcher live in the repository; the ISO
runtime must provide the `calamares` package either through the active package
repositories or through the SevenOS local archiso repository.

Useful commands:

```bash
seven installer experience
seven installer experience --json
seven installer experience plan
seven installer runtime
seven installer iso-runtime
seven installer iso-runtime --json
seven installer iso-runtime deps --yes
seven installer iso-runtime build-local-repo --dry-run
seven installer iso-runtime build-local-repo --yes
./install.sh calamares-runtime status
./install.sh iso --dry-run
```

`build-local-repo --yes` clones the Calamares AUR package recipe, builds it with
`makepkg`, copies the package into `archiso/localrepo/x86_64`, and creates the
`sevenos-local` repository database. During ISO builds, `scripts/build-iso.sh`
injects that repository into the temporary archiso profile.

SevenOS should not claim `public-release-ready` until the graphical ISO runtime
is actually available, the live session starts SevenOS-first, and the release
doctor is clean.

## Public Install Experience

`seven installer experience` is the public contract for a new machine. It
connects five parts that must feel like one OS flow:

- modern graphical installer route;
- automatic hardware detection;
- GPU driver guidance;
- preset profiles for developer, gamer, creator, server and balanced use;
- post-install assistant through `seven setup new-device --yes`,
  `seven first-run verify` and `seven post-install`.

The command is intentionally safe: it reports and recommends. Package changes
stay behind explicit commands and installer confirmations.

## Language Readiness

The installer must not leave SevenOS half translated after first boot. Locale,
session environment and generated runtime labels are part of the install
contract.

After the live session or a finished installation, use:

```bash
seven language doctor
seven language audit
seven first-run verify
```

Expected result:

- English and French catalogues are available.
- The active locale is projected into the user session and systemd user
  environment.
- Waybar, Prism, widgets and Mini OS profile configs do not keep stale labels
  from the previous language.
- `seven first-run verify` reports the language contract and runtime label audit
  as OK.

Machine-readable consumers should use the stable first-run keys
`language-contract` and `runtime-labels` instead of localized titles.

If a machine feels inconsistent after switching languages, run:

```bash
seven language repair
```

This is the supported public repair path. Users should not need to edit
`~/.profile`, Waybar configs or Mini OS files by hand.

## Options Under Review

### Scripted TUI Installer

Best fit for early SevenOS:

- transparent Bash workflow
- easy to review
- aligned with current scripts
- less heavy than a full GUI installer

### Calamares

Good long-term option for a polished graphical install flow:

- mature distro installer
- partitioning UI
- localization support
- more packaging and maintenance overhead

### Custom Seven Hub Installer

Possible later:

- strongest brand fit
- more development work
- should only happen after CLI install flow is proven

## Current Recommendation

Keep the scripted TUI path as the safe fallback, and use Calamares as the public
graphical ISO path once the runtime package is present in the ISO build
environment.

Until then, SevenOS should be tested as the SevenOS system layer:

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
./install.sh base --dry-run
./install.sh base --yes
seven phase-gate
```

## Minimum TUI Scope

- disk selection
- partition confirmation
- LUKS option
- filesystem selection
- bootloader selection
- timezone, locale, and keymap
- swap strategy
- base system install
- bootloader setup
- user creation
- profile selection
- post-install SevenOS bootstrap
