# SevenOS Cyber Policy

SevenOS treats cybersecurity as a professional workspace, not a random bundle of
tools. The default policy is:

- official Arch packages first
- explicit categories instead of one unclear blob
- isolated labs for risky experiments
- BlackArch as an optional bridge
- no offensive tooling without user intent

## Recommended Flow

Install the core profile:

```bash
./install.sh cybersecurity core
```

Add only the families you need:

```bash
./install.sh cybersecurity forensics
./install.sh cybersecurity reversing
./install.sh cybersecurity wireless
./install.sh cybersecurity sandbox
```

Audit the machine:

```bash
./install.sh cyber-audit
```

Open an isolated lab:

```bash
./install.sh cyber-lab --name webapp
./install.sh cyber-lab --preset web
```

Open an offline lab:

```bash
./install.sh cyber-lab --name reversing --offline
./install.sh cyber-lab --preset forensics
./install.sh cyber-lab --preset reversing
./install.sh cyber-lab --preset offline
```

Use BlackArch only when SevenOS Cyber Core does not cover a tool:

```bash
./install.sh blackarch-setup --dry-run
./install.sh blackarch-setup --yes
./install.sh blackarch-category webapp
```
