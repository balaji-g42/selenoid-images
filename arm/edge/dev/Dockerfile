# Microsoft Edge does NOT have a Linux arm64 build.
# See: https://learn.microsoft.com/en-us/microsoft-edge/deploy/linux
# Only amd64 Linux packages are published at packages.microsoft.com/repos/edge.
#
# This Dockerfile intentionally fails at build time with a clear message.
FROM debian:bookworm-slim
RUN echo "" && \
    echo "ERROR: Microsoft Edge is not available for Linux arm64 / aarch64." && \
    echo "       Microsoft only publishes amd64 Linux packages." && \
    echo "       Use Chromium or Firefox as an arm64-compatible alternative." && \
    echo "" && \
    exit 1
