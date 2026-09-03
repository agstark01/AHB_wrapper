module weights_clauses_glue #(
    parameter ADDR_WIDTH        = 10,   // Changed from 8 to 10 to accommodate control bits
    parameter WORD_WIDTH        = 32,
    parameter DATA_WIDTH        = 256
)(
    input  wire                      i_clk,
    input  wire                      i_rst_n,

    // ====================================================
    // Inputs from APB register block
    // ====================================================
    // NOW 10 bits: [9]=clauses_sel, [8]=weight_sel, [7:0]=address
    input  wire [ADDR_WIDTH-1:0]     i_addr_reg,

    // Weight data inputs (8 x 32-bit)
    input  wire [WORD_WIDTH-1:0]     i_weight_data0,
    input  wire [WORD_WIDTH-1:0]     i_weight_data1,
    input  wire [WORD_WIDTH-1:0]     i_weight_data2,
    input  wire [WORD_WIDTH-1:0]     i_weight_data3,
    input  wire [WORD_WIDTH-1:0]     i_weight_data4,
    input  wire [WORD_WIDTH-1:0]     i_weight_data5,
    input  wire [WORD_WIDTH-1:0]     i_weight_data6,
    input  wire [WORD_WIDTH-1:0]     i_weight_data7,

    // Individual command bits
    input  wire                      i_cmd_weight_write,
    input  wire                      i_cmd_weight_read,
    input  wire                      i_cmd_Clauses_write,
    input  wire                      i_cmd_Clauses_read,

    // ====================================================
    // SRAM READ PORTS (Port-B from both RAMs)
    // ====================================================
    input  wire [DATA_WIDTH-1:0]     i_weight_sram_dout,
    input  wire [DATA_WIDTH-1:0]     i_Clauses_sram_dout,

    // ====================================================
    // OUTPUTS to WEIGHT SRAM (Port-A)
    // ====================================================
    output reg                       o_weight_sram_ena,
    output reg                       o_weight_sram_wea,
    output reg  [7:0]                o_weight_sram_addra,  // Only 8 bits needed
    output reg  [DATA_WIDTH-1:0]     o_weight_sram_dina,

    // ====================================================
    // OUTPUTS to Clauses SRAM (Port-A)
    // ====================================================
    output reg                       o_Clauses_sram_ena,
    output reg                       o_Clauses_sram_wea,
    output reg  [7:0]                o_Clauses_sram_addra, // Only 8 bits needed
    output reg  [DATA_WIDTH-1:0]     o_Clauses_sram_dina,

    // ====================================================
    // BACK to APB (optional read/debug)
    // ====================================================
    output reg  [DATA_WIDTH-1:0]     o_read_data,
    output reg                       o_read_data_valid
);
    wire [7:0] target_addr;
    wire       weight_select;
    wire       clauses_select;
    
    
    // ====================================================
    // CONCATENATE 8 x 32 INTO 256 
    // ====================================================
    wire [DATA_WIDTH-1:0] w_weight_data_256;

    assign w_weight_data_256 = {
        i_weight_data7, i_weight_data6,
        i_weight_data5, i_weight_data4,
        i_weight_data3, i_weight_data2,
        i_weight_data1, i_weight_data0
    };

    // ====================================================
    // NEW ADDRESS DECODE LOGIC - Using Control Bits
    // ====================================================
    assign target_addr      = i_addr_reg[7:0];   // Actual SRAM address
    assign weight_select    = i_addr_reg[8];      // Bit 8: Weight select
    assign clauses_select   = i_addr_reg[9];      // Bit 9: Clauses select

// ====================================================
// NEXT-STATE SIGNALS (for flopping)
// ====================================================
reg                       nxt_weight_ena, nxt_weight_wea;
reg  [7:0]                nxt_weight_addra;
reg  [DATA_WIDTH-1:0]     nxt_weight_dina;

reg                       nxt_clauses_ena, nxt_clauses_wea;
reg  [7:0]                nxt_clauses_addra;
reg  [DATA_WIDTH-1:0]     nxt_clauses_dina;

// ====================================================
// WRITE PATH LOGIC (COMBINATIONAL)
// ====================================================
always @(*) begin
    // Defaults
    nxt_weight_ena    = 1'b0;
    nxt_weight_wea    = 1'b0;
    nxt_weight_addra  = 8'h00;
    nxt_weight_dina   = {DATA_WIDTH{1'b0}};

    nxt_clauses_ena   = 1'b0;
    nxt_clauses_wea   = 1'b0;
    nxt_clauses_addra = 8'h00;
    nxt_clauses_dina  = {DATA_WIDTH{1'b0}};

    // ---------------------------
    // Weight Write
    // ---------------------------
    if (i_cmd_weight_write && weight_select) begin
        nxt_weight_ena    = 1'b1;
        nxt_weight_wea    = 1'b1;
        nxt_weight_addra  = target_addr;
        nxt_weight_dina   = w_weight_data_256;
    end

    // ---------------------------
    // Clauses Write
    // ---------------------------
    if (i_cmd_Clauses_write && clauses_select) begin
        nxt_clauses_ena   = 1'b1;
        nxt_clauses_wea   = 1'b1;
        nxt_clauses_addra = target_addr;
        nxt_clauses_dina  = w_weight_data_256;
    end
end

// ====================================================
// WRITE OUTPUT REGISTERS (FLOPPED)
// ====================================================
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        o_weight_sram_ena   <= 1'b0;
        o_weight_sram_wea   <= 1'b0;
        o_weight_sram_addra <= 8'h00;
        o_weight_sram_dina  <= {DATA_WIDTH{1'b0}};

        o_Clauses_sram_ena   <= 1'b0;
        o_Clauses_sram_wea   <= 1'b0;
        o_Clauses_sram_addra <= 8'h00;
        o_Clauses_sram_dina  <= {DATA_WIDTH{1'b0}};
    end
    else begin
        o_weight_sram_ena   <= nxt_weight_ena;
        o_weight_sram_wea   <= nxt_weight_wea;
        o_weight_sram_addra <= nxt_weight_addra;
        o_weight_sram_dina  <= nxt_weight_dina;

        o_Clauses_sram_ena   <= nxt_clauses_ena;
        o_Clauses_sram_wea   <= nxt_clauses_wea;
        o_Clauses_sram_addra <= nxt_clauses_addra;
        o_Clauses_sram_dina  <= nxt_clauses_dina;
    end
end


    // ====================================================
    // READ PATH + VALID PULSE  (SEQUENTIAL)
    // ====================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            o_read_data       <= {DATA_WIDTH{1'b0}};
            o_read_data_valid <= 1'b0;
        end
        else begin
            o_read_data_valid <= 1'b0;

            // ---------------------------
            // Weight Read - Check bit [8]
            // ---------------------------
            if (i_cmd_weight_read && weight_select) begin
                o_read_data       <= i_weight_sram_dout;
                o_read_data_valid <= 1'b1;
            end

            // ---------------------------
            // Clauses Read - Check bit [9]
            // ---------------------------
            else if (i_cmd_Clauses_read && clauses_select) begin
                o_read_data       <= i_Clauses_sram_dout;
                o_read_data_valid <= 1'b1;
            end
        end
    end

endmodule
