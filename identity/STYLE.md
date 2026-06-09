# SevenOS Design System v2

> Beyond the Desktop.

SevenOS is a Prism Flow Linux operating system identity. It combines Hyprland
fluidity, contextual AI, cybersecurity clarity, creative workflows and
instrument-like native surfaces without copying another desktop OS.

## Source Of Truth

- `identity/CHARTER.md` is the official graphic charter.
- `identity/tokens.css` contains the CSS token contract.
- `identity/palette.sh` contains shell/script palette variables.
- `identity/LIQUID_GLASS_OS.md` defines the OS-level shell behavior.
- UI files should use this vocabulary and avoid undocumented random colors.

## Visual DNA

SevenOS should be perceived as the intelligent next generation Linux experience
for creators, developers and cybersecurity.

Core references:

- Seven Prism as the public symbol and behavior model
- Mini OS facets for contextual identity
- instrument panels for precise system control
- modern SOC dashboards for cybersecurity readability
- Hyprland for animated, adaptive Linux ergonomics
- African-rooted memory and transmission through Baobab, kept structural and
  subtle

## Official Palette

| Token | Hex | Role |
| --- | --- | --- |
| `--prism-ink` | `#070A10` | deep system foundation |
| `--graphite-plane` | `#111722` | primary panels |
| `--mineral-surface` | `#182131` | raised surfaces |
| `--frost-line` | `#A9B7C7` | separators and secondary text |
| `--prism-blue` | `#4C8DFF` | primary interaction and Equinox |
| `--signal-gold` | `#D6A84F` | identity and attention |
| `--baobab-green` | `#2FB87A` | trust and Baobab |
| `--atlas-teal` | `#33B6C4` | exploration and knowledge |
| `--surface-glass` | `rgba(255, 255, 255, 0.06)` | translucent surfaces |
| `--soft-white` | `#EDEDED` | primary text |
| `--muted-gray` | `#8A8F98` | secondary text |

Official gradient:

```css
linear-gradient(135deg, #4DA3FF 0%, #7A5CFF 50%, #00D4FF 100%)
```

## Typography

- Interface principale: Inter or Noto Sans for shell chrome, titles and controls.
- Texte normal: Noto Sans for body copy, lists and settings descriptions.
- Terminal / cyber: JetBrains Mono.
- Language coverage: Noto family.

Rules:

- Avoid weights above 500 in production UI CSS.
- Section labels use small mono or rounded text with restrained tracking.
- Body text stays readable, never decorative.

## Surfaces

SevenOS surfaces are precise, layered, stateful and minimal:

- Base: `--prism-ink`
- Panel: `--graphite-plane`
- Card: `--surface-glass` + `--glass-border`
- Focus: Prism edge, Signal Gold attention or profile facet accent
- Cyber: `--cyber-void`, `--surface-cyber`, `--seven-green`

Production shell CSS does not rely on web-only `backdrop-filter`; Hyprland blur
is the blur engine. Production UI also avoids decorative `box-shadow`; glow is
expressed through text shadow, borders and translucent gradients.

## Radius Scale

| Element | Radius |
| --- | --- |
| Tiny controls | 6px |
| Buttons and inputs | 8px |
| Panels and cards | 10px |
| Dialogs and sheets | 14px |
| Prism Passage overlays | 18px |

## Motion

- Hover: 120ms
- Fade: 180ms
- Window opening: 220ms
- Workspace transition: 280ms
- Spotlight: 300ms

Animate opacity and transform first. Motion should feel premium, slow enough to
read, and never like gaming RGB.

## Waybar

Waybar is the SevenOS cockpit:

- left: SevenOS logo and workspaces
- center: Spotlight, media and SevenAI
- right: battery, network, audio, Bluetooth, weather, VPN, time and monitoring

Every module should be an independent glass capsule with outline icons and
subtle blue/violet/cyan glow.

## Cyber Mode

Cyber Mode uses deep black-green surfaces, SF Mono / JetBrains Mono, live
network/security signals and SOC-like density without clutter.

## Absolute Rules

- No generic Linux bar look for primary shell surfaces.
- No macOS clone language for public SevenOS surfaces.
- No visually heavy black-on-black panels without glass depth.
- No aggressive rainbow/RGB effects.
- No cartoon icons.
- No `font-weight` 600, 700, 800 or 900 in UI CSS.
- No decorative `box-shadow` in production shell CSS.
- No production `backdrop-filter` in Linux shell CSS.
- No emoji in UI labels unless it is a deliberate icon fallback.

## PR Checklist

- Colors use `identity/tokens.css` or this charter.
- Typography follows Inter/Noto/JetBrains roles.
- Surfaces are precise, stateful and token-driven.
- Interactions expose features directly, not procedural menus.
- Motion uses calm fade, slide or subtle scale.
- Cyber surfaces use green/cyan data clarity without visual noise.
