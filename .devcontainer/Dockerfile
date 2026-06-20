FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG FLUTTER_VERSION=3.44.0
ARG SERVERPOD_CLI_VERSION=3.4.8
ARG SERVERPOD_CLOUD_CLI_VERSION=0.30.0
ARG LEFTHOOK_VERSION=2.1.9
ARG PATROL_CLI_VERSION=4.4.0

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        ca-certificates \
        postgresql-client \
    && ARCH=$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/arm64/') \
    && curl -sL "https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION}_Linux_${ARCH}" \
         -o /usr/local/bin/lefthook \
    && chmod +x /usr/local/bin/lefthook \
    && rm -rf /var/lib/apt/lists/*

USER vscode
WORKDIR /home/vscode

ENV FLUTTER_HOME=/home/vscode/flutter
ENV PUB_CACHE=/home/vscode/.pub-cache
ENV PATH=${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PUB_CACHE}/bin:${PATH}

RUN mkdir -p /home/vscode/.claude \
    && git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && git config --global --add safe.directory ${FLUTTER_HOME} \
    && git config --global --add safe.directory /workspaces/nabrudno \
    && flutter config --no-analytics --no-cli-animations \
    && flutter precache --web --no-android --no-ios --no-linux --no-macos --no-windows --no-fuchsia \
    && dart pub global activate serverpod_cli ${SERVERPOD_CLI_VERSION} \
    && dart pub global activate serverpod_cloud_cli ${SERVERPOD_CLOUD_CLI_VERSION} \
    && dart pub global activate patrol_cli ${PATROL_CLI_VERSION}
