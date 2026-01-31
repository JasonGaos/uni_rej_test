# ML-DSA rej_uniform_asm Test Repository

This repository contains a standalone test suite for the `rej_uniform_asm` function from the ML-DSA implementation. It tests the NEON-optimized assembly implementation for AArch64 processors.

## Purpose

This is a test repository for developing and testing the `rej_uniform_asm` function. The goal is to eventually rewrite this assembly code using SVE/SVE2 instructions while maintaining correctness.

## File Structure

```
.
├── common.h                          # Shared macros for assembly and C
├── Makefile                          # Build configuration
├── test.c                             # Test suite
└── src/
    ├── rej_uniform_asm.S             # Assembly implementation (NEON)
    ├── rej_uniform_table.c           # Lookup table data
    └── include/
        └── arith_native_aarch64.h   # C function declarations
```

## Building

### Prerequisites

- An AArch64 Linux system or ARM64 macOS system
- GCC compiler with AArch64 support
- Make utility

### Build Commands

```bash
# Build the test executable
make

# Build and run tests
make run

# Clean build artifacts
make clean

# Show help
make help
```

## Running the Tests

```bash
# Run all tests
./test_rej_uniform
```

### Test Cases

1. **Test 1 - Basic**: All values accepted (small values < MLDSA_Q)
2. **Test 2 - With Rejection**: Mixed accepted/rejected values (240 bytes)
3. **Test 3 - Small Input**: Exactly 24 bytes (8 triples)
4. **Test 4 - All Rejected**: All values >= MLDSA_Q

## Known Issues

The current NEON implementation has a bug where it **does not process partial data at the end** that is not a multiple of 24 bytes. This causes Test 2 to fail when the input size is not aligned to 24 bytes.

### Expected Behavior vs Actual

| Input Size | Expected Coefficients | ASM Output | Status |
|------------|----------------------|------------|--------|
| 240 (multiple of 24) | 60 | 60 | ✓ PASS |
| 300 (NOT multiple of 24) | 75 | 72 | ✗ FAIL |

The assembly processes data in chunks of 48 bytes (main loop) and 24 bytes (tail loop), but discards any remaining bytes that are less than 24.

## Function Signature

```c
uint64_t mldsa_rej_uniform_asm(
    int32_t *r,              // Output: array of coefficients
    const uint8_t *buf,      // Input: random bytes
    unsigned buflen,         // Input length in bytes
    const uint8_t *table     // Lookup table for permutation
);
```

Returns: Number of coefficients successfully sampled (max 256)

## Algorithm Description

The function performs **rejection sampling** to convert random bytes into uniformly random integers in the range [0, 8380416]:

1. Read 3 bytes from input
2. Combine into a 24-bit value (masking the top bit)
3. If value < 8,380,417 (MLDSA_Q), accept it
4. Repeat until we have 256 coefficients or run out of input

## Cross-Platform Notes

- **Linux**: No underscore prefix on symbols
- **macOS**: Symbols get a leading underscore prefix
- The `common.h` header handles this automatically via `MLD_ASM_NAMESPACE` macro

## License

This code is derived from the mldsa-native project and is licensed under Apache-2.0 OR ISC OR MIT.
