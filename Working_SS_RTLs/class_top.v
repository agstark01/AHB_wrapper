`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.07.2025 18:30:22
// Design Name: 
// Module Name: class_top
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
// 
//////////////////////////////////////////////////////////////////////////////////

module class_top#(
    parameter CLAUSEN = 140,
    CLASSN = 10,
    HEIGHT = 28,
    WIDTH  = 28,
    CLAUSE_WIDTH = (35 + HEIGHT + WIDTH)*2
)(  
    input clk,
   // input rt,
    input i_rst_n,
    input init_done,
    input [17:0] model_params,
    input [31:0] tdata,
    input [255:0] clause_write,
    input [255:0] weight_write,
    input [1:0] resetessen;
   // input tvalid,
   // input [15:0] tkeep,
    // input tlast,
    output reg [14:0] bram_addr_a,
    output reg [14:0] bram_addr_a2,
    output reg tready,
    // output enb,
    output reg [3:0] output_params,
    // output reg [31:0] web,
    // output reg [255:0] dinb,
    // output wire img_done
);
    wire img_rst;
    //rst;
    integer x;
    wire [127:0] total_img;
    wire [2:0] stride;
    reg [3:0] class_op;
    wire [3:0] class_op_wire;
    wire wea, wea2;
    wire [14:0] bram_addr_a_wire;
    wire [14:0] bram_addr_a2_wire;
    reg [((HEIGHT + 8)*WIDTH)-1:0] total_memory;
    wire [8:0] clause;
    wire img_done_wire;
    reg img_load_done;
    integer i, j, k, l;
    wire done_rmu;
    genvar idx;
    wire clause_act;
    reg [5:0] cycle_count;
    reg shift_enable;
    wire [7:0] pixel_out;
    wire [3:0] classes;
    reg [7:0] pixel_in;
    wire [7:2] residues_buf;
    wire [7:2] residues_rmu;
    wire [$clog2(WIDTH + 2):0] img_width_count;
    wire [7:0] pe_en;
    wire reset;
    wire [2:0] patch_size;
    wire [6:0] processor_in1,processor_in2,processor_in3,processor_in4,processor_in5,processor_in6,processor_in7,processor_in8;
    wire [WIDTH - 1:0] p1x1;
    wire [HEIGHT - 1:0] p1y1,p2y1,p3y1,p4y1,p5y1,p6y1,p7y1,p8y1;
    genvar b;
    wire cycle_change;
    wire [4:0] img_wide;

    assign img_wide    = WIDTH;
    assign clause      = model_params[13:6];
    assign classes     = model_params[17:14];
   //     assign img_rst     = rst ? 1 : img_done_wire;
     assign img_rst     = img_done_wire;

    // assign enb         = 1;
    assign total_img   = tdata;
  //  assign rst         = rt | init_done;
    assign patch_size  = model_params[2:0];
    assign stride      = model_params[5:3];
    assign wea         = init_done ? 1'b1 : (bram_addr_a  < {{6{1'b0}}, clause}) ? 1'b1 : 1'b0;
    assign wea2        = init_done ? 1'b1 : (bram_addr_a2 < classes * 5)         ? 1'b1 : 1'b0;
    //assign reset       = wea || rst || !img_load_done || wea2;
    assign reset       =  resetessen[1] || resetessen[0];

    // assign img_done    = img_done_wire;

    reg [9:0] addr0,addr1,addr2,addr3,addr4,addr5,addr6,addr7;
    reg valid_addr;
    assign bram_addr_a_wire  = bram_addr_a;
    assign bram_addr_a2_wire = bram_addr_a2;
    reg p0,p1,p2,p3,p4,p5,p6,p7;

    // ------------------------------------------------------------
    // BRAM address increment  bram_addr_a, bram_addr_a2, web, dinb, i
    // FIX: async reset with i_rst_n
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // web          <= 4'b0;
            // dinb         <= 32'b0;
            i            <= 0;
            bram_addr_a  <= 0;
            bram_addr_a2 <= 0;
        end
        else 
        // begin
        //     if (rst) begin
        //         web          <= 4'b0;
        //         dinb         <= 32'b0;
        //         i            <= 0;
        //         bram_addr_a  <= 0;
        //         bram_addr_a2 <= 0;
        //     end
        //     else 
            begin
                if (wea || wea2) begin
                    bram_addr_a2 <= wea2 ? bram_addr_a2 + 1 : bram_addr_a2;
                    bram_addr_a  <= wea  ? bram_addr_a  + 1 : bram_addr_a;
                end
                else begin
                    bram_addr_a  <= bram_addr_a;
                    bram_addr_a2 <= bram_addr_a2;
                end
            end
        end
    // end

    // Buffer instantiation
    buffer #(.BUF_WIDTH(WIDTH+2)) Buf(
        .clk(clk),
        .rst(reset),
        .i_rst_n(i_rst_n),
        .pixel_in(pixel_in),
        .shift_enable(shift_enable),
        .done(1'b0),
        .img_width(img_wide),
        .pixel_out(pixel_out),
        .residues(residues_buf),
        .cycle_change(cycle_change),
        .img_width_count(img_width_count)
    );

    // Reversing residues
    generate
        for (b = 2; b < 8; b = b + 1) begin: reverse_loop
            assign residues_rmu[b] = residues_buf[9 - b];
        end
    endgenerate

    // Remap unit instantiation
    remapunit #(
        .IMG_WIDTH(WIDTH),
        .IMG_HEIGHT(HEIGHT)
    ) R (
        .clk(clk),
        .i_rst_n(i_rst_n),
        .rst(reset),
        .patch_size(patch_size),
        .stride(stride),
        .done(done_rmu),
        .xcor1(img_width_count),
        .pixel_in(pixel_out),
        .residues(residues_rmu),
        .cycle_counts(cycle_count),
        .cycle_detect(cycle_change),
        .processor_in1(processor_in1), .processor_in2(processor_in2),
        .processor_in3(processor_in3), .processor_in4(processor_in4),
        .processor_in5(processor_in5), .processor_in6(processor_in6),
        .processor_in7(processor_in7), .processor_in8(processor_in8),
        .p_en(pe_en),
        .p1y1(p1y1), .p1x1(p1x1), .p2y1(p2y1), .p3y1(p3y1), .p4y1(p4y1),
        .p5y1(p5y1), .p6y1(p6y1), .p7y1(p7y1), .p8y1(p8y1),
        .clause_act(clause_act)
    );

    // ------------------------------------------------------------
    // Image address generation  addr0..7, valid_addr
    // FIX: async reset with i_rst_n
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            addr0 <= 0; addr1 <= 0; addr2 <= 0; addr3 <= 0;
            addr4 <= 0; addr5 <= 0; addr6 <= 0; addr7 <= 0;
            valid_addr <= 0;
        end
        else begin
            if (reset) begin
                addr0 <= 0; addr1 <= 0; addr2 <= 0; addr3 <= 0;
                addr4 <= 0; addr5 <= 0; addr6 <= 0; addr7 <= 0;
                valid_addr <= 0;
            end
            else begin
                addr0 <= (j+0)*WIDTH + k;
                addr1 <= (j+1)*WIDTH + k;
                addr2 <= (j+2)*WIDTH + k;
                addr3 <= (j+3)*WIDTH + k;
                addr4 <= (j+4)*WIDTH + k;
                addr5 <= (j+5)*WIDTH + k;
                addr6 <= (j+6)*WIDTH + k;
                addr7 <= (j+7)*WIDTH + k;
                valid_addr <= ((j*WIDTH)+k < WIDTH*HEIGHT);
            end
        end
    end

    // ------------------------------------------------------------
    // Pixel access  p0..p7
    // FIX: async reset with i_rst_n
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            p0<=0; p1<=0; p2<=0; p3<=0;
            p4<=0; p5<=0; p6<=0; p7<=0;
        end
        else begin
            if (reset) begin
                p0<=0; p1<=0; p2<=0; p3<=0;
                p4<=0; p5<=0; p6<=0; p7<=0;
            end
            else begin
                if (valid_addr) begin
                    p0 <= total_memory[addr0];
                    p1 <= total_memory[addr1];
                    p2 <= total_memory[addr2];
                    p3 <= total_memory[addr3];
                    p4 <= total_memory[addr4];
                    p5 <= total_memory[addr5];
                    p6 <= total_memory[addr6];
                    p7 <= total_memory[addr7];
                end
                else begin
                    p0 <= 1'b0; p1 <= 1'b0; p2 <= 1'b0; p3 <= 1'b0;
                    p4 <= 1'b0; p5 <= 1'b0; p6 <= 1'b0; p7 <= 1'b0;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Pixel packing  pixel_in, shift_enable
    // FIX: async reset with i_rst_n
    // ------------------------------------------------------------
    always @(posedge clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tready        <= 0;
            output_params <= 0;
            img_load_done <= 0;
            cycle_count   <= 6'b1;    // FIX 2: was 1 (preset FF on bit[0]), now 0
            k             <= 0;
            j             <= 0;
            class_op      <= 0;
            total_memory  <= 0;
        end
        else begin
        /*    if (rst) begin
                tready        <= 0;
                output_params <= 0;
                x             <= 6'sd0;   // FIX 1: was -2, now 0
                img_load_done <= 0;
                cycle_count   <= 1;       // sync reset keeps cycle_count=1 (UNCHANGED)
                k             <= 0;
                j             <= 0;
                class_op      <= 0;
                total_memory  <= 0;
            end
            else begin */
             tready <= img_done_wire;
                if (img_rst) begin
                 //   tready        <= 0; right now commented
                    img_load_done <= 0;
                end
                else begin
                    //tready   <= !img_load_done && !wea && !wea2;
                    //tready <= !img_load_done;
                    // tready <= img_done_wire; moving tready up
                    class_op <= class_op_wire;

                    
                    if (!(img_rst || !reset)) begin
                        for (i = 0; i < 32; i = i + 1) begin
                            total_memory[((x - 1'd1) << 5) + i] <= total_img[i];
                        end
                       // total_memory[((x) << 5) +: 32] <= total_img;
                    end
                    if (x == 7'd32) begin
                        img_load_done <= 1;
                      //  tready        <= 0; moving up
                    end
                     if (resetessen[0]) begin
                        img_load_done <= 0;
                      //  tready        <= 0; moving up
                    end

                    if (!reset && !cycle_change) begin
                        k <= k + 1;
                    end
                    else if (cycle_change && !reset) begin
                        j           <= j + 8;
                        k           <= 0;
                        cycle_count <= cycle_count + 1;
                    end
                    else begin
                        j           <= 0;
                        k           <= 0;
                        cycle_count <= 1;
                    end
                end

                if (img_done_wire) output_params <= class_op;
                else               output_params <= output_params;
            end
    end

    // Convolution Engine instantiation
    top #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .CLAUSEN(CLAUSEN),
        .CLASSN(CLASSN),
        .CLAUSE_WIDTH(CLAUSE_WIDTH)
    ) T (
        .clk(clk),
       // .rst(rst),
        .i_rst_n(i_rst_n),
        .img_rst(img_rst),
        .patch_size(patch_size),
        .stride(stride),
        .wea(wea),
        .bram_addr_a(bram_addr_a_wire),
        .clause_write(clause_write),
        .pe_en(pe_en),
        .clauses(clause),
        .weight_write(weight_write),
        .wea2(wea2),
        .bram_addr_a2(bram_addr_a2_wire),
        .clause_act(clause_act),
        .processor_in1(processor_in1),
        .processor_in2(processor_in2),
        .processor_in3(processor_in3),
        .processor_in4(processor_in4),
        .processor_in5(processor_in5),
        .processor_in6(processor_in6),
        .processor_in7(processor_in7),
        .processor_in8(processor_in8),
        .p1y1(p1y1),
        .p1x1(p1x1),
        .p2y1(p2y1),
        .p3y1(p3y1),
        .p4y1(p4y1),
        .p5y1(p5y1),
        .p6y1(p6y1),
        .p7y1(p7y1),
        .p8y1(p8y1),
        .done(img_done_wire),
        .class_op(class_op_wire),
        .done_rmu(done_rmu)
    );

endmodule
