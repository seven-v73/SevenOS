# SevenOS Test Machine Guide

This guide is for installing SevenOS on a disposable Arch or Arch-based test
machine after pushing the repository to GitHub.

SevenOS is still a post-install ecosystem layer, not a final disk installer.
Use a test machine or VM first.

## 1. Prepare The Machine

Minimum:

- Arch Linux or Arch-based system
- internet connection
- user with `sudo`
- 8 GB RAM, 16 GB recommended
- virtualization enabled for Windows Mode and VM tests

Recommended first check:

```bash
sudo pacman -Syu
sudo pacman -S --needed git sudo pacman-contrib
```

## 2. Clone SevenOS

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
chmod +x install.sh bootstrap.sh profiles/*.sh scripts/*.sh bin/* server/*.sh seven-hub/bin/*
```

If the repository already exists on the test machine:

```bash
cd ~/SevenOS
git status --short
git pull --ff-only
```

If `git pull` says everything is up to date but the UI still looks old, you
probably updated the repository without reapplying the installed user configs.
Run the UX reapply step below after pulling.

## 3. Preview Before Installing

Important:

Do not run the SevenOS installer with `sudo`.

Correct:

```bash
./install.sh base --yes
```

Wrong:

```bash
sudo ./install.sh base --yes
```

The scripts call `sudo` internally only for system operations. Running the whole
installer as root installs user configs into `/root`, which leaves your normal
Hyprland session unchanged.

```bash
./scripts/check.sh
./install.sh base --dry-run
./install.sh theme --dry-run
./install.sh branding --dry-run
seven readiness || ./scripts/readiness.sh
./bin/seven daily --json | python -m json.tool
./bin/seven phase-gate --json | python -m json.tool
./bin/seven stack --json | python -m json.tool
./bin/seven shell plan --json | python -m json.tool
```

If `seven` is not installed yet, use local paths:

```bash
./bin/seven --dry-run ecosystem
./bin/seven --dry-run repair
```

## 4. Install The Daily Desktop Layer

```bash
./install.sh base --yes
./install.sh post-install
```

This installs:

- Hyprland, Waybar, Rofi, Kitty
- Mako, swaylock, swayidle, Hyprpaper
- SevenOS CLI tools
- Seven Hub
- branding
- desktop theme
- terminal country signal

Log out and back in after install, especially if group membership changed.
If `seven` is not found immediately after install:

```bash
export PATH="$HOME/.local/bin:$PATH"
hash -r
./install.sh cli
seven post-install
```

The CLI installer creates wrappers in `~/.local/bin` and, when sudo is
available, `/usr/local/bin`. The wrappers keep `SEVENOS_ROOT` pointed at this
repository, so `seven` can find the rest of the SevenOS modules after reboot.

Check the command path with:

```bash
command -v seven
head -n 3 "$(command -v seven)"
```

If Hyprland still looks like the default/basic config:

```bash
seven repair ux --apply
hyprctl reload
```

If it still does not change, log out and back into Hyprland.

If some applications are dark while others are white:

```bash
./install.sh base --yes
./install.sh theme
hyprctl reload
```

SevenOS applies matching Rofi, GTK, Qt, Kitty, Mako and Waybar settings. Some
already-running GTK/Qt applications may need to be closed and opened again.

Expected desktop controls after the UX repair:

```text
Super+Space  SevenOS Control Center
Super+H      Seven Hub command palette
Super+A      Apps launcher
Super+D      Apps launcher
Super+E      Seven Files
Super+Shift+E Seven Files places menu
Super+/      SevenOS help
Super+Enter  Terminal
Super+Shift+P Power menu
```

Waybar should expose visible `SevenOS`, `Apps`, `Files`, `Hub`, `Help`, and `Power`
buttons. If the bar is missing, run:

```bash
pkill waybar || true
waybar &
```

If the wallpaper does not change after a theme update:

```bash
seven-wallpaper status
seven-wallpaper refresh
```

If that reports a missing SVG renderer:

```bash
sudo pacman -S --needed librsvg
seven-wallpaper refresh
```

If the paths are correct but the old image remains, force Hyprpaper to rebuild
its in-memory cache:

```bash
pkill hyprpaper || true
seven-wallpaper refresh
cat ~/.config/hypr/hyprpaper.conf
```

If you accidentally installed with `sudo ./install.sh ...`, recover as your
normal user:

```bash
cd ~/SevenOS
./install.sh cli
./install.sh hub
./install.sh theme
./install.sh branding
./install.sh post-install
```

Then log out and back into Hyprland.

## 5. Apply Or Reapply UX Only

```bash
./install.sh cli
./install.sh branding
./install.sh theme
./install.sh hub
./install.sh post-install
```

After pulling updates from GitHub, this is the safest refresh sequence for the
test machine:

```bash
git pull --ff-only
./install.sh cli
./install.sh hub
./install.sh theme
./install.sh branding
seven post-install
hyprctl reload
```

For the current daily-driver consolidation push, run the gate before applying
heavy packages:

```bash
seven daily
seven daily --json | python -m json.tool
```

If this is a disposable test machine and you want to exercise the full path:

```bash
sudo -v
seven improve daily --apply --yes
seven daily
seven readiness
```

On a real primary machine, keep the first run conservative:

```bash
seven daily
seven improve security
seven improve compatibility
seven improve target
```

Then apply only the parts you are ready to install.

Then check the product contracts:

```bash
seven daily --json | python -m json.tool
seven phase-gate --json | python -m json.tool
seven stack --json | python -m json.tool
seven shell status --json | python -m json.tool
seven shell plan --json | python -m json.tool
```

Open the main dashboard:

```bash
seven hub
```

If a browser does not open, start it explicitly:

```bash
seven-control-center open
```

If the graphical dashboard still does not appear, use the keyboard command
palette fallback:

```bash
seven-hub
seven-hub doctor
```

The legacy keyboard command palette is still available:

```bash
seven-hub
```

Seven Shell is currently a planned AGS/TypeScript layer, not the active shell.
The active fallback remains Waybar + GTK shell panels + Rofi. You can inspect
the planned migration with:

```bash
seven shell
seven shell preview
seven shell doctor
```

If you want to prepare the AGS foundation packages:

```bash
./install.sh shell-ags --yes
```

AGS itself may still require the chosen AUR/upstream workflow; SevenOS keeps it
explicit until the repository policy is settled.

Open the file manager:

```bash
seven files
seven files menu
seven-files downloads
```

SevenOS uses Nautilus with GVfs integration by default so local files,
removable drives, phone mounts, network shares, trash, recent files, previews,
and archives feel like part of the desktop instead of separate Linux chores.

Open a new Kitty terminal to see the SevenOS terminal country signal.

If country names appear but the flag is missing or rendered as empty boxes:

```bash
sudo pacman -S --needed noto-fonts-emoji
./install.sh theme
fc-cache -f
kitty
```

Disable it temporarily with:

```bash
export SEVENOS_TERMINAL_COUNTRY=0
```

## 6. Install Optional Profiles

Development:

```bash
./install.sh dev --yes
```

Cybersecurity core and sandbox:

```bash
./install.sh cybersecurity core --yes
./install.sh cybersecurity sandbox --yes
./install.sh cyber-audit
seven shield bootstrap
seven shield dashboard
seven shield dashboard --json | python -m json.tool
seven shield mode
seven shield mode --json | python -m json.tool
seven-daemon cyberspace --json | python -m json.tool
seven-daemon cyberspace-plan --json | python -m json.tool
seven shield workspaces --json | python -m json.tool
seven shield layout recon --json | python -m json.tool
seven shield hud
seven shield workspace --json | python -m json.tool
seven shield tools
seven shield scope
seven shield scope --json | python -m json.tool
seven shield report
```

CyberSpace shortcuts after reapplying the theme:

- `Super+C` opens the Shield CyberSpace map.
- `Super+Ctrl+C` opens the Cyber HUD.
- `seven shield context recon` switches to the Recon workspace.
- `seven shield context web` switches to the Web Pentest workspace.

Cyber Lab note:

```bash
seven shield lab --preset web
```

opens an isolated Firejail shell. Your prompt may show `sevenos-webapp`.
That is normal. In this isolated home, some commands from your normal
`~/.local/bin` may not be available.

Leave the lab with:

```bash
exit
```

Then continue from the normal SevenOS shell:

```bash
cd ~/SevenOS
seven status
seven readiness
```

Creative tools:

```bash
./install.sh creation --yes
```

Windows compatibility:

```bash
./install.sh windows --yes
./install.sh vm-check
./install.sh vm-network
seven windows guide
seven windows status
seven windows catalog
seven windows resolve photoshop --json | python -m json.tool
SEVENOS_DRY_RUN=1 seven run photoshop
SEVENOS_DRY_RUN=1 seven windows run /path/to/setup.exe
seven windows apps
seven windows vm
```

Windows compatibility should be tested app-first. A Windows ISO is only needed
when the resolver falls back to `vm` for a heavy or driver-sensitive workflow.

Server/deployment:

```bash
./install.sh server --yes
seven server status
seven deploy .
```

## 7. Repair And Improve

Dry-run repair plan:

```bash
seven repair
seven repair security
seven repair deployment
```

Apply a targeted repair:

```bash
sudo -v
seven repair security --apply --yes
```

Improve by OS criteria:

```bash
seven improve security
seven improve compatibility
seven improve deployment
```

## 8. B3 Consolidation Path

Before trying to build an ISO, use B3 as the single consolidation gate. It
orders the real blockers: trust, backend, profiles, shell and installer.

Inspect the current gate:

```bash
seven b3 status
seven b3 plan
seven phase-gate
```

Preview the next fixes without changing the machine:

```bash
seven b3 apply --limit 8
seven b3 apply --phase trust --limit 4
seven b3 apply --phase profiles --limit 4
```

Apply only after opening a sudo session:

```bash
sudo -v
seven b3 apply --phase trust --apply --yes --limit 4
seven b3 apply --phase backend --apply --yes --limit 4
seven b3 apply --phase profiles --apply --yes --limit 6
seven b3 apply --phase shell --apply --yes --limit 4
seven b3 apply --phase installer --apply --yes --limit 4
```

Then validate again:

```bash
seven shield status
seven profile bootstrap all
seven profile plan
seven server status
seven shell status
seven installer status
seven b3 status
seven readiness
```

Seven Core runtime checks:

```bash
seven core health --json | python -m json.tool
seven core profiles --json | python -m json.tool
seven-daemon shield --json | python -m json.tool
seven-daemon shield-plan --json | python -m json.tool
seven-daemon server --json | python -m json.tool
seven-daemon server-plan --json | python -m json.tool
seven-daemon windows --json | python -m json.tool
seven-daemon windows-plan --json | python -m json.tool
seven-daemon installer --json | python -m json.tool
seven-daemon installer-plan --json | python -m json.tool
seven-daemon packages --json | python -m json.tool
seven-daemon packages-plan --json | python -m json.tool
seven-daemon insights --json | python -m json.tool
seven-daemon phase-gate --json | python -m json.tool
seven core observe --json | python -m json.tool
seven events --json --limit 3 | python -m json.tool
```

`seven core observe` records one semantic context observation through
SevenDaemon into SevenBus. It is the current bridge toward a future continuous
runtime observer.

To enable the continuous observer for the test session:

```bash
seven core install-service
seven core start
seven core start-observer
systemctl --user status seven-context-observer.service
```

The observer is local-only. It records semantic context events every 60 seconds
through SevenBus so Seven Hub and Seven Shell can evolve toward live context
state instead of one-off probes.

Profile workspace bootstrap checks:

```bash
seven profile bootstrap all
seven profile current --json | python -m json.tool
seven profile open
```

Each profile should now contain `.sevenos/profile.json`,
`.sevenos/CHECKLIST.md` and `.sevenos/launch.sh` inside its workspace. This
turns Forge, Shield, Studio, Windows, Horizon and Baobab into visible working
spaces before the full profile package install is complete.

## 9. Validate The Result

```bash
seven status
seven doctor
seven post-install
seven readiness
seven daily
seven phase-gate
seven ecosystem
./scripts/check.sh
./scripts/ux-check.sh
```

Record readiness history:

```bash
seven readiness --record
seven daily --json | python -m json.tool
```

For a primary PC, do not treat the test as complete until `seven daily` reports
no `BLOCK` gates. The current consolidation command is:

```bash
sudo -v
seven improve daily --apply --yes
seven daily
```

## 10. What To Inspect Visually

- Hyprland window borders and animation feel
- Waybar profile/security/status modules
- Rofi launcher and Seven Hub categories
- Kitty theme, tabs, opacity and country signal
- Mako notifications
- Fastfetch branding
- Seven Hub terminal fallback
- Cyber Lab presets
- Windows Mode status
- `seven deploy .` generated plan

## 11. Feedback To Capture

For each test machine, record:

- hardware model
- GPU and driver
- RAM
- installed profiles
- readiness score
- phase-gate result
- broken packages
- visual issues
- commands that felt confusing

Useful command:

```bash
seven readiness --json
```
