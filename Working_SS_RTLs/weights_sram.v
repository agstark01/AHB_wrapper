module weights_sram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 256
)(
    input  wire                     clka,
    input  wire                     reset,
    input  wire                     ena,
    input  wire                     wea,
    input  wire [ADDR_WIDTH-1:0]    addra,
    input  wire [DATA_WIDTH-1:0]    dina,

    input  wire                     clkb,
    input  wire                     enb,
    input  wire [ADDR_WIDTH-1:0]    addrb,
    output wire [DATA_WIDTH-1:0]    doutb
);

    // Active-low reset for SRAM (memory NOT cleared)
    wire reset_n;
    assign reset_n = ~reset;

    // ====================================================
    // WEIGHT SRAM WITH BINARY PRELOAD
    // ====================================================
    blk_sram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_sram (
        .clka   (clka),
        .reset_n(reset_n),   // reset does NOT wipe memory
        .ena    (ena),
        .wea    (wea),
        .addra  (addra),
        .dina   (dina),

        .clkb   (clkb),
        .enb    (enb),
        .addrb  (addrb),
        .doutb  (doutb)
    );

endmodule

