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
chmod +x install.sh bootstrap.sh profiles/*.sh scripts/*.sh bin/* server/*.sh seven-hub/bin/seven-hub
```

## 3. Preview Before Installing

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

## 5. Apply Or Reapply UX Only

```bash
./install.sh cli
./install.sh branding
./install.sh theme
./install.sh hub
```

Open a new Kitty terminal to see the SevenOS terminal country signal.

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

Creative tools:

```bash
./install.sh creation --yes
```

Windows compatibility:

```bash
./install.sh windows --yes
./install.sh vm-check
./install.sh vm-network
seven windows status
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
