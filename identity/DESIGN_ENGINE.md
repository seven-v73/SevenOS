# Seven Design Engine

Seven Design Engine is the visual synchronization contract for SevenOS.

It uses Catppuccin-inspired palettes as a foundation, then adapts them into
SevenOS product modes:

- **Seven Mocha**: dark, cinematic, soft contrast, glass depth.
- **Seven Latte**: light, clear, productive, low-friction.

Catppuccin icons are treated as an optional enhancement, not a required system
dependency. When a compatible Catppuccin icon theme is installed, SevenOS uses
it automatically. When it is not installed, SevenOS falls back to Papirus or
Papirus-Dark so a fresh install remains coherent and reliable.

Runtime status:

```sh
seven identity design
seven identity design --json
```

Apply modes:

```sh
./install.sh theme dark
./install.sh theme light
```

The engine covers Waybar, Spotlight, Hub, Dock, Files, Settings,
notifications, Hyprlock, terminal and Seven AI surfaces.

Native SevenOS app marks live in `identity/icons/manifest.json` and install
into `hicolor/scalable/apps`. This keeps the main system icon theme open:
Catppuccin can skin the whole desktop when available, while SevenOS apps keep
recognizable product icons everywhere.
