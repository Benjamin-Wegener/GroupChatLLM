cmake_minimum_required(VERSION 3.14)
project(GroupChatLLM LANGUAGES CXX C)

# === Build Type Configuration ===
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING
      "Choose the type of build, options are: Debug Release RelWithDebInfo MinSizeRel."
      FORCE)
endif()

# === Compiler Settings ===
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# === Optimize for local CPU ===
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-march=native" HAS_MARCH_NATIVE)
if(HAS_MARCH_NATIVE)
  add_compile_options(-march=native)
endif()

# === Optional OpenBLAS Acceleration ===
find_package(OpenBLAS QUIET)

if(OpenBLAS_FOUND)
  message(STATUS "✅ OpenBLAS found, enabling acceleration")
  include_directories(${OpenBLAS_INCLUDE_DIRS})
  link_directories(${OpenBLAS_LIBRARY_DIRS})
  add_definitions(-DUSE_OPENBLAS)
else()
  message(STATUS "ℹ️ OpenBLAS not found, using fallback math")
endif()

# === Define SIMD / helper macros before submodule ===
add_compile_definitions(
  IQK_ALWAYS_INLINE=__attribute__((always_inline)) inline
)

# === Inject macro header globally without modifying submodules ===
include_directories(${CMAKE_SOURCE_DIR}/include)
add_compile_options(-include injected_macros.h)

# === Enable llama-server ===
set(LLAMA_BUILD_SERVER ON CACHE BOOL "Build llama-server" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "Disable examples" FORCE)

# === Add ik_llama.cpp submodule ===
message(STATUS "🔧 Adding submodule ik_llama.cpp")
add_subdirectory(ik_llama.cpp)
