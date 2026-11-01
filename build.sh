#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
#
# Build Rulerbench locally from an upstream ScanRuler release.
#
#   ./build.sh              # the newest upstream release
#   ./build.sh v0.9.4       # a specific tag
#   TAG=ghcr.io/redleader36/rulerbench:v0.9.4 ./build.sh v0.9.4
#
# Downloads the upstream source at that tag, drops this repository's packaging
# files beside it, and builds the from-source Dockerfile — the same steps the
# release workflow runs, minus the publishing.
set -euo pipefail

UPSTREAM_REPO="CNCKitchen/scanruler"
PACKAGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

want="${1:-}"
if [ -z "$want" ]; then
  # The newest published release; fall back to the newest tag if the project
  # ever stops cutting releases.
  want="$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" \
    | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)"
  [ -n "$want" ] || want="$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_REPO}/tags?per_page=1" \
    | grep -m1 '"name"' | cut -d'"' -f4)"
fi
case "$want" in v*) tag="$want" ;; *) tag="v$want" ;; esac
version="${tag#v}"

# The commit the tag points at goes into the image labels, so an image can be
# traced back to exact source even if the tag is ever moved.
commit="$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_REPO}/git/ref/tags/${tag}" \
  | grep -m1 '"sha"' | cut -d'"' -f4)"
if [ -z "${commit:-}" ]; then
  echo "error: no such upstream tag: ${tag}" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
echo "==> upstream ${tag} (${commit})"

curl -fsSL "https://github.com/${UPSTREAM_REPO}/archive/refs/tags/${tag}.tar.gz" \
  | tar -xz -C "$work" --strip-components=1
cp "${PACKAGING_DIR}/Dockerfile" "${PACKAGING_DIR}/nginx.conf" "${PACKAGING_DIR}/NOTICE" "${work}/"
cp "${PACKAGING_DIR}/LICENSE" "${work}/LICENSE"

image="${TAG:-rulerbench:${version}}"
echo "==> docker build -t ${image}"
docker build \
  --build-arg "VERSION=${version}" \
  --build-arg "UPSTREAM_COMMIT=${commit}" \
  --build-arg "VITE_FILES_URL=${VITE_FILES_URL:-https://files.scanruler.com/}" \
  -t "$image" "$work"

echo "==> built ${image}"
echo "    docker run -d --name rulerbench -p 8080:8080 ${image}"
