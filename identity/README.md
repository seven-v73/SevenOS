# SevenOS Identity

SevenOS uses an **African first** visual identity: modern, grounded, technical, and proudly rooted.

This is not an ornament layer. The identity should guide the whole system: colors, naming, rhythm, surfaces, spacing, boot messages, documentation, and future UI.

## Design Direction

- dark graphite base for focus and low eye strain
- gold accents for action and attention
- red clay and earth tones for warmth
- deep green for continuity, growth, and system health
- liquid glass surfaces: translucent, calm, rounded, and readable
- subtle line patterns inspired by African textile rhythm and carved geometry
- minimal surfaces, no heavy decoration, no generic neon sci-fi look

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| `obsidian` | `#0b0b0a` | primary background |
| `charcoal` | `#15130f` | elevated surfaces |
| `soil` | `#24180f` | selected surface |
| `clay` | `#9b4a2f` | warm secondary accent |
| `gold` | `#d6a84f` | primary accent |
| `sand` | `#e8dcc3` | primary text |
| `raffia` | `#b7a98a` | muted text |
| `baobab` | `#456b4f` | success and system health |
| `indigo` | `#26344f` | cool contrast |

## Naming

Use names that feel native to SevenOS:

- `Ancestral Gold` for primary action
- `Clay Signal` for warnings and secondary emphasis
- `Baobab Green` for success and stable system state
- `Obsidian Shell` for dark backgrounds
- `Raffia Text` for muted information

## UI Rules

- Keep layouts calm and functional.
- Use pattern as a fine border or background texture, never as visual noise.
- Do not use generic purple cyberpunk gradients.
- Do not use flags as the visual system. Country colors can appear as subtle accents only when a context specifically calls for it.
- Do not reduce African identity to random motifs. The style should feel intentional, architectural, and useful.
- Prefer high contrast and readable text over decorative complexity.
- `ttf-jetbrains-mono-nerd` is required for the complete Waybar icon experience.

## Current Implementation

- Hyprland border colors and behavior
- Waybar colors and workspace states
- Rofi launcher theme
- SevenOS live ISO welcome message
- SVG logo, wallpaper, and mode icon foundations in `identity/assets/`
- documentation language and branding direction

## Regional Accent Packs

Regional accent packs are planned as optional layers, not as the default visual language.

Possible packs:

- Pan-African
- West Africa
- North Africa
- Central Africa
- East Africa
- Southern Africa

These packs should use subtle color and pattern accents. They should not turn the interface into a collage of flags.
