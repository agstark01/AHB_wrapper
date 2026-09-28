module blk_sram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 256,
    parameter INIT_FILE  = ""
)(
    input clka,
    input reset_n,
    input ena,
    input wea,
    input [ADDR_WIDTH-1:0] addra,
    input [DATA_WIDTH-1:0] dina,

    input clkb,
    input enb,
    input [ADDR_WIDTH-1:0] addrb,
    output [DATA_WIDTH-1:0] doutb
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    
    // ===============================
    // WRITE PORT A
    // ===============================
    always @(posedge clka) begin
        if (ena && wea)
            mem[addra] <= dina;
    end

    // ===============================
    // READ PORT B (ASYNC)
    // ===============================
    assign doutb = mem[addrb];

endmodule

