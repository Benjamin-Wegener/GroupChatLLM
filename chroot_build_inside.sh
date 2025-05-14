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
    # Added ARM optimization flags for ARMv8.2-A with dot product and fp16 support
    CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ cmake ../ik_llama.cpp $CMAKE_ARGS -DGGML_ARCH_FLAGS="-march=armv8.2-a+dotprod+fp16"
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

# Make sure the server actually got built
echo "Checking for llama-server binary..."
if [ "$TARGET" = "cross-mingw64" ]; then
  # Check for Windows executable extension
  SERVER_PATH="bin/llama-server.exe"
else
  SERVER_PATH="bin/llama-server"
fi

if [ ! -f "$SERVER_PATH" ]; then
  echo "Server binary not found at expected path: $SERVER_PATH"
  # Try building the server specifically
  echo "Attempting to build server explicitly..."
  make -j$(nproc) server
  # List server folder contents for debugging
  echo "Contents of bin directory:"
  ls -la bin/
  # Check alternative paths
  ALTERNATE_PATHS=("bin/server" "server/llama-server" "server/server")
  for path in "${ALTERNATE_PATHS[@]}"; do
    if [ -f "$path" ]; then
      echo "Found server at: $path"
      # Create a symlink to ensure it can be found by the expected name
      mkdir -p bin
      ln -sf "../$path" "bin/llama-server"
      break
    fi
  done
fi

echo "Final bin directory contents:"
ls -la bin/
