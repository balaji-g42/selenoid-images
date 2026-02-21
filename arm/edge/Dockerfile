# ARM64 Microsoft Edge final image.
# Key difference: msedgedriver is downloaded for linux_arm64 instead of
# linux64.  Microsoft publishes arm64 drivers at the same CDN URL with a
# different archive name.
ARG DEV_IMAGE
ARG VERSION
FROM ${DEV_IMAGE}

# Pin DRIVER_VERSION to the version that matches the Edge release.
# Pass this via --build-arg DRIVER_VERSION=<version> (e.g. 135.0.3179.54).
ARG DRIVER_VERSION

ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends curl unzip && \
    curl -fsSL \
      "https://msedgewebdriverstorage.blob.core.windows.net/edgewebdriver/${DRIVER_VERSION}/edgedriver_linux_arm64.zip" \
      -o /tmp/msedgedriver.zip && \
    unzip -j /tmp/msedgedriver.zip msedgedriver -d /usr/bin/ && \
    chmod +x /usr/bin/msedgedriver && \
    rm -f /tmp/msedgedriver.zip && \
    echo "cookie-file = ~/.config/pulse/cookie" >> /etc/pulse/client.conf && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /

USER selenium

EXPOSE 4444
ENTRYPOINT ["/entrypoint.sh"]
