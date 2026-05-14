# SevenOS Calamares Profile

This is the first SevenOS graphical installer profile foundation.

Calamares is the target GUI installer because it gives SevenOS a realistic path
to non-technical test machines: partitioning, locale, users, bootloader and
post-install modules are already part of its model.

## Current Scope

This directory is a profile scaffold, not a final destructive installer.

It defines:

- SevenOS branding and product intent
- the intended module order
- a SevenOS post-install hook placeholder
- the boundary between Calamares and the existing SevenOS installer planner

## Strategy

SevenOS should keep two installer paths:

- Calamares for the graphical user journey
- Archinstall/planner scripts for automation and development safety

Calamares should eventually call SevenOS post-install actions inside the target
system:

```bash
/opt/SevenOS/install.sh base --yes
/opt/SevenOS/install.sh post-install
```

No disk-writing Calamares config should be treated as release-ready until it is
tested in disposable VMs and reviewed through `seven installer doctor`.
