# SevenOS BlackArch Bridge

SevenOS keeps the default cybersecurity profile based on official Arch packages.
BlackArch is supported as an optional bridge when a user needs the much larger
catalog of offensive security tools.

## Why Optional

BlackArch is powerful, but it adds an external package repository and a very
large tool catalog. SevenOS should stay stable for daily development, creation,
and security work, so BlackArch is opt-in.

## Commands

Preview repository setup:

```bash
./install.sh blackarch-setup --dry-run
```

Enable the BlackArch repository after review:

```bash
./install.sh blackarch-setup --yes
```

Install one BlackArch category:

```bash
./install.sh blackarch-category webapp
```

Preview the complete BlackArch catalog install:

```bash
seven shield toolchain blackarch-full --dry-run
```

Install the complete BlackArch catalog after explicit confirmation:

```bash
seven shield toolchain blackarch-full --yes
```

Install one BlackArch package:

```bash
./install.sh blackarch-tool feroxbuster
```

## Policy

- Prefer SevenOS Cyber Core first.
- Install BlackArch categories only when needed.
- Install the complete BlackArch catalog only on a dedicated Shield/security
  workstation; it is intentionally blocked without `--yes`.
- Use these tools only on systems and networks where you have authorization.
