#!/bin/bash

set -e

echo "==> Installing dev tools..."
apt update -q
apt install -y cmake ninja-build git python3-pip clang-format bear

echo "==> Cloning your repos..."
git clone https://github.com/mille-printemps/rocm-playground.git

echo "==> Installing Python tools..."
pip3 install lit pytest numpy

echo "==> Verifying ROCm..."
rocminfo | grep "Agent Type" | head -5

echo ""
echo "✓ Ready."
