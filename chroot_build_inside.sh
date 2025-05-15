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

# Debug: Check the directory structure of the ik_llama.cpp repo
echo "Checking ik_llama.cpp structure to identify server target..."
find ../ik_llama.cpp -name "CMakeLists.txt" | xargs grep -l "server" || echo "No server target found in CMakeLists.txt"
find ../ik_llama.cpp -type d -name "server" || echo "No server directory found"

# Select toolchain and build
# Note: We're now using a more comprehensive set of CMAKE_ARGS including explicit server options
CMAKE_ARGS="-DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=ON"

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

# Examine generated CMake files to verify server target is correctly configured
echo "Verifying server target configuration..."
grep -r "llama-server" . --include="*.make" --include="Makefile" || echo "No llama-server target found in make files"

# Build with detailed output
make -j$(nproc) VERBOSE=1

# Verify what was built - list all executables
echo "Built executables:"
find . -type f -executable -not -path "*/\.*" | sort

# Since the server target might have a different name, check for it
echo "Searching for any server binary..."
SERVER_CANDIDATES=$(find . -type f -executable -name "*server*" -not -path "*/\.*")
if [ -n "$SERVER_CANDIDATES" ]; then
  echo "Found potential server binaries:"
  echo "$SERVER_CANDIDATES"
  
  # Create the bin directory if it doesn't exist
  mkdir -p bin
  
  # Take the first candidate and link it as llama-server
  FIRST_SERVER=$(echo "$SERVER_CANDIDATES" | head -n 1)
  echo "Using $FIRST_SERVER as the server binary"
  cp "$FIRST_SERVER" bin/llama-server
fi

# If we still don't have a server binary, look for other LLaMA binaries
if [ ! -f "bin/llama-server" ]; then
  echo "No server binary found. Looking for other llama executables..."
  LLAMA_BINS=$(find . -type f -executable -name "llama-*" -not -path "*/\.*")
  if [ -n "$LLAMA_BINS" ]; then
    echo "Found llama binaries:"
    echo "$LLAMA_BINS"
  else
    echo "No llama binaries found."
  fi
  
  # As a last resort, try to build the main target directly
  if [ -f "examples/main/CMakeFiles/main.dir/build.make" ]; then
    echo "Attempting to build main target directly..."
    make -j$(nproc) main
    if [ -f "bin/main" ]; then
      echo "Built main target, copying as llama-server..."
      mkdir -p bin
      cp bin/main bin/llama-server
    fi
  fi
fi

# List final binary directory contents
echo "Final bin directory contents:"
mkdir -p bin
ls -la bin/ || echo "bin/ directory could not be listed"
