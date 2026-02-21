# ARM64 Chromium dev image — Debian bookworm base.
#
# Ubuntu no longer ships a real chromium-browser .deb on any version (all
# recent releases redirect to snap).  Debian bookworm still ships a genuine
# `chromium` + `chromium-driver` package for arm64, so we use it here.
#
# This is a standalone image that replicates the desktop tooling from
# selenium/base (xvfb, pulseaudio, fluxbox, fileserver, xseld, selenium user)
# directly on Debian bookworm, avoiding the Ubuntu snap problem entirely.

# ── Stage 1: compile Go helpers (fileserver + xseld) ────────────────────────
FROM golang:1.22-bullseye AS go

# xseld/ and fileserver/ are copied into the build context by build-arm-native.sh
COPY xseld      /xseld
COPY fileserver /fileserver

RUN \
    if [ "$(uname -m)" = "aarch64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    apt-get update && \
    apt-get install -y upx-ucl libx11-dev && \
    cd /xseld     && GOOS=linux GOARCH=$ARCH go build -ldflags="-s -w" && upx /xseld/xseld && \
    cd /fileserver && go test -race && \
        GOOS=linux GOARCH=$ARCH go build -ldflags="-s -w" && upx /fileserver/fileserver

# ── Stage 2: Debian bookworm desktop + Chromium ─────────────────────────────
FROM debian:bookworm-slim

ARG VERSION
# On Debian the package is `chromium`, not `chromium-browser`
ARG PACKAGE=chromium
ARG DEBIAN_FRONTEND=noninteractive

LABEL browser=$PACKAGE:$VERSION

RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        locales \
        tzdata && \
    # Fonts & desktop tools
    apt-get install -y --no-install-recommends \
        fontconfig \
        fonts-dejavu-core \
        fonts-liberation \
        fonts-noto-color-emoji \
        fonts-wqy-zenhei \
        jq \
        libnss3-tools \
        libnss-wrapper \
        libfontconfig1 \
        libfreetype6 \
        xfonts-base \
        xfonts-encodings \
        xfonts-utils \
        xvfb \
        x11vnc \
        pulseaudio \
        fluxbox \
        feh \
        wmctrl \
        xsel \
        iproute2 \
        libgtk-3-0 && \
    # Chromium + driver (real .deb on Debian, no snap stub)
    apt-get install -y --no-install-recommends \
        ${PACKAGE}${VERSION:+=$VERSION} \
        chromium-driver${VERSION:+=$VERSION} && \
    # Symlink so existing scripts that call `chromium-browser` still work
    ln -sf /usr/bin/chromium /usr/bin/chromium-browser && \
    # Also symlink chromedriver name used by selenoid
    ln -sf /usr/bin/chromedriver /usr/bin/chromedriver || true && \
    chromium --version && \
    # Timezone
    echo UTC | tee /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    # Locale — must add entry to /etc/locale.gen before running locale-gen on Debian slim
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/default/locale && \
    fc-cache -f && \
    # selenium user (uid 4096, no password, home /home/selenium)
    adduser --system --home /home/selenium --uid 4096 \
        --ingroup root --disabled-password --shell /bin/bash selenium && \
    mkdir -p /home/selenium/Downloads /home/selenium/.fluxbox && \
    chgrp -R 0 /home/selenium && chmod -R g=u /home/selenium && \
    ln -sf /bin/true /usr/bin/xdg-open && \
    echo "gtk-cursor-blink=0" > /root/.gtkrc-2.0 && \
    apt-get clean && rm -Rf /tmp/* /var/lib/apt/lists/*

# Copy compiled Go helpers
COPY --from=go /fileserver/fileserver /usr/bin/
COPY --from=go /xseld/xseld          /usr/bin/

# Copy fluxbox theme (copied into build context by build-arm-native.sh)
COPY fluxbox /usr/share/fluxbox/styles/
COPY --chown=selenium:root fluxbox /home/selenium/.fluxbox/

