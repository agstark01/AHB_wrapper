/*
 * tm_wrapper.c
 *
 * Driver implementation for the AHB-Lite Tsetlin Machine inference
 * wrapper (ahb_ip_wrapper_dma_irq, Revision R3).
 *
 * Every polling loop below has a bounded timeout rather than spinning
 * forever, since a hardware issue (e.g. the unconnected bram_addr_a /
 * bram_addr_a2 ports flagged in the spec sheet) could otherwise hang
 * the driver indefinitely with no way to recover. TM_WRAPPER_TIMEOUT_ITERS
 * is a crude iteration-count timeout; replace the wait loops with a real
 * hardware timer (SysTick, etc.) once one is available on your platform.
 */
 #ifdef CORTEX_M0
#include "CMSDK_CM0.h"
#include "core_cm0.h"
#endif

#ifdef CORTEX_M0PLUS
#include "CMSDK_CM0plus.h"
#include "core_cm0plus.h"
#endif

#include <stdio.h>
#include "uart_stdout.h"
 
 
 
#include "tm_wrapper.h"
#include "tm_wrapper_regs.h"
#include "tm_model_data.h"

/* ------------------------------------------------------------------
 * Configuration
 * ------------------------------------------------------------------ */
#ifndef TM_WRAPPER_TIMEOUT_ITERS
#define TM_WRAPPER_TIMEOUT_ITERS   1000000UL
#endif


#define TM_MODEL_MAX_CLAUSE_ROWS   140u
#define TM_MODEL_MAX_WEIGHT_ROWS   50u

/* Called from tm_wrapper_irq_init() to enable the NVIC (or equivalent)
 * line wired to irq_merged. Weak default is a no-op so this file links
 * standalone; override it in your platform/BSP code. */
#if defined(__GNUC__)
__attribute__((weak))
#endif
void tm_wrapper_platform_irq_enable(void)
{
    /* No-op by default. Example override elsewhere in your BSP:
     *
     *   void tm_wrapper_platform_irq_enable(void) {
     *       NVIC_EnableIRQ(TM_WRAPPER_IRQn);
     *   }
     */
}

/* ------------------------------------------------------------------
 * Internal state
 * ------------------------------------------------------------------ */
static tm_status_t     g_last_error   = TM_OK;

static volatile uint8_t g_async_ready = 0;
static volatile uint8_t g_async_error = 0;
static volatile uint8_t g_async_result = 0;

/* ------------------------------------------------------------------
 * Bring-up
 * ------------------------------------------------------------------ */
void tm_wrapper_present(void)
{
    /* Weak check only -- these are debug ID markers left over on the
     * DRQ_EN/IRQ_EN read paths (spec sheet Sec. 3), not a dedicated
     * identification register. A future revision could remove them. */
    uint32_t ID_marker = TM_REG(TM_OFF_RCon_MARKER);
    uint32_t ID_marker2 = TM_REG(TM_OFF_CoTM_MARKER);
    printchar(ID_marker);
    printchar(ID_marker2);
    printf("/n");

    // return (ID_marker == TM_MARKER_DRQ_EN) && (ID_marker2 == TM_MARKER_IRQ_EN);
}

tm_status_t tm_wrapper_reset(void)
{
    /* Assert: core held in reset, session state continuously pinned to
     * its cleared values for as long as IP_RST stays 1. */
    TM_CTRL_SET = TM_CTRL_IP_RST;

    /* IP_RST is level-held (R3), not self-clearing -- no polling is
     * needed here for hardware to "finish" the reset on its own. The
     * two writes below are both volatile accesses to the same
     * peripheral and are therefore guaranteed to be issued in order by
     * the compiler; on a typical in-order AHB-Lite bus with no posted
     * writes in between, that's sufficient for the core to see at
     * least one full clock cycle with IP_RST=1 before it's released.
     * If your bus/bridge can ever post or coalesce writes, insert an
     * explicit dummy read (e.g. `(void)TM_STATUS;`) here to force the
     * assert write to land before continuing. */

    /* Deassert: core released, session state now clean. */
    TM_CTRL_CLR = TM_CTRL_IP_RST;

    /* Sanity check - session state should now read as freshly cleared. */
    if (TM_STATUS & (TM_STATUS_MODEL_WR | TM_STATUS_ALL_DONE)) {
        return TM_ERR_RESET_VERIFY_FAILED;
    }

    return TM_OK;
}

/* ------------------------------------------------------------------
 * Model loading
 * ------------------------------------------------------------------ */
