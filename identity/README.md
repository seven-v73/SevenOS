# SevenOS Identity

SevenOS uses an **African first** visual identity: modern, grounded, technical, and proudly rooted.

This is not an ornament layer. The identity should guide the whole system: colors, naming, rhythm, surfaces, spacing, boot messages, documentation, and future UI.

The broader product direction lives in:

- `docs/VISION.md`
- `docs/UX_PRINCIPLES.md`
- `docs/VOCABULARY.md`

## Design Direction

SevenOS uses **Design System v1: Sovereign by design**.

The goal is not to look like a themed Arch rice. The system should feel like an
independent professional OS: calm, precise, luxurious, and culturally rooted
without becoming decorative.

- adaptive graphite surfaces for serious daily work without black-on-black fatigue
- ancestral gold for identity and primary action
- clay for warning, urgency and danger
- baobab for trusted/security states
- indigo for network, VM, deployment, and technical flow
- warm text colors for readable day/night dark UI
- architectural pattern, not surface decoration
- glass is used as depth and hierarchy, not as a gimmick
- color is functional: each accent has a job

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| `ebene` | `#141319` | zero surface |
| `surface-0` | `#191821` | page background |
| `surface-1` | `#22212b` | cards and panels |
| `surface-2` | `#2d2b38` | raised cards |
| `surface-3` | `#383645` | modals and popovers |
| `gold` | `#c8a96e` | identity and primary action |
| `gold-bright` | `#e2c07a` | hover and active states |
| `clay` | `#c4673a` | warning, danger and urgency |
| `baobab` | `#4a8c5c` | security, health, success |
| `indigo` | `#5b7fa6` | network, VM, deployment, technical flow |
| `text-1` | `#f0ede6` | primary text |
| `text-2` | `#c7c0b2` | secondary text |

## Naming

Use names that feel native to SevenOS:

- `Ebene Base` for the system shell
- `Ancestral Gold` for primary action and SevenOS identity
- `Clay Signal` for warning and urgency
- `Baobab Trust` for Shield, health, and success
- `Indigo Flow` for networking, VM, deployment, and technical states

## UI Rules

- Keep layouts highly functional, but visually deliberate and premium.
- Use pattern as architectural rhythm, not as wallpaper noise.
- Do not use generic neon cyberpunk gradients or rainbow borders.
- Do not let the wallpaper carry the identity alone.
- Do not use flags as the visual system. Country colors can appear as subtle accents only when a context specifically calls for it.
- Do not reduce African identity to random motifs. The style should feel intentional, architectural, and useful.
- Prefer high contrast and readable text over decorative complexity.
- `ttf-jetbrains-mono-nerd` is required for the complete Waybar icon experience.

## Current Implementation

- Hyprland border colors and behavior
- Hyprland idle lock and power controls
- Waybar colors and workspace states
- Waybar SevenOS profile/security/system indicators
- Rofi launcher theme
- Rofi power theme
- Mako notification theme
- SevenOS live ISO welcome message
- SVG logo, wallpaper, and mode icon foundations in `identity/assets/`
- documentation language and branding direction
- `identity/STYLE.md` as the design contract
- `identity/tokens.css` as CSS token source
- `identity/patterns/` for low-opacity geometric motifs

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
