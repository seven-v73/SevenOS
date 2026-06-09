# Seven Design Engine

Seven Design Engine is the visual synchronization contract for SevenOS Prism
Flow.

It uses SevenOS-owned Prism Mineral palettes as the foundation, with third-party
themes only as optional compatibility layers.

- **Prism Dark**: mineral dark, precise, contextual and restrained.
- **Prism Light**: clear, spacious, low-friction and productive.

Catppuccin icons are treated as an optional compatibility enhancement, not a
SevenOS identity dependency. When a compatible theme is installed, SevenOS can
use it. Otherwise SevenOS falls back to Papirus/Papirus-Dark and keeps its own
app marks.

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

The engine covers Prism Bar, Context Rail, Spotlight, Hub, Files, Settings,
notifications, Hyprlock, terminal and SevenAI surfaces.

Native SevenOS app marks live in `identity/icons/manifest.json` and install
into `hicolor/scalable/apps`. This keeps the main system icon theme open while
SevenOS apps keep recognizable product icons everywhere.
