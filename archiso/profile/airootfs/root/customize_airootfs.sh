#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
systemctl enable NetworkManager.service
systemctl enable sshd.service

useradd -m -G wheel -s /bin/bash seven
passwd -d seven
