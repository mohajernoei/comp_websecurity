#!/usr/bin/env bash

set -euo pipefail

# 1) Remove old/conflicting packages (safe if not installed)
sudo apt-get update
sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

# 2) Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# 3) Add Docker’s official GPG key + apt repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# 4) Install Docker Engine + CLI + containerd + buildx + compose plugin
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5) Enable + start Docker
sudo systemctl enable --now docker

# 6) Optional: allow running docker without sudo (log out/in after)
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"

# 7) Quick test
docker run --rm hello-world || true
docker compose version




















IMAGE="mohajernoei/websecurity"
PORT="${1:-3000}"

# Ensure image is present / up to date
docker pull "${IMAGE}"


docker run --rm -it -p "${PORT}:3000" --volume .:/app/ "${IMAGE}"

