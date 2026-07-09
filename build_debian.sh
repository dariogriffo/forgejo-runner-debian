#!/bin/bash
set -euo pipefail

# Upstream Linux architectures for forgejo-runner (https://code.forgejo.org/forgejo/runner):
#   amd64  -> forgejo-runner-<version>-linux-amd64
#   arm64  -> forgejo-runner-<version>-linux-arm64
#
# amd64 and arm64 only.

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

# Returns the forgejo-runner release suffix for a given Debian architecture
get_forgejo_runner_release() {
    local arch=$1
    case "$arch" in
        "amd64") echo "linux-amd64" ;;
        "arm64") echo "linux-arm64" ;;
        *)       echo "" ;;
    esac
}

# Downloads the forgejo-runner binary for the given arch into a local directory
download_binary() {
    local build_arch=$1
    local release_suffix

    release_suffix=$(get_forgejo_runner_release "$build_arch")
    if [ -z "$release_suffix" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64"
        return 1
    fi

    if [ -f "$build_arch/forgejo-runner" ]; then
        echo "  Binary for $build_arch already downloaded, skipping."
        return 0
    fi

    mkdir -p "$build_arch"

    local url="https://code.forgejo.org/forgejo/runner/releases/download/v${forgejo_runner_VERSION}/forgejo-runner-${forgejo_runner_VERSION}-${release_suffix}"
    echo "  Downloading $url"
    if ! wget -q -O "$build_arch/forgejo-runner" "$url"; then
        echo "❌ Failed to download forgejo-runner binary for $build_arch"
        rm -f "$build_arch/forgejo-runner"
        return 1
    fi
    chmod +x "$build_arch/forgejo-runner"
}

build_architecture() {
    local build_arch=$1

    echo "Building Debian packages for architecture: $build_arch"

    if ! download_binary "$build_arch"; then
        return 1
    fi

    declare -a arr=("bookworm" "trixie" "forky" "sid")

    for dist in "${arr[@]}"; do
        FULL_VERSION="$forgejo_runner_VERSION-${BUILD_VERSION}+${dist}_${build_arch}"
        echo "  Building $FULL_VERSION"

        if ! docker build . -t "forgejo-runner-$dist-$build_arch" \
            --build-arg DEBIAN_DIST="$dist" \
            --build-arg FORGEJO_RUNNER_VERSION="$forgejo_runner_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg FORGEJO_RUNNER_RELEASE="$build_arch"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "forgejo-runner-$dist-$build_arch")"
        if ! docker cp "$id:/forgejo-runner_$FULL_VERSION.deb" - > "./forgejo-runner_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./forgejo-runner_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    echo "✅ Successfully built Debian packages for $build_arch"
    return 0
}

if [ "$ARCH" = "all" ]; then
    echo "🚀 Building forgejo-runner $forgejo_runner_VERSION-$BUILD_VERSION for all supported architectures (Debian)..."
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

    echo "🎉 All Debian packages built successfully!"
    echo "Generated packages:"
    ls -la forgejo-runner_*.deb
else
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
