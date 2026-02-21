# ARM64-compatible Firefox dev image.
# Firefox is available in Ubuntu's multi-arch apt repos (and via Mozilla
# PPA) for arm64 — the existing apt install approach works without changes.
FROM browsers/base:7.4.2

ARG VERSION
ARG PACKAGE=firefox
ARG PPA

LABEL browser=$PACKAGE:$VERSION

RUN \
        ( [ "$PPA" != "" ] && \
            apt-get update && \
            apt-get install -y software-properties-common && \
            apt-get update && \
            add-apt-repository -y $PPA \
        ) || true && \
        apt-get update && \
        apt-get -y --no-install-recommends install iproute2 libavcodec58 ${PACKAGE}${VERSION:+=$VERSION} && \
        ( [ "$PACKAGE" != "firefox" ] && ln /usr/bin/$PACKAGE /usr/bin/firefox ) || true && \
        firefox --version && \
        rm -Rf /tmp/* && rm -Rf /var/lib/apt/lists/*
