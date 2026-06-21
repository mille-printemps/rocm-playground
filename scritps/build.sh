#!/bin/bash
# Usage:
#   ./scripts/build.sh            — build everything
#   ./scripts/build.sh clean      — clean and rebuild
#   ./scripts/build.sh vector_add — build one target only

set -e

BUILD_DIR="build"

# Detect platform and set compiler
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    export HIP_PLATFORM=nvidia
    echo "==> Detected NVIDIA GPU — targeting CUDA backend"

    COMPILER=$(which nvcc 2>/dev/null || echo "")
    if [ -z "$COMPILER" ]; then
        echo "Error: nvcc not found. Is the CUDA toolkit installed?"
        exit 1
    fi
    echo "    Compiler: $COMPILER"

else
    export HIP_PLATFORM=amd
    echo "==> Targeting AMD ROCm backend"

    # Find hipcc dynamically — don't assume /opt/rocm/bin
    COMPILER=$(which hipcc 2>/dev/null || echo "")
    if [ -z "$COMPILER" ]; then
        echo "Error: hipcc not found in PATH."
        echo "Try: find / -name hipcc 2>/dev/null"
        exit 1
    fi
    echo "    Compiler: $COMPILER"

    if [ "$HIP_PLATFORM" = "amd" ]; then
        # Derive ROCm root from hipcc location (strip /bin/hipcc)
        ROCM_PATH=$(dirname $(dirname "$COMPILER"))
        echo "    ROCm path: $ROCM_PATH"
    fi
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
    -DCMAKE_PREFIX_PATH="${ROCM_PATH:-/opt/rocm}" \
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
