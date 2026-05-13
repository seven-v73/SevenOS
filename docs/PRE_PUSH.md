# SevenOS Pre-Push Checklist

Run this before pushing a SevenOS phase to GitHub.

## Required

```bash
./scripts/check.sh
./scripts/ux-check.sh
./scripts/readiness.sh --json
./scripts/post-install.sh
./scripts/phase-gate.sh
git status --short
```

## Recommended

```bash
./install.sh base --dry-run
./install.sh theme --dry-run
./install.sh branding --dry-run
./install.sh iso --dry-run
./bin/seven ecosystem
./bin/seven repair
```

## Git Hygiene

Make sure generated files are not committed:

- `out/`
- `work/`
- `iso/`
- `__pycache__/`
- `*.pyc`

Commit all intentional source files, including new executable scripts.

Suggested commit shape:

```bash
git add .
git status --short
git commit -m "Build SevenOS ecosystem foundation"
git push origin main
```

## Current Release Caveat

SevenOS is still a post-install layer and live ISO foundation. It is ready for
test machines, but not yet a polished public installer distribution.

## Test-Machine Warning

Never document installation as `sudo ./install.sh ...`.

The supported form is:

```bash
./install.sh base --yes
```

SevenOS handles privileged operations internally.
