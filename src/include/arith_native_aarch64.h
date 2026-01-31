#ifndef ARITH_NATIVE_AARCH64_H
#define ARITH_NATIVE_AARCH64_H

#include <stdint.h>

/* Alignment macro */
#define MLD_ALIGN __attribute__((aligned(32)))

/* Lookup table and function declarations */
#define mld_rej_uniform_table mldsa_rej_uniform_table
extern const uint8_t mld_rej_uniform_table[];

#define mld_rej_uniform_asm mldsa_rej_uniform_asm
uint64_t mld_rej_uniform_asm(int32_t *r, const uint8_t *buf, unsigned buflen,
                             const uint8_t *table);

#endif /* ARITH_NATIVE_AARCH64_H */
