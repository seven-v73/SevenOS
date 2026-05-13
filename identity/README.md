# SevenOS Identity

SevenOS uses an **African first** visual identity: modern, grounded, technical, and proudly rooted.

This is not an ornament layer. The identity should guide the whole system: colors, naming, rhythm, surfaces, spacing, boot messages, documentation, and future UI.

The broader product direction lives in:

- `docs/VISION.md`
- `docs/UX_PRINCIPLES.md`
- `docs/VOCABULARY.md`

## Design Direction

SevenOS uses a **Sovereign Graphite** design language.

The goal is not to look like a themed Arch rice. The system should feel like an
independent professional OS: calm, precise, luxurious, and culturally rooted
without becoming decorative.

- graphite and ink foundations for serious daily work
- brass and copper for identity, primary actions, and crafted warmth
- malachite for trusted/security states
- cobalt for network, VM, deployment, and technical flow
- oxblood for destructive or urgent moments only
- ivory and raffia for readable, warm text
- architectural pattern, not surface decoration
- glass is used as depth and hierarchy, not as a gimmick
- color is functional: each accent has a job

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| `ink` | `#07090b` | deep system base |
| `graphite` | `#10161d` | primary background |
| `surface` | `#17212b` | elevated surface |
| `panel` | `#1f2b35` | active glass panel |
| `brass` | `#d7b46a` | identity and primary action |
| `copper` | `#c47a3c` | warmth and secondary emphasis |
| `malachite` | `#2e8b6d` | security, health, success |
| `cobalt` | `#2f5d8c` | network, VM, deployment, technical flow |
| `oxblood` | `#7a2e3a` | destructive or urgent state |
| `ivory` | `#ede3d1` | primary text |
| `raffia` | `#bca77d` | secondary text |

## Naming

Use names that feel native to SevenOS:

- `Sovereign Graphite` for the system shell
- `Brass Signal` for primary action and SevenOS identity
- `Copper Warmth` for secondary emphasis and creative warmth
- `Malachite Trust` for Shield, health, and success
- `Cobalt Flow` for networking, VM, deployment, and technical states
- `Oxblood Alert` for destructive or urgent moments

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
