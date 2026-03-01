#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# 0. Detect container runtime.
#    Prefer `container` (https://github.com/apple/container) when available,
#    fall back to `docker`. The CLI surface used here (image list, build, run)
#    is identical across both runtimes.
# ---------------------------------------------------------------------------
if command -v container &>/dev/null; then
    RUNTIME=container
elif command -v docker &>/dev/null; then
    RUNTIME=docker
else
    echo "Error: no container runtime found. Install apple/container or docker." >&2
    exit 1
fi
echo "==> Using container runtime: $RUNTIME"

# ---------------------------------------------------------------------------
# 1. Derive a cache key from the Containerfile content + today's date.
#    A new key means a new image tag, triggering a fresh build.
#    An existing tag skips the container build entirely.
#    Including the date ensures the image is rebuilt at least once per day,
#    picking up the latest Zig master nightly.
# ---------------------------------------------------------------------------
CACHE_KEY=$(printf '%s%s' "$(cat Containerfile.coverage)" "$(date +%Y-%m-%d)" | shasum -a 256 | cut -c1-8)
IMAGE="zig-clap-coverage:${CACHE_KEY}"

if $RUNTIME image inspect "$IMAGE" &>/dev/null; then
    echo "==> Image ${IMAGE} already exists, skipping build."
else
    echo "==> Building coverage image ${IMAGE}..."
    $RUNTIME build \
        -t "$IMAGE" \
        -f Containerfile.coverage \
        .
fi

# ---------------------------------------------------------------------------
# 2. Run the test binary under kcov inside the container.
# ---------------------------------------------------------------------------
echo "==> Running tests with coverage..."
$RUNTIME run --rm \
    -v "$REPO_ROOT:/src" \
    -w /src \
    "$IMAGE" \
    sh -c '
        set -e
        mkdir -p zig-out/bin zig-out/coverage
        zig test clap.zig --test-no-exec -femit-bin=zig-out/bin/clap-tests -fllvm
        kcov --clean \
             --include-pattern=clap \
             zig-out/coverage \
             zig-out/bin/clap-tests
    '

echo ""
echo "==> Coverage report: $REPO_ROOT/zig-out/coverage/index.html"
