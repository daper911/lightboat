# Build environment for the Lightboat Android client (a FlClash fork).
# DRAFT, written 2026-10-04 and not built yet: verify on the first build (milestone M0) and fix here.
# Toolchain versions follow FlClash's release CI (.github/workflows/build.yaml, android/gradle/libs.versions.toml);
# when you merge a newer FlClash, re-check them there.
#
#   sudo docker build -t lightboat-android-env -f env/Dockerfile env/
#   sudo docker run --rm -it -v "$PWD":/work -w /work \
#     -v lb-gradle:/root/.gradle -v lb-pub:/root/.pub-cache -v lb-go:/root/go -v lb-cargo:/root/.cargo/registry \
#     lightboat-android-env bash -lc 'flutter pub get && dart setup.dart android --arch arm64'
FROM ubuntu:24.04

ARG FLUTTER_VERSION=3.47.4
ARG GO_VERSION=1.26.4
# https://dl.google.com/android/repository/repository2-3.xml lists the current revisions.
ARG ANDROID_CMDLINE_TOOLS=16111833
ARG ANDROID_PLATFORM=android-37.0
ARG ANDROID_BUILD_TOOLS=37.0.0
ARG ANDROID_NDK=28.2.13676358

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip file \
      openjdk-17-jdk-headless \
      build-essential clang cmake ninja-build pkg-config python3 \
    && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Android SDK + NDK. Gradle may fetch an exact platform/build-tools revision on its own; licenses are
# accepted here so that works non-interactively.
ENV ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk
RUN mkdir -p "$ANDROID_HOME/cmdline-tools" \
    && curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" -o /tmp/clt.zip \
    && unzip -q /tmp/clt.zip -d /tmp/clt && mv /tmp/clt/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest" \
    && rm -rf /tmp/clt /tmp/clt.zip
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
RUN yes | sdkmanager --licenses >/dev/null \
    && sdkmanager "platform-tools" "platforms;${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}" "ndk;${ANDROID_NDK}"

# Go (mihomo core)
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xz
ENV PATH=/usr/local/go/bin:/root/go/bin:$PATH

# Rust (FlClash plugins/rust_api), with the Android targets
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/root/.cargo
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable \
    && /root/.cargo/bin/rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
ENV PATH=/root/.cargo/bin:$PATH

# Flutter, pinned
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH
RUN git config --global --add safe.directory '*' \
    && flutter config --no-analytics --no-cli-animations \
    && dart --disable-analytics \
    && flutter precache --android \
    && flutter doctor -v

WORKDIR /work
