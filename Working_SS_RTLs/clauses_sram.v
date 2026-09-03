module clauses_sram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 256
)(
    input clka,
    input reset,
    input ena,
    input wea,
    input [ADDR_WIDTH-1:0] addra,
    input [DATA_WIDTH-1:0] dina,

    input clkb,
    input enb,
    input [ADDR_WIDTH-1:0] addrb,
    output [DATA_WIDTH-1:0] doutb
);

wire reset_n;
assign reset_n = ~reset;

blk_sram #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) u_sram (
    .clka(clka),
    .reset_n(reset_n),
    .ena(ena),
    .wea(wea),
    .addra(addra),
    .dina(dina),

    .clkb(clkb),
    .enb(enb),
    .addrb(addrb),
    .doutb(doutb)
);

endmodule

