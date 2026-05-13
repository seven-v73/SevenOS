# SevenOS Branding

This directory contains SevenOS system identity files.

## Files

- `os-release`: used directly inside the live ISO
- `sevenos-release`: SevenOS release marker
- `issue`: TTY login banner
- `motd`: shell login message
- `fastfetch/config.jsonc`: SevenOS fastfetch config

## Apply On A Host

```bash
./install.sh branding
```

This installs `/etc/sevenos-release`, `/etc/issue`, `/etc/motd`, and the user fastfetch config.

For safety, host systems do not have `/etc/os-release` replaced. The live ISO uses SevenOS `os-release` directly.
