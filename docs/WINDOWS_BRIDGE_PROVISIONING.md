# SevenOS Windows Bridge Provisioning

SevenOS does not redistribute Windows images or prebuilt Windows `qcow2`
templates. Windows Bridge builds the local VM artifacts from official or
user-authorized Windows media.

## First Install

Use one public command first:

```bash
seven windows setup
```

For the native SevenOS surface:

```bash
seven windows open
seven-windows-native
```

When the official Windows ISO is available:

```bash
seven windows setup --iso ~/Downloads/Win11.iso
```

`seven windows setup` installs the Windows Bridge requirements, prepares
libvirt/networking, creates the local `qcow2` disk, prepares VirtIO driver
media when possible, and creates/registers the VM when an official Windows ISO
is available. If the ISO is missing, it stops with one clear next step instead
of exposing the whole expert command chain.

The app-first layer remains available everywhere in SevenOS, independently of
the active Mini OS. Wine, Bottles, Lutris and Proton are preferred for normal
apps; the VM path is only for apps that need a real Windows session.

## What SevenOS Prepares

- KVM/libvirt readiness.
- Local `qcow2` disk.
- VirtIO driver media when confirmed.
- Windows-friendly VM defaults.
- Console launch after the VM is registered.

`quickemu`/`quickget` is optional and is tracked in
`scripts/packages-windows-aur.txt`. If it is unavailable, the user can provide
an official Windows ISO manually.

## Policy

- SevenOS builds a local VM disk; it does not host a Windows image.
- SevenOS does not inject a product key.
- SevenOS does not bypass Windows activation.
- `qcow2` is a host-side QEMU/KVM disk format. Windows sees only a normal
  virtual disk exposed through VirtIO/SATA/SCSI.
