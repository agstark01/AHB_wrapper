/*
 * tm_wrapper.h
 *
 * Driver API for the AHB-Lite Tsetlin Machine inference wrapper
 * (ahb_ip_wrapper_dma_irq, Revision R3).
 *
 * This is a polled + interrupt-capable driver. DMA is not usable yet --
 * drq_ipdma128/drq_opdma128 are undriven in the current RTL revision --
 * so every data path here goes through CPU-driven register writes/reads.
 */
#ifndef TM_WRAPPER_H
#define TM_WRAPPER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------
 * Status / error codes
 * ------------------------------------------------------------------ */
typedef enum {
    TM_OK                    = 0,
    TM_ERR_NOT_PRESENT        = -1,  /* bring-up check failed */
    TM_ERR_BAD_ARG             = -2,  /* invalid row count, null pointer, etc. */
    TM_ERR_MODEL_WRITE_FAILED   = -3,  /* MODEL_PARAM write rejected (double-write) */
    TM_ERR_LOAD_TIMEOUT          = -4,  /* ALL_DONE never asserted */
    TM_ERR_LOAD_HW_ERROR          = -5,  /* error_flag set during model load */
    TM_ERR_CLASSIFY_TIMEOUT         = -6,  /* IMG_DONE never asserted */
    TM_ERR_CLASSIFY_HW_ERROR         = -7,  /* error_flag set during classification */
    TM_ERR_RESET_VERIFY_FAILED        = -8,  /* session state didn't clear after reset */
} tm_status_t;

/* Sentinel returned by tm_wrapper_classify_blocking() on hardware error,
 * distinguishable from any real 4-bit classification result (0-15). */
#define TM_CLASSIFY_ERROR_SENTINEL   0xFFu

/* ------------------------------------------------------------------
 * Bring-up
 * ------------------------------------------------------------------ */

/*
 * Weak sanity check that TM_WRAPPER_BASE actually points at this
 * peripheral. There is no dedicated ID register in this revision (the
 * old 0x78 case was removed and folded into the generic bad-read
 * sentinel), so this checks the two leftover debug ID markers on
 * DRQ_EN/IRQ_EN reads instead. Those are debug scaffolding and could
 * change or be removed in a future revision -- treat a failure here as
 * "something's wrong," not as a hard guarantee either way.
 *
 * Returns 1 if both markers match, 0 otherwise.
 */
void tm_wrapper_present(void);

/*
 * Assert and release IP_RST (CTRL[0]). This is level-held, not
 * self-clearing (Revision R3) -- the driver owns both edges explicitly.
 * Clears the core reset AND the wrapper's session state
 * (model_written, stream_state, all counters/masks, init_done)
 * together, since the two must never desync.
 *
 * Returns TM_OK, or TM_ERR_RESET_VERIFY_FAILED if the session state
 * did not read back as cleared afterward.
 */
tm_status_t tm_wrapper_reset(void);

/* ------------------------------------------------------------------
 * Model loading
 * ------------------------------------------------------------------ */

/*
 * Load one model's clause/weight data and wait for ALL_DONE.
 *
 * clause_rows: number of 256-bit clause rows to load (1-255; clause
 *              memory capacity is 140 rows -- check your class_top build).
 * weight_rows: number of 256-bit weight rows to load. MUST be a
 *              multiple of 5 (weight memory capacity is 50 rows).
 * clauses:     clause_rows * 8 words, row-major
 *              (row i occupies clauses[8*i .. 8*i+7]).
 * weights:     weight_rows * 8 words, same row-major layout.
 *
 * Call tm_wrapper_reset() first if a previous model is already loaded --
 * MODEL_PARAM is write-once per session and a second write is rejected.
 */
tm_status_t tm_wrapper_load_model(uint8_t clause_rows, uint8_t weight_rows,
                                   const uint32_t *clauses,
                                   const uint32_t *weights);

/* ------------------------------------------------------------------
 * Classification -- polled
 * ------------------------------------------------------------------ */

/*
 * Classify one 32-bit-packed image word, blocking until a result is
 * ready or the operation times out.
 *
 * Returns the 4-bit classification result (0-15) on success, or
 * TM_CLASSIFY_ERROR_SENTINEL (0xFF) on hardware error or timeout --
 * call tm_wrapper_last_error() to distinguish which.
 *
 * Must only be called after tm_wrapper_load_model() has returned TM_OK.
 */
uint8_t tm_wrapper_classify_blocking(const uint32_t *image_word);

/*
 * Classify a whole array of images, blocking, stopping at the first
 * error. Returns TM_OK if all n_images were classified, or the first
 * error encountered. results_out must hold at least n_images entries.
 */
tm_status_t tm_wrapper_classify_batch(const uint32_t *images, uint32_t n_images,
                                       uint8_t *results_out);

