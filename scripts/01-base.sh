#!/usr/bin/env bash
# =============================================================================
# 01-base.sh  —  minimal post-install configuration
# Runs inside the Kali VM via Packer SSH provisioner
# =============================================================================
set -euo pipefail

echo ">>> [01-base] Starting base configuration"

# Refresh package index
apt-get update -qq

# Ensure SSH server is enabled and starts on boot
systemctl enable ssh
systemctl start  ssh || true

# Install a handful of demo-relevant tools (lightweight, fast to install)
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl \
    wget \
    net-tools \
    nmap \
    git

echo ">>> [01-base] Base configuration complete"
