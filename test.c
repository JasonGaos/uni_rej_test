#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#define MLDSA_N 256
#define MLDSA_Q 8380417

/* External assembly function and table */
extern const uint8_t mldsa_rej_uniform_table[];
extern uint64_t mldsa_rej_uniform_asm(int32_t *r, const uint8_t *buf, unsigned buflen,
                                      const uint8_t *table);

#if defined(HAVE_SVE)
extern uint64_t mldsa_rej_uniform_asm_sve(int32_t *r, const uint8_t *buf, unsigned buflen,
                                          const uint8_t *table);

// Use SVE function by default when HAVE_SVE is defined
#define REJ_UNIFORM_FN mldsa_rej_uniform_asm_sve
#define VARIANT_STR "SVE"
#else
// Use NEON function otherwise
#define REJ_UNIFORM_FN mldsa_rej_uniform_asm
#define VARIANT_STR "NEON"
#endif

/* Reference C implementation for verification */
static unsigned int rej_uniform_c_ref(int32_t *r, const uint8_t *buf, unsigned int len) {
    unsigned int count = 0;
    unsigned int pos = 0;

    while (count < MLDSA_N && pos + 3 <= len) {
        /* Get 24-bit value */
        uint32_t val = (buf[pos] & 0xFF) | ((buf[pos + 1] & 0xFF) << 8) | ((buf[pos + 2] & 0x7F) << 16);

        /* Check if value is in range [0, MLDSA_Q-1] */
        if (val < MLDSA_Q) {
            r[count++] = (int32_t)val;
        }
        pos += 3;
    }

    return count;
}

static void test_basic(void) {
    printf("Test 1: Basic rejection sampling with valid values...\n");

    int32_t output_asm[MLDSA_N];
    int32_t output_c[MLDSA_N];
    uint8_t input[MLDSA_N * 3];

    /* Fill with values that are all within range */
    for (int i = 0; i < MLDSA_N * 3; i++) {
        input[i] = i % 128;
    }

    memset(output_asm, 0, sizeof(output_asm));
    memset(output_c, 0, sizeof(output_c));

    uint64_t count_asm = REJ_UNIFORM_FN(output_asm, input, sizeof(input), mldsa_rej_uniform_table);
    unsigned int count_c = rej_uniform_c_ref(output_c, input, sizeof(input));

    printf("  ASM: %lu coefficients, C ref: %u coefficients\n", count_asm, count_c);

    int errors = 0;
    if (count_asm != count_c) {
        printf("  ERROR: Count mismatch!\n");
        errors++;
    }

    for (unsigned int i = 0; i < count_asm && i < count_c; i++) {
        if (output_asm[i] != output_c[i]) {
            printf("  ERROR: Mismatch at index %u: ASM=%d, C=%d\n", i, output_asm[i], output_c[i]);
            errors++;
        }
    }

    if (errors == 0) {
        printf("  PASSED!\n\n");
    } else {
        printf("  FAILED with %d errors!\n\n", errors);
    }
}

static void test_with_rejection(void) {
    printf("Test 2: Rejection sampling with some rejected values (240 bytes)...\n");

    int32_t output_asm[MLDSA_N];
    int32_t output_c[MLDSA_N];
    uint8_t input[240];

    /* Fill input with pattern that causes some rejections */
    for (int i = 0; i < 240; i++) {
        if (i % 4 == 0) {
            input[i] = 0xFF;
        } else if (i % 4 == 1) {
            input[i] = 0xFF;
        } else if (i % 4 == 2) {
            input[i] = 0x80;
        } else {
            input[i] = i % 64;
        }
    }

    memset(output_asm, 0, sizeof(output_asm));
    memset(output_c, 0, sizeof(output_c));

    uint64_t count_asm = REJ_UNIFORM_FN(output_asm, input, sizeof(input), mldsa_rej_uniform_table);
    unsigned int count_c = rej_uniform_c_ref(output_c, input, sizeof(input));

    printf("  ASM: %lu coefficients, C ref: %u coefficients\n", count_asm, count_c);

    int errors = 0;
    if (count_asm != count_c) {
        printf("  ERROR: Count mismatch (delta=%d)!\n", (int)count_c - (int)count_asm);
        errors++;
    }

    for (unsigned int i = 0; i < count_asm && i < count_c; i++) {
        if (output_asm[i] != output_c[i]) {
            if (errors < 5) {  /* Only show first 5 mismatches */
                printf("  ERROR: Mismatch at index %u: ASM=%d, C=%d\n", i, output_asm[i], output_c[i]);
            }
            errors++;
        }
    }

    if (errors == 0) {
        printf("  PASSED!\n\n");
    } else {
        printf("  FAILED with %d errors!\n\n", errors);
    }
}

