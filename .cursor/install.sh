#!/usr/bin/env bash
# Idempotent dependency setup for building the MikroTik (linux/arm/v5) image.
# Installs Docker Engine, Buildx, and QEMU user-mode emulation so this repo's
# cross-platform Docker image can be built on an x86_64 Cloud Agent VM.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

sudo apt-get update -qq
sudo apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin \
  qemu-user-static binfmt-support

# Let the agent user talk to the Docker socket without sudo in new shells.
sudo groupadd -f docker
sudo usermod -aG docker "$(id -un)" || true

docker --version
docker buildx version
