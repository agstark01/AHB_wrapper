`timescale 1ns / 1ps
module weight_adder #(
    parameter CLAUSEN = 140
)(
    input clk,
    input i_rst_n,                          // FIX: added i_rst_n port
    input valid,
    input [255:0] weight_write,
    input [2:0] offset,
    input [$clog2(CLAUSEN)-1:0] clauses,
    input [$clog2(CLAUSEN)-1:0] clause_no,
    output reg signed [8:0] weight
);
    reg [2048:0] dout;
    reg [$clog2(CLAUSEN*9)-1:0] idx;
    wire [$clog2(CLAUSEN*9)-1:0] idx_w;
    reg signed [8:0] wt;

    // ------------------------------------------------------------
    // Write logic
    // FIX: async reset with i_rst_n
    // ------------------------------------------------------------
   reg [2048:0] dout_nxt;
   reg [$clog2(CLAUSEN*9)-1:0] idx_nxt;
   reg [8:0] wt_nxt;
   reg [8:0] weight_nxt;
   assign idx_w = idx + 9;

always @(posedge clk or negedge i_rst_n) begin
    if (!i_rst_n)
        dout <= 0;
    else
        dout <= dout_nxt;
end

always @(*) begin
    dout_nxt[2048:1280] = 0;
    dout_nxt[1279:0] = dout[1279:0];

    if (valid) begin
        case (offset)
            3'd0: dout_nxt[255:0]     = weight_write;
            3'd1: dout_nxt[511:256]   = weight_write;
            3'd2: dout_nxt[767:512]   = weight_write;
            3'd3: dout_nxt[1023:768]  = weight_write;
            3'd4: dout_nxt[1279:1024] = weight_write;
            default: dout_nxt = 0;
        endcase
    end
end


always @(posedge clk or negedge i_rst_n) begin
    if (!i_rst_n)
        idx <= 0;
    else
        idx <= idx_nxt;
end

always @(*) begin
    idx_nxt = (clauses - clause_no - 1) * 9;
end


always @(posedge clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        wt     <= 0;
        weight <= 0;
    end
    else begin
        wt     <= wt_nxt;
        weight <= weight_nxt;
    end
end

always @(*) begin
    wt_nxt     = dout[idx +: 9];
    weight_nxt = wt;
end
endmodule
