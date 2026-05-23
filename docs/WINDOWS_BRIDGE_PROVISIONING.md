# SevenOS Windows Bridge Provisioning

SevenOS does not redistribute Windows images or prebuilt Windows `qcow2`
templates. Windows Bridge builds the local VM artifacts from official or
user-authorized Windows media.

## Flow

```text
User enables Windows Bridge
  -> SevenOS checks KVM/libvirt and storage
  -> SevenOS prepares a local qcow2 disk
  -> SevenOS fetches VirtIO driver media when confirmed
  -> SevenOS uses quickget when available, or accepts a user ISO
  -> SevenOS creates/launches the libvirt VM
```

## Commands

```bash
seven windows sources
seven windows provision
seven windows provision --yes
seven windows virtio --yes
seven windows autounattend
seven windows create --iso /path/to/windows.iso --virtio-iso ~/.local/share/sevenos/vm/windows/virtio-win.iso --disk-path ~/.local/share/sevenos/vm/windows/sevenos-windows.qcow2
```

`quickemu`/`quickget` is optional and is tracked in
`scripts/packages-windows-aur.txt`. If it is unavailable, the user can provide
an official Windows ISO manually.

SevenOS base installation prepares AUR helpers with:

```bash
./install.sh aur-helpers --yes
```

This installs `yay` and `paru` so Windows Bridge can later install optional
helpers such as `quickemu` without making them mandatory pacman packages.

## Policy

- SevenOS builds a local VM disk; it does not host a Windows image.
- SevenOS does not inject a product key.
- SevenOS does not bypass Windows activation.
- `qcow2` is a host-side QEMU/KVM disk format. Windows sees only a normal
  virtual disk exposed through VirtIO/SATA/SCSI.
