# SevenOS Profile Themes

SevenOS profiles are not simple presets. Each profile is a self-contained mini
OS with four internal layers:

- Kernel Layer: resource policy, latency, power and service pressure.
- Runtime Layer: tools, packages, services and application defaults.
- Experience Layer: Waybar, panels, workspace intent and UI rhythm.
- Intelligence Layer: SevenAI rules, suggestions, diagnostics and safety.

Equinox keeps the neutral SevenOS experience. Specialized profiles change the
goal of the system itself without forcing their stack onto other profiles.

## Rules

- No profile dependency, only profile collaboration.
- Every profile must be useful alone.
- Equinox is the balanced general mini OS, not a hidden super-profile.
- Baobab is culture and learning only: no dev, security, cloud or gaming noise.
- Windows Bridge is VM-first; Wine and Bottles are fallback compatibility paths.
- The Waybar always shows the active profile as a compact icon pill.
- Wi-Fi, Bluetooth, audio, battery, clock and SevenAI are essential shell
  controls and must never disappear when switching profiles.
- Clicking the profile pill opens a graphical profile switcher, never a terminal.
- Catppuccin roles are used as profile accents, with SevenOS icons and Papirus
  fallback so the system remains reliable.

## Profiles

| ID | Public Name | Domain | Waybar Intent |
| --- | --- | --- | --- |
| `equinox` | Equinox Balance | Balanced general computing | General shell, broad readiness |
| `baobab` | Baobab Culture | African culture and learning | Reader/media/language/culture surface |
| `forge` | Forge DevOps | Development and deployment | Code, builds, containers, services, deploys and logs |
| `shield` | Shield Cybersecurity | Cybersecurity | VPN, audit, isolation and recorder awareness |
| `studio` | Studio Creator | Creation | Media, audio, capture and production flow |
| `windows` | Windows Bridge | Windows VM and compatibility | VM, app routing, snapshots and fallbacks |
| `pulse` | Pulse Gaming | Linux gaming/performance | Low latency, overlays, media and recording |

The machine-readable contract lives in `identity/profile-themes.json` and
`profiles/catalog.json`.
