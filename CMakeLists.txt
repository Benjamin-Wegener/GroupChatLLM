cmake_minimum_required(VERSION 3.14)
project(MultimodalCodingLab LANGUAGES CXX C)

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING
      "Choose the type of build, options are: Debug Release RelWithDebInfo MinSizeRel."
      FORCE)
endif()

# Compiler standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Detect CPU features automatically
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-march=native" HAS_MARCH_NATIVE)
if(HAS_MARCH_NATIVE)
  add_compile_options(-march=native)
endif()

# Try to find OpenBLAS (auto-detect only)
find_package(OpenBLAS QUIET)

if(OpenBLAS_FOUND)
  message(STATUS "✅ OpenBLAS found, enabling acceleration")
  include_directories(${OpenBLAS_INCLUDE_DIRS})
  link_directories(${OpenBLAS_LIBRARY_DIRS})
  add_definitions(-DUSE_OPENBLAS)
else()
  message(STATUS "ℹ️ OpenBLAS not found, using fallback math")
endif()

# Define common SIMD macros before including ik_llama
add_compile_definitions(
  IQK_ALWAYS_INLINE=__attribute__((always_inline)) inline
  MM256_SET_M128I(m0,m1)=_mm256_insertf128_si256(_mm256_castsi128_si256(m0), m1, 1)
)

# Include ik_llama submodule
message(STATUS "🔧 Adding submodule ik_llama.cpp")

set(LLAMA_BUILD_SERVER ON CACHE BOOL "Build llama-server" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "Disable examples" FORCE)

add_subdirectory(ik_llama.cpp)