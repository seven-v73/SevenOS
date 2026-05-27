# SevenOS Wallpaper Direction

Future wallpapers should follow the SevenOS Beyond the Desktop identity:

- abstract geometry over literal symbols
- graphite base with brass, copper, malachite, and cobalt accents
- textile rhythm, carved linework, or architectural forms
- no generic stock silhouettes
- no generic neon cyberpunk gradients; color must feel luxurious, cultural, and intentional

Current starter asset:

```text
identity/assets/wallpaper-sevenos.svg
out/design/wallpaper-sevenos.png
```

The generated collection now includes:

- 45 base dynamic SevenOS wallpapers;
- 49 Mini OS wallpapers, grouped as 7 variants for each of Equinox, Baobab,
  Forge, Shield, Studio, Atlas and Pulse;
- light, neutral/balanced and dark tones for every Mini OS family.

The collection is regenerated from:

```bash
python identity/wallpaper/generate-sevenos-wallpapers.py
```

`identity/wallpaper/dynamic/manifest.json` is the source of truth consumed by
`seven-wallpaper collection-list`, Settings and wallpaper rotation.

## Profile Scope

Wallpaper choices are mini-OS scoped. `seven-wallpaper set IMAGE` saves the
custom wallpaper for the active SevenOS profile only:

```text
~/.config/sevenos/profiles/<profile>/wallpaper-state
~/.local/share/sevenos/wallpapers/profiles/<profile>/wallpaper-custom.png
```

`~/.local/share/sevenos/wallpapers/wallpaper-sevenos-active.png` is only the
current Hyprpaper projection. It is replaced when switching profiles, but each
mini OS keeps its own source state.
