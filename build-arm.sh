#!/usr/bin/env bash
# =============================================================================
# build-arm.sh — Build Selenoid browser images for linux/arm64
# =============================================================================
#
# Usage:
#   ./build-arm.sh [OPTIONS]
#
# Options / environment variables:
#   BASE_TAG              browsers/base image tag          (default: 7.4.2)
#   CHROMIUM_VERSION      Pin chromium apt version         (default: latest)
#   FIREFOX_VERSION       Pin firefox apt version          (default: latest)
#   EDGE_VERSION          Pin Microsoft Edge apt version   (default: latest)
#   EDGE_DRIVER_VERSION   msedgedriver version to bundle   (required for Edge)
#   GECKODRIVER_VERSION   geckodriver release tag, no 'v'  (default: 0.35.0)
#   SELENOID_VERSION      selenoid release tag             (default: 1.11.3)
#   IMAGE_PREFIX          prefix for final image tags      (default: selenoid)
#   NO_CACHE              set to 1 to pass --no-cache      (default: 0)
#   PUSH                  set to 1 to push images after    (default: 0)
#   BUILD_BROWSERS        space-separated list of browsers to build
#                         Valid values: chromium firefox edge
#                         (default: "chromium firefox edge")
#
# Prerequisites:
#   • Docker 20.10+ with BuildKit enabled (docker buildx create --use)
#   • QEMU binfmt handlers registered:
#       docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
#
# Notes:
#   • Google Chrome does NOT ship a Linux arm64 build; use Chromium instead.
#   • Yandex Browser and Opera are AMD64-only; they are not supported here.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARM_DIR="${SCRIPT_DIR}/arm"
STATIC_DIR="${SCRIPT_DIR}/static"
BASE_DOCKERFILE="${SCRIPT_DIR}/selenium/base"

PLATFORM="linux/arm64"

# ---- Configurable versions --------------------------------------------------
BASE_TAG="${BASE_TAG:-7.4.2}"
CHROMIUM_VERSION="${CHROMIUM_VERSION:-}"         # empty = latest from apt
FIREFOX_VERSION="${FIREFOX_VERSION:-}"           # empty = latest from apt
EDGE_VERSION="${EDGE_VERSION:-}"                 # empty = latest from apt
EDGE_DRIVER_VERSION="${EDGE_DRIVER_VERSION:-}"   # should match EDGE_VERSION
GECKODRIVER_VERSION="${GECKODRIVER_VERSION:-0.35.0}"
SELENOID_VERSION="${SELENOID_VERSION:-1.11.3}"
IMAGE_PREFIX="${IMAGE_PREFIX:-selenoid}"
NO_CACHE="${NO_CACHE:-0}"
PUSH="${PUSH:-0}"
BUILD_BROWSERS="${BUILD_BROWSERS:-chromium firefox edge}"

# ---- Helpers ----------------------------------------------------------------
log()  { echo "==> $*"; }
info() { echo "    $*"; }

no_cache_flag() {
    [ "$NO_CACHE" = "1" ] && echo "--no-cache" || echo ""
}

# Build an image using docker buildx.
# Usage: buildx_build <context_dir> <tag> [extra docker buildx args...]
buildx_build() {
    local ctx="$1"; shift
    local tag="$1"; shift
    local nc
    nc="$(no_cache_flag)"

    local cmd=(docker buildx build
        --platform "$PLATFORM"
        --load
        -t "$tag"
        ${nc:+$nc}
        "$@"
        "$ctx"
    )
    log "docker buildx build → $tag"
    "${cmd[@]}"
}

push_image() {
    local tag="$1"
    if [ "$PUSH" = "1" ]; then
        log "push $tag"
        docker push "$tag"
    fi
}

# Derive major.minor version from an apt package version string.
# e.g. "135.0+build1-0ubuntu0.22.04.1" → "135.0"
#      "120.0.6099.109-1"               → "120.0"
major_minor() {
    echo "$1" | grep -oE '^[0-9]+\.[0-9]+' || echo "$1"
}

