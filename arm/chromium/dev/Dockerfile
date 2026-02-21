# ARM64-compatible Chromium dev image.
#
# Ubuntu 22.04 replaced chromium-browser with a snap stub — the real .deb
# package still exists on Ubuntu 20.04 (focal).  We use browsers/base:focal
# (browsers/base built with UBUNTU_VERSION=20.04) so we keep all the desktop
# tooling (xvfb, pulseaudio, fileserver, xseld, fluxbox) AND get a genuine
# chromium-browser deb.
#
# chromium-chromedriver is co-versioned with chromium-browser on focal, so
# both packages resolve to the same version automatically.
FROM browsers/base:focal

ARG VERSION
ARG PACKAGE=chromium-browser
ARG DEBIAN_FRONTEND=noninteractive

LABEL browser=$PACKAGE:$VERSION

# ${VERSION:+=$VERSION} appends =<version> only when VERSION is non-empty,
# so omitting --build-arg VERSION installs the latest available package.
RUN \
    apt-get update && \
    apt-get -y --no-install-recommends install \
      ca-certificates \
      curl \
      iproute2 \
      libgtk-3-0 \
      ${PACKAGE}${VERSION:+=$VERSION} \
      chromium-chromedriver${VERSION:+=$VERSION} && \
    chromium-browser --version && \
    rm -Rf /tmp/* && rm -Rf /var/lib/apt/lists/*
