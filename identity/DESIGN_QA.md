# SevenOS Design QA Checklist

Use this checklist before shipping a SevenOS visual change.

## Identity

- SevenOS reads as Prism Flow: clear, sovereign, intelligent and Linux-native.
- The direction matches `identity/CHARTER.md` and the tagline “Beyond the Desktop.”
- Light Mode follows `identity/CHARTER_LIGHT.md` and the tagline “Clarity first.”
- Interfaces feel fluid, precise, stateful, deep and contextual.

## Palette

- Primary accents use Prism Blue `#4C8DFF`, Signal Gold `#D6A84F` and Atlas Teal `#33B6C4`.
- Trust/security signals use Shield Mint `#4DE6A8` and Baobab Green `#2FB87A`.
- Base surfaces use Prism Ink `#070A10`, Graphite Plane `#111722` and Mineral Surface `#182131`.
- Text uses Soft White `#EDEDED` and Muted Gray `#8A8F98`.

## Surface Rules

- Surfaces use compact Prism Flow radius according to role.
- Production shell CSS avoids decorative `box-shadow` and web-only `backdrop-filter`.
- Depth is expressed through mineral surfaces, borders, profile facets and restrained light lanes.
- UI CSS avoids font weights above 500.
- `identity/tokens-light.css` and `hyprland-light/` define the installable
  clarity-first Light Mode.

## UX

- Controls expose features directly.
- Tabs and procedure-heavy menus are avoided unless they are genuinely needed.
- Icons are outline, minimal and consistent.
- Motion is calm: fade, slide, subtle scale and breathing focus.
