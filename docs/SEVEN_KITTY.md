# Seven Kitty

SevenOS ships two terminal experiences:

- `seven-terminal`: the default native SevenOS terminal with VTE, tabs, palette, search and profile-aware context.
- `seven-kitty`: the official Kitty-backed alternative for users who prefer Kitty performance, its renderer and its mature keyboard model.

Both follow the same SevenOS profiles: Equinox, Forge, Shield, Atlas, Focus, Admin, dark and light. The user does not need to know the backend; SevenOS keeps the default stable while exposing Kitty as a clear choice.

Seven Kitty keeps the visible title calm and OS-like: tabs are labeled
`SevenOS`, direct Kitty launches use the same `seven-terminal-shell` profile,
and shell-process labels such as `bash in SevenOS` should not appear in the
user-facing chrome.

## Commands

```bash
seven-terminal
seven-kitty
seven-kitty forge
seven-kitty menu
seven-kitty status
```

## Installation Contract

Kitty is part of `scripts/packages-base.txt` and `archiso/profile/packages.x86_64`, so it is available on fresh SevenOS installations. The `seven-kitty` launcher and desktop entry are installed by `scripts/install-cli.sh` and refreshed by `scripts/apply-theme.sh`.

## Identity Rules

- Keep `seven-terminal` as the default terminal.
- Keep `seven-kitty` visible as an advanced but friendly alternative.
- Use the same font, spacing, palette, profile names and SevenOS logo hints across both terminals.
- Keep the chrome title stable as `SevenOS`; details belong in the prompt, not in the titlebar.
- Never make Kitty a fallback that feels accidental; it should feel like a first-class SevenOS option.
