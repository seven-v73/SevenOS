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
- `scripts/packages-cybersecurity-optional.txt` for optional official packages such as Tor, proxychains, Trivy and Obsidian
- `scripts/packages-cybersecurity-aur.txt` for optional AUR tools such as BurpSuite and Autopsy

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

Install optional AUR tools through SevenStore or your AUR helper after review:

```bash
seven shield optional-tools
seven shield optional-tools install --yes
seven store install-app aur burpsuite
seven store install-app aur autopsy
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

## Shield Persona Engine

Shield is now persona-aware. It can behave as a defensive SOC workspace, OSINT
desk, pentest lab, forensics bench, malware triage sandbox or DevSecOps review
surface without loading unrelated profile stacks.

```bash
seven shield personas
seven shield persona safe
seven shield persona osint
seven shield persona malware
seven shield session ephemeral
seven shield cleanup
```

Personas are scope-first and do not grant permission to test third-party
systems. Unknown samples default to offline or ephemeral workflows.

## Shield Scope, Network Guard and Evidence

Shield now has three safety-first workflow primitives:

```bash
seven shield scope create --owner "Name" --engagement "Lab" --window "Today" --target 127.0.0.1
seven shield scope activate
seven shield network
seven shield evidence init
seven shield evidence add ./artifact.bin --case case-001
```

- Scope is required for intrusive contexts such as `seven shield context exploit`.
- Network Guard explains VPN/Tor/offline/scope requirements for the active persona.
- Evidence Manager records SHA-256, timestamps and handling metadata without changing originals.

## Shield Toolchain Compatibility

Shield can now act as a compatibility hub for Arch, AUR, optional BlackArch and
Kali Rolling containers:

```bash
seven shield toolchain
seven shield toolchain search feroxbuster
seven shield toolchain blackarch-setup --yes
seven shield toolchain kali-prepare --yes
seven shield toolchain kali-run "apt update && apt install -y kali-tools-top10"
```

This keeps SevenOS stable while still allowing Kali/BlackArch-level tool access
when the user intentionally enables the source.

## Focused Shield Bundles

Use bundles before enabling huge catalogs:

```bash
seven shield bundles
seven shield bundles status web
seven shield bundles install web --yes
seven shield bundles install forensics --yes
seven shield bundles install wireless --yes
```

Bundles keep Shield closer to a professional workstation than a giant tool dump:
web, forensics, OSINT, reverse, malware lab, DevSecOps and wireless.

## GUI Compatibility And Performance

```bash
seven shield wrappers install
seven shield tool-doctor
seven shield performance apply
```

Wrappers add stable launchers for mixed Java/Qt/Electron tools under
Wayland/Hyprland. Tool Doctor scores coverage by domain. Performance mode
reduces costly compositor effects during cyber sessions.
