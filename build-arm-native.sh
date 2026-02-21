#!/usr/bin/env bash
# =============================================================================
# build-arm-native.sh — Build Selenoid browser images on a NATIVE arm64 host
#                        (e.g. AWS EC2 m6g / Graviton2, Apple M1/M2)
#
# No QEMU, no buildx cross-compilation needed — plain `docker build`.
# =============================================================================
#
# Usage:
#   ./build-arm-native.sh [OPTIONS]
#
# Environment variables:
#   BASE_TAG              browsers/base image tag          (default: 7.4.2)
#   CHROMIUM_VERSION      Pin chromium apt version         (default: latest)
#   FIREFOX_VERSION       Pin firefox apt version          (default: latest)
#   EDGE_VERSION          Pin Microsoft Edge apt version   (default: latest)
#   EDGE_DRIVER_VERSION   msedgedriver version to bundle   (required for Edge)
#   GECKODRIVER_VERSION   geckodriver tag, no 'v'          (default: 0.35.0)
#   SELENOID_VERSION      selenoid release tag             (default: 1.11.3)
#   IMAGE_PREFIX          prefix for final image tags      (default: selenoid)
#   NO_CACHE              set to 1 to pass --no-cache      (default: 0)
#   PUSH                  set to 1 to docker push images   (default: 0)
#   BUILD_BROWSERS        space-separated list             (default: "chromium firefox edge")
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARM_DIR="${SCRIPT_DIR}/arm"
STATIC_DIR="${SCRIPT_DIR}/static"
BASE_DOCKERFILE="${SCRIPT_DIR}/selenium/base"

BASE_TAG="${BASE_TAG:-7.4.2}"
CHROMIUM_VERSION="${CHROMIUM_VERSION:-}"
FIREFOX_VERSION="${FIREFOX_VERSION:-}"
EDGE_VERSION="${EDGE_VERSION:-}"
EDGE_DRIVER_VERSION="${EDGE_DRIVER_VERSION:-}"
GECKODRIVER_VERSION="${GECKODRIVER_VERSION:-0.35.0}"
SELENOID_VERSION="${SELENOID_VERSION:-1.11.3}"
IMAGE_PREFIX="${IMAGE_PREFIX:-gbalajihbox}"
NO_CACHE="${NO_CACHE:-0}"
PUSH="${PUSH:-0}"
BUILD_BROWSERS="${BUILD_BROWSERS:-chromium firefox edge}"

log()  { echo "==> $*"; }
info() { echo "    $*"; }

no_cache_flag() { [ "$NO_CACHE" = "1" ] && echo "--no-cache" || echo ""; }

docker_build() {
    local ctx="$1"; shift
    local tag="$1"; shift
    local nc; nc="$(no_cache_flag)"
    log "docker build → $tag"
    docker build ${nc:+$nc} -t "$tag" "$@" "$ctx"
}

push_image() {
    [ "$PUSH" = "1" ] && docker push "$1" || true
}

major_minor() {
    echo "$1" | grep -oE '^[0-9]+\.[0-9]+' || echo "$1"
}

make_tmpdir() {
    local d; d="$(mktemp -d)"
    trap "rm -rf '$d'" EXIT
    echo "$d"
}

# ── Verify running on arm64 ──────────────────────────────────────────────────
check_arch() {
    local arch; arch="$(uname -m)"
    if [ "$arch" != "aarch64" ]; then
        echo "ERROR: This script must run on an arm64/aarch64 host." >&2
        echo "       Detected: $arch" >&2
        echo "       Use build-arm.sh for cross-compilation on x86." >&2
        exit 1
    fi
    log "Host arch: $arch  (native build, no QEMU needed)"
}

# =============================================================================
# 1. browsers/base
# =============================================================================
build_base() {
    log "Building browsers/base:${BASE_TAG}"
    docker_build "$BASE_DOCKERFILE" "browsers/base:${BASE_TAG}"
    push_image "browsers/base:${BASE_TAG}"
}

# =============================================================================
# 2. Chromium
# =============================================================================
build_chromium() {
    local ver_arg=()
    [ -n "$CHROMIUM_VERSION" ] && ver_arg=(--build-arg "VERSION=${CHROMIUM_VERSION}")

    local tag_ver; tag_ver="$(major_minor "${CHROMIUM_VERSION:-latest}")"
    local dev_tag="${IMAGE_PREFIX}/dev_chromium:${tag_ver}"
    local final_tag="${IMAGE_PREFIX}/vnc_arm64:chromium_${tag_ver}"

    log "Building Chromium dev image: $dev_tag"
    docker_build "${ARM_DIR}/chromium/dev" "$dev_tag" "${ver_arg[@]}"

    local ctx; ctx="$(make_tmpdir)"
    cp "${ARM_DIR}/chromium/Dockerfile"       "${ctx}/Dockerfile"
    cp "${STATIC_DIR}/chromium/entrypoint.sh" "${ctx}/entrypoint.sh"

    log "Building Chromium final image: $final_tag"
    docker_build "$ctx" "$final_tag" --build-arg "VERSION=${tag_ver}"

    push_image "$dev_tag"
    push_image "$final_tag"
    info "Chromium dev  : $dev_tag"
    info "Chromium final: $final_tag"
}

