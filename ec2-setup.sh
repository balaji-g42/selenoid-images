#!/usr/bin/env bash
# =============================================================================
# ec2-setup.sh — One-time Docker setup on Amazon Linux 2023 (m6g / Graviton)
# Run as: sudo bash ec2-setup.sh
# =============================================================================
set -euo pipefail

echo "==> Installing Docker on Amazon Linux 2023..."
dnf update -y
dnf install -y docker git

echo "==> Starting Docker daemon..."
systemctl enable --now docker

echo "==> Adding ec2-user to docker group (re-login required)..."
usermod -aG docker ec2-user

echo "==> Docker version:"
docker version --format 'Client: {{.Client.Version}}  Server: {{.Server.Version}}'

echo ""
echo "==> Setup complete."
echo "    Log out and back in (or run: newgrp docker) then:"
echo "    git clone <your-repo> && cd images && bash build-arm-native.sh"
