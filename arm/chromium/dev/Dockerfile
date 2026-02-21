# ARM64-compatible Chromium dev image.
# chromium-browser and chromium-chromedriver are available in Ubuntu's
# multi-arch apt repos for arm64 — no arch= pin is needed.
FROM browsers/base:7.4.2

ARG VERSION
ARG PACKAGE=chromium-browser

LABEL browser=$PACKAGE:$VERSION

# ${VERSION:+=$VERSION} appends =<version> only when VERSION is non-empty,
# so omitting --build-arg VERSION installs the latest available package.
RUN \
    apt-get update && \
    apt-get -y --no-install-recommends install \
      iproute2 \
      libgtk-3-0 \
      ${PACKAGE}${VERSION:+=$VERSION} \
      chromium-chromedriver${VERSION:+=$VERSION} && \
    chromium-browser --version && \
    rm -Rf /tmp/* && rm -Rf /var/lib/apt/lists/*
