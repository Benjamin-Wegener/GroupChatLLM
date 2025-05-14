#pragma once
#include <immintrin.h>

#ifndef MM256_SET_M128I
#define MM256_SET_M128I(m0, m1) \
  _mm256_insertf128_si256(_mm256_castsi128_si256(m0), m1, 1)
#endif
