
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/14/2026 08:15:51 PM
// Design Name: 
// Module Name: tb_ahb_ip_wrapper
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

module tb_ahb_ip_wrapper;

    // AHB Signals
    reg         ahb_hclk;
    reg         ahb_hresetn;
    reg         ahb_hsel;
    reg  [15:0] ahb_haddr16;
    reg  [1:0]  ahb_htrans;
    reg         ahb_hwrite;
    reg  [31:0] ahb_hwdata;
    reg         ahb_hready;
    wire        ahb_hreadyout;
    wire [31:0] ahb_hrdata;
    wire        ahb_hresp;

    // IP Interfaces
    wire drq_ipdma128, drq_opdma128;
    wire irq_key128, irq_ip128, irq_op128, irq_error, irq_merged;

    // Clock Generation (100 MHz)
    initial begin
        ahb_hclk = 0;
        forever #5 ahb_hclk = ~ahb_hclk;
    end

    // DUT Instantiation
    ahb_ip_wrapper_dma_irq dut (
        .ahb_hclk(ahb_hclk),
        .ahb_hresetn(ahb_hresetn),
        .ahb_hsel(ahb_hsel),
        .ahb_haddr16(ahb_haddr16),
        .ahb_htrans(ahb_htrans),
        .ahb_hwrite(ahb_hwrite),
        .ahb_hwdata(ahb_hwdata),
        .ahb_hready(ahb_hready),
        .ahb_hreadyout(ahb_hreadyout),
        .ahb_hrdata(ahb_hrdata),
        .ahb_hresp(ahb_hresp),
        .drq_ipdma128(drq_ipdma128),
        .dlast_ipdma128(1'b0),
        .drq_opdma128(drq_opdma128),
        .dlast_opdma128(1'b0),
        .irq_key128(irq_key128),
        .irq_ip128(irq_ip128),
        .irq_op128(irq_op128),
        .irq_error(irq_error),
        .irq_merged(irq_merged)
    );

    // Standard AHB Write Task
    task ahb_write(input [15:0] addr, input [31:0] data);
    begin
        // Address Phase
        @(posedge ahb_hclk);
        ahb_hsel    = 1'b1;
        ahb_htrans  = 2'b10; // NONSEQ
        ahb_hwrite  = 1'b1;
        ahb_haddr16 = addr;
        ahb_hready  = 1'b1; 

        // Data Phase
        @(posedge ahb_hclk);
        ahb_hsel    = 1'b0;
        ahb_htrans  = 2'b00; // IDLE
        ahb_hwdata  = data;

        // Wait for slave to be ready
        while (!ahb_hreadyout) @(posedge ahb_hclk);
    end
    endtask
    
    
task ahb_bwrite(
    input [15:0]  addr,
    input integer a,
    input [255:0] data
);
    integer i;

    begin
        // First transfer: address/control phase
        @(posedge ahb_hclk);
        ahb_hsel     = 1'b1;
        ahb_htrans   = 2'b10;       // NONSEQ
        ahb_hwrite   = 1'b1;
        ahb_haddr16  = addr;
        ahb_hready   = 1'b1;

        // Remaining 7 transfers
        for (i = 0; i < a; i = i + 1) begin

            // Data phase of current transfer
            @(posedge ahb_hclk);
            ahb_hwdata = data[i*32 +: 32];

            // Address/control phase of NEXT transfer
            if (i < a-1) begin
                ahb_hsel    = 1'b1;
                ahb_htrans  = 2'b11;       // SEQ
                ahb_hwrite  = 1'b1;

                addr = addr + 16'd4;
                ahb_haddr16 = addr;
            end
            else begin
                // End of burst
                ahb_hsel    = 1'b0;
                ahb_htrans  = 2'b00;       // IDLE
                ahb_hwrite  = 1'b0;
            end

            // Wait for current transfer to complete
            while (!ahb_hreadyout)
                @(posedge ahb_hclk);
        end
    end
endtask
    
    task ahb_ibwrite(
    input [15:0]  addr,
    input integer a,
    input [31:0] data
);
    integer i;

    begin
        // First transfer: address/control phase
        @(posedge ahb_hclk);
        ahb_hsel     = 1'b1;
        ahb_htrans   = 2'b10;       // NONSEQ
        ahb_hwrite   = 1'b1;
        ahb_haddr16  = addr;
        ahb_hready   = 1'b1;

        // Remaining 3 transfers
        for (i = 0; i < a; i = i + 1) begin

            // Data phase of current transfer
            @(posedge ahb_hclk);
//            ahb_hwdata = data[i*32 +: 32];
                 ahb_hwdata = data;

            // Address/control phase of NEXT transfer
            if (i < a-1) begin
                ahb_hsel    = 1'b1;
                ahb_htrans  = 2'b11;       // SEQ
                ahb_hwrite  = 1'b1;

//                addr = addr + 16'd4;
//                ahb_haddr16 = addr;
            end
            else begin
                // End of burst
                ahb_hsel    = 1'b0;
                ahb_htrans  = 2'b00;       // IDLE
                ahb_hwrite  = 1'b0;
            end

            // Wait for current transfer to complete
            while (!ahb_hreadyout)
                @(posedge ahb_hclk);
        end
    end
endtask
    
            integer k = 0;  
 
reg [255:0] clause_mem [0:1023];

initial begin
    $readmemb("/home/23EC01002/working_tselinwrapper/clause.txt", clause_mem);
end

reg [255:0] weight_mem [0:1023];

initial begin
    $readmemb("/home/23EC01002/working_tselinwrapper/weight.txt", weight_mem);
end

reg [31:0] image_mem [0:16384];

//initial begin
//    $readmemb("/home/23EC01002/working_tselinwrapper/mnist_32x32_continuous.txt", image_mem);
//end

//initial begin
//    $readmemb("/home/23EC01002/working_tselinwrapper/output1000_128bit.txt", image_mem);
//end

//initial begin
//    $readmemb("/home/23EC01002/working_tselinwrapper/output_32bit_bulk.txt", image_mem);
//end

initial begin
    $readmemb("/home/23EC01002/working_tselinwrapper/simple_conv_128to32.txt", image_mem);
end

//reg [3:0] image_label [0:4096];

//initial begin
//    $readmemh("/home/23EC01002/working_tselinwrapper/mnist_labels.txt", image_label);
//end


       integer count_err = 0;

integer label= 0;
    // Variables for loops
    integer i, j;

    initial begin
        // Reset sequence
        ahb_hresetn = 0; ahb_hsel = 0; ahb_htrans = 0; ahb_hwrite = 0; 
        ahb_haddr16 = 0; ahb_hwdata = 0; ahb_hready = 1;
        
        #25 ahb_hresetn = 1;
        @(posedge ahb_hclk);
        
         ahb_write(16'h44,{4'b0000,18'b1010_10001100_001111}); 
        

        $display("[%0t] Starting initialization...", $time);

        // 1. Write 150 Clauses (Addresses 0x00 to 0x1C loop)
      /*  for (i = 0; i < 150; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                ahb_write(16'h0000 + (j * 4), (i * 100) + j); 
           ahb_write(16'h44,{4'b0000,18'b1010_10001100_001111}); 
            end
            // Need a dummy image write to trigger the cycle in normal mode
            ahb_write(16'h0040, 32'hDEADBEEF); 
        end */
        
        for (i = 0; i < 140; i = i + 1) begin
//            for (j = 0; j < 8; j = j + 1) begin
//                ahb_write(16'h0000 + (j * 4), clause_mem[i][32*j +: 32]); 
//            end
                ahb_bwrite(16'h0000, 8,clause_mem[i]); 
            if ( i < 50) begin
//            	 for (j = 0; j < 8; j = j + 1) begin
//                	ahb_write(16'h0020 + (j * 4), (i * 100) + j);
//            	end
                ahb_bwrite(16'h0020,8,weight_mem[i]);
            end
            
        end
        
           ahb_write(16'h4c,{4'b0000,32'h1}); 
        $display("reset assereted");
        #100;
         ahb_write(16'h4c,{4'b0000,32'h0}); 
          ahb_write(16'h44,{4'b0000,18'b1010_10001100_001111}); 
        

        $display("[%0t] Starting initialization... again", $time);

        // 1. Write 150 Clauses (Addresses 0x00 to 0x1C loop)
      /*  for (i = 0; i < 150; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                ahb_write(16'h0000 + (j * 4), (i * 100) + j); 
           ahb_write(16'h44,{4'b0000,18'b1010_10001100_001111}); 
            end
            // Need a dummy image write to trigger the cycle in normal mode
            ahb_write(16'h0040, 32'hDEADBEEF); 
        end */
        
        for (i = 0; i < 140; i = i + 1) begin
//            for (j = 0; j < 8; j = j + 1) begin
//                ahb_write(16'h0000 + (j * 4), clause_mem[i][32*j +: 32]); 
//            end
                ahb_bwrite(16'h0000, 8,clause_mem[i]); 
            if ( i < 50) begin
//            	 for (j = 0; j < 8; j = j + 1) begin
//                	ahb_write(16'h0020 + (j * 4), (i * 100) + j);
//            	end
                ahb_bwrite(16'h0020,8,weight_mem[i]);
            end
            
        end

        
        
 
        
        $display("[%0t] Finished writing 150 clauses. and 50 weights Clause count: %d", $time, dut.clause_cnt);

      /*  // 2. Write 50 Weights (Addresses 0x20 to 0x3C loop)
        for (i = 0; i < 50; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                ahb_write(16'h0020 + (j * 4), (i * 100) + j);
            end
            ahb_write(16'h0040, 32'hDEADBEEF); 
        end */
        $display("[%0t] Finished writing 50 weights. Weight count: %d", $time, dut.weight_cnt);
        
        // Wait a few clocks for states to settle
        repeat(5) @(posedge ahb_hclk);
    //      if (dut.init_done) 
             //   $display("  -> triggered IP successfully (init_done asserted). Image count: %d", dut.image_cnt);

        // 3. Verify stream_state logic
        if (dut.stream_state) begin
            $display("[%0t] SUCCESS: DUT successfully entered stream_state!", $time);
        end else begin
            $display("[%0t] FAILURE: DUT did not enter stream_state.", $time);
            $stop;
        end

        // 4. Test Image Streaming
        label = 0;
        $display("[%0t] Streaming a images...", $time);

        for (j = 0; j < 150; j = j + 1)begin
        for (k = 0; k < 32; k = k + 1) begin
            ahb_ibwrite(16'h0040,1, image_mem[(j << 5)+ k]);
            
            // Wait one clock and verify trigger_pulse happened
           /* if (dut.init_done) 
                $display("  -> Image %0d triggered IP successfully (init_done asserted). Image count: %d", i, dut.image_cnt);
            else
                $display("  -> ERROR: Image %0d did not trigger IP!", i); */
        end
         $display("Simulating: %d",j);
        
           @(posedge dut.core.tready);

           if(dut.ip_final_answer != (label)/96) count_err = count_err + 1;
//             if(dut.ip_final_answer != image_label[label]) count_err = count_err + 1;
              label = label + 1;          

           
        end
              repeat(5) @(posedge ahb_hclk);


        $display("[%0t] Simulation complete.", $time);
        #100 $finish;
    end

endmodule

//// Stub for class_top so the TB compiles standalone
//module class_top (
//    input clk, i_rst_n,
//    output reg init_done,
//    input [31:0] tdata, model_params,
//    input [6:0] x_w,
//    input [255:0] clause_write, weight_write,
//    output [15:0] bram_addr_a, bram_addr_a2,
//    output [31:0] output_params,
//    output reg tready
//);
//    assign output_params = 32'h12345678;
//    always @(posedge clk) begin
//        if (!i_rst_n) tready <= 0;
//        else tready <= 1; // Dummy constant response
//    end
//endmodule