tm_status_t tm_wrapper_load_model(uint8_t clause_rows, uint8_t weight_rows,
                                   const uint32_t *clauses,
                                   const uint32_t *weights)
{
    uint32_t row, w;
    uint32_t timeout;

    // if (weight_rows % 5u != 0u) {
    //     return TM_ERR_BAD_ARG;
    // }
    if (clause_rows == 0u || weight_rows == 0u) {
        return TM_ERR_BAD_ARG;
    }
    if (clause_rows > TM_MODEL_MAX_CLAUSE_ROWS || weight_rows > TM_MODEL_MAX_WEIGHT_ROWS) {
        return TM_ERR_BAD_ARG;
    }
    if (clauses == NULL || weights == NULL) {
        return TM_ERR_BAD_ARG;
    }

    /* 1. Program model size FIRST - clause/weight writes are rejected
     *    (error_flag set) until this register has been written. It is
     *    write-once per session; a second write here would also be
     *    rejected -- call tm_wrapper_reset() between models.  0b0000_0000_0000_00_1010_10001100_001_111*/
    TM_MODEL_PARAM = 0b00000000000000101010001100001111;

    if (TM_STATUS & TM_STATUS_ERROR) {
        return TM_ERR_MODEL_WRITE_FAILED;
    }

    /* 2. Stream clause rows, 8 words at a time. The wrapper
     *    auto-triggers a burst-load into the core once all 8 words of
     *    a row are present -- no explicit "commit" write is needed. */
    for (row = 0; row < clause_rows; row++) {
        for (w = 0; w < TM_MODEL_ROW_STRIDE_WORDS; w++) {
            TM_CLAUSE(w) = clauses[row * TM_MODEL_ROW_STRIDE_WORDS + w];
            printf(" clause no: %d\n",row );
        }
        if( row < weight_rows){
        for (w = 0; w < TM_MODEL_ROW_STRIDE_WORDS; w++) {
            TM_WEIGHT(w) = weights[row * TM_MODEL_ROW_STRIDE_WORDS + w];
            printf(" weight no: %d\n",row);
        }
        }
    }

    /* 3. Stream weight rows, 8 words at a time, same layout. */
   /* for (row = 0; row < weight_rows; row++) {
        for (w = 0; w < TM_MODEL_ROW_STRIDE_WORDS; w++) {
            TM_WEIGHT(w) = weights[row * TM_MODEL_ROW_STRIDE_WORDS + w];
            printf(" weight no: %d\n",row * TM_MODEL_ROW_STRIDE_WORDS + w);
        }
    }
*/
    /* 4. Confirm the model is fully loaded before entering stream mode. */
    for (timeout = 0; timeout < 50; timeout++) {
        uint32_t status = TM_STATUS;

        if (status & TM_STATUS_ERROR) {
            return TM_ERR_LOAD_HW_ERROR;
        }
        if (status & TM_STATUS_ALL_DONE) {
            return TM_OK;
        }
    }

    return TM_ERR_LOAD_TIMEOUT;
}

/* ------------------------------------------------------------------
 * Classification -- polled
 * ------------------------------------------------------------------ */
uint8_t tm_wrapper_classify_blocking(const uint32_t *image_word)
{
    uint32_t timeout;

    g_last_error = TM_OK;

    //TM_IMAGE_DATA = image_word;

    for (int ii = 0; ii < 32; ii++) {
            TM_IMAGE_DATA = image_word[ii];
        }

    /* No explicit "busy" or "one classification complete" bit is
     * exposed independent of the 32-word circular counter (see spec
     * sheet Sec. 5) -- IMG_DONE is used here as a best-effort proxy.
     * Also be aware of the image_cnt wrap-to-1 RTL bug: after 32
     * images the buffer index restarts at 1 instead of 0, which can
     * shift subsequent results by one slot relative to what you expect
     * if you're relying on exact buffer-index alignment across wraps. */
    for (timeout = 0; timeout < TM_WRAPPER_TIMEOUT_ITERS; timeout++) {
        uint32_t status = TM_STATUS;

        if (status & TM_STATUS_ERROR) {
            g_last_error = TM_ERR_CLASSIFY_HW_ERROR;
            return TM_CLASSIFY_ERROR_SENTINEL;
        }
        if (status & TM_STATUS_IMG_DONE) {
            /* Reading RESULT both retrieves the answer and acknowledges
             * the pending-result condition (clears ip_computation_done_r
             * and deasserts the result half of irq_merged). */
            return (uint8_t)(TM_RESULT & 0xFu);
        }
    }

    g_last_error = TM_ERR_CLASSIFY_TIMEOUT;
    return TM_CLASSIFY_ERROR_SENTINEL;
}

