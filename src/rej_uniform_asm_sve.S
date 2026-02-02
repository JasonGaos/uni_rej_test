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

    // ============================================================
    // PROLOGUE: Save SVE registers
    // ============================================================
    // Simple fixed-size save (assumes VL <= 256 bits = 32 bytes)
    // Stack layout (growing down):
    //   [sp-48] ... [sp-1]  : 48 bytes total
    //   [sp-48]..[sp-17]    : z0 (32 bytes max, for 256-bit SVE)
    //   [sp-16]..[sp-1]     : p0 (16 bytes, over-provisioned)

    sub sp, sp, #48       // Allocate 48 bytes on stack

    // Save z0 first (vector register, VL bytes)
    // Use unpredicated store to save entire register
    str z0, [sp, #16]     // Save z0 at [sp+16]

    // Save p0 (predicate register)
    str p0, [sp]          // Save p0 at [sp]

    // ============================================================
    // FUNCTION BODY: Your SVE code here
    // ============================================================
    // Now you can freely modify p0 and z0
    ptrue p0.b            // Modifies p0 (safe, we saved it)
    eor z0.b, z0.b, z0.b  // Modifies z0 (safe, we saved it)

    // ============================================================
    // EPILOGUE: Restore SVE registers (in REVERSE order!)
    // ============================================================
    // Restore p0 first (saved second, restore first)
    ldr p0, [sp]          // Restore p0 from [sp]

    // Restore z0 last (saved first, restore last)
    ldr z0, [sp, #16]     // Restore z0 from [sp+16]

    // Clean up stack
    add sp, sp, #48       // Deallocate 48 bytes

    // Return 0 for now
    mov x0, #0
    ret

/* simpasm: footer-start */
#endif /* MLD_ARITH_BACKEND_AARCH64 && !MLD_CONFIG_MULTILEVEL_NO_SHARED */
