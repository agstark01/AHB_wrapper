/*
 * tm_wrapper_regs.h
 *
 * Register-level definitions for ahb_ip_wrapper_dma_irq (Revision R3).
 * This header describes the hardware exactly as implemented -- including
 * the quirks. Do not "fix" the quirks here without updating the RTL first;
 * see the accompanying spec sheet for the full rationale on each one.
 */
#ifndef TM_WRAPPER_REGS_H
#define TM_WRAPPER_REGS_H

#include <stdint.h>

/* ------------------------------------------------------------------
 * Base address
 * ------------------------------------------------------------------
 * PLACEHOLDER - confirm against the real NanoSoC AHB peripheral map
 * before use. Wrong base address will not be caught at compile time.
 */
#ifndef TM_WRAPPER_BASE
#define TM_WRAPPER_BASE   0x60000000UL
#endif

#define TM_REG(off)   (*(volatile uint32_t *)(TM_WRAPPER_BASE + (off)))

/* ------------------------------------------------------------------
 * Offsets
 * ------------------------------------------------------------------ */
#define TM_OFF_CLAUSE(i)      (0x00u + ((i) * 4u))   /* i = 0..7, write-only */
#define TM_OFF_WEIGHT(i)      (0x20u + ((i) * 4u))   /* i = 0..7, write-only */
#define TM_OFF_IMAGE_DATA     0x40u                   /* write-only */
#define TM_OFF_MODEL_PARAM    0x44u                   /* write-once, write-only */
#define TM_OFF_STATUS         0x48u                   /* read-only */
#define TM_OFF_CTRL            0x4Cu                   /* read/write */
#define TM_OFF_CTRL_SET        0x50u                   /* write-only */
#define TM_OFF_CTRL_CLR         0x54u                   /* write-only */
#define TM_OFF_DRQ_EN_SET       0x5Cu                   /* write-only, no base write exists at 0x58 */
#define TM_OFF_DRQ_EN_CLR        0x60u                   /* write-only */
#define TM_OFF_IRQ_EN              0x64u                   /* write sets it; READ returns a fixed marker, not live state */
#define TM_OFF_IRQ_EN_SET           0x68u
#define TM_OFF_IRQ_EN_CLR            0x6Cu
#define TM_OFF_RESULT                 0x70u                   /* read-only */

/* Read-only diagnostic marker addresses (see quirk note below) */
#define TM_OFF_RCon_MARKER            0x58u   /* returns "RCon" ASCII, not drq_enable */
#define TM_OFF_CoTM_MARKER            0x64u   /* returns "CoTM" ASCII on read, not irq_enable */

/* ------------------------------------------------------------------
 * Register access macros
 * ------------------------------------------------------------------ */
#define TM_CLAUSE(i)          TM_REG(TM_OFF_CLAUSE(i))
#define TM_WEIGHT(i)          TM_REG(TM_OFF_WEIGHT(i))
#define TM_IMAGE_DATA          TM_REG(TM_OFF_IMAGE_DATA)
#define TM_MODEL_PARAM          TM_REG(TM_OFF_MODEL_PARAM)
#define TM_STATUS                 TM_REG(TM_OFF_STATUS)
#define TM_CTRL                    TM_REG(TM_OFF_CTRL)
#define TM_CTRL_SET                  TM_REG(TM_OFF_CTRL_SET)
#define TM_CTRL_CLR                   TM_REG(TM_OFF_CTRL_CLR)
#define TM_DRQ_EN_SET                    TM_REG(TM_OFF_DRQ_EN_SET)
#define TM_DRQ_EN_CLR                     TM_REG(TM_OFF_DRQ_EN_CLR)
#define TM_IRQ_EN                           TM_REG(TM_OFF_IRQ_EN)
#define TM_IRQ_EN_SET                          TM_REG(TM_OFF_IRQ_EN_SET)
#define TM_IRQ_EN_CLR                           TM_REG(TM_OFF_IRQ_EN_CLR)
#define TM_RESULT                                  TM_REG(TM_OFF_RESULT)

/* ------------------------------------------------------------------
 * Quirk: read sentinel / diagnostic markers
 * ------------------------------------------------------------------
 * Any offset the read multiplexer doesn't explicitly case on -- including
 * the entire write-only clause/weight/image/model region (0x00-0x44) and
 * any truly unmapped offset -- returns this fixed poison pattern instead
 * of 0. Useful for catching a driver bug (reading something write-only)
 * immediately rather than silently getting a plausible-looking 0.
 */
#define TM_BAD_READ_SENTINEL   0xBAD0BAD0UL

/* DRQ_EN (0x58) and IRQ_EN (0x64) no longer return live register state on
 * read in this revision -- they return these fixed ASCII markers instead.
 * There is currently NO hardware-verifiable way to read back which DMA
 * channels or IRQ sources are enabled; the driver must shadow this state
 * itself (see tm_wrapper.c). These markers are still useful as a weak
 * "is this really the TM wrapper" bring-up check. */
