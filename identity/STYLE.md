# SevenOS Design System v1

> Sovereign by design.

SevenOS is an afro-futurist, premium, liquid glass operating system identity.
The interface must feel sovereign, fluid and grounded: refined like a premium
desktop, but with a visual language owned by SevenOS.

## Philosophy

- Sovereign: every element expresses control and clarity, not decoration.
- Fluid: surfaces breathe through spacing, opacity and soft transitions.
- Grounded: African identity is structural through rhythm, geometry and color.

## Source Of Truth

- `identity/tokens.css` contains UI CSS variables.
- `identity/palette.sh` contains shell/script palette variables.
- `identity/patterns/` contains low-opacity geometric motifs.
- UI files should reference this vocabulary and avoid random hex colors.

## Palette

| Token | Hex | Role |
| --- | --- | --- |
| `--ebene` | `#efe3cf` | warm glass canvas |
| `--surface-0` | `#f6ead8` | page background |
| `--surface-1` | `#fbf5ea` | glass cards and panels |
| `--surface-2` | `#ead9bd` | raised warm glass |
| `--surface-3` | `#d8bd91` | focused popovers |
| `--gold` | `#c8a96e` | primary action |
| `--gold-bright` | `#e2c07a` | hover and active |
| `--gold-dim` | `#8a7048` | borders and details |
| `--clay` | `#c4673a` | warning and urgency |
| `--baobab` | `#4a8c5c` | success and health |
| `--baobab-bright` | `#5aad72` | live success |
| `--indigo` | `#5b7fa6` | info and secondary states |
| `--indigo-bright` | `#7ba3cf` | info text and icons |
| `--text-1` | `#2a1f12` | primary text |
| `--text-2` | `#5c4d3a` | secondary text |
| `--text-3` | `#827158` | tertiary text |
| `--text-4` | `#aa9673` | disabled text |

## Typography

- Display: Cormorant Garamond for expressive hero/title moments only.
- Interface: DM Sans or system UI for navigation, cards, labels and body.
- Mono: JetBrains Mono for CLI, code, technical badges and status values.

Rules:

- Avoid weights above 500 in UI surfaces.
- Section labels use 10px, uppercase, letter spacing and `--text-3`.
- Do not uppercase body text or headings.

## Surfaces

SevenOS uses a light liquid glass foundation. The default target is
`Sovereign Glass`: readable in daylight, elegant at night, and free from
black-on-black desktop surfaces. Liquid glass is simulated with translucent
surfaces, warm borders and soft opacity. Do not rely on production
`backdrop-filter` blur for core Linux surfaces.

- Base: `--surface-1` + `--glass-border`
- Floating: `--glass` + `--glass-border`
- Focus: `--surface-3` + `--gold-dim`
- Action: `--gold-pale` + `--gold-dim`

Avoid decorative shadows. Elevation should come from surface tone and border.

## Motion

- Animate only `transform` and `opacity`.
- Use 120ms for micro interactions, 200ms for standard interactions, 350ms for panel entry.
- Respect `prefers-reduced-motion`.

## African Identity

African identity is expressed through rhythm, geometry and palette, not visual
collage. Kente-inspired separators and geometric motifs must remain subtle.

Background motif opacity: 3-8%.
Decorative motif opacity: 15-30%.
Functional icon opacity: 60-100%.

## Absolute Rules

- No black app surfaces for interactive lists, launchers or control panels.
- White is allowed only as a glass surface with warm borders and dark text.
- No generic blue/green system palette.
- No rainbow, purple/pink or neon cyberpunk gradients.
- No `font-weight` 600, 700, 800 or 900 in UI CSS.
- No colored `box-shadow`.
- No `backdrop-filter` in production UI.
- No `border-radius` above 30px except circles.
- No emoji in UI labels.

## PR Checklist

- Colors use tokens or documented SevenOS palette values.
- Typography follows Display / Interface / Mono roles.
- App tiles, panels and launchers must be light, readable and glass-forward.
- Child radius is smaller than parent radius.
- Animations use transform and opacity only.
- `prefers-reduced-motion` is present for web UI.
- Motifs are low-opacity when decorative.
- Icons remain outline-style.
