# SevenOS Windows App Layer

SevenOS should not make Windows compatibility feel like “open another OS”.
The target experience is:

```bash
seven run photoshop
```

SevenOS resolves the application, chooses the best available engine, applies
the right safety model, and opens the result as a normal Hyprland window when
possible.

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
seven windows catalog
seven windows catalog --json
seven windows resolve photoshop
seven windows resolve photoshop --json
seven run photoshop
seven windows run /path/to/setup.exe
```

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