#define TM_MARKER_DRQ_EN       0x52436F6EUL  /* "RCon" packed MSB-first, as written in RTL */ // THIS HAS TO BE CHNAGED FIRST
#define TM_MARKER_IRQ_EN       0x436F544DUL  /* "CoTM" packed MSB-first, as written in RTL */

/* ------------------------------------------------------------------
 * CTRL register bits (offset 0x4C / 0x50 / 0x54)
 * ------------------------------------------------------------------
 * Bit 0 is named IP_RST here rather than IP_EN (the RTL comment's name)
 * because its actual polarity is a reset-assert, not an enable: writing
 * 1 holds class_top in reset AND continuously forces the wrapper's
 * session state to its cleared values for as long as it stays 1.
 *
 * IP_RST is LEVEL-HELD, NOT SELF-CLEARING. Software must explicitly
 * write it back to 0 -- hardware will never clear it automatically.
 * ERR_CLR (bit 1) IS self-clearing (hardware clears it the same cycle
 * it services the clear). Do not assume the two bits behave the same way.
 *
 * Bit 2 is declared in the RTL (control is a 3-bit reg) but is dead:
 * every write path only touches ahb_hwdata[1:0], so bit 2 can never be
 * set from software and always reads 0. No macro is defined for it.
 */
#define TM_CTRL_IP_RST          (1u << 0)   /* level-held */
#define TM_CTRL_ERR_CLR         (1u << 1)   /* self-clearing */

/* ------------------------------------------------------------------
 * STATUS register bits (offset 0x48, read-only)
 * ------------------------------------------------------------------
 * Bit positions derived from the RTL concatenation order
 * {8'd0, weight_cnt, 2'd0, clause_cnt, error_flag, model_written,
 *  all_finished, image_done, weight_done, clause_done} (30 bits total),
 * which Verilog zero-extends on the LEFT into the 32-bit register --
 * i.e. WEIGHT_CNT starts at bit 16, not bit 18. Verify against your own
 * build before trusting these if the RTL concatenation ever changes.
 */
/*
  8'h48: ahb_hrdata = {9'd0, weight_cnt, ip_computation_done_r, clause_cnt, error_flag, model_written, all_finished, image_done, weight_done, clause_done};
*
*
*
*/


#define TM_STATUS_CLAUSE_DONE       (1u << 0)
#define TM_STATUS_WEIGHT_DONE       (1u << 1)
#define TM_STATUS_IMG_DONE          (1u << 14)
#define TM_STATUS_ALL_DONE          (1u << 3)
#define TM_STATUS_MODEL_WR          (1u << 4)
#define TM_STATUS_ERROR             (1u << 5)
#define TM_STATUS_CLAUSE_CNT_SHIFT  6
#define TM_STATUS_CLAUSE_CNT_MASK   (0xFFu << TM_STATUS_CLAUSE_CNT_SHIFT)
#define TM_STATUS_WEIGHT_CNT_SHIFT  15
#define TM_STATUS_WEIGHT_CNT_MASK   (0x3Fu << TM_STATUS_WEIGHT_CNT_SHIFT)

#define TM_STATUS_CLAUSE_CNT(status)  (((status) & TM_STATUS_CLAUSE_CNT_MASK) >> TM_STATUS_CLAUSE_CNT_SHIFT)
#define TM_STATUS_WEIGHT_CNT(status)  (((status) & TM_STATUS_WEIGHT_CNT_MASK) >> TM_STATUS_WEIGHT_CNT_SHIFT)

/* ------------------------------------------------------------------
 * MODEL_PARAM field packing (offset 0x44, write-once per session)
 * ------------------------------------------------------------------
 * weight_rows MUST be a multiple of 5 -- the field stores rows/5 in 4
 * bits (0-75 rows in steps of 5; weight memory capacity is 50 rows).
 * clause_rows is a direct 8-bit value (0-255; clause memory capacity
 * is 140 rows).
 */
 /*
#define TM_MODEL_CLAUSE_ROWS(n)       (((uint32_t)(n) & 0xFFu) << 6)
#define TM_MODEL_WEIGHT_ROWS_DIV5(n)  (((uint32_t)(n) & 0xFu)  << 14)
*/
#define TM_MODEL_ROW_STRIDE_WORDS   8u   /* words per 256-bit clause/weight row */

/* ------------------------------------------------------------------
 * Quirk: image_cnt wrap-to-1 bug (RTL, unresolved as of R3)
 * ------------------------------------------------------------------
 * On overflow the RTL sets image_cnt back to 1 instead of 0
 * (`image_cnt <= 7'b01;`), shifting the 32-word circular window by one
 * slot on every wrap. There is nothing software can do to work around
 * this from outside the core; it is flagged here so anyone debugging a
 * one-word misalignment after 32 images knows where to look first.
 */
#define TM_IMAGE_WINDOW_WORDS   32u

#endif /* TM_WRAPPER_REGS_H */
