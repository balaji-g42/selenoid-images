# ARM64 Chromium final image.
# chromedriver is provided by the chromium-chromedriver apt package
# already installed in the dev image — no architecture-specific binary
# download required.
# DEV_IMAGE is the full dev image tag built by build-arm-native.sh
# e.g. gbalajihbox/dev_chromium:latest
ARG DEV_IMAGE
ARG VERSION
FROM ${DEV_IMAGE}

ENV DBUS_SESSION_BUS_ADDRESS=/dev/null
COPY entrypoint.sh /

RUN \
    chmod +x /usr/bin/chromedriver && \
    echo "cookie-file = ~/.config/pulse/cookie" >> /etc/pulse/client.conf

USER selenium

EXPOSE 4444
ENTRYPOINT ["/entrypoint.sh"]
