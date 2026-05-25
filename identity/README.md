# SevenOS Identity

SevenOS uses a futuristic premium visual identity for an intelligent Linux
ecosystem: fluid, secure, immersive and adaptive.

The broader product direction lives in:

- `identity/CHARTER.md`
- `identity/STYLE.md`
- `identity/LIQUID_GLASS_OS.md`
- `docs/VISION.md`
- `docs/UX_PRINCIPLES.md`
- `docs/VOCABULARY.md`

## Design Direction

SevenOS uses **Design System v2: Beyond the Desktop**.

The goal is not to look like a themed Linux desktop. SevenOS should feel like a
coherent, commercial-grade operating system for creators, developers and
cybersecurity: premium, cinematic, intelligent and fast.

- dark translucent surfaces for immersion and focus
- Hyprland compositor blur as the real glass engine
- blue/violet/cyan glow for identity and interactions
- green cyber signals for security and trusted live state
- contextual AI and profile signals in visible shell surfaces
- outline iconography inspired by Lucide, Phosphor and SF Symbols
- feature-first controls instead of procedural menus
- consistent SF Pro Display, SF Pro Rounded, SF Pro Text and SF Mono roles

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| `seven-blue` | `#4DA3FF` | primary accent |
| `seven-violet` | `#7A5CFF` | glow and identity depth |
| `seven-cyan` | `#00D4FF` | interaction and active state |
| `seven-green` | `#00FFB3` | cyber and trusted live state |
| `deep-void` | `#09090B` | primary background |
| `surface-dark` | `#12131A` | panels and cards |
| `surface-glass` | `rgba(255, 255, 255, 0.06)` | glass surfaces |
| `soft-white` | `#EDEDED` | primary text |
| `muted-gray` | `#8A8F98` | secondary text |

## Naming

Use names that feel native to SevenOS:

- `Deep Void` for the immersive base
- `Seven Blue` for primary interaction
- `Seven Violet` for identity glow
- `Seven Cyan` for active focus and fluid UI
- `Seven Green` for Cyber Mode and trusted state
- `Surface Glass` for translucent cards and widgets

## Current Implementation

- `identity/CHARTER.md` as the official graphic charter
- `identity/SYMBOL.md` as the SevenOS public symbol direction
- `identity/STYLE.md` as the design contract
- `identity/tokens.css` as CSS token source
- `identity/palette.sh` as shell/script palette source
- `scripts/identity.sh` / `seven identity --json` as the machine-readable identity contract
- Hyprland border colors, blur and animation tuning
- Waybar cockpit modules and glass capsules
- Rofi launcher, Spotlight, quick settings and power themes
- Mako notification theme
- Kitty terminal profiles
- Seven Hub, Seven Files, Settings and native shell panels
- SVG logo, wallpaper and mode icon foundations in `identity/assets/`
- the recommended public symbol direction is the **Seven Prism**, with a first
  reference asset at `identity/assets/symbol-seven-prism.svg`

## Components

SevenOS keeps reusable identity components for profile and status surfaces:

- `identity/components/adinkra-status-ok.svg`
- `identity/components/baobab-system-mark.svg`
- `identity/components/griot-doc-mark.svg`
- `identity/components/forge-profile-mark.svg`
- `identity/components/shield-profile-mark.svg`
- `identity/components/kente-divider.svg`

Regional and cultural accent components remain optional layers. The default
SevenOS identity is now the global premium sci-fi glass direction.

## Tagline

Official:

```text
Beyond the Desktop.
```

Alternatives:

- The Intelligent Linux Experience.
- Fluid. Secure. Immersive.
- Next Generation Linux.
- Your Adaptive System.
