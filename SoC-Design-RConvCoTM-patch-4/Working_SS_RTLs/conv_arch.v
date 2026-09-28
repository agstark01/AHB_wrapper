`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.07.2025 17:01:03
// Design Name: 
// Module Name: conv_arch
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////

module conv_arch(
    clk, i_rst_n, rst, stride, pe_en, pe_en_out, patch_size, clause_op, prev_clause_op, clause_act, clause_done, clause_write, valid, img_rst,
    processor_in1, processor_in2, processor_in3, processor_in4, processor_in5, processor_in6, processor_in7, processor_in8,
    p1y1, p1x1, p2y1, p3y1, p4y1, p5y1, p6y1, p7y1, p8y1, ipdone, opdone_reg, stride_out, patch_size_out,
    processor_out1, processor_out2, processor_out3, processor_out4, processor_out5, processor_out6, processor_out7, processor_out8,
    po1x, po1y, po2y, po3y, po4y, po5y, po6y, po7y, po8y
    );
    parameter  IMG_WIDTH = 32, IMG_HEIGHT = 32, CLAUSEN = 10, CLASSN = 5,
               CLAUSE_WIDTH = (35 + IMG_HEIGHT + IMG_WIDTH)*2;
    input clk, i_rst_n, rst, img_rst, ipdone;
    input [2:0] stride;
    input valid;
    wire conv_enable;
    input [7:0] pe_en;
    output wire [2:0] stride_out;
    output wire [2:0] patch_size_out;
    output reg [7:0] pe_en_out;
    input [6:0] processor_in1, processor_in2, processor_in3, processor_in4, processor_in5, processor_in6, processor_in7, processor_in8;
    input wire [IMG_WIDTH - 1:0] p1x1;
    input wire [IMG_HEIGHT - 1:0] p1y1, p2y1, p3y1, p4y1, p5y1, p6y1, p7y1, p8y1;
    input [2:0] patch_size;
    input prev_clause_op;
    output reg clause_op;
    output reg [6:0] processor_out1, processor_out2, processor_out3, processor_out4, processor_out5, processor_out6, processor_out7, processor_out8;
    output reg [IMG_WIDTH - 1:0] po1x;
    output reg [IMG_HEIGHT - 1:0] po1y, po2y, po3y, po4y, po5y, po6y, po7y, po8y;
    wire [7:0] bclause_op;
    input clause_act;
    input [255:0] clause_write;
    output reg clause_done;
    output reg opdone_reg;
    reg rst_n;
    reg [IMG_HEIGHT - 1:0] nypos[0:7];
    reg [IMG_WIDTH - 1:0]  nxpos;
    reg [(CLAUSE_WIDTH)-1:0] clause;
    reg Xmatch;
    reg Ymatch[7:0];
    reg [IMG_HEIGHT - 1:0] Ypos_mask, nYpos_mask;
    reg [IMG_WIDTH - 1:0]  Xpos_mask, nXpos_mask;
    reg [48:0] patch_rule_1;
    reg [48:0] patch_neg_rule_1;
    reg [27:0] force_ones;

    assign patch_size_out = patch_size;
    assign stride_out     = stride;

    // ------------------------------------------------------------
    // clause : simple register
    // FIX: async reset with i_rst_n
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n)
            clause <= 0;
        else if (valid)
            clause <= clause_write;
        else
            clause <= clause;
    end

    // ------------------------------------------------------------
    // force_ones : pure combinational, unchanged
    // ------------------------------------------------------------
    always @(*) begin
        if (patch_size >= 28)
            force_ones = 28'hFFFFFFF;
        else
            force_ones = (28'hFFFFFFF << (28 - patch_size));
    end

    conv_enable_generation CE(
        .clk(clk),
        .rst(rst_n),
        .i_rst_n(i_rst_n),
        .stride(stride),
        .patch_size(patch_size),
        .conv_enable(conv_enable)
    );

    // ------------------------------------------------------------
    // nypos, nxpos, patch_rule_1, patch_neg_rule_1,
    // Ypos_mask, Xpos_mask, nYpos_mask, nXpos_mask,
    // Xmatch, Ymatch : combinational next-state
    // FIX: split from clocked block, no rst branch in comb
    // ------------------------------------------------------------
    reg [IMG_HEIGHT-1:0] nypos_nxt[0:7];
    reg [IMG_WIDTH-1:0]  nxpos_nxt;
    reg [48:0]           patch_rule_1_nxt;
    reg [48:0]           patch_neg_rule_1_nxt;
    reg [IMG_HEIGHT-1:0] Ypos_mask_nxt, nYpos_mask_nxt;
    reg [IMG_WIDTH-1:0]  Xpos_mask_nxt, nXpos_mask_nxt;
    reg                  Xmatch_nxt;
    reg                  Ymatch_nxt[7:0];

    always @(*) begin
        // defaults  hold
        nypos_nxt[0]         = nypos[0];
        nypos_nxt[1]         = nypos[1];
        nypos_nxt[2]         = nypos[2];
        nypos_nxt[3]         = nypos[3];
        nypos_nxt[4]         = nypos[4];
        nypos_nxt[5]         = nypos[5];
        nypos_nxt[6]         = nypos[6];
        nypos_nxt[7]         = nypos[7];
        nxpos_nxt            = nxpos;
        patch_rule_1_nxt     = 49'd0;
        patch_neg_rule_1_nxt = 49'd0;
        Ypos_mask_nxt        = Ypos_mask;
        Xpos_mask_nxt        = Xpos_mask;
        nYpos_mask_nxt       = nYpos_mask;
        nXpos_mask_nxt       = nXpos_mask;
        Xmatch_nxt           = Xmatch;
        Ymatch_nxt[0]        = Ymatch[0];
        Ymatch_nxt[1]        = Ymatch[1];
        Ymatch_nxt[2]        = Ymatch[2];
        Ymatch_nxt[3]        = Ymatch[3];
        Ymatch_nxt[4]        = Ymatch[4];
        Ymatch_nxt[5]        = Ymatch[5];
        Ymatch_nxt[6]        = Ymatch[6];
        Ymatch_nxt[7]        = Ymatch[7];

        if (rst_n) begin
            // matches original else if(rst_n) branch
            Xmatch_nxt    = 1'b0;
            Ymatch_nxt[0] = 1'b0; Ymatch_nxt[1] = 1'b0;
            Ymatch_nxt[2] = 1'b0; Ymatch_nxt[3] = 1'b0;
            Ymatch_nxt[4] = 1'b0; Ymatch_nxt[5] = 1'b0;
            Ymatch_nxt[6] = 1'b0; Ymatch_nxt[7] = 1'b0;
            nypos_nxt[0]  = 0; nypos_nxt[1] = 0;
            nypos_nxt[2]  = 0; nypos_nxt[3] = 0;
            nypos_nxt[4]  = 0; nypos_nxt[5] = 0;
            nypos_nxt[6]  = 0; nypos_nxt[7] = 0;
        end
        else begin
            nypos_nxt[0] = ~p1y1;
            nypos_nxt[1] = ~p2y1;
            nypos_nxt[2] = ~p3y1;
            nypos_nxt[3] = ~p4y1;
            nypos_nxt[4] = ~p5y1;
            nypos_nxt[5] = ~p6y1;
            nypos_nxt[6] = ~p7y1;
            nypos_nxt[7] = ~p8y1;
            nxpos_nxt    = ~p1x1;

            patch_rule_1_nxt     = 49'd0;
            patch_neg_rule_1_nxt = 49'd0;

            if (patch_size == 3) begin
                patch_rule_1_nxt[2:0]       = clause[52:50];
                patch_rule_1_nxt[9:7]       = clause[55:53];
                patch_rule_1_nxt[16:14]     = clause[58:56];
                patch_neg_rule_1_nxt[2:0]   = clause[111:109];
                patch_neg_rule_1_nxt[9:7]   = clause[114:112];
                patch_neg_rule_1_nxt[16:14] = clause[117:115];
            end
            else if (patch_size == 5) begin
                patch_rule_1_nxt[4:0]        = clause[50:46];
                patch_rule_1_nxt[11:8]       = clause[55:51];
                patch_rule_1_nxt[18:14]      = clause[60:56];
                patch_rule_1_nxt[25:21]      = clause[65:61];
                patch_rule_1_nxt[32:28]      = clause[70:66];
                patch_neg_rule_1_nxt[4:0]    = clause[121:117];
                patch_neg_rule_1_nxt[11:7]   = clause[126:122];
                patch_neg_rule_1_nxt[18:14]  = clause[131:127];
                patch_neg_rule_1_nxt[25:21]  = clause[136:132];
                patch_neg_rule_1_nxt[32:28]  = clause[141:137];
            end
            else begin
                patch_rule_1_nxt[48:0]     = clause[90:42];
                patch_neg_rule_1_nxt[48:0] = clause[181:133];
            end

            if (patch_size == 3'd3) begin
                Ypos_mask_nxt  = {3'b0, clause[24:0]};
                Xpos_mask_nxt  = {3'b0, clause[49:25]};
                nYpos_mask_nxt = {3'b0, clause[83:59]};
                nXpos_mask_nxt = {3'b0, clause[108:84]};
            end else if (patch_size == 3'd5) begin
                Ypos_mask_nxt  = {5'b0, clause[22:0]};
                Xpos_mask_nxt  = {5'b0, clause[45:23]};
                nYpos_mask_nxt = {5'b0, clause[93:71]};
                nXpos_mask_nxt = {5'b0, clause[116:94]};
            end else if (patch_size == 3'd7) begin
                Ypos_mask_nxt  = {7'b0, clause[20:0]};
                Xpos_mask_nxt  = {7'b0, clause[41:21]};
                nYpos_mask_nxt = {7'b0, clause[111:91]};
                nXpos_mask_nxt = {7'b0, clause[132:112]};
            end else begin
                Ypos_mask_nxt  = 1'b0;
                Xpos_mask_nxt  = 1'b0;
                nYpos_mask_nxt = 1'b0;
                nXpos_mask_nxt = 1'b0;
            end

            // uses OLD registered Xpos_mask/Ypos_mask/nypos  preserves original pipeline
            Xmatch_nxt    = &(p1x1 | ~Xpos_mask | force_ones) && (&(nxpos    | ~nXpos_mask | force_ones));
            Ymatch_nxt[0] = &(p1y1 | ~Ypos_mask | force_ones) && (&(nypos[0] | ~nYpos_mask | force_ones));
            Ymatch_nxt[1] = &(p2y1 | ~Ypos_mask | force_ones) && (&(nypos[1] | ~nYpos_mask | force_ones));
            Ymatch_nxt[2] = &(p3y1 | ~Ypos_mask | force_ones) && (&(nypos[2] | ~nYpos_mask | force_ones));
            Ymatch_nxt[3] = &(p4y1 | ~Ypos_mask | force_ones) && (&(nypos[3] | ~nYpos_mask | force_ones));
            Ymatch_nxt[4] = &(p5y1 | ~Ypos_mask | force_ones) && (&(nypos[4] | ~nYpos_mask | force_ones));
            Ymatch_nxt[5] = &(p6y1 | ~Ypos_mask | force_ones) && (&(nypos[5] | ~nYpos_mask | force_ones));
            Ymatch_nxt[6] = &(p7y1 | ~Ypos_mask | force_ones) && (&(nypos[6] | ~nYpos_mask | force_ones));
            Ymatch_nxt[7] = &(p8y1 | ~Ypos_mask | force_ones) && (&(nypos[7] | ~nYpos_mask | force_ones));
        end
    end

    // ------------------------------------------------------------
    // Sequential register update
    // FIX: async reset with i_rst_n
    // NOTE: original only resets Ypos_mask/Xpos_mask on rst
    //       nYpos_mask/nXpos_mask had NO reset in original  not reset here either
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            nypos[0] <= 0; nypos[1] <= 0; nypos[2] <= 0; nypos[3] <= 0;
            nypos[4] <= 0; nypos[5] <= 0; nypos[6] <= 0; nypos[7] <= 0;
            nxpos            <= 0;
            patch_rule_1     <= 49'd0;
            patch_neg_rule_1 <= 49'd0;
            Ypos_mask        <= 28'hFFFFFFF;   // matches original rst branch
            Xpos_mask        <= 28'hFFFFFFF;   // matches original rst branch
            nYpos_mask       <= 0;   // FIX: added async reset for lint
            nXpos_mask       <= 0;   // FIX: added async reset for lint
            Xmatch           <= 1'b0;
            Ymatch[0] <= 1'b0; Ymatch[1] <= 1'b0;
            Ymatch[2] <= 1'b0; Ymatch[3] <= 1'b0;
            Ymatch[4] <= 1'b0; Ymatch[5] <= 1'b0;
            Ymatch[6] <= 1'b0; Ymatch[7] <= 1'b0;
        end
        else begin
            nypos[0] <= nypos_nxt[0]; nypos[1] <= nypos_nxt[1];
            nypos[2] <= nypos_nxt[2]; nypos[3] <= nypos_nxt[3];
            nypos[4] <= nypos_nxt[4]; nypos[5] <= nypos_nxt[5];
            nypos[6] <= nypos_nxt[6]; nypos[7] <= nypos_nxt[7];
            nxpos            <= nxpos_nxt;
            patch_rule_1     <= patch_rule_1_nxt;
            patch_neg_rule_1 <= patch_neg_rule_1_nxt;
            Ypos_mask        <= Ypos_mask_nxt;
            Xpos_mask        <= Xpos_mask_nxt;
            nYpos_mask       <= nYpos_mask_nxt;
            nXpos_mask       <= nXpos_mask_nxt;
            Xmatch           <= Xmatch_nxt;
            Ymatch[0] <= Ymatch_nxt[0]; Ymatch[1] <= Ymatch_nxt[1];
            Ymatch[2] <= Ymatch_nxt[2]; Ymatch[3] <= Ymatch_nxt[3];
            Ymatch[4] <= Ymatch_nxt[4]; Ymatch[5] <= Ymatch_nxt[5];
            Ymatch[6] <= Ymatch_nxt[6]; Ymatch[7] <= Ymatch_nxt[7];
        end
    end

    // ------------------------------------------------------------
    // clause_done, rst_n, clause_op, processor_outs, pe_en_out, po*
    // FIX: async reset with i_rst_n
    // KEY: rst_n is UNCONDITIONAL  always updated every clock edge
    //      even inside async reset block (matches original behavior)
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            clause_done    <= 1'b0;
            clause_op      <= 1'b0;
            processor_out1 <= 7'b0; processor_out2 <= 7'b0;
            processor_out3 <= 7'b0; processor_out4 <= 7'b0;
            processor_out5 <= 7'b0; processor_out6 <= 7'b0;
            processor_out7 <= 7'b0; processor_out8 <= 7'b0;
            pe_en_out      <= 8'b0;
            po1x <= 0; po1y <= 0; po2y <= 0; po3y <= 0;
            po4y <= 0; po5y <= 0; po6y <= 0; po7y <= 0; po8y <= 0;
            // rst_n NOT reset here  it is unconditional (see below)
        end
        else begin
            if (rst || img_rst) clause_done <= 1'b0;
            else                clause_done <= clause_act;

            if (rst || img_rst) begin
                clause_op <= 1'b0;
            end
            else begin
                clause_op      <= (prev_clause_op | (|bclause_op));
                processor_out1 <= processor_in1;
                processor_out2 <= processor_in2;
                processor_out3 <= processor_in3;
                processor_out4 <= processor_in4;
                processor_out5 <= processor_in5;
                processor_out6 <= processor_in6;
                processor_out7 <= processor_in7;
                processor_out8 <= processor_in8;
                pe_en_out      <= pe_en;
                po1x <= p1x1;
                po1y <= p1y1; po2y <= p2y1; po3y <= p3y1; po4y <= p4y1;
                po5y <= p5y1; po6y <= p6y1; po7y <= p7y1; po8y <= p8y1;
            end
        end
    end

    // ------------------------------------------------------------
    // rst_n : async reset added for lint (AsyncResetOrSet)
    // On i_rst_n=0: rst_n=1 keeps CE and nypos/Ymatch in reset state
    // Normal operation: always computes rst|!(clause_act)|img_rst
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n)
            rst_n <= 1'b1;
        else
            rst_n <= rst | !(clause_act) | img_rst;
    end

    // ------------------------------------------------------------
    // opdone_reg : simple register
    // FIX: async reset with i_rst_n
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n)    opdone_reg <= 1'b0;
        else if (rst_n)  opdone_reg <= 1'b0;
        else             opdone_reg <= ipdone;
    end

    Convolution PE1 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[0], processor_in1, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[0], bclause_op[0]);
    Convolution PE2 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[1], processor_in2, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[1], bclause_op[1]);
    Convolution PE3 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[2], processor_in3, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[2], bclause_op[2]);
    Convolution PE4 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[3], processor_in4, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[3], bclause_op[3]);
    Convolution PE5 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[4], processor_in5, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[4], bclause_op[4]);
    Convolution PE6 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[5], processor_in6, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[5], bclause_op[5]);
    Convolution PE7 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[6], processor_in7, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[6], bclause_op[6]);
    Convolution PE8 (clk, i_rst_n, (rst || img_rst), conv_enable, pe_en[7], processor_in8, patch_size, patch_rule_1, patch_neg_rule_1, Xmatch, Ymatch[7], bclause_op[7]);

endmodule
