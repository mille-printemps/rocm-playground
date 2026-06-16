#!/bin/bash
# Usage:
#   ./scripts/build.sh            — build everything
#   ./scripts/build.sh clean      — clean and rebuild
#   ./scripts/build.sh vector_add — build one target only

set -e

BUILD_DIR="build"
ROCM_PATH="${ROCM_PATH:-$(dirname $(dirname $(which hipcc)))}"

# Detect platform and set compiler
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    export HIP_PLATFORM=nvidia
    echo "==> Detected NVIDIA GPU — targeting CUDA backend"

    # Find nvcc
    COMPILER=$(which nvcc 2>/dev/null || echo "")
    if [ -z "$COMPILER" ]; then
        echo "Error: nvcc not found. Is the CUDA toolkit installed?"
        exit 1
    fi
    echo "    Compiler: $COMPILER"

else
    export HIP_PLATFORM=amd
    echo "==> Targeting AMD ROCm backend"

    # Find hipcc
    ROCM_PATH="${ROCM_PATH:-$(dirname $(dirname $(which hipcc)))}"
    COMPILER="$ROCM_PATH/bin/hipcc"
    if [ ! -f "$COMPILER" ]; then
        echo "Error: hipcc not found at $COMPILER"
        exit 1
    fi
    echo "    Compiler: $COMPILER"
fi

# Clean
if [ "$1" = "clean" ]; then
    echo "==> Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    shift
fi

# Configure
echo "==> Configuring with CMake + Ninja..."
cmake -B "$BUILD_DIR" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER="$COMPILER" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DHIP_PLATFORM="${HIP_PLATFORM}"

# Copy compile_commands.json to root for clangd/VSCode
cp "$BUILD_DIR/compile_commands.json" .

# Build
if [ -n "$1" ]; then
    echo "==> Building target: $1"
    cmake --build "$BUILD_DIR" --target "$1"
else
    echo "==> Building all targets..."
    cmake --build "$BUILD_DIR"
fi

echo ""
echo "✓ Build complete. Binaries are in $BUILD_DIR/"
