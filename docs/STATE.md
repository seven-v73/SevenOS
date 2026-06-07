# SevenOS State Contract

`seven state --json` is the compact machine snapshot for native UI, Seven Hub,
SevenAI, Settings, Doctor and future server endpoints.

It should be used when a surface needs to know the current OS state without
running many independent commands.

## Required Blocks

The state cache is valid only when these public contracts are present:

- `packages_strategy`
- `packages_catalog`
- `packages_footprint`
- `production`
- `language`
- `language_audit`
- `first_run`

The language-related blocks are intentionally first-class:

- `language` checks installed catalogues, locale projection and Mini OS profile
  language state.
- `language_audit` checks generated runtime labels such as Waybar, Prism,
  widgets and Mini OS surfaces.
- `first_run` reports fresh-machine readiness and exposes stable checks such as
  `language-contract` and `runtime-labels`.

## Usage Rule

Graphical surfaces should prefer:

```bash
seven state --json
```

over separate calls to:

```bash
seven language doctor
seven language audit
seven first-run verify
seven production
```

Those direct commands remain useful for repair screens, logs and advanced
diagnostics, but the default UI path should read the cached state snapshot.

## Refresh Rule

Use a refresh only after actions that deliberately change global state:

```bash
seven state --json --refresh
```

Examples:

- language switch or repair;
- theme switch;
- Mini OS profile activation;
- update or rollback;
- first-run/new-device repair.

Normal UI rendering should not force refreshes continuously. This keeps SevenOS
fast and avoids turning every settings page into a heavy diagnostic run.

## Footprint Rule

Storage and footprint surfaces should not run a deep size scan during normal
rendering. Use:

```bash
seven footprint --fast --json
```

for SevenAI, Spotlight, Settings, Doctor and widgets. Use the full
`seven footprint --json` or `seven footprint plan` only when the user opens a
maintenance view. SevenOS treats rootfs trees, VM images, Windows prefixes and
profile containers as platform state, not cache.
