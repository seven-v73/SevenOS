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
Baobab and Windows. Mini OS profiles may keep their own packages private, but
the Windows Compatibility panel, command resolver and shared Windows app
workspace are public SevenOS tools.

## Engine Order

1. **Wine** for direct `.exe` and `.msi` execution.
2. **Bottles** for friendly app bottles and per-app isolation.
3. **Proton / Lutris** for games and DirectX-heavy workflows.
4. **KVM/QEMU VM** only when an app really needs a full Windows session.

The VM is a fallback, not the default. SevenOS does not download or redistribute
Windows images. Users provide their own legal ISO/image when the VM path is
needed.

## Commands

```bash
seven windows open
seven-windows-native
seven windows catalog
seven windows catalog --json
seven windows resolve photoshop
seven windows resolve photoshop --json
seven run photoshop
seven windows run /path/to/setup.exe
seven windows apps
seven windows vm
```

The native panel includes a quick launcher. Users can type an app id such as
`photoshop`, `office`, `epic`, or choose a local `.exe`/`.msi`; SevenOS resolves
the recommended engine inside the interface before launching. The panel keeps a
small local recent list under `~/.local/state/sevenos/windows/` and exposes
direct actions to prepare or diagnose an app without hunting for commands.
It also shows the decision path so the user can see why SevenOS selected Wine,
Bottles, Lutris, Proton or the VM.

## Contract

`seven windows resolve <app> --json` emits:

- `schema: sevenos.windows-app-resolve.v1`
- selected `engine`
- available engines
- preferred engines
- native-window capability
- sandbox recommendation
- VM fallback state
- next blockers/actions

This contract is meant for Seven Hub, Seven Shell and SevenDaemon. The UI should
never parse human text to understand Windows compatibility.

## Product Rule

If a Windows app can run through Wine, Bottles, Proton or Lutris, SevenOS should
not ask for a Windows ISO. The ISO flow is reserved for full desktop mode,
driver-sensitive apps, enterprise plugins and professional workflows that cannot
run reliably through compatibility layers.

## Fresh Machine Contract

`scripts/install-cli.sh` installs both `seven-windows-assistant` and
`seven-windows-native` as user and system commands. `./install.sh windows`
installs the base Wine/Lutris/Protontricks/KVM tooling, configures libvirt, and
adds Bottles through Flatpak when Flatpak is present. Optional AUR helpers live
in `scripts/packages-windows-aur.txt`.
