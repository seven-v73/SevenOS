# SevenOS Pre-Push Checklist

Run this before pushing a SevenOS phase to GitHub.

## Required

```bash
./scripts/check.sh
./scripts/ux-check.sh
./scripts/readiness.sh --json
./scripts/stack.sh --json
./scripts/shell.sh status --json
./scripts/shell.sh plan --json
./scripts/core.sh status --json
./scripts/core.sh plan --json
./scripts/core.sh bus --json
./scripts/core.sh profiles --json
./bin/seven-daemon shield --json
./bin/seven-daemon shield-plan --json
./bin/seven-daemon server --json
./bin/seven-daemon server-plan --json
./bin/seven-daemon windows --json
./bin/seven-daemon windows-plan --json
./bin/seven-daemon installer --json
./bin/seven-daemon installer-plan --json
./bin/seven-daemon packages --json
./bin/seven-daemon packages-plan --json
./bin/seven-daemon insights --json
./bin/seven-daemon phase-gate --json
SEVENOS_DRY_RUN=1 ./scripts/core.sh observe --json
SEVENOS_DRY_RUN=1 ./scripts/core.sh install-observer
./scripts/core.sh doctor
./scripts/context.sh status --json
./scripts/context.sh graph --json
SEVENOS_DRY_RUN=1 ./scripts/context.sh emit
./scripts/scheduler.sh status --json
./scripts/scheduler.sh plan --json
./scripts/manifest.sh doctor
./scripts/migrate.sh plan
./scripts/installer-stack.sh doctor
./seven-hub/gui-stack.sh doctor
./scripts/post-install.sh
./scripts/phase-gate.sh
./scripts/phase-gate.sh --json
./scripts/daily-driver.sh status
./scripts/daily-driver.sh status --json
SEVENOS_DRY_RUN=1 ./scripts/improve.sh daily --apply --yes
git status --short
```

Make sure the main system reference remains present:

```bash
test -s docs/SYSTEM_EXPERIENCE_LAYER.md
test -s docs/CONTEXT_ENGINE.md
test -s docs/SCHEDULING.md
```

## Recommended

```bash
./install.sh base --dry-run
./install.sh theme --dry-run
./install.sh branding --dry-run
./install.sh iso --dry-run
./bin/seven ecosystem
./bin/seven stack
./bin/seven shell preview
./bin/seven core
./bin/seven context graph
./bin/seven scheduler plan
./bin/seven architecture doctor
./bin/seven manifest restore-plan
./bin/seven migrate plan
./bin/seven installer plan
./bin/seven hub-gui status
./bin/seven flatpak status
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

SevenOS is still a post-install layer and live ISO foundation in Phase B2. It is
ready for test machines, but not yet a polished public installer distribution.

Before presenting a push as a phase upgrade, verify:

```bash
seven phase-gate --json | python -m json.tool
seven stack --json | python -m json.tool
seven shell plan --json | python -m json.tool
```

If the phase gate says `blocked`, the push can still be useful, but it should be
described as consolidation work, not as a completed higher phase.

## Test-Machine Warning

Never document installation as `sudo ./install.sh ...`.

The supported form is:

```bash
./install.sh base --yes
```

SevenOS handles privileged operations internally.
