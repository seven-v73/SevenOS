# SevenOS Graphic Charter

> Beyond the Desktop.

SevenOS is the next generation intelligent Linux experience for creators,
developers and cybersecurity work. Its visual system fuses premium operating
system polish, realistic sci-fi interfaces, contextual AI and modern SOC
dashboard clarity.

This charter defines the default immersive Dark Mode. SevenOS also ships a
parallel clarity-first Light Mode in `identity/CHARTER_LIGHT.md`.

## Positioning

SevenOS should feel like a commercial high-end operating system designed in the
future: fluid, secure, immersive and adaptive.

Core perception:

- intelligent
- fluid
- elegant
- powerful
- modern
- innovative
- premium minimal

## Design Pillars

1. Fluidity: every interaction should feel alive and continuous.
2. Transparency: glass and compositor blur are central to the system identity.
3. Intelligent minimalism: remove procedural clutter and expose useful features.
4. Depth: build interfaces from translucent layers, borders and luminous focus.
5. Contextuality: profile, security and AI state should tune visible actions.

## Official Palette

| Token | Color | Role |
| --- | --- | --- |
| Seven Blue | `#4DA3FF` | primary accent |
| Seven Violet | `#7A5CFF` | glow and identity depth |
| Seven Cyan | `#00D4FF` | interactions and active states |
| Seven Green | `#00FFB3` | cyber mode and trusted live signals |
| Deep Void | `#09090B` | primary background |
| Surface Dark | `#12131A` | cards and panels |
| Surface Glass | `rgba(255,255,255,0.06)` | translucent surfaces |
| Soft White | `#EDEDED` | primary text |
| Muted Gray | `#8A8F98` | secondary text |

Official gradient:

```css
linear-gradient(135deg, #4DA3FF 0%, #7A5CFF 50%, #00D4FF 100%)
```

Official glow intent:

```css
0 0 12px rgba(77,163,255,0.25),
0 0 24px rgba(122,92,255,0.18)
```

Production Linux surfaces express this glow through borders, alpha gradients
and `text-shadow`; Hyprland provides the real blur. Web-only `backdrop-filter`
and decorative `box-shadow` are not used in shipped shell CSS.

## Typography

- Main UI: SF Pro Display
- Secondary UI: SF Pro Rounded
- Terminal and cyber: SF Mono, JetBrains Mono fallback

## Radius Scale

| Element | Radius |
| --- | --- |
| Buttons | 14px |
| Cards | 22px |
| Windows | 28px |
| Widgets | 18px |
| Waybar | 24px |

## Motion

| Interaction | Duration |
| --- | --- |
| Hover | 120ms |
| Window opening | 220ms |
| Workspace transition | 280ms |
| Fade | 180ms |
| Spotlight | 300ms |

Motion should breathe: fade, slide, subtle scaling, luminous focus and calm
workspace motion. Avoid aggressive bounce, gaming RGB effects and noisy motion.

## Waybar

SevenOS Waybar is a floating cockpit:

- left: SevenOS logo and workspaces
- center: Spotlight, media and SevenAI entry points
- right: power, network, audio, Bluetooth, VPN, weather, time and monitoring

Modules live in independent glass capsules with subtle blue/violet/cyan focus.

## Cyber Mode

Cyber Mode shifts the system to:

- background: `#0A0F0D`
- surfaces: `#002B22`
- accent: `#00FFB3`
- activity: `#00E676`

It should feel like a premium SOC cockpit: live data, terminal clarity,
minimal logs, discreet monitoring and no visual noise.

## System Surfaces

Hyprlock, wlogout, notifications, settings, Seven Hub, Seven Files, terminal,
Spotlight, Dock and native profile/security panels all follow the same glass,
radius, typography and palette.

## Wallpaper Direction

Official wallpapers should use cyber-futuristic depth, night cities, subtle
neon, fluid abstraction, spatial depth and AI intelligence cues.

## Signature

SevenOS visual signature:

- premium blur
- subtle glow
- translucent layers
- cinematic depth
- intelligent minimalism
- discreet neon
- contextual motion
