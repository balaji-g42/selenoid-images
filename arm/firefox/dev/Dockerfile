# ARM64 Firefox dev image — Debian bookworm base.
#
# Ubuntu 22.04 replaced firefox with a snap stub on ALL versions.
# Debian bookworm + Mozilla's official apt repo gives a real firefox .deb
# for arm64 with the latest stable release.

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

# ── Stage 2: Debian bookworm desktop + Firefox ───────────────────────────
FROM debian:bookworm-slim

ARG VERSION
ARG PACKAGE=firefox
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
    # Mozilla official apt repo — ships latest stable Firefox as a real .deb\
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
        | gpg --dearmor -o /usr/share/keyrings/mozilla.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
        > /etc/apt/sources.list.d/mozilla.list && \
    # Pin Mozilla repo above Debian so 'firefox' resolves here, not to firefox-esr\
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
        > /etc/apt/preferences.d/mozilla && \
    apt-get update && \
    # Desktop tools\
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
        libavcodec59 \
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
        iproute2 && \
    # Firefox from Mozilla repo\
    apt-get install -y --no-install-recommends \
        ${PACKAGE}${VERSION:+=$VERSION} && \
    firefox --version && \
    # Timezone\
    echo UTC | tee /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    # Locale\
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/default/locale && \
    fc-cache -f && \
    # selenium user\
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