# =============================================================================
# 3. Firefox
# =============================================================================
build_firefox() {
    local ver_arg=()
    [ -n "$FIREFOX_VERSION" ] && ver_arg=(--build-arg "VERSION=${FIREFOX_VERSION}")

    local tag_ver; tag_ver="$(major_minor "${FIREFOX_VERSION:-latest}")"
    local dev_tag="${IMAGE_PREFIX}/dev_firefox:${tag_ver}"
    local final_tag="${IMAGE_PREFIX}/vnc_arm64:firefox_${tag_ver}"

    log "Building Firefox dev image: $dev_tag"
    docker_build "${ARM_DIR}/firefox/dev" "$dev_tag" \
        "${ver_arg[@]}" \
        --build-arg "PPA=ppa:mozillateam/ppa"

    local ctx; ctx="$(make_tmpdir)"
    cp "${ARM_DIR}/firefox/Dockerfile"               "${ctx}/Dockerfile"
    cp "${STATIC_DIR}/firefox/selenoid/browsers.json" "${ctx}/browsers.json"
    cp "${STATIC_DIR}/firefox/selenoid/entrypoint.sh" "${ctx}/entrypoint.sh"

    log "Building Firefox final image: $final_tag"
    docker_build "$ctx" "$final_tag" \
        --build-arg "VERSION=${tag_ver}" \
        --build-arg "FIREFOX_MAJOR_VERSION=${tag_ver}" \
        --build-arg "GECKODRIVER_VERSION=${GECKODRIVER_VERSION}" \
        --build-arg "SELENOID_VERSION=${SELENOID_VERSION}"

    push_image "$dev_tag"
    push_image "$final_tag"
    info "Firefox dev  : $dev_tag"
    info "Firefox final: $final_tag  (geckodriver ${GECKODRIVER_VERSION}, selenoid ${SELENOID_VERSION})"
}

# =============================================================================
# 4. Microsoft Edge (arm64 packages available from packages.microsoft.com)
# =============================================================================
build_edge() {
    if [ -z "$EDGE_DRIVER_VERSION" ]; then
        echo "WARNING: EDGE_DRIVER_VERSION not set — skipping Edge." >&2
        echo "         Set EDGE_DRIVER_VERSION=<version> matching EDGE_VERSION." >&2
        return 0
    fi

    local ver_arg=()
    [ -n "$EDGE_VERSION" ] && ver_arg=(--build-arg "VERSION=${EDGE_VERSION}")

    local tag_ver; tag_ver="$(major_minor "${EDGE_VERSION:-latest}")"
    local dev_tag="${IMAGE_PREFIX}/dev_edge:${tag_ver}"
    local final_tag="${IMAGE_PREFIX}/vnc_arm64:edge_${tag_ver}"

    log "Building Edge dev image: $dev_tag"
    docker_build "${ARM_DIR}/edge/dev" "$dev_tag" "${ver_arg[@]}"

    local ctx; ctx="$(make_tmpdir)"
    cp "${ARM_DIR}/edge/Dockerfile"       "${ctx}/Dockerfile"
    cp "${STATIC_DIR}/edge/entrypoint.sh" "${ctx}/entrypoint.sh"

    log "Building Edge final image: $final_tag"
    docker_build "$ctx" "$final_tag" \
        --build-arg "VERSION=${tag_ver}" \
        --build-arg "DRIVER_VERSION=${EDGE_DRIVER_VERSION}"

    push_image "$dev_tag"
    push_image "$final_tag"
    info "Edge dev  : $dev_tag"
    info "Edge final: $final_tag  (msedgedriver ${EDGE_DRIVER_VERSION})"
}

# =============================================================================
# Main
# =============================================================================
main() {
    check_arch

    log "Native ARM64 browser image build"
    log "Browsers: $BUILD_BROWSERS"
    echo ""

    build_base

    for browser in $BUILD_BROWSERS; do
        case "$browser" in
            chromium) build_chromium ;;
            firefox)  build_firefox  ;;
            edge)     build_edge     ;;
            *) echo "WARNING: Unknown browser '$browser' — skipping." >&2 ;;
        esac
    done

    echo ""
    log "All done."
}

main "$@"
