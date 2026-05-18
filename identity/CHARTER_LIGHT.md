# SevenOS Light Graphic Charter

> Clarity first.

SevenOS Light Mode is the clear productivity face of SevenOS. Dark Mode is
immersive, cinematic and cyber-aware; Light Mode is calm, precise, spacious and
focused. The system should visually step back so the user's work becomes the
main subject.

## Identity

Light Mode represents:

- clarity
- precision
- productivity
- purity
- calm intelligence
- high readability

It is inspired by modern SaaS interfaces, macOS Light UI, clear VisionOS
surfaces, restrained Material design and contemporary fintech dashboards.

## Philosophy

SevenOS Light should communicate:

- mental clarity
- low visual friction
- strong hierarchy
- clean structure
- generous space
- maximum concentration

Avoid cyberpunk styling, aggressive neon, heavy glow and visual overload. The
signature is quiet, white, precise and professional.

## Official Light Palette

| Token | Color | Role |
| --- | --- | --- |
| Pure White | `#FFFFFF` | primary background |
| Soft Gray | `#F5F7FA` | general surfaces |
| Light Surface | `#EEF1F5` | cards and panels |
| Border Light | `#DDE3EA` | separators |
| Text Primary | `#1C1F26` | primary text |
| Text Secondary | `#6B7280` | secondary text |
| Seven Blue Light | `#2F7BFF` | restrained primary accent |
| Seven Violet Light | `#6A5CFF` | identity accent |
| Seven Cyan Light | `#00B8D9` | interactions |

Official Light gradient:

```css
linear-gradient(135deg, #2F7BFF 0%, #6A5CFF 50%, #00B8D9 100%)
```

## Typography

- Main UI: SF Pro Display
- Content: SF Pro Text
- Terminal and development: SF Mono

Use high readability, moderate contrast, strong hierarchy and spacious text
rhythm. Titles may be semibold; labels stay medium; body text stays regular.

## Light Glass

Light glass should feel like clean paper over glass:

```css
background: rgba(255,255,255,0.7);
border: 1px solid rgba(0,0,0,0.06);
```

Hyprland provides compositor blur. Production Linux shell CSS avoids web-only
`backdrop-filter`; any Light depth is expressed through transparency, borders,
soft gradients and restrained surface contrast.

## Depth

Light Mode uses quiet floating depth. Shadows may be used in app/web surfaces,
but production shell CSS keeps depth portable through borders, alpha gradients
and compositor blur.

## Waybar Light

The Light Waybar is:

- floating
- white translucent
- visually quiet
- grouped into simple system clusters
- focused on fast status reading

Left: SevenOS logo and workspaces.  
Center: Spotlight productivity entry point.  
Right: battery, Wi-Fi, Bluetooth, audio, time and system status.

## Spotlight Light

Spotlight becomes a pure productivity tool:

- translucent white surface
- clear text
- light blue focus edge
- no heavy glow
- quick fade and slight slide

## Motion

Light motion is fast, subtle and natural:

| Action | Duration |
| --- | --- |
| Hover | 100ms |
| Transition | 160ms |
| Opening | 200ms |

Avoid neon, pulsing, spectacle and slow decorative animation.

## Notifications

Notifications use white cards, fine borders, simple icons and discrete slide
motion. They should be readable first, decorative second.

## Terminal Light

Terminal Light uses an off-white background, soft black text and blue accents
for prompts or commands. The goal is maximum readability and low fatigue.

## Wallpaper Light

Official Light wallpapers should use soft abstraction, organic gradients,
natural light, spacious white/blue atmosphere and a clean Apple-like workspace
feeling.

## Signature

SevenOS Light is recognizable by:

- pure white clarity
- discreet Seven Blue accents
- subtle glass
- generous spacing
- quiet professional polish

Dark Mode: future immersion.  
Light Mode: pure productivity.
