#!/usr/bin/env bash
# Run a command inside the Lightboat build container, from the repository root.
#
#   env/run.sh flutter test
#   env/run.sh dart setup.dart android --arch arm64
#
# The lb-android volume keeps ~/.android/debug.keystore, so every development build is signed with the same
# key and installs over the previous one. Files the container writes are handed back to the calling user.
set -euo pipefail
cd "$(dirname "$0")/.."
tty=()
[ -t 0 ] && tty=(-it)
exec sudo docker run --rm "${tty[@]}" \
  -v "$PWD":/work -w /work \
  -v lb-gradle:/root/.gradle -v lb-pub:/root/.pub-cache \
  -v lb-go:/root/go -v lb-cargo:/root/.cargo/registry \
  -v lb-android:/root/.android \
  lightboat-env \
  bash -lc "$*; rc=\$?; chown -R $(id -u):$(id -g) /work; exit \$rc"
