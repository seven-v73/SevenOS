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
- `identity/LIQUID_GLASS_OS.md` defines the OS-level liquid glass direction.
- UI files should reference this vocabulary and avoid random hex colors.

## Palette

| Token | Hex | Role |
| --- | --- | --- |
| `--ebene` | `#eef4f8` | frosted glass canvas |
| `--surface-0` | `#f6fbfe` | page background |
| `--surface-1` | `#ffffffd9` | glass cards and panels |
| `--surface-2` | `#edf5f9cc` | raised glass |
| `--surface-3` | `#dbe9efc2` | focused popovers |
| `--gold` | `#b89a62` | cultural micro-accent only |
| `--gold-bright` | `#cbb37a` | subtle warm highlight |
| `--gold-dim` | `#8f7a53` | fine cultural detail |
| `--clay` | `#a95738` | warning and urgency |
| `--baobab` | `#3f8b65` | success and health |
| `--baobab-bright` | `#4ba979` | live success |
| `--indigo` | `#567f9d` | primary interaction and secondary states |
| `--indigo-bright` | `#6f9dbc` | focus rings and icons |
| `--text-1` | `#17232b` | primary text |
| `--text-2` | `#4d606a` | secondary text |
| `--text-3` | `#7c8c94` | tertiary text |
| `--text-4` | `#a8b4ba` | disabled text |

## Typography

- Interface principale: SF Pro Display for navigation chrome, primary titles and large control labels.
- Texte normal: SF Pro Text for body copy, lists, cards and secondary labels.
- Terminal: SF Mono for terminal surfaces, code previews and command output.
- Dashboard cyber: JetBrains Mono or SF Mono for security metrics, badges and audit status.
- Branding SevenOS: SF Pro Rounded with SF Pro Display fallback for marks and identity lockups.

Rules:

- Avoid weights above 500 in UI surfaces.
- Section labels use 10px, uppercase, letter spacing and `--text-3`.
- Do not uppercase body text or headings.

## Surfaces

SevenOS uses a transparent minimal foundation with frosted liquid glass accents.
The default target is `Sovereign Frost`: readable in daylight, elegant at
night, and free from both black-on-black desktop surfaces and dominant
yellow/orange chrome. The ratio is intentional: about 70% transparent minimal
UI, 30% glass premium on active windows, Hub, notifications, overlays, control
surfaces and widgets. Liquid glass is simulated with translucent surfaces,
white glass borders and soft opacity. Do not rely on production `backdrop-filter`
blur for core Linux surfaces.

- Base: `--surface-1` + `--glass-border`
- Floating: `--glass` + `--glass-border`
- Focus: `--glass-3` + `--indigo-bright`
- Action: `--indigo-pale` + `--indigo`

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
