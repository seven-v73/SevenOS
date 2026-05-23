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

Generated or commissioned bitmap wallpapers can be added later.

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
