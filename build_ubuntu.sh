#!/bin/bash
set -euo pipefail

# Upstream Linux architectures for forgejo-runner (https://code.forgejo.org/forgejo/runner):
#   amd64  -> forgejo-runner-<version>-linux-amd64
#   arm64  -> forgejo-runner-<version>-linux-arm64
#
# amd64 and arm64 only. Reuses the binary downloaded by build_debian.sh.

forgejo_runner_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$forgejo_runner_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <forgejo_runner_version> <build_version> [architecture]"
    echo "Example: $0 12.13.0 1 arm64"
    echo "Example: $0 12.13.0 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

build_architecture() {
    local build_arch=$1

    if [ ! -f "$build_arch/forgejo-runner" ]; then
        echo "❌ Binary for $build_arch not found. Run build_debian.sh first."
        return 1
    fi

    echo "Building Ubuntu packages for architecture: $build_arch"

    declare -a arr=("jammy" "noble" "questing" "resolute")

    for dist in "${arr[@]}"; do
        FULL_VERSION="$forgejo_runner_VERSION-${BUILD_VERSION}+${dist}_${build_arch}_ubu"
        echo "  Building $FULL_VERSION"

        if ! docker build . -f Dockerfile.ubu -t "forgejo-runner-ubuntu-$dist-$build_arch" \
            --build-arg UBUNTU_DIST="$dist" \
            --build-arg FORGEJO_RUNNER_VERSION="$forgejo_runner_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg FORGEJO_RUNNER_RELEASE="$build_arch"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "forgejo-runner-ubuntu-$dist-$build_arch")"
        if ! docker cp "$id:/forgejo-runner_$FULL_VERSION.deb" - > "./forgejo-runner_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./forgejo-runner_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    echo "✅ Successfully built Ubuntu packages for $build_arch"
    return 0
}

if [ "$ARCH" = "all" ]; then
    echo "🚀 Building forgejo-runner $forgejo_runner_VERSION-$BUILD_VERSION for all supported architectures (Ubuntu)..."
    echo ""

    ARCHITECTURES=("amd64" "arm64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All Ubuntu packages built successfully!"
    echo "Generated packages:"
    ls -la forgejo-runner_*.deb
else
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
