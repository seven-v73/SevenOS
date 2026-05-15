# Seven Shell AGS Foundation

This directory is the controlled AGS + TypeScript foundation for SevenOS B3.

AGS is intentionally not mandatory in B2. The current production fallback is:

```text
Hyprland + Waybar + GTK shell panels + Rofi fallback
```

The AGS layer becomes active only when:

- the runtime workflow is chosen;
- `seven shell doctor` passes;
- Quick Settings and Notifications can use the same JSON contracts as the Hub;
- Rofi remains available as fallback.

## Planned Surfaces

| Surface | Current | Target |
| --- | --- | --- |
| Quick Settings | GTK/Rofi | AGS panel |
| Notifications | GTK/Rofi/Mako | AGS notification center |
| Launcher | Rofi Launchpad | AGS launcher |
| Dock | planned | AGS dock |

## Developer Notes

The TypeScript files in `src/` define contracts and structure first. They are
not meant to be a finished shell yet.
