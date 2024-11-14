`timescale 1ns/1ns

module floating_point_accumulator_tb;

    parameter CLK_PERIOD   = 10;
    parameter RESET_TIME   = 100;
    parameter NUM_SAMPLES  = 16;
    
    localparam INIT  = 0;
    localparam LOAD  = 1;
    localparam CHECK = 2;
    
    wire clk;
    wire rst;
    
    reg [1:0] stateR;
    
    reg [31:0] dataR;
    reg [31:0] resultR;
    reg validR;
    reg startR;
    reg lastR;
    
    wire [31:0] accumData;
    wire accumValid;
    
    clk_gen #(.CLK_PERIOD(CLK_PERIOD)) clk_gen_i (.clkOut(clk));
    rst_gen #(.RESET_TIME(RESET_TIME)) rst_gen_i (.rstOut(rst));
    
    floating_point_accumulate accum_i (
        .clkIn(clk),
        .rstIn(rst),
        .startIn(startR),
        .lastIn(lastR),
        .validIn(validR),
        .dataIn(dataR),
        .validOut(accumValid),
        .dataOut(accumData));
        
    always @(posedge clk) begin
        if (rst) begin
            stateR  <= INIT;
            validR  <= 0;
            startR  <= 0;
            lastR   <= 0;
            dataR   <= 0;
            resultR <= 0;
        end else begin
            startR  <= 0;
            lastR   <= 0;
            case (stateR)
                INIT : begin
                    stateR  <= LOAD;
                    validR  <= 1;
                    startR  <= 1;
                    dataR   <= $shortrealtobits(1.0);
                    resultR <= $shortrealtobits(1.0);
                    if (NUM_SAMPLES == 1) begin
                        lastR   <= 1;
                        stateR  <= CHECK;
                    end else begin
                        stateR  <= LOAD;
                    end
                end
                LOAD : begin
                    resultR <= $shortrealtobits($bitstoshortreal(resultR) + ($bitstoshortreal(dataR) + 1.0));
                    dataR   <= $shortrealtobits($bitstoshortreal(dataR) + 1.0);
                    if ($rtoi($bitstoshortreal(dataR)) == (NUM_SAMPLES - 1)) begin
                        lastR   <= 1;
                        stateR  <= CHECK;
                    end
                end
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