static void test_small_input(void) {
    printf("Test 3: Small input (24 bytes = 8 triples)...\n");

    int32_t output_asm[MLDSA_N];
    int32_t output_c[MLDSA_N];
    uint8_t input[24];

    for (int i = 0; i < 24; i++) {
        input[i] = i;
    }

    memset(output_asm, 0, sizeof(output_asm));
    memset(output_c, 0, sizeof(output_c));

    uint64_t count_asm = REJ_UNIFORM_FN(output_asm, input, sizeof(input), mldsa_rej_uniform_table);
    unsigned int count_c = rej_uniform_c_ref(output_c, input, sizeof(input));

    printf("  ASM: %lu coefficients, C ref: %u coefficients (expected 8)\n", count_asm, count_c);

    int errors = 0;
    if (count_asm != 8 || count_c != 8) {
        printf("  ERROR: Unexpected count!\n");
        errors++;
    }

    for (unsigned int i = 0; i < count_asm && i < count_c; i++) {
        if (output_asm[i] != output_c[i]) {
            printf("  ERROR: Mismatch at index %u: ASM=%d, C=%d\n", i, output_asm[i], output_c[i]);
            errors++;
        }
    }

    if (errors == 0) {
        printf("  PASSED!\n\n");
    } else {
        printf("  FAILED with %d errors!\n\n", errors);
    }
}

static void test_all_rejected(void) {
    printf("Test 4: All values rejected (48 bytes)...\n");

    int32_t output_asm[MLDSA_N];
    int32_t output_c[MLDSA_N];
    uint8_t input[48];

    for (int i = 0; i < 48; i++) {
        input[i] = 0xFF;
    }

    memset(output_asm, 0, sizeof(output_asm));
    memset(output_c, 0, sizeof(output_c));

    uint64_t count_asm = REJ_UNIFORM_FN(output_asm, input, sizeof(input), mldsa_rej_uniform_table);
    unsigned int count_c = rej_uniform_c_ref(output_c, input, sizeof(input));

    printf("  ASM: %lu coefficients, C ref: %u coefficients (expected 0)\n", count_asm, count_c);

    int errors = 0;
    if (count_asm != 0 || count_c != 0) {
        printf("  ERROR: Expected 0 coefficients!\n");
        errors++;
    }

    if (errors == 0) {
        printf("  PASSED!\n\n");
    } else {
        printf("  FAILED with %d errors!\n\n", errors);
    }
}

static void test_tail_bytes(void) {
    printf("Test 5: Tail bytes (300 bytes = NOT a multiple of 24)...\n");
    printf("  NOTE: NEON discards partial data, SVE handles it correctly\n");

    int32_t output_asm[MLDSA_N];
    int32_t output_c[MLDSA_N];
    uint8_t input[300];

    /* Fill with sequential values */
    for (int i = 0; i < 300; i++) {
        input[i] = i % 128;
    }

    memset(output_asm, 0, sizeof(output_asm));
    memset(output_c, 0, sizeof(output_c));

    uint64_t count_asm = REJ_UNIFORM_FN(output_asm, input, sizeof(input), mldsa_rej_uniform_table);
    unsigned int count_c = rej_uniform_c_ref(output_c, input, sizeof(input));

    printf("  ASM (%s): %lu coefficients, C ref: %u coefficients\n", VARIANT_STR, count_asm, count_c);

    int errors = 0;
    if (count_asm != count_c) {
        printf("  WARNING: Count mismatch! (delta=%d)\n", (int)count_c - (int)count_asm);
        printf("  Expected: %s should handle tail bytes correctly\n", VARIANT_STR);
        if (count_asm < count_c) {
            printf("  %s implementation is missing %u coefficients from tail bytes\n", VARIANT_STR, count_c - count_asm);
        }
        errors++;
    }

    for (unsigned int i = 0; i < count_asm && i < count_c; i++) {
        if (output_asm[i] != output_c[i]) {
            if (errors < 5) {
                printf("  ERROR: Mismatch at index %u: ASM=%d, C=%d\n", i, output_asm[i], output_c[i]);
            }
            errors++;
        }
    }

    if (errors == 0) {
        printf("  PASSED! (%s correctly handles tail bytes)\n\n", VARIANT_STR);
    } else {
        printf("  FAILED with %d errors!\n\n", errors);
    }
}

int main(void) {
    printf("==============================================\n");
    printf("ML-DSA rej_uniform_asm Test Suite (%s variant)\n", VARIANT_STR);
    printf("==============================================\n\n");

    test_basic();
    test_with_rejection();
    test_small_input();
    test_all_rejected();
    test_tail_bytes();

    printf("==============================================\n");
    printf("All tests completed!\n");
    printf("==============================================\n");

    return 0;
}
