/*
 * SVE implementation - testing instructions one by one
 */

#include "../../../common.h"
#if defined(MLD_ARITH_BACKEND_AARCH64) && \
    !defined(MLD_CONFIG_MULTILEVEL_NO_SHARED)
/* simpasm: header-end */

    .text
    .global MLD_ASM_NAMESPACE(rej_uniform_asm_sve)
    .balign 4
MLD_ASM_FN_SYMBOL(rej_uniform_asm_sve)
    // x0 = output, x1 = buf, x2 = buflen, x3 = table

    // Test: ptrue worked, now test eor to zero
    ptrue p0.b
    eor z0.b, z0.b, z0.b

    // Return 0 for now
    mov x0, #0
    ret

/* simpasm: footer-start */
#endif /* MLD_ARITH_BACKEND_AARCH64 && !MLD_CONFIG_MULTILEVEL_NO_SHARED */
