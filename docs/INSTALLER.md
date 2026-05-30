# SevenOS Installer Direction

SevenOS currently provides a live ISO foundation, post-install setup and
installer planning. The final public disk installer is still a productization
target, not something that should be presented as finished.

For testing before the standalone installer is ready, use the SevenOS route on
top of an Arch-compatible foundation:

```text
docs/TEST_MACHINE.md
```

The current ISO is a live environment that contains the SevenOS repository at:

```text
/opt/SevenOS
```

The current installer implementation is a non-destructive planning and script
generation flow:

```bash
seven installer status --json
seven installer plan
seven installer plan --json
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
```

`seven installer plan --json` is the machine-readable contract consumed by
Seven Hub, Seven Server and the Control Plane. It tracks Archinstall,
Calamares, Archiso and ISO build readiness before SevenOS becomes a public
installable distribution.

## Calamares ISO Runtime

SevenOS now separates the Calamares profile from the package source used by the
live ISO. The profile, branding and launcher live in the repository; the ISO
runtime must provide the `calamares` package either through the active package
repositories or through the SevenOS local archiso repository.

Useful commands:

```bash
seven installer experience
seven installer experience --json
seven installer experience plan
seven installer runtime
seven installer iso-runtime
seven installer iso-runtime --json
seven installer iso-runtime deps --yes
seven installer iso-runtime build-local-repo --dry-run
seven installer iso-runtime build-local-repo --yes
./install.sh calamares-runtime status
./install.sh iso --dry-run
```

`build-local-repo --yes` clones the Calamares AUR package recipe, builds it with
`makepkg`, copies the package into `archiso/localrepo/x86_64`, and creates the
`sevenos-local` repository database. During ISO builds, `scripts/build-iso.sh`
injects that repository into the temporary archiso profile.

SevenOS should not claim `public-release-ready` until the graphical ISO runtime
is actually available and the release doctor is clean.

## Public Install Experience

`seven installer experience` is the public contract for a new machine. It
connects five parts that must feel like one OS flow:

- modern graphical installer route;
- automatic hardware detection;
- GPU driver guidance;
- preset profiles for developer, gamer, creator, server and balanced use;
- post-install assistant through `seven setup new-device --yes`,
  `seven first-run verify` and `seven post-install`.

The command is intentionally safe: it reports and recommends. Package changes
stay behind explicit commands and installer confirmations.

## Options Under Review

### Scripted TUI Installer

Best fit for early SevenOS:

- transparent Bash workflow
- easy to review
- aligned with current scripts
- less heavy than a full GUI installer

### Calamares

Good long-term option for a polished graphical install flow:

- mature distro installer
- partitioning UI
- localization support
- more packaging and maintenance overhead

### Custom Seven Hub Installer

Possible later:

- strongest brand fit
- more development work
- should only happen after CLI install flow is proven

## Current Recommendation

Keep the scripted TUI path as the safe fallback, and use Calamares as the public
graphical ISO path once the runtime package is present in the ISO build
environment.

Until then, SevenOS should be tested as the SevenOS system layer:

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
./install.sh base --dry-run
./install.sh base --yes
seven phase-gate
```

## Minimum TUI Scope

- disk selection
- partition confirmation
- LUKS option
- filesystem selection
- bootloader selection
- timezone, locale, and keymap
- swap strategy
- base system install
- bootloader setup
- user creation
- profile selection
- post-install SevenOS bootstrap
