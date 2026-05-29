# SevenOS Layout Contract

SevenOS public windows must fit common laptop displays and remain usable when
content grows.

## Baseline

- Public surfaces should fit within 1024x600.
- Default windows should prefer compact, centered sizes.
- Tall content needs a scrolled region.
- Sidebars and detail panes should degrade gracefully instead of forcing the
  whole window off screen.
- Dialogs should stay below 760x540 unless they are full-screen experiences.

## SevenOS Public Window Targets

- Settings: balanced control center, scrollable content, not full screen by
  default.
- Files: Finder-like compact file manager, responsive content grid.
- Store: catalog with progress and details, scrollable panels.
- Public Studio: 900x640 class quality surface with detail sheets.
- Experience Center: calm dashboard with internal pages.

## Gate

```bash
seven layout-gate
```

The gate scans native surfaces for oversized default windows, fixed minimum
widths, unscrollable dense layouts and known overflow risks.
