#!/usr/bin/env bash
# Build the add-on image outside Home Assistant and push it to a registry, so
# installing on the HA box is a download instead of a source build.
#
# The Dockerfile compiles libwebsockets and mosquitto from source. On a modest
# HA machine that takes a long time and competes with everything else running
# there. Any amd64 box with Docker can do it faster and only once.
#
# Usage:
#   ./build-and-push.sh ghcr.io/<user>           # build + push
#   ./build-and-push.sh ghcr.io/<user> --no-push # build only (test the recipe)
set -euo pipefail
cd "$(dirname "$0")"

REGISTRY="${1:?usage: $0 <registry-prefix> [--no-push]   e.g. ghcr.io/rtrevisan}"
NO_PUSH="${2:-}"

# Match the values the Supervisor would pass, read straight from build.yaml so
# the image cannot silently drift from what a local build would produce.
get_arg() { grep -E "^\s+$1:" build.yaml | awk '{print $2}'; }
BASE=$(grep -A3 '^build_from:' build.yaml | grep 'amd64:' | awk '{print $2}')
VERSION=$(grep -E '^version:' config.yaml | awk '{print $2}' | tr -d '"')

IMAGE="${REGISTRY}/mosquitto-ts-amd64"

echo "==> base:    ${BASE}"
echo "==> image:   ${IMAGE}:${VERSION}"
echo "==> tailscale $(get_arg TAILSCALE_VERSION)"
echo

# --platform is explicit: on an arm64 machine (Apple Silicon) the default would
# silently produce an arm64 image that the amd64 HA box cannot run.
docker build \
  --platform linux/amd64 \
  --build-arg "BUILD_FROM=${BASE}" \
  --build-arg "LIBWEBSOCKET_VERSION=$(get_arg LIBWEBSOCKET_VERSION)" \
  --build-arg "MOSQUITTO_VERSION=$(get_arg MOSQUITTO_VERSION)" \
  --build-arg "MOSQUITTO_AUTH_VERSION=$(get_arg MOSQUITTO_AUTH_VERSION)" \
  --build-arg "TAILSCALE_VERSION=$(get_arg TAILSCALE_VERSION)" \
  -t "${IMAGE}:${VERSION}" \
  -t "${IMAGE}:latest" \
  .

echo
echo "==> built ${IMAGE}:${VERSION}"

if [ "${NO_PUSH}" = "--no-push" ]; then
  echo "==> --no-push given, stopping here"
  exit 0
fi

docker push "${IMAGE}:${VERSION}"
docker push "${IMAGE}:latest"

cat <<EOF

==> pushed.

Now add this line to config.yaml so the Supervisor pulls instead of building:

  image: ${REGISTRY}/mosquitto-ts-{arch}

The {arch} placeholder is expanded by the Supervisor. If you only ever build
amd64, that is the only tag that needs to exist.

Note: on ghcr.io a newly pushed package is PRIVATE. Make it public, or the
Supervisor cannot pull it.
EOF
