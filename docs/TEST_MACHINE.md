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
```

Cyber Lab note:

```bash
./install.sh cyber-lab --name webapp
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
seven windows apps
seven windows vm
```

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

## 8. Validate The Result

```bash
seven status
seven doctor
seven post-install
seven readiness
seven phase-gate
seven ecosystem
./scripts/check.sh
./scripts/ux-check.sh
```

Record readiness history:

```bash
seven readiness --record
```

## 9. What To Inspect Visually

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

## 10. Feedback To Capture

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
