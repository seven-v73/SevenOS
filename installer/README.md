# SevenOS Installer

This directory contains the first safe installer foundation.

The current installer is a **planning TUI**. It does not partition disks, format drives, install bootloaders, or modify the target system. Instead, it gathers installation choices and writes a reproducible plan.

## Run

From the repository root:

```bash
./install.sh installer-plan
```

Dry-run:

```bash
./install.sh installer-plan --dry-run
```

Validate a plan:

```bash
./install.sh installer-check
```

Generate a non-destructive install preview script:

```bash
./install.sh installer-script
```

## Output

The generated plan is written to:

```text
out/installer/sevenos-install-plan.conf
```

The generated preview script is written to:

```text
out/installer/sevenos-install-steps.sh
```

## Current Questions

The planner asks for:

- target disk
- hostname
- username
- LUKS preference
- filesystem preference
- bootloader preference
- timezone, locale, and keymap
- swap strategy
- selected profiles

## Graphical Installer Direction

SevenOS now keeps a Calamares profile scaffold in:

```text
installer/calamares/
```

Use:

```bash
seven installer status
seven installer release
seven installer doctor
seven installer plan
```

Calamares is the preferred graphical installer path. Archinstall remains the
secondary automation backend for scripts, CI experiments and recovery flows.

`seven installer release` is the public-ISO readiness contract. It separates
the current TUI release path from the future graphical path:

- required checks: Archinstall backend, installer planner, Calamares profile
  files, SevenOS post-install hook, Archiso profile, ISO builder, package list,
  repository injection and live CLI bootstrap
- optional graphical check: Calamares runtime availability

This lets SevenOS say "TUI release ready" honestly before Calamares is packaged
for the live ISO.

## Next Step

The next implementation phase should consume the generated plan and perform installation steps behind explicit confirmations.

No destructive disk operation should be added without:

- a final typed confirmation
- a clear disk summary
- a dry-run mode
- a recovery note
