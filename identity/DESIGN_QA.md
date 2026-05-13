# SevenOS Design QA Checklist

Use this checklist before shipping visual changes.

## Identity

- African first, not generic cyberpunk.
- Cultural references are structural, subtle, and respectful.
- Flags are not used as the default design system.
- Palette stays close to obsidian, gold, clay, baobab, raffia, sand, and indigo.

## Readability

- Primary text uses `sand` or another high-contrast color.
- `clay` and `baobab` are used mostly as accents, borders, or large elements.
- Small Waybar text remains readable at 13px.
- Buttons and labels do not overflow their containers.

## Premium Feel

- Surfaces are calm, translucent, and purposeful.
- Corners stay consistent.
- Icon weight is consistent across the profile set.
- Wallpaper does not fight app windows or status bars.

## Technical Checks

```bash
jq empty hyprland/waybar/config.jsonc
rofi -no-config -theme hyprland/rofi/sevenos.rasi -dump-theme
rofi -no-config -theme hyprland/rofi/power.rasi -dump-theme
python3 - <<'PY'
from pathlib import Path
from xml.etree import ElementTree as ET
for path in Path("identity/assets").glob("*.svg"):
    ET.parse(path)
    print("OK", path)
PY
./scripts/check.sh
```

## UX Checks

- Seven Hub opens first-level categories before action lists.
- Waybar shows profile and security status without crowding the bar.
- Power actions live in `seven-power`, not behind a misleading icon.
- Cyber Lab presets create predictable private workspaces.
