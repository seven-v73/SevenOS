# SevenOS Windows App Layer

SevenOS should not make Windows compatibility feel like “open another OS”.
The target experience is:

```bash
seven run photoshop
```

SevenOS resolves the application, chooses the best available engine, applies
the right safety model, and opens the result as a normal Hyprland window when
possible.

This compatibility layer is global SevenOS infrastructure. It must remain
available from Equinox and from every Mini OS: Forge, Studio, Shield, Pulse,
Baobab and Atlas. Mini OS profiles may keep their own packages private, but
the Windows Compatibility panel, command resolver and shared Windows app
workspace are public SevenOS tools.

## Engine Order

1. **Bottles** for friendly app bottles and per-app isolation.
2. **Wine** for direct `.exe`, `.msi`, `.msp` and script execution.
3. **Lutris / Proton flows** for games and DirectX-heavy workflows.

SevenOS no longer exposes Windows as a mini OS or a default VM route. Windows
app support is an app-first compatibility layer that remains available from
every profile.

## Commands

```bash
seven windows open
seven-windows-native
seven windows catalog
seven windows catalog --json
seven windows resolve photoshop
seven windows resolve photoshop --json
seven run photoshop
./install.sh windows-compat --yes
seven windows run /path/to/setup.exe
seven-files windows /path/to/setup.exe
seven-wincompat status --json
seven-wincompat plan /path/to/setup.msi --json
seven windows apps
```

Seven Files is the normal user-facing launcher for local Windows files. A
double click or context-menu action on `.exe`, `.msi`, `.msp`, `.bat`, `.cmd`,
`.com`, `.scr` or `.lnk` opens the SevenOS Windows App Compatibility flow.
SevenOS resolves the recommended engine, shows a safety confirmation, then
launches through Bottles, Wine or Lutris without turning Windows into a mini OS.

The native panel includes a quick launcher. Users can type an app id such as
`photoshop`, `office`, `epic`, or choose a local `.exe`/`.msi`; SevenOS resolves
the recommended engine inside the interface before launching. The compatibility
layer keeps a small local recent list under
`~/.local/state/sevenos/wincompat/` and exposes direct actions to prepare or
diagnose an app without hunting for commands.
It also shows the decision path so the user can see why SevenOS selected
Bottles, Wine or Lutris.

## Contract

`seven windows resolve <app> --json` emits:

- `schema: sevenos.windows-app-resolve.v1`
- selected `engine`
- available engines
- preferred engines
- native-window capability
- sandbox recommendation
- next blockers/actions

This contract is meant for Seven Hub, Seven Shell and SevenDaemon. The UI should
never parse human text to understand Windows compatibility.

## Product Rule

If a Windows app can run through Bottles, Wine or Lutris, SevenOS should open
it as a normal app workflow. SevenOS must not ask for a Windows ISO as part of
the normal product experience.

## Fresh Machine Contract

`bin/seven-wincompat` is installed with the SevenOS CLI and `./install.sh
windows-compat` prepares the optional Wine/Lutris packages plus the Bottles
Flatpak route. AUR candidates, if any, should stay in a separate package
manifest instead of blocking the base install.
