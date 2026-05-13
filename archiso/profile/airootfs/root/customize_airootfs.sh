#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
systemctl enable NetworkManager.service

useradd -m -G wheel -s /bin/bash seven
passwd -l seven

install -Dm755 /opt/SevenOS/bin/sevenosctl /usr/local/bin/sevenosctl
install -Dm755 /opt/SevenOS/bin/seven /usr/local/bin/seven
install -Dm755 /opt/SevenOS/bin/sevenpkg /usr/local/bin/sevenpkg
