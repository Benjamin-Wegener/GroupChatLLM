#!/bin/bash
set -e

TARGET="$1"
cd /mnt/project

# Ensure submodule is initialized
if [ ! -d "ik_llama.cpp" ]; then
  git submodule add https://github.com/ikawrakow/ik_llama.cpp.git ik_llama.cpp
  git submodule update --init --recursive
fi

# Prepare build dir
rm -rf build-"$TARGET" || true
mkdir -p build-"$TARGET"
cd build-"$TARGET"

# Select toolchain and build
CMAKE_ARGS="-DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_EXAMPLES=OFF"

case "$TARGET" in
  cross-mingw64)
    CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ cmake ../ik_llama.cpp $CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=../ik_llama.cpp/cmake/toolchains/mingw64.cmake
    ;;
  cross-aarch64)
    CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ cmake ../ik_llama.cpp $CMAKE_ARGS
    ;;
  native)
    cmake ../ik_llama.cpp $CMAKE_ARGS
    ;;
  *)
    echo "❌ Unknown target: $TARGET"
    exit 1
    ;;
esac

make -j$(nproc)
