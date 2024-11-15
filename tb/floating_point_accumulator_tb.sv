`timescale 1ns/1ns

module floating_point_accumulator_tb;

    // Define testbench parameters.
    parameter CLK_PERIOD   = 10;
    parameter RESET_TIME   = 100;
    parameter MAX_SAMPLES  = 256;
    
    // Floating point configuration
    parameter FRAC_WIDTH   = 24;
    parameter EXP_WIDTH    =  8;
    
    // Derived floating point configuration
    parameter DATA_WIDTH   = FRAC_WIDTH + EXP_WIDTH;
    
    // State enumerations
    localparam INIT  = 0;
    localparam LOAD  = 1;
    localparam CHECK = 2;
    
    // Define FSM registers
    reg [1:0] stateR;
    reg [DATA_WIDTH-1:0] numSampR;
    reg [DATA_WIDTH-1:0] dataR;
    reg [DATA_WIDTH-1:0] resultR;
    reg validR;
    reg lastR;
    
    // Clock and reset signals
    wire clk;
    wire rst;
    
    // Accumulator outputs
    wire [DATA_WIDTH-1:0] accumData;
    wire accumValid;  

    // Create clock and reset
    clk_gen #(.CLK_PERIOD(CLK_PERIOD)) clk_gen_i (.clkOut(clk));
    rst_gen #(.RESET_TIME(RESET_TIME)) rst_gen_i (.rstOut(rst));
    
    // Include accumulator
    floating_point_accumulator #(.EXP_WIDTH(EXP_WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) accum_i (
        .clkIn(clk),
        .rstIn(rst),
        .lastIn(lastR),
        .validIn(validR),
        .dataIn(dataR),
        .validOut(accumValid),
        .dataOut(accumData));
        
    // Define FSM
    always @(posedge clk) begin
        if (rst) begin
            stateR      <= INIT;
            validR      <= 0;
            lastR       <= 0;
            dataR       <= 0;
            resultR     <= 0;
            numSampR    <= 0;
        end else begin
            lastR       <= 0;
            
            case (stateR)
                // Initialize iteration
                INIT : begin
                    stateR      <= LOAD;
                    validR      <= 1;
                    dataR       <= $shortrealtobits(1.0);
                    resultR     <= $shortrealtobits(1.0);
                    
                    // Modulo counter for number of accumulator samples in iteration
                    if ($rtoi($bitstoshortreal(numSampR)) < MAX_SAMPLES) begin
                        numSampR    <= $shortrealtobits($bitstoshortreal(numSampR) + 1.0);
                    end else begin
                        numSampR    <= $shortrealtobits(1.0);
                    end
                    
                    // Handle single sample accumulation
                    if ((numSampR == 0) || ($rtoi($bitstoshortreal(numSampR)) == MAX_SAMPLES)) begin
                        lastR       <= 1;
                        stateR      <= CHECK;
                    end else begin
                        stateR      <= LOAD;
                    end
                end
                
                // Load samples into accumulator
                // Samples are incrementing floating point numbers
                LOAD : begin
                    resultR <= $shortrealtobits($bitstoshortreal(resultR) + ($bitstoshortreal(dataR) + 1.0));
                    dataR   <= $shortrealtobits($bitstoshortreal(dataR) + 1.0);
                    if ($rtoi($bitstoshortreal(dataR)) == ($rtoi($bitstoshortreal(numSampR)) - 1)) begin
                        lastR   <= 1;
                        stateR  <= CHECK;
                    end
                end
                
                // Check Accumulator output
                CHECK : begin
                    validR  <= 0;
                    if (accumValid) begin
                        stateR  <= INIT;
                        if (resultR !== accumData) begin
                            $error("Error Detected at Time %t: Received 0x%08X, Expected 0x%08X", $realtime, accumData, resultR);
                        end
                    end
                end
            endcase                
        end
    end
    
endmodule