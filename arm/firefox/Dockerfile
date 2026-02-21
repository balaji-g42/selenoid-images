# ARM64 Firefox final image.
# Key differences from the amd64 version:
#   - geckodriver is downloaded for linux-aarch64 instead of linux64
#   - selenoid is downloaded for linux_arm64 instead of linux_amd64
#   - browsers.json is generated from a template via sed at build time
ARG VERSION
FROM selenoid/dev_firefox:$VERSION

# Override these to pin specific binary versions.
ARG GECKODRIVER_VERSION=0.35.0
ARG SELENOID_VERSION=1.11.3
# FIREFOX_MAJOR_VERSION is used as the key in browsers.json.
# The build script derives this from VERSION (e.g. "135.0+build1..." → "135.0").
ARG FIREFOX_MAJOR_VERSION

ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    # --- geckodriver arm64 ---
    curl -fsSL \
      "https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux-aarch64.tar.gz" \
      | tar -xz -C /usr/bin/ && \
    chmod +x /usr/bin/geckodriver && \
    # --- selenoid arm64 ---
    curl -fsSL \
      "https://github.com/aerokube/selenoid/releases/download/${SELENOID_VERSION}/selenoid_linux_arm64" \
      -o /usr/bin/selenoid && \
    chmod +x /usr/bin/selenoid && \
    echo "cookie-file = ~/.config/pulse/cookie" >> /etc/pulse/client.conf && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# browsers.json template — @@VERSION@@ substituted at build time.
COPY --chown=selenium:root browsers.json /home/selenium/browsers.json.tmpl
RUN sed "s/@@VERSION@@/${FIREFOX_MAJOR_VERSION}/g" \
      /home/selenium/browsers.json.tmpl \
      > /home/selenium/browsers.json && \
    rm /home/selenium/browsers.json.tmpl && \
    chown selenium:root /home/selenium/browsers.json

COPY entrypoint.sh /

USER selenium

EXPOSE 4444
ENTRYPOINT ["/entrypoint.sh"]
