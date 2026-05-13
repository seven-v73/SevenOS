# SevenOS Security Layer

This directory will contain security hardening and profile isolation work.

Planned scope:

- firewall defaults
- sandbox policies
- secure mode
- VPN integration
- forensic tooling notes
- cybersecurity profile isolation guidance

Security tooling must be used only on systems and networks where you have authorization.

Current Phase 1 behavior:

- installs the packages listed in `scripts/packages-security.txt`
- enables `ufw.service`
- sets incoming traffic to deny by default
- sets outgoing traffic to allow by default
- enables UFW non-interactively
