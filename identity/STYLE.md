# SevenOS Design System v2

> Beyond the Desktop.

SevenOS is a futuristic, premium and immersive Linux operating system identity.
It combines Hyprland fluidity, contextual AI, cybersecurity clarity, creative
workflows and cinematic glass surfaces.

## Source Of Truth

- `identity/CHARTER.md` is the official graphic charter.
- `identity/tokens.css` contains the CSS token contract.
- `identity/palette.sh` contains shell/script palette variables.
- `identity/LIQUID_GLASS_OS.md` defines the OS-level shell behavior.
- UI files should use this vocabulary and avoid undocumented random colors.

## Visual DNA

SevenOS should be perceived as the intelligent next generation Linux experience
for creators, developers and cybersecurity.

Core influences:

- Apple VisionOS and macOS for premium OS polish
- realistic sci-fi interfaces for depth and atmosphere
- modern SOC dashboards for cybersecurity readability
- Arc/Nothing-style minimalism for calm, focused surfaces
- Hyprland for transparent, animated and adaptive Linux ergonomics

## Official Palette

| Token | Hex | Role |
| --- | --- | --- |
| `--seven-blue` | `#4DA3FF` | primary accent |
| `--seven-violet` | `#7A5CFF` | identity glow and depth |
| `--seven-cyan` | `#00D4FF` | interactions and active states |
| `--seven-green` | `#00FFB3` | cyber mode and trusted live signals |
| `--deep-void` | `#09090B` | primary background |
| `--surface-dark` | `#12131A` | cards and panels |
| `--surface-glass` | `rgba(255, 255, 255, 0.06)` | translucent surfaces |
| `--soft-white` | `#EDEDED` | primary text |
| `--muted-gray` | `#8A8F98` | secondary text |

Official gradient:

```css
linear-gradient(135deg, #4DA3FF 0%, #7A5CFF 50%, #00D4FF 100%)
```

## Typography

- Interface principale: SF Pro Display for shell chrome, titles and controls.
- UI secondaire: SF Pro Rounded for brand, badges and friendly controls.
- Texte normal: SF Pro Text for body copy, lists and settings descriptions.
- Terminal / cyber: SF Mono with JetBrains Mono fallback.

Rules:

- Avoid weights above 500 in production UI CSS.
- Section labels use small mono or rounded text with restrained tracking.
- Body text stays readable, never decorative.

## Surfaces

SevenOS surfaces are floating, translucent, luminous and minimal:

- Base: `--deep-void`
- Panel: `--surface-1`
- Card: `--surface-glass` + `--glass-border`
- Focus: gradient border, cyan/blue text glow and alpha overlays
- Cyber: `--cyber-void`, `--surface-cyber`, `--seven-green`

Production shell CSS does not rely on web-only `backdrop-filter`; Hyprland blur
is the blur engine. Production UI also avoids decorative `box-shadow`; glow is
expressed through text shadow, borders and translucent gradients.

## Radius Scale

| Element | Radius |
| --- | --- |
| Buttons | 14px |
| Widgets | 18px |
| Cards | 22px |
| Waybar | 24px |
| Windows | 28px |

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
- No visually heavy black-on-black panels without glass depth.
- No aggressive rainbow/RGB effects.
- No cartoon icons.
- No `font-weight` 600, 700, 800 or 900 in UI CSS.
- No decorative `box-shadow` in production shell CSS.
- No production `backdrop-filter` in Linux shell CSS.
- No emoji in UI labels unless it is a deliberate icon fallback.

## PR Checklist

- Colors use `identity/tokens.css` or this charter.
- Typography follows Display / Rounded / Text / Mono roles.
- Surfaces are floating, translucent and rounded.
- Interactions expose features directly, not procedural menus.
- Motion uses calm fade, slide or subtle scale.
- Cyber surfaces use green/cyan data clarity without visual noise.
