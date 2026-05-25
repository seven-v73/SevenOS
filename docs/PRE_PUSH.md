# SevenOS Pre-Push Checklist

Run this before pushing a SevenOS phase to GitHub.

## Daily Gate

```bash
seven pre-push
git status --short
```

This is the fast GitHub push gate. It checks shell syntax, Python entrypoints,
JSON contracts, whitespace, design-check, smoke/state contracts, `seven new`
dry-run and Windows Bridge first-run dry-run.

## Release Audit

Use this only before a release tag or a major phase claim:

```bash
seven pre-push full
./scripts/ux-check.sh
seven doctor release --json | python -m json.tool
seven phase-gate --json | python -m json.tool
```

If the long audit times out, keep the fast gate as the daily push signal and
fix the slow check separately before tagging a release.

## Useful Spot Checks

```bash
seven smoke --json | python -m json.tool
seven state --json | python -m json.tool
seven system-profile doctor
seven post-install
seven profile-rootfs verify all
seven windows setup --yes --no-open --dry-run
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
git add <intentional files>
git status --short
git commit -m "Improve SevenOS first-install and pre-push gate"
git push origin main
```

## Current Release Caveat

SevenOS is ready for test machines, but not yet a polished public installer
distribution. Before presenting a push as a phase upgrade, verify:

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
seven new
```

SevenOS handles privileged operations internally.
