#ifndef ARITH_NATIVE_AARCH64_H
#define ARITH_NATIVE_AARCH64_H

#include <stdint.h>

/* Alignment macro */
#define MLD_ALIGN __attribute__((aligned(32)))

/* Lookup table and function declarations */
#define mld_rej_uniform_table mldsa_rej_uniform_table
extern const uint8_t mld_rej_uniform_table[];

/* NEON implementation (always available on AArch64) */
#define mld_rej_uniform_asm mldsa_rej_uniform_asm
uint64_t mld_rej_uniform_asm(int32_t *r, const uint8_t *buf, unsigned buflen,
                             const uint8_t *table);

/* SVE implementation (requires SVE support) */
#if defined(HAVE_SVE)
#define mld_rej_uniform_asm_sve mldsa_rej_uniform_asm_sve
uint64_t mld_rej_uniform_asm_sve(int32_t *r, const uint8_t *buf, unsigned buflen,
                                 const uint8_t *table);
#endif

#endif /* ARITH_NATIVE_AARCH64_H */
