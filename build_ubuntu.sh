#!/bin/bash
set -euo pipefail

# Upstream Linux architectures for forgejo-runner (https://code.forgejo.org/forgejo/runner):
#   amd64  -> forgejo-runner-<version>-linux-amd64(.xz)
#   arm64  -> forgejo-runner-<version>-linux-arm64(.xz)
#
# amd64 and arm64 only.
# TODO: implement forgejo-runner build

forgejo_runner_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$forgejo_runner_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <forgejo_runner_version> <build_version> [architecture]"
    echo "Example: $0 1.2.3 1 arm64"
    echo "Example: $0 1.2.3 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

echo "build_ubuntu.sh for forgejo-runner is not implemented yet."
exit 1
