#!/bin/bash
set -e

TARGET="$1"
cd /mnt/project

# Ensure submodule is initialized
if [ ! -d "ik_llama" ]; then
  git submodule add https://github.com/ikawrakow/ik_llama.cpp.git ik_llama
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
    CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ cmake ../ik_llama $CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=../ik_llama/cmake/toolchains/mingw64.cmake
    ;;
  cross-mingw32)
    CC=i686-w64-mingw32-gcc CXX=i686-w64-mingw32-g++ cmake ../ik_llama $CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=../ik_llama/cmake/toolchains/mingw32.cmake
    ;;
  cross-aarch64)
    CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ cmake ../ik_llama $CMAKE_ARGS
    ;;
  cross-i386)
    CC=i686-linux-gnu-gcc CXX=i686-linux-gnu-g++ cmake ../ik_llama $CMAKE_ARGS
    ;;
  native)
    cmake ../ik_llama $CMAKE_ARGS
    ;;
  *)
    echo "❌ Unknown target: $TARGET"
    exit 1
    ;;
esac

make -j$(nproc)
