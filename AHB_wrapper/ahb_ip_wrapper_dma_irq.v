module ahb_ip_wrapper_dma_irq (
    // ---------------------------------------------------------
    // AHB-Lite Bus Interface
    // ---------------------------------------------------------
    input  wire        ahb_hclk,
    input  wire        ahb_hresetn,
    input  wire        ahb_hsel,
    input  wire [15:0] ahb_haddr16,
    input  wire [1:0]  ahb_htrans,
    input  wire        ahb_hwrite,
    input  wire [31:0] ahb_hwdata,
    input  wire        ahb_hready,
    output wire        ahb_hreadyout,
    output reg  [31:0] ahb_hrdata,
    output wire        ahb_hresp,

    // ---------------------------------------------------------
    // IP Core Data Interface
    // ---------------------------------------------------------
//    output reg          init_done,
    // ---------------------------------------------------------
    // DMA Handshake Ports (Matched to your requested naming)
    // ---------------------------------------------------------
    output wire         drq_ipdma128,   // (to DMAC) input burst request
    input  wire         dlast_ipdma128, // (from DMAC) input burst end
    output wire         drq_opdma128,   // (to DMAC) output burst request
    input  wire         dlast_opdma128, // (from DMAC) output burst end

    // ---------------------------------------------------------
    // Interrupt Ports (Matched to your requested naming)
    // ---------------------------------------------------------
    output wire         irq_key128,     // Used as input request here
    output wire         irq_ip128,      // Can be tied off or used for intermediate steps
    output wire         irq_op128,      // Computation complete request
    output wire         irq_error,      // Invalid access error
    output wire         irq_merged      // Combined interrupt request to CPU
);

    // Standard AHB Slave responses
    assign ahb_hreadyout = 1'b1; 
    assign ahb_hresp     = 1'b0; 
    
    // Core instantiation
     reg  [255:0] clause_write;
     reg  [255:0] weight_write;
     reg  [31:0]  imagedata;
     reg          init_done;
     wire  [6:0]  x_imag_addr;
     reg  [31:0]  model_parameter;
     wire [3:0]   ip_final_answer;
     wire         ip_computation_done;
     
     //Internal signals
     reg wcyc_r;
     reg rcyc_r;

    // ---------------------------------------------------------
    // 1. AHB Bus Capture (Address & Control Phase)
    // ---------------------------------------------------------
    reg [15:0] ahb_haddr16_r;
    reg        ahb_hwrite_r;
    reg        ahb_hsel_r;
    reg [1:0]  ahb_htrans_r;

    always @(posedge ahb_hclk or negedge ahb_hresetn) begin
        if (!ahb_hresetn) begin
            ahb_haddr16_r  <= 16'd0;
            ahb_hwrite_r <= 1'b0;
            ahb_hsel_r   <= 1'b0;
            ahb_htrans_r <= 2'b00;
        end else if (ahb_hready) begin
            // ahb_haddr16_r  <= ahb_haddr16;
            // ahb_hwrite_r <= ahb_hwrite;
            // ahb_hsel_r   <= ahb_hsel;
            // ahb_htrans_r <= ahb_htrans;
            ahb_haddr16_r <= (ahb_hsel & ahb_htrans[1]) ?  ahb_haddr16 : ahb_haddr16_r;
            ahb_hsel_r    <= (ahb_hsel & ahb_htrans[1]);
            wcyc_r   <= (ahb_hsel & ahb_htrans[1]  &  ahb_hwrite);
            rcyc_r   <= (ahb_hsel & ahb_htrans[1]  & !ahb_hwrite);


        end
    end

    // Equates to wcyc_r and rcyc_r from your snippet
    //wire wcyc_r = ahb_hsel_r &&  ahb_hwrite_r && (ahb_htrans_r == 2'b10 || ahb_htrans_r == 2'b11);
    //wire rcyc_r = ahb_hsel_r && !ahb_hwrite_r && (ahb_htrans_r == 2'b10 || ahb_htrans_r == 2'b11);

    // Memory Map Decoding
    wire sel_clause = (ahb_haddr16_r[7:5] == 3'b000); // 0x00 - 0x1C
    wire sel_weight = (ahb_haddr16_r[7:5] == 3'b001); // 0x20 - 0x3C
    wire sel_image  = (ahb_haddr16_r[7:0] == 8'h40);
    wire sel_model  = (ahb_haddr16_r[7:0] == 8'h44);
    wire sel_ipbuf  = (sel_clause | sel_weight | sel_image);
    wire sel_opbuf  = (ahb_haddr16_r[7:0] == 8'h70);

    // ---------------------------------------------------------
    // 2. Core Internal Registers
    // ---------------------------------------------------------
   reg [1:0] control;      // [0]=IP RST, [1]=Error Clear,
    reg [1:0] drq_enable;   // [0]=Input DMA En, [1]=Output DMA En
    reg [2:0] irq_enable;   // [0]=Input IRQ En, [1]=Output IRQ En, [2]=Err IRQ En
    reg       error_flag;
    reg       model_written = 1'b0;

    // Data Registers
    reg [31:0] clause_reg [0:7];
    reg [31:0] weight_reg [0:7];
    reg [31:0] image_reg;

    reg [7:0] clause_cnt; 
    reg [5:0] weight_cnt; 
    reg [5:0] image_cnt ;  
    reg [7:0] clause_mask;
    reg [7:0] weight_mask;
    reg       image_mask;
    reg       stream_state; // new state to indicate streaming mode after initial setup


    wire [2:0] word_idx = ahb_haddr16_r[4:2];

    wire clause_done  = (model_written)&(clause_cnt >= (model_parameter[13:6]));
    wire weight_done  = (model_written)&((weight_cnt >= (model_parameter[17:14]*5)));  // model_params[17:14]
    wire image_done   = (image_cnt >= 6'd32);

    // assinging image address same as image count for simplicity
    assign x_imag_addr = image_cnt[6:0];
   // wire all_finished = (clause_done && weight_done && image_done); //// replacing this line with below
    wire all_finished = (clause_done && weight_done);

    wire clause_ready = (clause_mask == 8'hFF) || clause_done;
    wire weight_ready = (weight_mask == 8'hFF) || weight_done;
    wire image_ready  = image_mask || image_done;
   // wire trigger_pulse = clause_ready && weight_ready && image_ready && !all_finished && !init_done;
//    wire trigger_pulse = clause_ready && weight_ready && !all_finished && !init_done;
    wire enter_stream_state = !stream_state && clause_done && weight_done; // stream state is entered when both clause and weight are done, allowing image to be written
   // wire trigger_pulse = ((!stream_state && clause_ready && weight_ready && image_ready && !all_finished && !init_done) ||
                         // (stream_state && image_ready && !all_finished && !init_done));
    wire trigger_pulse = ((!stream_state && clause_ready && weight_ready && !all_finished && !init_done)); // depending on stream state, trigger pulse is generated when clause and weight are ready and not all finished and init done is low


    // additional signals for streaming state
    reg weight_stream_flag;
    reg clause_stream_flag;
    
    wire mod_rst;
    wire read_ack;
    wire error_ack;
    
    reg ip_computation_done_r;
    // ---------------------------------------------------------
    // 3. Write Handlers & Register Aliasing Logic
    // ---------------------------------------------------------
    integer i;
    always @(posedge ahb_hclk or negedge ahb_hresetn) begin
        if (!ahb_hresetn) begin
            control <= 3'b000; drq_enable <= 2'b00; irq_enable <= 3'b000;
            error_flag <= 1'b0; model_written <= 1'b0;
            clause_cnt <= 8'd0; weight_cnt <= 6'd0; image_cnt <= 6'd0;
            clause_mask <= 8'd0; weight_mask <= 8'd0; image_mask <= 1'b0;
            stream_state <= 1'b0;clause_stream_flag <= 1'b0; weight_stream_flag <= 1'b0;
            ip_computation_done_r <= 1'b0;
            for(i=0; i<8; i=i+1) begin clause_reg[i] <= 0; weight_reg[i] <= 0; end
            image_reg <= 0; init_done <= 0; clause_write <= 0; weight_write <= 0;
        end else begin
              if (control[0]) begin // software reset
                model_written <= 1'b0;
                stream_state  <= 1'b0;
                clause_stream_flag <= 1'b0;
                weight_stream_flag <= 1'b0;
                clause_cnt  <= 8'd0;
                weight_cnt  <= 6'd0;
                image_cnt   <= 6'd0;
                clause_mask <= 8'd0;
                weight_mask <= 8'd0;
                image_mask  <= 1'b0;
                init_done   <= 1'b0;
                //control[0]  <= 1'b0; // 0 clears the reset
            end
            
            if (ip_computation_done)
                ip_computation_done_r <= 1'b1;   // capture on the pulse
            else if(ip_computation_done_r & read_ack)
                 ip_computation_done_r <= 1'b0;   // capture on the pulse
            
            // --- 3A. DMA Auto-Terminate (From User Snippet) ---
            // If writing to input buffers and DMAC signals burst end, disable IP DMA
            if (sel_ipbuf & wcyc_r & dlast_ipdma128)
                drq_enable[0] <= 1'b0;
                
            // If reading from output buffer and DMAC signals burst end, disable OP DMA
            if (sel_opbuf & rcyc_r & dlast_opdma128)
                drq_enable[1] <= 1'b0;


            // --- 3B. Setup Registers (SET / CLR Aliasing) ---
            if (wcyc_r) begin
                case (ahb_haddr16_r[7:0])
                    8'h4C: control    <= ahb_hwdata[1:0];             // ADDR_CTRL Base
                    8'h50: {ip_computation_done_r , control}    <= {1'b0,control | ahb_hwdata[1:0]};   // ADDR_CTRL_SET writing nything will clear the interrupt
                    8'h54: control    <= control & ~ahb_hwdata[1:0];  // ADDR_CTRL_CLR
                    
                    //8'h58:  <= ahb_hwdata[1:0];             // ADDR_DREQ Base
                    8'h5C: drq_enable <= drq_enable | ahb_hwdata[1:0];// ADDR_DREQ_SET
                    8'h60: drq_enable <= drq_enable & ~ahb_hwdata[1:0];// ADDR_DREQ_CLR
                    
                    8'h64: irq_enable <= ahb_hwdata[2:0];             // ADDR_IREQ Base
                    8'h68: irq_enable <= irq_enable | ahb_hwdata[2:0];// ADDR_IREQ_SET
                    8'h6C: irq_enable <= irq_enable & ~ahb_hwdata[2:0];// ADDR_IREQ_CLR
                endcase
            end

            // Software Error Clear
            if (control[1]) begin 
                error_flag <= 1'b0; 
                control[1] <= 1'b0;
            end 

            // --- 3C. Data Capture ---
            if (wcyc_r) begin
                  if (stream_state) begin
                    if (sel_image) begin
                        image_reg  <= ahb_hwdata;
                        image_mask <= 1'b1;
                       // if (image_done) error_flag <= 1'b1;
                    if ((!image_done) )  image_cnt  <= image_cnt + 1;
                    else if (image_cnt >= 6'd32) image_cnt <= 6'b01; // Prevent overflow
                    end
                end else begin
                if (sel_clause) begin
                      if (!model_written) begin
                         error_flag <= 1'b1;
                      end else begin 
                    clause_reg[word_idx]  <= ahb_hwdata;
                    clause_mask[word_idx] <= 1'b1;
                    //if (clause_done) error_flag <= 1'b1; no need as of now
                    end
                end
                else if (sel_weight) begin
                 if (!model_written) begin
                         error_flag <= 1'b1;
                      end else begin 
                    weight_reg[word_idx]  <= ahb_hwdata;
                    weight_mask[word_idx] <= 1'b1;
                    //if (weight_done) error_flag <= 1'b1;
                    end
                end
                else if (sel_model) begin
                    if (!model_written) begin
                        model_parameter <= ahb_hwdata;
                        model_written <= 1'b1;
                    end else begin
                        error_flag <= 1'b1; // writing model param twice needs to be reset first
                    end
                end
            end
            end
            
              if (enter_stream_state) begin
                stream_state <= 1'b1;
                clause_stream_flag <= 1'b1;
                weight_stream_flag <= 1'b1;
            end


            imagedata    <= image_reg;
      /*      if (!image_done)  image_cnt  <= image_cnt + 1;
            else if (image_cnt >= 32) image_cnt <= 7'b00; // Prevent overflow */
            
            // --- 3D. Trigger IP Pulse ---
            if (trigger_pulse) begin
                init_done <= 1'b1;
                
                clause_write <= {clause_reg[7], clause_reg[6], clause_reg[5], clause_reg[4],
                                 clause_reg[3], clause_reg[2], clause_reg[1], clause_reg[0]};
                
                weight_write <= {weight_reg[7], weight_reg[6], weight_reg[5], weight_reg[4],
                                 weight_reg[3], weight_reg[2], weight_reg[1], weight_reg[0]};
                
                // imagedata    <= image_reg; // removing this from here and keeping it outside so image can pass out without initdone signal

                // Clear masks and increment counters
                clause_mask <= 8'd0; weight_mask <= 8'd0; image_mask  <= 1'b0;
                // if (!clause_done) clause_cnt <= clause_cnt + 1;
                // if (!weight_done) weight_cnt <= weight_cnt + 1;
                // // if (!image_done)  image_cnt  <= image_cnt + 1; putting it up
                 if (!stream_state) begin
                    if (!clause_done) clause_cnt <= clause_cnt + 1;
                    if (!weight_done) weight_cnt <= weight_cnt + 1;
                end
            end else begin
            	if(!stream_state)
                	init_done <= 1'b0;
//                else
//                	init_done <= 1'b1;
            end
        end
    end

    // ---------------------------------------------------------
    // 4. DMA and Interrupt Handshake (Snippet Implementation)
    // ---------------------------------------------------------
    // Active conditions (Only activate if control[0] - IP Enable is SET by CPU)
 //   wire drq_active_ip  = control[1] & (!all_finished);
   // wire drq_active_op  = control[0] & (ip_computation_done);
  //  wire drq_active_op  = (ip_computation_done) && (all_finished); // to be modified later
   // wire drq_active_err = error_flag;

    // 1. DMA channels (direct translation of snippet)
   // assign drq_ipdma128 = (drq_enable[0] & drq_active_ip); // Feeds data until all_finished
   // assign drq_opdma128 = (drq_enable[1] & drq_active_op); // Pulls answer when computation done
   // assign drq_opdma128 = (drq_active_op); 
    
    // 2. Interrupt Requests are MASKED OUT if corresponding DMA request is enabled
    // (This guarantees the CPU isn't interrupted to feed data if the DMA is already doing it!)
  //  wire irq_active_ip = drq_active_ip & !drq_enable[0]; 
  //  wire irq_active_op = drq_active_op & !drq_enable[1];
   // wire irq_active_err = drq_active_err; // Error is always directed to CPU

    // 3. Final AND with IREQ masking
//    assign irq_key128 = irq_active_ip & irq_enable[0]; // Using key128 port as the main input IRQ
//    assign irq_ip128  = 1'b0; // Spare, tied off
//    assign irq_op128  = irq_active_op & irq_enable[1];
//    assign irq_error  = irq_active_err & irq_enable[2];
    
    // Add near top of module, before first use:


//    // 4. Merge and Mask
//    assign read_ack = (rcyc_r & (ahb_haddr16 == 16'h70));
//     assign error_ack = (rcyc_r & (ahb_haddr16 == 16'h48));
    assign read_ack  = (rcyc_r & (ahb_haddr16_r[7:0] == 8'h70));
    assign error_ack = (rcyc_r & (ahb_haddr16_r[7:0] == 8'h48));
    assign irq_merged = (ip_computation_done_r & (!read_ack)) | (error_flag & (!error_ack)) ;
    

    // ---------------------------------------------------------
    // 5. AHB Read Multiplexer
    // ---------------------------------------------------------
    always @(*) begin
        if (ahb_hsel_r & rcyc_r) begin
            case (ahb_haddr16_r[7:0])
                8'h48: ahb_hrdata = {9'd0, 
                                 weight_cnt, ip_computation_done_r,
                                 clause_cnt, 
                                 error_flag, model_written, all_finished, 
                                 image_done, weight_done, clause_done};
                8'h4C: ahb_hrdata = {30'b11111111111111111111,ahb_haddr16_r[7:0],2'b00, control}; // this is just kept for testing
                8'h58: ahb_hrdata = 32'h52_43_6F_6E; // RCon
                8'h64: ahb_hrdata = 32'h43_6F_54_4D; // CoTM  ID
                8'h70: ahb_hrdata = {28'b0,ip_final_answer};
                //8'h78: ahb_hrdata = 32'h52_43_6F_6E;
                default: ahb_hrdata = 32'hbad0bad0;
            endcase
        end else begin
            ahb_hrdata = 32'd0;
        end
    end
    
   assign mod_rst = ahb_hresetn & ~control[0]; // control[0]=1 now actually forces core reset

     class_top core (  
    .clk(ahb_hclk),
    .i_rst_n(mod_rst), // added software reset  
    .init_done(init_done),
    .tdata(imagedata),
    .model_params(model_parameter),
    .x_w({1'b0,((image_cnt))}),
    .resetessen({!all_finished,!image_done}),// size have to decreased !
    .clause_write(clause_write),
    .weight_write(weight_write),
    .bram_addr_a(),
    .bram_addr_a2(),
    .output_params( ip_final_answer ),
    .tready(ip_computation_done)
);

endmodule


// temporary change please uncomment for connection

//`include "class_top.v"
//`default_nettype wire
//`include "weight_adder.v"
//`default_nettype wire
//`include "conv_arch.v"
//`default_nettype wire
//`include "conv_enable_generation.v"
//`default_nettype wire
//`include "Convolution.v"
//`default_nettype wire
//`include "processor_en.v"
//`default_nettype wire
//`include "addr_gen.v"
//`default_nettype wire
//`include "my_buffer.v"
//`default_nettype wire
//`include "remapunit.v"
//`default_nettype wire
//`include "top.v"
//`default_nettype wire
//`include "weight_adder.v"
//`default_nettype wire
