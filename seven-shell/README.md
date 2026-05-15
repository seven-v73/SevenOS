# Seven Shell

Seven Shell is the B3 desktop shell direction for SevenOS.

It does not replace the current Waybar/Rofi/GTK fallback yet. It prepares a
controlled AGS + TypeScript layer for:

- Quick Settings
- Notification Center
- launcher / overview
- dock
- profile-aware widgets

The rule is simple:

```text
Seven Shell replaces visible friction gradually. It does not rewrite the whole
desktop before the contracts are stable.
```

## Commands

```bash
seven shell
seven shell status --json
seven shell plan
seven shell plan --json
seven shell doctor
seven shell preview
```

## Data Sources

Seven Shell consumes JSON contracts only:

- `seven state --json`
- `seven actions --json`
- `seven profile current --json`
- `seven shell status --json`

Human terminal output is not an API.