# Create a temporary directory that is cleaned up automatically on EXIT.
make_tmpdir() {
    local d
    d="$(mktemp -d)"
    # Register cleanup
    # shellcheck disable=SC2064
    trap "rm -rf '$d'" EXIT
    echo "$d"
}

# Check docker buildx is available and a builder exists.
check_buildx() {
    if ! docker buildx version &>/dev/null; then
        echo "ERROR: docker buildx not available." >&2
        echo "       Install Docker Desktop or 'docker buildx' plugin." >&2
        exit 1
    fi
    # Ensure a builder that can handle linux/arm64 exists.
    if ! docker buildx inspect arm64-builder &>/dev/null; then
        log "Creating buildx builder 'arm64-builder' ..."
        docker buildx create --name arm64-builder --driver docker-container --use
    else
        docker buildx use arm64-builder
    fi
}

# =============================================================================
# 1. browsers/base  (already ARM-aware via uname -m detection)
# =============================================================================
build_base() {
    log "Building browsers/base:${BASE_TAG} for arm64"
    buildx_build "$BASE_DOCKERFILE" "browsers/base:${BASE_TAG}"
    push_image "browsers/base:${BASE_TAG}"
}

# =============================================================================
# 2. Chromium
# =============================================================================
build_chromium() {
    local ver_arg=()
    local pkg_ver="latest"
    if [ -n "$CHROMIUM_VERSION" ]; then
        ver_arg=(--build-arg "VERSION=${CHROMIUM_VERSION}")
        pkg_ver="$CHROMIUM_VERSION"
    fi
    local tag_ver
    # For tag, strip ubuntu suffix: "118.0.5993.70-0ubuntu0.22.04.1" → "118.0"
    tag_ver="$(major_minor "${CHROMIUM_VERSION:-latest}")"

    local dev_tag="selenoid/dev_chromium:${tag_ver}"
    local final_tag="${IMAGE_PREFIX}/vnc_arm64:chromium_${tag_ver}"

    # --- dev image ---
    log "Building Chromium dev image: $dev_tag"
    buildx_build "${ARM_DIR}/chromium/dev" "$dev_tag" "${ver_arg[@]}"

    # --- final image ---
    # Build context: arm/chromium/Dockerfile + chromium entrypoint.sh
    local ctx
    ctx="$(make_tmpdir)"
    cp "${ARM_DIR}/chromium/Dockerfile"           "${ctx}/Dockerfile"
    cp "${STATIC_DIR}/chromium/entrypoint.sh"     "${ctx}/entrypoint.sh"

    log "Building Chromium final image: $final_tag"
    buildx_build "$ctx" "$final_tag" \
        --build-arg "VERSION=${tag_ver}"

    push_image "$dev_tag"
    push_image "$final_tag"

    info "Chromium images:"
    info "  dev   : $dev_tag"
    info "  final : $final_tag"
}

