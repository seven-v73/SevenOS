# Migrating From ML4W To SevenOS

SevenOS and ML4W both configure the same desktop layer:

- `~/.config/hypr`
- `~/.config/waybar`
- `~/.config/rofi`
- `~/.config/kitty`
- notification, GTK, Qt and autostart settings

That is why SevenOS appears to take over the ML4W desktop after applying the
theme or daily-driver path. SevenOS is not replacing Arch; it is replacing the
active Hyprland user configuration.

## Recommended Path

First inspect what still looks ML4W-owned:

```bash
seven migrate-ml4w plan
```

Back it up:

```bash
seven migrate-ml4w backup
```

Switch fully to SevenOS:

```bash
seven migrate-ml4w switch
```

The switch command does not permanently delete your old config. It quarantines
detected ML4W paths under:

```text
~/.local/share/sevenos/migrations/ml4w-<timestamp>/
```

Then it reapplies:

- SevenOS Hyprland config
- Waybar
- Rofi
- Kitty
- Mako
- GTK/Qt theme hints
- wallpaper service
- SevenOS session services

## After Reboot

Choose the `SevenOS` session in your display manager if it is available, then:

```bash
seven session status
seven primary
seven-wallpaper status
```

## Manual Cleanup

If you prefer doing it manually, back up first:

```bash
mkdir -p ~/.local/share/sevenos/migrations/manual-ml4w
cp -a ~/.config/ml4w ~/.local/share/sevenos/migrations/manual-ml4w/ 2>/dev/null || true
cp -a ~/.config/hypr ~/.local/share/sevenos/migrations/manual-ml4w/ 2>/dev/null || true
cp -a ~/.config/waybar ~/.local/share/sevenos/migrations/manual-ml4w/ 2>/dev/null || true
cp -a ~/.config/rofi ~/.local/share/sevenos/migrations/manual-ml4w/ 2>/dev/null || true
```

Then remove ML4W-specific folders and reapply SevenOS:

```bash
rm -rf ~/.config/ml4w ~/.local/share/ml4w ~/.cache/ml4w ~/.ml4w
./install.sh theme
seven session restart
```

Prefer `seven migrate-ml4w switch` because it keeps a timestamped quarantine
instead of deleting active files immediately.
