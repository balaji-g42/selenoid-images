# ARM64 Microsoft Edge dev image.
# Key fix: the apt sources list must use arch=arm64 (not arch=amd64).
# Microsoft ships arm64 .deb packages via the same packages.microsoft.com
# repository — only the architecture pin needs to change.
FROM browsers/base:7.4.2

ARG VERSION
ARG PACKAGE=microsoft-edge-stable
ARG INSTALL_DIR=msedge

LABEL browser=$PACKAGE:$VERSION

RUN \
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
        echo 'deb [arch=arm64] https://packages.microsoft.com/repos/edge stable main' \
          > /etc/apt/sources.list.d/microsoft-edge.list && \
        apt-get update && \
        apt-get -y --no-install-recommends install ${PACKAGE}${VERSION:+=$VERSION} && \
        ( \
          sed -i -e 's@exec -a "$0" "$HERE/msedge"@& --no-sandbox --disable-gpu@' \
            /opt/microsoft/$INSTALL_DIR/$PACKAGE || \
          sed -i -e 's@exec -a "$0" "$HERE/msedge"@& --no-sandbox --disable-gpu@' \
            /opt/microsoft/$INSTALL_DIR/microsoft-edge \
        ) && \
        ( chown root:root /opt/microsoft/$INSTALL_DIR/msedge-sandbox && \
          chmod 4755 /opt/microsoft/$INSTALL_DIR/msedge-sandbox ) || true && \
        microsoft-edge --version && \
        rm -Rf /tmp/* && rm -Rf /var/lib/apt/lists/*
