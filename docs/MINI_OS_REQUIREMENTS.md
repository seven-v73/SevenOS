# Mini OS Requirements

SevenOS does not only isolate mini OS profiles. Each mini OS declares the tools
it needs to be useful immediately, plus optional tools that the user can add
when the workflow grows.

## Rule

- Equinox owns the host/admin baseline and shared system services.
- Forge, Studio, Baobab, Shield, Atlas and Pulse keep profile-specific apps inside
  their own package view through `sevenpkg <profile> install`.
- Required package files describe the stable baseline for that mini OS.
- Optional package files describe useful extras that should not block first use.

## Commands

```bash
seven mini-doctor
seven mini-doctor forge
seven mini-doctor studio
seven mini-doctor baobab
seven mini-doctor shield
seven mini-doctor atlas
seven mini-doctor pulse
seven mini-doctor forge plan --json
seven-mini-doctor studio install
seven-mini-doctor baobab optional
seven-mini-doctor shield rootfs
seven-mini-doctor pulse install
seven atlas status
seven atlas install --yes
sevenpkg forge install code --source pacman
sevenpkg studio install obs-studio --source pacman
sevenpkg baobab install calibre --source pacman
sevenpkg shield install burpsuite --source paru
sevenpkg pulse install steam lutris --source pacman
```

## Baselines

| Mini OS | Required baseline | Optional examples |
| --- | --- | --- |
| Forge | Git, SSH, Node, Python, Rust, Go, containers, editors, build tools, local services | Lazygit, Poetry, extra IDEs |
| Studio | Image, vector, video, audio, 3D, capture, codecs, audio plugins | Office/export extras |
| Baobab | Fonts, reading, narration, translation, offline knowledge, media | Calibre, sync, cultural AI/search |
| Shield | Authorized audit, forensics, reversing, wireless, sandbox and evidence tools | Burp Suite, Autopsy, advanced catalogs |
| Atlas | Documents, PDFs/ebooks, maps, OCR, archives, references and local research | Anki, Recoll, Zeal, QGIS/JOSM and advanced map tools |
| Pulse | GameMode, Vulkan/audio/portal basics, performance rootfs and GPU guidance | Steam, Lutris, MangoHud, Gamescope, Proton helpers |

## Public User Flow

1. Open the mini OS center.
2. Choose `Verifier` to see what is missing.
3. Choose `Preparer` to install the required baseline.
4. Add optional tools only when the user asks for that workflow.
5. Use `sevenpkg <profile> install` for profile-private apps.

For Atlas, the public path is `seven atlas status` and
`seven atlas install --yes`. It prepares the native document, map, OCR and
reference baseline without reintroducing a Windows/VM dependency.
