#!/usr/bin/env bash
# Per-boot runtime setup. The VM has no systemd, so start the Docker daemon
# directly, register QEMU binfmt handlers for arm emulation, and prepare a
# multi-platform Buildx builder. Safe to run repeatedly.
set -euo pipefail

# Start dockerd if it is not already accepting connections.
if ! sudo docker info >/dev/null 2>&1; then
  sudo nohup dockerd >/var/log/dockerd.log 2>&1 &
fi

for _ in $(seq 1 30); do
  if sudo docker info >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
sudo docker info >/dev/null

# Register QEMU handlers so linux/arm/v5 (and other arm variants) can run.
sudo docker run --privileged --rm tonistiigi/binfmt --install arm >/dev/null 2>&1 || true

# A docker-container builder is required for the repo's multi-platform build.
if ! sudo docker buildx inspect armbuilder >/dev/null 2>&1; then
  sudo docker buildx create --name armbuilder --driver docker-container --bootstrap >/dev/null
fi
sudo docker buildx use armbuilder

echo "Docker daemon ready; buildx builder 'armbuilder' active for linux/arm/v5."
