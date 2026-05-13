# SevenOS Design QA Checklist

Use this checklist before shipping visual changes.

## Identity

- African first, not generic cyberpunk.
- Cultural references are structural, subtle, and respectful.
- Flags are not used as the default design system.
- Palette follows Royal Kente: void, midnight, palace, Kente gold, sunfire, hibiscus, Nile cyan, emerald, ivory, and raffia.

## Readability

- Primary text uses `ivory` or another high-contrast color.
- Kente gold, Nile cyan, hibiscus, sunfire, and emerald are used as purposeful accents by function.
- Small Waybar text remains readable at 13px.
- Buttons and labels do not overflow their containers.

## Premium Feel

- Surfaces are dimensional, translucent, luminous, and purposeful.
- Corners stay consistent.
- Icon weight is consistent across the profile set.
- Wallpaper does not fight app windows or status bars.
- Terminal theme feels premium while keeping command output highly readable.
- Terminal cultural signals are concise, random, and easy to disable.

## Technical Checks

```bash
jq empty hyprland/waybar/config.jsonc
rofi -no-config -theme hyprland/rofi/sevenos.rasi -dump-theme
rofi -no-config -theme hyprland/rofi/power.rasi -dump-theme
kitty +runpy 'from kitty.config import load_config; load_config("hyprland/kitty/kitty.conf")'
bin/seven-country plain
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
- Kitty uses SevenOS colors, readable contrast, calm opacity, and ergonomic tabs.
- Country facts appear on terminal open/close without taking over the prompt.