# =============================================================================
# 3. Firefox
# =============================================================================
build_firefox() {
    local ver_arg=()
    local pkg_ver="latest"
    if [ -n "$FIREFOX_VERSION" ]; then
        ver_arg=(--build-arg "VERSION=${FIREFOX_VERSION}")
        pkg_ver="$FIREFOX_VERSION"
    fi

    local tag_ver
    tag_ver="$(major_minor "${FIREFOX_VERSION:-latest}")"
    local dev_tag="selenoid/dev_firefox:${tag_ver}"
    local final_tag="${IMAGE_PREFIX}/vnc_arm64:firefox_${tag_ver}"

    # --- dev image ---
    log "Building Firefox dev image: $dev_tag"
    # Pass the Mozilla PPA so the latest stable Firefox is available on arm64.
    buildx_build "${ARM_DIR}/firefox/dev" "$dev_tag" \
        "${ver_arg[@]}" \
        --build-arg "PPA=ppa:mozillateam/ppa"

    # --- final image ---
    # The final image downloads geckodriver (aarch64) and selenoid (arm64) via
    # curl at build time, so no pre-downloaded binaries are needed.
    local ctx
    ctx="$(make_tmpdir)"
    cp "${ARM_DIR}/firefox/Dockerfile"                          "${ctx}/Dockerfile"
    cp "${STATIC_DIR}/firefox/selenoid/browsers.json"          "${ctx}/browsers.json"
    cp "${STATIC_DIR}/firefox/selenoid/entrypoint.sh"          "${ctx}/entrypoint.sh"

    log "Building Firefox final image: $final_tag"
    buildx_build "$ctx" "$final_tag" \
        --build-arg "VERSION=${tag_ver}" \
        --build-arg "FIREFOX_MAJOR_VERSION=${tag_ver}" \
        --build-arg "GECKODRIVER_VERSION=${GECKODRIVER_VERSION}" \
        --build-arg "SELENOID_VERSION=${SELENOID_VERSION}"

    push_image "$dev_tag"
    push_image "$final_tag"

    info "Firefox images:"
    info "  dev   : $dev_tag"
    info "  final : $final_tag  (geckodriver ${GECKODRIVER_VERSION}, selenoid ${SELENOID_VERSION})"
}

# =============================================================================
# 4. Microsoft Edge
# =============================================================================
build_edge() {
    if [ -z "$EDGE_DRIVER_VERSION" ]; then
        echo "WARNING: EDGE_DRIVER_VERSION is not set; skipping Edge build." >&2
        echo "         Set EDGE_DRIVER_VERSION to the msedgedriver version" >&2
        echo "         matching your EDGE_VERSION (e.g. 135.0.3179.54)." >&2
        return 0
    fi

    local ver_arg=()
    if [ -n "$EDGE_VERSION" ]; then
        ver_arg=(--build-arg "VERSION=${EDGE_VERSION}")
    fi

    local tag_ver
    tag_ver="$(major_minor "${EDGE_VERSION:-latest}")"
    local dev_tag="selenoid/dev_edge:${tag_ver}"
    local final_tag="${IMAGE_PREFIX}/vnc_arm64:edge_${tag_ver}"

    # --- dev image ---
    log "Building Edge dev image: $dev_tag"
    buildx_build "${ARM_DIR}/edge/dev" "$dev_tag" "${ver_arg[@]}"

    # --- final image ---
    local ctx
    ctx="$(make_tmpdir)"
    cp "${ARM_DIR}/edge/Dockerfile"       "${ctx}/Dockerfile"
    cp "${STATIC_DIR}/edge/entrypoint.sh" "${ctx}/entrypoint.sh"

    log "Building Edge final image: $final_tag"
    buildx_build "$ctx" "$final_tag" \
        --build-arg "VERSION=${tag_ver}" \
        --build-arg "DRIVER_VERSION=${EDGE_DRIVER_VERSION}"

    push_image "$dev_tag"
    push_image "$final_tag"

    info "Edge images:"
    info "  dev   : $dev_tag"
    info "  final : $final_tag  (msedgedriver ${EDGE_DRIVER_VERSION})"
}

# =============================================================================
# Main
# =============================================================================
main() {
    log "ARM64 browser image build starting"
    log "Platform : $PLATFORM"
    log "Browsers : $BUILD_BROWSERS"
    echo ""

    check_buildx

    # Enable QEMU binfmt helpers for cross-compilation if not already done.
    if ! docker run --rm --platform linux/arm64 alpine uname -m 2>/dev/null | grep -q aarch64; then
        log "Registering QEMU binfmt handlers ..."
        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    fi

    build_base

    for browser in $BUILD_BROWSERS; do
        case "$browser" in
            chromium) build_chromium ;;
            firefox)  build_firefox  ;;
            edge)     build_edge     ;;
            *)
                echo "WARNING: Unknown browser '$browser' — skipping." >&2
                ;;
        esac
    done

    echo ""
    log "All done."
}

main "$@"
