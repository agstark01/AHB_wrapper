// ============================================================================
// Modified APB Accelerator Register Block with o_load_done Control
// 
// Changes:
// 1. o_weight_addr uses bits [9:0] with control bits
// 2. Result capture now done internally using img_done signal
// 3. Command error detection added using one-hot encoding
// 4. o_load_done register added at index 45 to control STOP signal
// ============================================================================

module apb_accel_regs
(
    // ====================================================
    // APB interface
    // ====================================================
    input  wire              PCLK,
    input  wire              PRESETn,

    input  wire              PSEL,
    input  wire [11:2]       PADDR,     // word-aligned address
    input  wire              PENABLE,
    input  wire              PWRITE,
    input  wire [31:0]       PWDATA,
    input  wire [3:0]        PSTRB,

    output wire [31:0]       PRDATA,
    output wire              PREADY,
    output wire              PSLVERR,

    // ====================================================
    // Result from ACC (captured internally on img_done)
    // ====================================================
    input  wire [3:0]        i_result_data_in,   // From class_top
    input  wire              i_img_done,          // Done signal from class_top

    // ====================================================
    // Weight registers (10) -> to weights/clauses glue
    // ====================================================
    output wire [31:0]       o_weight_data0,
    output wire [31:0]       o_weight_data1,
    output wire [31:0]       o_weight_data2,
    output wire [31:0]       o_weight_data3,
    output wire [31:0]       o_weight_data4,
    output wire [31:0]       o_weight_data5,
    output wire [31:0]       o_weight_data6,
    output wire [31:0]       o_weight_data7,
    output wire [31:0]       o_weight_addr,     // 10 bits used [9:0]

    // 1-cycle command pulses for glue logic
    output wire              o_cmd_weight_write,
    output wire              o_cmd_weight_read,
    output wire              o_cmd_clauses_write,
    output wire              o_cmd_clauses_read,
    
    // Command error output (mutual exclusion violation)
    output wire              o_cmd_error,

    // ====================================================
    // Image registers (32 data) -> to image glue
    // ====================================================
    output wire [31:0]       o_img_data0,
    output wire [31:0]       o_img_data1,
    output wire [31:0]       o_img_data2,
    output wire [31:0]       o_img_data3,
    output wire [31:0]       o_img_data4,
    output wire [31:0]       o_img_data5,
    output wire [31:0]       o_img_data6,
    output wire [31:0]       o_img_data7,
    output wire [31:0]       o_img_data8,
    output wire [31:0]       o_img_data9,
    output wire [31:0]       o_img_data10,
    output wire [31:0]       o_img_data11,
    output wire [31:0]       o_img_data12,
    output wire [31:0]       o_img_data13,
    output wire [31:0]       o_img_data14,
    output wire [31:0]       o_img_data15,
    output wire [31:0]       o_img_data16,
    output wire [31:0]       o_img_data17,
    output wire [31:0]       o_img_data18,
    output wire [31:0]       o_img_data19,
    output wire [31:0]       o_img_data20,
    output wire [31:0]       o_img_data21,
    output wire [31:0]       o_img_data22,
    output wire [31:0]       o_img_data23,
    output wire [31:0]       o_img_data24,
    output wire [31:0]       o_img_data25,
    output wire [31:0]       o_img_data26,
    output wire [31:0]       o_img_data27,
    output wire [31:0]       o_img_data28,
    output wire [31:0]       o_img_data29,
    output wire [31:0]       o_img_data30,
    output wire [31:0]       o_img_data31,

    // 1-cycle pulse to image glue to start transfer
    output wire              o_img_cmd_pulse,

    // ====================================================
    // Model parameters (19 bits) -> to class_top
    // ====================================================
    output wire [18:0]       o_model_params,
    
    // ====================================================
    // Load done control -> to class_top STOP input
    // ====================================================
    output reg               o_load_done
);

    // ====================================================
    // Address index constants (PADDR[11:2])
    // ====================================================
    // Weights 0..7, addr, cmd
    localparam [9:0] ADDR_WEIGHT0       = 10'd0;
    localparam [9:0] ADDR_WEIGHT1       = 10'd1;
    localparam [9:0] ADDR_WEIGHT2       = 10'd2;
    localparam [9:0] ADDR_WEIGHT3       = 10'd3;
    localparam [9:0] ADDR_WEIGHT4       = 10'd4;
    localparam [9:0] ADDR_WEIGHT5       = 10'd5;
    localparam [9:0] ADDR_WEIGHT6       = 10'd6;
    localparam [9:0] ADDR_WEIGHT7       = 10'd7;
    localparam [9:0] ADDR_WADDR         = 10'd8;
    localparam [9:0] ADDR_WCMD          = 10'd9;

    // Image data 0..31
    localparam [9:0] ADDR_IMG0          = 10'd10;
    localparam [9:0] ADDR_IMG1          = 10'd11;
    localparam [9:0] ADDR_IMG2          = 10'd12;
    localparam [9:0] ADDR_IMG3          = 10'd13;
    localparam [9:0] ADDR_IMG4          = 10'd14;
    localparam [9:0] ADDR_IMG5          = 10'd15;
    localparam [9:0] ADDR_IMG6          = 10'd16;
    localparam [9:0] ADDR_IMG7          = 10'd17;
    localparam [9:0] ADDR_IMG8          = 10'd18;
    localparam [9:0] ADDR_IMG9          = 10'd19;
    localparam [9:0] ADDR_IMG10         = 10'd20;
    localparam [9:0] ADDR_IMG11         = 10'd21;
    localparam [9:0] ADDR_IMG12         = 10'd22;
    localparam [9:0] ADDR_IMG13         = 10'd23;
    localparam [9:0] ADDR_IMG14         = 10'd24;
    localparam [9:0] ADDR_IMG15         = 10'd25;
    localparam [9:0] ADDR_IMG16         = 10'd26;
    localparam [9:0] ADDR_IMG17         = 10'd27;
    localparam [9:0] ADDR_IMG18         = 10'd28;
    localparam [9:0] ADDR_IMG19         = 10'd29;
    localparam [9:0] ADDR_IMG20         = 10'd30;
    localparam [9:0] ADDR_IMG21         = 10'd31;
    localparam [9:0] ADDR_IMG22         = 10'd32;
    localparam [9:0] ADDR_IMG23         = 10'd33;
    localparam [9:0] ADDR_IMG24         = 10'd34;
    localparam [9:0] ADDR_IMG25         = 10'd35;
    localparam [9:0] ADDR_IMG26         = 10'd36;
    localparam [9:0] ADDR_IMG27         = 10'd37;
    localparam [9:0] ADDR_IMG28         = 10'd38;
    localparam [9:0] ADDR_IMG29         = 10'd39;
    localparam [9:0] ADDR_IMG30         = 10'd40;
    localparam [9:0] ADDR_IMG31         = 10'd41;
    localparam [9:0] ADDR_IMG_CMD       = 10'd42;

    // Result register (read-only, captured on img_done)
    localparam [9:0] ADDR_RESULT        = 10'd43;

    // Model params register (19 bits used)
    localparam [9:0] ADDR_MODEL_PARAMS  = 10'd44;

    // Load done register (controls STOP signal to class_top)
    localparam [9:0] ADDR_LOAD_DONE     = 10'd45;

    // We store all registers 0..45 in regs[]
    localparam integer NUM_STORED       = 46;

    // ====================================================
    // Internal storage
    // ====================================================
    reg  [31:0] regs     [0:NUM_STORED-1];
    reg  [31:0] read_data;
    reg         slverr_reg;

    wire [9:0]  addr_idx = PADDR[11:2];

    assign PREADY  = 1'b1;
    assign PSLVERR = slverr_reg;

    // ====================================================
    // Result capture logic (internal - no external module needed)
    // ====================================================
    reg  [3:0]  r_result_reg;      // Captured result
    reg         r_img_done_prev;    // For edge detection
    wire        w_img_done_pulse;   // Rising edge of img_done
    
    // Detect rising edge of img_done
    assign w_img_done_pulse = i_img_done & ~r_img_done_prev;

    // ====================================================
    // Byte write helper
    // ====================================================
    function automatic [31:0] apply_strb;
        input [31:0] old;
        input [31:0] newval;
        input [3:0]  strb;
        begin
            apply_strb[ 7: 0] = strb[0] ? newval[ 7: 0] : old[ 7: 0];
            apply_strb[15: 8] = strb[1] ? newval[15: 8] : old[15: 8];
            apply_strb[23:16] = strb[2] ? newval[23:16] : old[23:16];
            apply_strb[31:24] = strb[3] ? newval[31:24] : old[31:24];
        end
    endfunction

    // ====================================================
    // Command pulse registers (1-cycle)
    // ====================================================
    reg r_cmd_weight_write;
    reg r_cmd_weight_read;
    reg r_cmd_clauses_write;
    reg r_cmd_clauses_read;
    reg r_img_cmd_pulse;
    
    // Command error register
    reg r_cmd_error;

    // ====================================================
    // Command mutual exclusion check using one-hot encoding
    // ====================================================
    wire [3:0] cmd_vector;
    wire       cmd_valid;

    // Create one-hot vector of commands
    assign cmd_vector = {r_cmd_clauses_read, r_cmd_clauses_write, 
                         r_cmd_weight_read, r_cmd_weight_write};

    // Check if exactly one bit is set (one-hot valid)
    // Valid one-hot: 0001, 0010, 0100, 1000
    // Invalid: 0000 (no command), or multiple bits set
    assign cmd_valid = (cmd_vector == 4'b0001) || 
                       (cmd_vector == 4'b0010) || 
                       (cmd_vector == 4'b0100) || 
                       (cmd_vector == 4'b1000);

    // ====================================================
    // WRITE logic + pulse generation + result capture
    // ====================================================
    integer i;
    always @(posedge PCLK or negedge PRESETn) begin
        if(!PRESETn) begin
            for(i=0; i<NUM_STORED; i=i+1)
                regs[i] <= 32'h0;

            slverr_reg          <= 1'b0;
            r_cmd_weight_write  <= 1'b0;
            r_cmd_weight_read   <= 1'b0;
            r_cmd_clauses_write <= 1'b0;
            r_cmd_clauses_read  <= 1'b0;
            r_img_cmd_pulse     <= 1'b0;
            r_cmd_error         <= 1'b0;
            
            // Result capture
            r_result_reg        <= 4'h0;
            r_img_done_prev     <= 1'b0;
            
            // Load done control - default to 0 (not loading, allow inference)
            o_load_done         <= 1'b0;
        end
        else begin
            slverr_reg          <= 1'b0;

            // default: pulses deasserted
            r_cmd_weight_write  <= 1'b0;
            r_cmd_weight_read   <= 1'b0;
            r_cmd_clauses_write <= 1'b0;
            r_cmd_clauses_read  <= 1'b0;
            r_img_cmd_pulse     <= 1'b0;

            // Check for command mutual exclusion violation
            // Error if cmd_vector is not one-hot (and not zero)
            r_cmd_error         <= (cmd_vector != 4'b0000) && !cmd_valid;

            // ====================================================
            // Result Capture Logic (replaces result_glue_logic)
            // ====================================================
            r_img_done_prev <= i_img_done;
            
            // Capture result when img_done pulses
            if(w_img_done_pulse) begin
                r_result_reg <= i_result_data_in;
            end

            // ====================================================
            // APB Write Operations
            // ====================================================
            if(PSEL && PENABLE && PWRITE) begin
                // normal register write (excluding result register)
                if(addr_idx < NUM_STORED && addr_idx != ADDR_RESULT) begin
                    regs[addr_idx] <= apply_strb(regs[addr_idx], PWDATA, PSTRB);
                end
                else if(addr_idx != ADDR_RESULT) begin
                    // outside reg space and not result
                    slverr_reg <= 1'b1;
                end

                // ------------------------------------------------
                // Decode WCMD register into 1-cycle command pulses
                // ------------------------------------------------
                if(addr_idx == ADDR_WCMD) begin
                    if(PWDATA[0]) r_cmd_weight_write  <= 1'b1;  // bit0: write WEIGHT
                    if(PWDATA[1]) r_cmd_weight_read   <= 1'b1;  // bit1: read  WEIGHT
                    if(PWDATA[2]) r_cmd_clauses_write <= 1'b1;  // bit2: write CLAUSES
                    if(PWDATA[3]) r_cmd_clauses_read  <= 1'b1;  // bit3: read  CLAUSES
                end

                // ------------------------------------------------
                // Image command pulse (to image glue logic)
                // ------------------------------------------------
                if(addr_idx == ADDR_IMG_CMD) begin
                    if(PWDATA[0]) r_img_cmd_pulse <= 1'b1; // bit0 = trigger image transfer
                end

                // ------------------------------------------------
                // Load done control (register 45)
                // Manual control for STOP signal
                // ------------------------------------------------
                if(addr_idx == ADDR_LOAD_DONE) begin
                    o_load_done <= PWDATA[0];  // bit[0] = load_done control
                    // PWDATA[0] = 1: loading mode (stop=1, enables wea/wea2)
                    // PWDATA[0] = 0: inference mode (stop=0, allows class_top to run)
                end
            end
        end
    end

    // ====================================================
    // READ logic
    // ====================================================
    always @(*) begin
        if(addr_idx == ADDR_RESULT) begin
            // Return captured result
            read_data = {28'h0, r_result_reg};
        end
        else if(addr_idx == ADDR_LOAD_DONE) begin
            // Return current load_done status
            read_data = {31'h0, o_load_done};
        end
        else if(addr_idx < NUM_STORED) begin
            read_data = regs[addr_idx];           // 0..45
        end
        else begin
            read_data = 32'h0;
        end
    end

    assign PRDATA = (PSEL && !PWRITE) ? read_data : 32'h0;

    // ====================================================
    // Connect regs[] to outputs
    // ====================================================
    // Weights
    assign o_weight_data0 = regs[ADDR_WEIGHT0];
    assign o_weight_data1 = regs[ADDR_WEIGHT1];
    assign o_weight_data2 = regs[ADDR_WEIGHT2];
    assign o_weight_data3 = regs[ADDR_WEIGHT3];
    assign o_weight_data4 = regs[ADDR_WEIGHT4];
    assign o_weight_data5 = regs[ADDR_WEIGHT5];
    assign o_weight_data6 = regs[ADDR_WEIGHT6];
    assign o_weight_data7 = regs[ADDR_WEIGHT7];
    assign o_weight_addr  = regs[ADDR_WADDR];  // Full 32 bits (only [9:0] used)

    // Image
    assign o_img_data0  = regs[ADDR_IMG0];
    assign o_img_data1  = regs[ADDR_IMG1];
    assign o_img_data2  = regs[ADDR_IMG2];
    assign o_img_data3  = regs[ADDR_IMG3];
    assign o_img_data4  = regs[ADDR_IMG4];
    assign o_img_data5  = regs[ADDR_IMG5];
    assign o_img_data6  = regs[ADDR_IMG6];
    assign o_img_data7  = regs[ADDR_IMG7];
    assign o_img_data8  = regs[ADDR_IMG8];
    assign o_img_data9  = regs[ADDR_IMG9];
    assign o_img_data10 = regs[ADDR_IMG10];
    assign o_img_data11 = regs[ADDR_IMG11];
    assign o_img_data12 = regs[ADDR_IMG12];
    assign o_img_data13 = regs[ADDR_IMG13];
    assign o_img_data14 = regs[ADDR_IMG14];
    assign o_img_data15 = regs[ADDR_IMG15];
    assign o_img_data16 = regs[ADDR_IMG16];
    assign o_img_data17 = regs[ADDR_IMG17];
    assign o_img_data18 = regs[ADDR_IMG18];
    assign o_img_data19 = regs[ADDR_IMG19];
    assign o_img_data20 = regs[ADDR_IMG20];
    assign o_img_data21 = regs[ADDR_IMG21];
    assign o_img_data22 = regs[ADDR_IMG22];
    assign o_img_data23 = regs[ADDR_IMG23];
    assign o_img_data24 = regs[ADDR_IMG24];
    assign o_img_data25 = regs[ADDR_IMG25];
    assign o_img_data26 = regs[ADDR_IMG26];
    assign o_img_data27 = regs[ADDR_IMG27];
    assign o_img_data28 = regs[ADDR_IMG28];
    assign o_img_data29 = regs[ADDR_IMG29];
    assign o_img_data30 = regs[ADDR_IMG30];
    assign o_img_data31 = regs[ADDR_IMG31];

    // Model params (19 bits)
    assign o_model_params = regs[ADDR_MODEL_PARAMS][18:0];

    // Command pulses
    assign o_cmd_weight_write  = r_cmd_weight_write;
    assign o_cmd_weight_read   = r_cmd_weight_read;
    assign o_cmd_clauses_write = r_cmd_clauses_write;
    assign o_cmd_clauses_read  = r_cmd_clauses_read;

    // Image command pulse
    assign o_img_cmd_pulse     = r_img_cmd_pulse;
    
    // Command error output
    assign o_cmd_error         = r_cmd_error;

    // Note: o_load_done is already a registered output, assigned in always block

endmodule
