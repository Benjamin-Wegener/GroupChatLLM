option(LLAMA_BUILD_SERVER "Build llama-server" ON)
option(LLAMA_BUILD_EXAMPLES "Build examples" OFF)
option(LLAMA_BUILD_TESTS "Build tests" OFF)

# Include macros and setup
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-march=native" HAS_MARCH_NATIVE)
if(HAS_MARCH_NATIVE)
  add_compile_options(-march=native)
endif()

add_compile_definitions(
  IQK_ALWAYS_INLINE=__attribute__((always_inline)) inline
)

# Add llama submodule
add_subdirectory(ik_llama.cpp)
