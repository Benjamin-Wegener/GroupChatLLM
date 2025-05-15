#!/bin/bash
set -e

TARGET="$1"
cd /mnt/project

# Initialize submodule if missing
[ ! -d "ik_llama.cpp" ] && git submodule add https://github.com/ikawrakow/ik_llama.cpp.git ik_llama.cpp
git submodule update --init --recursive

# Create or reuse build directory
mkdir -p build-"$TARGET"
cd build-"$TARGET"

# Server-only CMake config
CMAKE_ARGS="-DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TESTS=OFF -DBUILD_SHARED_LIBS=ON"

# Configure build
CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ cmake ../ik_llama.cpp $CMAKE_ARGS -DGGML_ARCH_FLAGS="-march=armv8.2-a+dotprod+fp16"

# Build
make -j$(nproc)

# Collect binaries
mkdir -p bin
find . -type f -executable -name '*server*' | head -n1 | xargs -I{} cp "{}" bin/llama-server || echo "⚠️ No server binary found"
find . -type f -executable -name 'llama-cli' | head -n1 | xargs -I{} cp "{}" bin/llama-cli || echo "ℹ️ No CLI found"

# Final directory listing
echo "✅ Final bin contents:"
ls -lh bin/
