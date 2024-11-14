module delay (
    clkIn,
    rstIn,
    dataIn,
    dataOut);
    
    parameter LATENCY = 8;
    parameter DATA_WIDTH = 32;
    
    input clkIn;
    input rstIn;
    
    input  [DATA_WIDTH-1:0] dataIn;
    output [DATA_WIDTH-1:0] dataOut
    
    reg [DATA_WIDTH-1:0] dataR [0:(LATENCY-1)];
    
    always @(posedge clkIn) begin
        if (LATENCY == 1) begin
            dataR <= dataIn;
        end else begin
            dataR <= {dataIn, dataR[0:(LATENCY-2)]};
        end
    end
    
    assign dataOut = dataR[LATENCY-1];
        
endmodule;
    
    