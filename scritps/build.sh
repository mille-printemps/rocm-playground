#!/bin/bash
# Usage:
#   ./scripts/build.sh            — build everything
#   ./scripts/build.sh clean      — clean and rebuild
#   ./scripts/build.sh vector_add — build one target only

set -e

BUILD_DIR="build"
ROCM_PATH="${ROCM_PATH:-/opt/rocm}"

if [ "$1" = "clean" ]; then
    echo "==> Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    shift
fi

echo "==> Configuring with CMake + Ninja..."
cmake -B "$BUILD_DIR" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER="$ROCM_PATH/bin/hipcc" \
    -DCMAKE_PREFIX_PATH="$ROCM_PATH" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

# Copy compile_commands.json to root for clangd/VSCode
cp "$BUILD_DIR/compile_commands.json" .

if [ -n "$1" ]; then
    echo "==> Building target: $1"
    cmake --build "$BUILD_DIR" --target "$1"
else
    echo "==> Building all targets..."
    cmake --build "$BUILD_DIR"
fi

echo ""
echo "✓ Build complete. Binaries are in $BUILD_DIR/"
