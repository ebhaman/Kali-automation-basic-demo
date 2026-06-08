#!/usr/bin/env bash
# =============================================================================
# 99-cleanup.sh  —  seal the image before Packer shuts it down
# Removes machine-specific state so the template is clean for cloning
# =============================================================================
set -euo pipefail

echo ">>> [99-cleanup] Cleaning up before template seal"

# Remove SSH host keys — they are regenerated on first boot of each clone
rm -f /etc/ssh/ssh_host_*

# Clear shell history
unset HISTFILE
rm -f /root/.bash_history /home/kali/.bash_history
history -c || true

# Remove temporary files
apt-get clean
rm -rf /tmp/* /var/tmp/*

# Zero free space to improve qcow2 compression (optional but reduces image size)
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo ">>> [99-cleanup] Template sealed successfully"
