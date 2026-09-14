#!/usr/bin/env bash
# Per-boot runtime setup. The VM has no systemd, so start the Docker daemon
# directly, register QEMU binfmt handlers for arm emulation, and prepare a
# multi-platform Buildx builder. Safe to run repeatedly.
set -euo pipefail

# Start dockerd if it is not already accepting connections. The whole command
# (including the log redirect) must run as root, otherwise the unprivileged
# shell owns the redirect and cannot write to /var/log.
if ! sudo docker info >/dev/null 2>&1; then
  sudo sh -c 'nohup dockerd >/var/log/dockerd.log 2>&1 &'
fi

for _ in $(seq 1 30); do
  if sudo docker info >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
sudo docker info >/dev/null

# binfmt_misc must be mounted on the host so the QEMU handlers registered by
# the tonistiigi/binfmt container persist system-wide (they are otherwise
# confined to the throwaway container and lost on exit).
if [ ! -e /proc/sys/fs/binfmt_misc/register ]; then
  sudo mount -t binfmt_misc none /proc/sys/fs/binfmt_misc
fi

# Register QEMU handlers so linux/arm/v5 (and other arm variants) can run.
if [ ! -e /proc/sys/fs/binfmt_misc/qemu-arm ]; then
  sudo docker run --privileged --rm tonistiigi/binfmt --install arm >/dev/null
fi

# A docker-container builder is required for the repo's multi-platform build.
# Recreate it if a stale builder exists without arm support (binfmt must be
# registered before the builder is created for it to advertise linux/arm).
if sudo docker buildx inspect armbuilder >/dev/null 2>&1; then
  if ! sudo docker buildx inspect armbuilder 2>/dev/null | grep -q 'linux/arm'; then
    sudo docker buildx rm armbuilder >/dev/null 2>&1 || true
  fi
fi
if ! sudo docker buildx inspect armbuilder >/dev/null 2>&1; then
  sudo docker buildx create --name armbuilder --driver docker-container --bootstrap >/dev/null
fi
sudo docker buildx use armbuilder

echo "Docker daemon ready; buildx builder 'armbuilder' active for linux/arm/v5."
