# SevenOS Design QA Checklist

Use this checklist before shipping a SevenOS visual change.

## Identity

- SevenOS reads as premium, futuristic, intelligent and Linux-native.
- The direction matches `identity/CHARTER.md` and the tagline “Beyond the Desktop.”
- Light Mode follows `identity/CHARTER_LIGHT.md` and the tagline “Clarity first.”
- Interfaces feel fluid, transparent, minimal, deep and contextual.

## Palette

- Primary accents use Seven Blue `#4DA3FF`, Seven Violet `#7A5CFF` and Seven Cyan `#00D4FF`.
- Cyber/security signals use Seven Green `#00FFB3`.
- Base surfaces use Deep Void `#09090B`, Surface Dark `#12131A` and translucent glass.
- Text uses Soft White `#EDEDED` and Muted Gray `#8A8F98`.

## Surface Rules

- Floating surfaces use 14px, 18px, 22px, 24px or 28px radius according to role.
- Production shell CSS avoids decorative `box-shadow` and web-only `backdrop-filter`.
- Glow is expressed through alpha gradients, borders, Hyprland blur and text-shadow.
- UI CSS avoids font weights above 500.
- `identity/tokens-light.css` and `hyprland-light/` define the installable
  clarity-first Light Mode.

## UX

- Controls expose features directly.
- Tabs and procedure-heavy menus are avoided unless they are genuinely needed.
- Icons are outline, minimal and consistent.
- Motion is calm: fade, slide, subtle scale and breathing focus.
