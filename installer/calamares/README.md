# SevenOS Calamares Profile

This is the first SevenOS graphical installer profile foundation.

Calamares is the target GUI installer because it gives SevenOS a realistic path
to non-technical test machines: partitioning, locale, users, bootloader and
post-install modules are already part of its model.

## Current Scope

This directory is a SevenOS graphical install profile foundation. It is still
validated through disposable ISO tests before public release, but it now avoids
custom Calamares plugin names in the critical path.

It defines:

- SevenOS branding and product intent
- the intended module order
- a SevenOS post-install hook through Calamares' standard `shellprocess` module
- the boundary between Calamares and the existing SevenOS installer planner

SevenOS tracks this boundary with:

```bash
seven installer release
seven installer plan --json
```

The release contract should remain green only when the live ISO can boot into
the SevenOS graphical session, install the SevenOS Calamares config into
`/etc/calamares`, and provide the Calamares runtime package.

## Strategy

SevenOS should keep two installer paths:

- Calamares for the graphical user journey
- Archinstall/planner scripts for automation and development safety

Calamares calls SevenOS post-install actions inside the target system through
`modules/shellprocess.conf`:

```bash
/opt/SevenOS/install.sh base --yes
/opt/SevenOS/install.sh post-install
```

No disk-writing Calamares config should be treated as release-ready until it is
tested in disposable VMs and reviewed through `seven installer doctor`.
