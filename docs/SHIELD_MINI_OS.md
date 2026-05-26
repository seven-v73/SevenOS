# SevenOS Shield Mini OS

Shield is not a Kali or BlackArch clone. It is a dynamic cybersecurity mini OS
inside SevenOS: scope-first, isolated by default, persona-aware and designed for
authorized work.

## Core Model

Shield has four layers:

- Kernel layer: guarded networking, audit-aware scheduling, sandbox readiness.
- Runtime layer: cybersecurity tools, labs, sessions, evidence and reports.
- Experience layer: SOC-style workspace, CyberSpace contexts, visible scope.
- Intelligence layer: risk explanation, posture repair, mode-specific guidance.

## Persona Engine

Shield adapts through personas:

| Persona | Purpose |
| --- | --- |
| `safe` | Defensive local audit and hardening |
| `research` | CVE and security research |
| `lab` | Authorized pentest lab |
| `osint` | Privacy-aware OSINT workspace |
| `forensics` | Offline evidence analysis |
| `malware` | Offline disposable sample triage |
| `devsecops` | Code and dependency review |
| `redteam` | Authorized adversary emulation |
| `blueteam` | Logs, detection and monitoring |

Commands:

```bash
seven shield personas
seven shield persona osint
seven shield session ephemeral
seven shield cleanup
seven shield dashboard
```

## Scope Workflow

Scope is the hard authorization gate. Shield can prepare dashboards and labs at
any time, but intrusive contexts stay blocked until the scope has an owner,
engagement, time window and at least one target.

```bash
seven shield scope
seven shield scope create --owner "Name" --engagement "Lab" --window "2026-05-21" --target 127.0.0.1
seven shield scope activate
seven shield scope complete
seven shield scope archive
```

The `exploit` CyberSpace context is locked when no active scope exists.

## Network Guard

Network Guard maps the active persona to a visible network posture:

- `safe`: normal guarded network.
- `osint`: VPN or Tor recommended.
- `forensics`: offline preferred.
- `malware`: offline enforced by policy.
- `redteam`: active scope required.

Commands:

```bash
seven shield network
seven shield network apply
```

The current implementation is advisory-safe: it records posture and warnings
without silently changing host firewall, VPN or Tor routes.

## Evidence Manager

Evidence Manager records hash metadata without modifying originals.

```bash
seven shield evidence init
seven shield evidence add ./sample.bin --case incident-001 --note "static triage"
seven shield evidence list
```

It stores chain-of-custody metadata in `~/ShieldLab/.sevenos/evidence-index.json`.

## Optional Advanced Tools

BurpSuite and Autopsy are intentionally optional. They are large AUR packages,
so Shield surfaces them as a deliberate advanced step instead of installing
them silently with the baseline.

```bash
seven shield optional-tools
seven shield optional-tools install --yes
```

This keeps the stable Shield baseline light while preserving a clear path to a
full web pentest and forensic GUI workstation.

## Toolchain Compatibility

Shield aims for Kali/BlackArch-level compatibility without turning the host into
an overloaded tool dump. The compatibility order is:

1. Arch official packages for stable baseline tooling.
2. AUR for reviewed advanced GUI/tools such as BurpSuite and Autopsy.
3. BlackArch as an explicit opt-in repository for very large Arch-native tool coverage.
4. Kali Rolling in an isolated container for maximum Kali command compatibility.

Commands:

```bash
seven shield toolchain
seven shield toolchain search feroxbuster
seven shield toolchain install feroxbuster --yes
seven shield toolchain blackarch-setup --yes
seven shield toolchain blackarch-full --dry-run
seven shield toolchain blackarch-full --yes
seven shield toolchain blackarch-category webapp --yes
seven shield toolchain kali-prepare --yes
seven shield toolchain kali-run "apt update && apt install -y kali-tools-web"
```

The full BlackArch command installs the complete `blackarch` package set. It is
intentionally guarded by `--dry-run` and `--yes` because it is large enough to
belong on a dedicated Shield/security workstation rather than a casual daily
profile.

The Kali container mounts `~/ShieldLab` at `/ShieldLab` so reports and evidence
stay in the Shield workspace.

## Focused Bundles

Shield installs by workflow, not by dumping every security package on the host.
This keeps the mini OS fast while still making the right tools one command away:

```bash
seven shield bundles
seven shield bundles status web
seven shield bundles install web --yes
seven shield bundles install forensics --yes
seven shield bundles install reverse --yes
seven shield bundles install wireless --yes
```

Available bundles:

- `web`: ZAP, sqlmap, nikto, gobuster, Metasploit, nmap and web assessment basics.
- `forensics`: Sleuth Kit, Volatility, YARA, binwalk, recovery and metadata tools.
- `osint`: WHOIS/DNS/traceroute, Tor/proxy tooling, metadata and notes.
- `reverse`: Ghidra, Cutter, radare2/rizin, GDB, fuzzing and Python exploit helpers.
- `malware`: offline triage helpers, sandbox launchers and static analysis basics.
- `devsecops`: Trivy, Bandit, YARA and code/dependency review tools.
- `wireless`: aircrack-ng, bettercap, Ettercap, macchanger and packet analysis.

Use `--with-aur` only when you want specialist tools that require AUR review.

## GUI Compatibility And Performance

Cyber tools often mix Java, Qt, Electron and GTK. Shield provides wrappers that
prefer stable XWayland variables for tools that are known to be sensitive under
Wayland/Hyprland:

```bash
seven shield wrappers
seven shield wrappers install
seven-burpsuite
seven-autopsy
seven-ghidra
seven-wireshark
seven-zaproxy
seven-bloodhound
```

Use the domain doctor to see where Shield is strong or incomplete:

```bash
seven shield tool-doctor
```

For long analysis sessions, apply a calmer compositor profile:

```bash
seven shield performance apply
seven shield performance reset
```

## Session Modes

Persistent mode keeps scope, notes, reports and evidence.

Ephemeral mode is for OSINT, malware triage and sensitive lab work. It writes
disposable data under `~/ShieldLab/Ephemeral` and can be cleaned with:

```bash
seven shield cleanup
```

## Safety Rule

Shield does not authorize offensive action by itself. The user must define scope
before scans or lab work. Unknown samples belong in offline or disposable labs.
