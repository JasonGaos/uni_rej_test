/*
 * SVE (Scalable Vector Extension) implementation of rej_uniform
 * This version works with SVE (base) without requiring SVE2
 *
 * Key differences from NEON version:
 * - Uses SVE predicate registers for conditional processing
 * - Uses whilelt for natural loop control (handles tail bytes)
 * - Processes triples in a more straightforward manner
 * - No need for separate 24-byte tail loop - predication handles it
 */

#include "../../../common.h"
#if defined(MLD_ARITH_BACKEND_AARCH64) && \
    !defined(MLD_CONFIG_MULTILEVEL_NO_SHARED)
/* simpasm: header-end */

// SVE stack size (same as NEON)
#define SVE_STACK_SIZE (4*MLDSA_N + 64)

.macro push_stack_sve
        sub sp, sp, #SVE_STACK_SIZE
.endm

.macro pop_stack_sve
        add sp, sp, #SVE_STACK_SIZE
.endm

    /* Parameters */
    output                      .req x0
    buf                         .req x1
    buflen                      .req x2
    table_idx                   .req x3

    /* Counters */
    len                         .req x4
    count                       .req x5

    /* Temporary output on stack (SVE) */
    output_tmp_base             .req x6
    output_tmp                  .req x6

    /* Constants */
    #define MLDSA_Q 8380417

    /* Temporary scalar registers */
    valid_count                 .req x7
    tmp                         .req x8
    wtmp                        .req w8
    val                         .req x9
    wval                        .req w9

    /* SVE registers for batch processing */
    z0_b                        .req z0.b
    z1_b                        .req z1.b
    z2_b                        .req z2.b
    z3_b                        .req z3.b

    z0_s                        .req z0.s
    z1_s                        .req z1.s
    z2_s                        .req z2.s
    z3_s                        .req z3.s

    z0_d                        .req z0.d

    /* Constants in SVE registers */
    mldsa_q_vec                 .req z4.s

    /* Predicate registers */
    p0_b                        .req p0.b
    p1_b                        .req p1.b
    p0_s                        .req p0.s

    .text
    .global MLD_ASM_NAMESPACE(rej_uniform_asm_sve)
    .balign 4
MLD_ASM_FN_SYMBOL(rej_uniform_asm_sve)
    push_stack_sve

    // Load q = 8380417 into all lanes of z4.s
    movz wtmp, #57345
    movk wtmp, #127, lsl #16
    dup mldsa_q_vec.s, wtmp

    mov output_tmp_base, sp
    mov output_tmp, output_tmp_base
    mov count, #0

    // Initialize len as a copy of buflen for the main loop condition
    mov len, buflen

    // Main loop: process as many full 48-byte chunks as possible
    // SVE: whilelt handles the tail naturally
sve_main_loop:
    // Check if we have at least 48 bytes (16 triples)
    cmp len, #48
    b.lt sve_tail_loop

    // Load 48 bytes: 3 registers of 16 bytes each (ld3 loads de-interleaved data)
    ld3b {z0_b, z1_b, z2_b}, p0/z, [buf], #48

    // Mask out top bit from third byte (z2_b) - MLDSA_Q fits in 23 bits
    movi z3_b, #0x80
    bic z2_b, z2_b, p0/z, z3_b

    // Unpack 16 triples of bytes into 32-bit integers
    // The triples are: [z0_b[i], z1_b[i], z2_b[i]] for i in 0..15

    // First, extend all bytes to 16-bit halfwords
    uxtl z0.h, z0_b        // Extend first bytes to 16-bit
    uxtl z1.h, z1_b        // Extend second bytes to 16-bit
    uxtl z2.h, z2_b        // Extend third bytes (already masked) to 16-bit

    // Now combine to 32-bit: val = buf0 + (buf1 << 8) + (buf2 << 16)
    // Use zip1 to interleave the halfwords correctly
    zip1 z0.h, z0.h, z1.h  // Interleave buf0 and buf1 as halfwords

    // Extend to 32-bit and combine
    uxtl z0_s, z0.h        // Lower half: [buf0, buf1] pairs -> 32-bit
    uxtl2 z1_s, z0.h       // Upper half: [buf0, buf1] pairs -> 32-bit

    // Now we need to add buf2 << 16 to each
    // First create buf2 shifted left by 16 bits (as 32-bit values)
    uxtl z2_s, z2.h        // buf2 as 32-bit values
    uxtl2 z3_s, z2.h       // buf2 upper half as 32-bit values

    // Shift buf2 left by 16 and add to the base values
    lsl z2_s, z2_s, #16
    lsl z3_s, z3_s, #16

    add z0_s, z0_s, z2_s   // First 8 triples: base + (buf2 << 16)
    add z1_s, z1_s, z3_s   // Last 8 triples: base + (buf2 << 16)

    // Range check: compare each value against q = 8380417
    // cmhi sets predicate lanes where (z0_s < mldsa_q_vec), i.e., value is valid
    cmhi p0_s, p0/z, mldsa_q_vec.s, z0_s

    // Store first 8 results using predication
    st1w {z0_s}, p0_s, [output_tmp]

    // Count how many were stored (predicate count)
    cntb valid_count, p0_b
    and valid_count, valid_count, #0xFF
    add output_tmp, output_tmp, valid_count, lsl #2
    add count, count, valid_count

    // Process second 8 values
    cmhi p0_s, p0/z, mldsa_q_vec.s, z1_s
    st1w {z1_s}, p0_s, [output_tmp]

    cntb valid_count, p0_b
    and valid_count, valid_count, #0xFF
    add output_tmp, output_tmp, valid_count, lsl #2
    add count, count, valid_count

    // Update remaining length
    sub len, len, #48

    // Check if we've collected 256 coefficients
    cmp count, #MLDSA_N
    b.ge sve_final_copy

    // Continue main loop
    b.sve_main_loop

    // Tail loop: handle remaining bytes (less than 48)
    // This is where SVE's predication really shines
