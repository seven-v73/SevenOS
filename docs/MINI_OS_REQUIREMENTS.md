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
seven mini-doctor all guide
seven mini-doctor all guide --refresh --json
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
| Baobab | Fonts, reading, narration, African-language memory, offline cultural collections, oral/story workflows | Calibre/Anki for learning, cultural AI/search, optional community sync |
| Shield | Authorized audit, forensics, reversing, wireless, sandbox and evidence tools | Burp Suite, Autopsy, advanced catalogs |
| Atlas | Documents, PDFs/ebooks, office files, scans, OCR, annotations, maps, archives, references and local research | Zeal, Kiwix, QGIS/JOSM and advanced map tools |
| Pulse | GameMode, Vulkan/audio/portal basics, performance rootfs and GPU guidance | Steam, Lutris, MangoHud, Gamescope, Proton helpers |

## Public User Flow

1. Start with `seven mini-doctor all guide`.
2. Open the mini OS center for the profile that needs attention.
3. Choose `Verifier` to see what is missing.
4. Choose `Preparer` only when the required baseline is missing.
5. Add optional tools only when the user asks for that workflow.
6. Use `sevenpkg <profile> install` for profile-private apps.

The guide is intentionally more product-oriented than the raw doctors. It keeps
Baobab light by default, reminds Shield to declare scope before audits, and
shows the next safe action for each mini OS without forcing optional heavy
packages.

For Atlas, the public path is `seven atlas status` and
`seven atlas install --yes`. It prepares the native document, map, OCR and
reference baseline without reintroducing a Windows/VM dependency.
For the complete Atlas contract, use `seven atlas` or see
`docs/ATLAS_MINI_OS.md`.

Baobab/Atlas boundary:
- Baobab owns culture, oral memory, African languages, storytelling, local
  heritage packs and community transmission.
- Atlas owns general documents, scan/OCR, annotations, maps, GPX, references,
  archives and travel/research navigation.
- Run `seven mini-boundaries` to check that future package changes keep the
  overlap explicit and reviewed.
