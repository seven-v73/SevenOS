# SevenOS Security Layer

This directory contains SevenOS security hardening, cybersecurity readiness
checks, and the optional BlackArch bridge.

Planned scope:

- firewall defaults
- sandbox policies
- secure mode
- VPN integration
- forensic tooling notes
- cybersecurity profile isolation guidance
- BlackArch bridge policy

Security tooling must be used only on systems and networks where you have authorization.

Current Phase 1 behavior:

- installs the packages listed in `scripts/packages-security.txt`
- enables `ufw.service`
- sets incoming traffic to deny by default
- sets outgoing traffic to allow by default
- enables UFW non-interactively

## Cybersecurity Profile

SevenOS now separates the cybersecurity layer into official Arch package groups:

- `scripts/packages-cybersecurity.txt` for core network, web, cracking, and exploitation tools
- `scripts/packages-cybersecurity-forensics.txt` for forensic analysis
- `scripts/packages-cybersecurity-reversing.txt` for reverse engineering and binary work
- `scripts/packages-cybersecurity-wireless.txt` for wireless and local network testing
- `scripts/packages-cybersecurity-sandbox.txt` for isolation helpers and secure code checks

Audit the local machine:

```bash
./install.sh cyber-audit
```

Install a single category:

```bash
./install.sh cybersecurity core
./install.sh cybersecurity forensics
./install.sh cybersecurity reversing
./install.sh cybersecurity wireless
./install.sh cybersecurity sandbox
```

Open an isolated lab shell:

```bash
./install.sh cyber-lab --name webapp
./install.sh cyber-lab --name reversing --offline
```

## BlackArch Bridge

BlackArch is optional. SevenOS prefers a clean official Arch cyber base first,
then offers BlackArch for specialized packages and categories.

See `security/BLACKARCH.md`.
See `security/cyber-policy.md` for the full SevenOS cyber workflow.