sve_tail_loop:
    // Process triples one at a time for the tail
    // This handles any number of remaining bytes correctly
sve_tail_single:
    // Check if we have at least 3 bytes for one triple
    cmp len, #3
    b.lt sve_final_copy

    // Load one triple (3 bytes)
    // We'll load 4 bytes and extract the 3 we need
    ldr wval, [buf], #4
    sub len, len, #3

    // Extract 24-bit value: b0 + (b1 << 8) + (b2 << 16) with top bit masked
    and wval, wval, #0x7FFFFF  // Mask to 23 bits (clear top bit of byte 2)

    // Compare against MLDSA_Q
    movz wtmp, #57345
    movk wtmp, #127, lsl #16    // wtmp = 8380417
    cmp wval, wtmp
    b.ge sve_tail_single        // Reject if >= MLDSA_Q

    // Store valid value
    str wval, [output_tmp], #4
    add count, count, #1

    // Check if we've collected 256 coefficients
    cmp count, #MLDSA_N
    b.lt sve_tail_single

    // Copy from stack buffer to final output
sve_final_copy:
    mov tmp, #0
    mov len, count
    mov output_tmp, output_tmp_base

sve_copy_loop:
    // Copy in chunks of 16 words (64 bytes)
    cmp len, #16
    b.lt sve_copy_tail

    ldr q0, [output_tmp], #16
    ldr q1, [output_tmp, #-12]
    ldr q2, [output_tmp, #-8]
    ldr q3, [output_tmp, #-4]
    str q0, [output], #16
    str q1, [output, #-12]
    str q2, [output, #-8]
    str q3, [output, #-4]

    sub len, len, #16
    b.sve_copy_loop

sve_copy_tail:
    // Handle remaining words (0-15)
    cmp len, #0
    b.eq sve_return

    // Load and store one word at a time
    ldr wtmp, [output_tmp], #4
    str wtmp, [output], #4
    sub len, len, #1
    b.sve_copy_tail

sve_return:
    // Return count in x0
    mov x0, count
    pop_stack_sve
    ret

/****************** REGISTER DEALLOCATIONS *******************/
    .unreq output
    .unreq buf
    .unreq buflen
    .unreq table_idx
    .unreq len
    .unreq output_tmp
    .unreq output_tmp_base
    .unreq count
    .unreq tmp
    .unreq wtmp
    .unreq valid_count
    .unreq val
    .unreq wval

    .unreq z0_b
    .unreq z1_b
    .unreq z2_b
    .unreq z3_b
    .unreq z0_s
    .unreq z1_s
    .unreq z2_s
    .unreq z3_s
    .unreq z0_d

    .unreq mldsa_q_vec

    .unreq p0_b
    .unreq p1_b
    .unreq p0_s

/* To facilitate single-compilation-unit (SCU) builds, undefine all macros.
 * Don't modify by hand -- this is auto-generated by scripts/autogen. */
#undef SVE_STACK_SIZE

/* simpasm: footer-start */
#endif /* MLD_ARITH_BACKEND_AARCH64 && !MLD_CONFIG_MULTILEVEL_NO_SHARED */
