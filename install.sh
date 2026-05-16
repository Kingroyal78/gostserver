#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

REPO_TARBALL_URL="https://github.com/Kingroyal78/gostserver/archive/refs/heads/master.tar.gz"

curl -fsSL "${REPO_TARBALL_URL}" -o "${TMP_DIR}/gostserver.tar.gz"
tar -xzf "${TMP_DIR}/gostserver.tar.gz" -C "${TMP_DIR}"

REPO_DIR="$(find "${TMP_DIR}" -maxdepth 1 -type d -name 'gostserver-*' | head -n 1)"
if [[ -z "${REPO_DIR}" ]]; then
  echo "Failed to unpack gostserver repository."
  exit 1
fi

exec bash "${REPO_DIR}/deploy-gost-server.sh"
