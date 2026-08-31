FROM ghcr.io/cirruslabs/flutter:3.38.10@sha256:3a94866984c440444661873d06668b0c38817923b931780e7932370618c484ed AS flutter_sdk

RUN flutter config --no-analytics --enable-web \
    && flutter precache --web

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

ENV FLUTTER_ROOT=/opt/flutter \
    PUB_CACHE=/home/vscode/.pub-cache \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}

RUN apt-get update \
    && apt-get install --yes --no-install-recommends libglu1-mesa \
    && rm -rf /var/lib/apt/lists/* \
    && (gpasswd --delete vscode sudo 2>/dev/null || true) \
    && rm -f /etc/sudoers.d/vscode \
    && mkdir -p /home/vscode/.pub-cache \
    && chown -R vscode:vscode /home/vscode/.pub-cache

COPY --chown=vscode:vscode --from=flutter_sdk /sdks/flutter /opt/flutter

USER vscode