tm_status_t tm_wrapper_classify_batch(const uint32_t *images, uint32_t n_images,
                                       uint8_t *results_out)
{
    uint32_t i;

    if (images == NULL || results_out == NULL) {
        return TM_ERR_BAD_ARG;
    }

    for (i = 0; i < n_images; i++) {
        uint8_t r = tm_wrapper_classify_blocking(&images[i << 5]);

        if (r == TM_CLASSIFY_ERROR_SENTINEL) {
            return g_last_error;
        }
        results_out[i] = r;
    }

    return TM_OK;
}

tm_status_t tm_wrapper_last_error(void)
{
    return g_last_error;
}

/* ------------------------------------------------------------------
 * Classification -- interrupt-driven
 * ------------------------------------------------------------------ */
void tm_wrapper_irq_init(void)
{
    /* Enables bits [1:0] of irq_enable. Only irq_merged actually
     * reaches the interrupt controller in this revision (Sec. 2.3 /
     * Sec. 6 of the spec sheet) -- irq_key128/irq_op128/irq_error are
     * undriven, so this mainly future-proofs the field for when those
     * are wired up. Note TM_IRQ_EN read will NOT reflect this value
     * afterward (Sec. 3) -- if you need to confirm it took effect,
     * track it in software. */
    TM_IRQ_EN_SET = 0x3u;

    g_async_ready = 0;
    g_async_error = 0;

    /* Enable the actual interrupt line at the controller. Platform-
     * specific -- override tm_wrapper_platform_irq_enable() in your BSP. */
    tm_wrapper_platform_irq_enable();
}

void tm_wrapper_irq_handler(void)
{
    uint32_t status = TM_STATUS;   /* this read also serves as error_ack */

    if (status & TM_STATUS_ERROR) {
        g_async_error  = 1;
        g_async_ready  = 1;

        /* STATUS read above only deasserts irq_merged's error half; it
         * does NOT clear error_flag itself. Clear it explicitly so the
         * peripheral can resume normal operation. */
        TM_CTRL_SET = TM_CTRL_ERR_CLR;
        return;
    }

    /* Reading RESULT both retrieves the answer and acknowledges the
     * pending-result condition (clears ip_computation_done_r). */
    g_async_result = (uint8_t)(TM_RESULT & 0xFu);
    g_async_ready  = 1;
}

void tm_wrapper_classify_async(uint32_t image_word)
{
    g_async_ready = 0;
    g_async_error = 0;
    TM_IMAGE_DATA = image_word;
}

int tm_wrapper_poll_async_result(uint8_t *result_out, int *is_error_out)
{
    if (!g_async_ready) {
        return 0;
    }

    if (is_error_out != NULL) {
        *is_error_out = g_async_error ? 1 : 0;
    }
    if (result_out != NULL) {
        *result_out = g_async_error ? TM_CLASSIFY_ERROR_SENTINEL : g_async_result;
    }

    g_async_ready = 0;
    return 1;
}

void printchar(uint32_t data){
	printf("%c%c%c%c",
       (char)((data >> 24) & 0xFF),
       (char)((data >> 16) & 0xFF),
       (char)((data >> 8) & 0xFF),
       (char)(data & 0xFF));
}

int main() {

    UartStdOutInit();

    printf("1st run \n");
    tm_wrapper_present();
     printf("\n 2nd run \n");
    if (tm_wrapper_reset() != TM_OK) {
        return tm_wrapper_reset();
    }
  printf("\n3rd run \n");
    // check if the model is loaded successfully
    tm_status_t loadcheck = tm_wrapper_load_model(140, 50, tm_model_clause_words, tm_model_weight_words);
 printf("\n 4th run \n");
    if (loadcheck != TM_OK) {
        return loadcheck;
    }
 printf("\n 4th run \n");
    // image streaming and classification
    uint8_t results_out[4];

    tm_status_t imagecheck = tm_wrapper_classify_batch(tm_model_image_words, 4, results_out);
    
 printf("\n 5th run \n");
    if(imagecheck != TM_OK){
        return imagecheck;
    }
 printf("\n 6th run \n");
    for(int i = 0; i < 4; i++){
        printf("Result for image %d: %d\n", i, results_out[i]);
    }
    //printf("hello \n");
    
      // End simulation
    UartEndSimulation();
  


    return 0;
}