/* Retrieves the tm_status_t of the last failure from a *_blocking /
 * *_batch call, for callers that only got back TM_CLASSIFY_ERROR_SENTINEL
 * and need to know why. */
tm_status_t tm_wrapper_last_error(void);

/* ------------------------------------------------------------------
 * Classification -- interrupt-driven
 * ------------------------------------------------------------------
 * Only irq_merged is functional in this revision -- the discrete
 * irq_key128/irq_op128/irq_error lines are undriven. Route your NVIC
 * (or equivalent) vector for this peripheral to irq_merged and call
 * tm_wrapper_irq_handler() from that ISR; this driver disambiguates
 * result-vs-error internally by reading STATUS.
 */

/* One-time setup: enables IRQ_EN bits and readies internal state.
 * Does NOT enable the NVIC line itself -- that's platform-specific and
 * left to the caller (see the .c file for where to hook it in). */
void tm_wrapper_irq_init(void);

/* Call this from your ISR for the line wired to irq_merged. */
void tm_wrapper_irq_handler(void);

/* Kick off one classification without blocking. Result/error are
 * delivered via tm_wrapper_irq_handler() into the internal state
 * queried by tm_wrapper_poll_async_result(). */
void tm_wrapper_classify_async(uint32_t image_word);

/* Non-blocking check for an async result.
 * Returns 1 and fills *result_out if a result or error is ready
 * (check *is_error_out), 0 if nothing is ready yet. */
int tm_wrapper_poll_async_result(uint8_t *result_out, int *is_error_out);

/*
 * ------------------------------------------------------------------
 * Embedded model data (bare-metal / QuestaSim workflow)
 * ------------------------------------------------------------------
 * Bare-metal firmware has no filesystem, so clause.txt/weight.txt can't
 * be "opened" at runtime. Instead, convert them at build time into a C
 * header using tools/txt_to_tm_header.py, and link the result directly
 * into the firmware image. In QuestaSim this data then arrives for free
 * as part of whatever $readmemh preload already puts your compiled
 * firmware into simulated memory -- no separate BRAM-preload step is
 * needed, and the CPU performs real AHB writes exactly as it would on
 * actual silicon.
 *
 * The generated header must define this exact contract:
 *
 *   #define TM_MODEL_CLAUSE_ROWS   <N>
 *   #define TM_MODEL_WEIGHT_ROWS   <M>
 *   static const uint32_t tm_model_clause_words[N * 8];
 *   static const uint32_t tm_model_weight_words[M * 8];
 *
 * (txt_to_tm_header.py produces exactly this.) Word ordering within
 * each row matters: word[0] must be the row's least-significant 32
 * bits, since that's the first word tm_wrapper_load_model() writes and
 * the wrapper reassembles the 256-bit row as
 * {reg[7],reg[6],...,reg[0]} -- see the script's docstring for the
 * exact bit-slicing.
 *
 * Usage:
 *
 *   #include "tm_model_data.h"   // generated by txt_to_tm_header.py -- include FIRST
 *   #include "tm_wrapper.h"
 *
 *   tm_wrapper_reset();
 *   TM_LOAD_EMBEDDED_MODEL();    // expands to the load_model() call below
 *
 * TM_LOAD_EMBEDDED_MODEL always expands to a call referencing
 * tm_model_clause_words / tm_model_weight_words / TM_MODEL_CLAUSE_ROWS /
 * TM_MODEL_WEIGHT_ROWS by name. If tm_model_data.h wasn't included
 * first, you'll get an ordinary "undeclared identifier" compiler error
 * at the call site -- include tm_model_data.h before tm_wrapper.h to
 * avoid that.
 */

void printchar(uint32_t data);
/* it just prints the hexdata in char format*/

#define TM_LOAD_EMBEDDED_MODEL() \
    tm_wrapper_load_model(TM_MODEL_CLAUSE_ROWS, TM_MODEL_WEIGHT_ROWS, \
                           tm_model_clause_words, tm_model_weight_words)

/*
 * If the generated header also defines TM_MODEL_IMAGE_WORDS and
 * tm_model_image_words[] (i.e. --image was passed to the converter),
 * this streams every embedded image word through the blocking path and
 * writes results into an array you provide (must hold at least
 * TM_MODEL_IMAGE_WORDS entries). Equivalent to calling
 * tm_wrapper_classify_batch(tm_model_image_words, TM_MODEL_IMAGE_WORDS,
 * results_out) -- same include-order requirement as TM_LOAD_EMBEDDED_MODEL.
 */
#define TM_CLASSIFY_EMBEDDED_IMAGES(results_out) \
    tm_wrapper_classify_batch(tm_model_image_words, TM_MODEL_IMAGE_WORDS, (results_out))

    

#ifdef __cplusplus
}
#endif

#endif /* TM_WRAPPER_H */