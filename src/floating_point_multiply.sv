module floating_point_multiply(
    clkIn,
    rstIn,
    dataAIn,
    dataBIn,
    validIn,
    dataOut,
    validOut);

    parameter LATENCY = 8;

    localparam DATA_WIDTH = 32;

    // Inputs
    input clkIn, rstIn;
    input [DATA_WIDTH-1:0] dataAIn;
    input [DATA_WIDTH-1:0] dataBIn;
    input validIn;

    // Outputs
    output [DATA_WIDTH-1:0] dataOut;
    output validOut;

    wire [DATA_WIDTH-1:0] prod;
    reg  [DATA_WIDTH-1:0] dataOutR [LATENCY-1:0];
    reg  [   LATENCY-1:0] validOutR;

    integer i;
    
    assign prod = $shortrealtobits($bitstoshortreal(dataAIn) * $bitstoshortreal(dataBIn));

    // Data process
    always @(posedge clkIn) begin
        dataOutR[0] <= prod;
        for (i=1; i < LATENCY; i=i+1) begin
            dataOutR[i] <= dataOutR[i-1];
        end
    end

    // Valid process
    always @(posedge clkIn or posedge rstIn) begin
        if (rstIn) begin
            validOutR <= 0;
        end else begin
            if (LATENCY == 1) begin
                validOutR[0] <= validIn;
            end else begin
                validOutR    <= {validOutR, validIn};
            end
        end
    end

    assign dataOut  = dataOutR [LATENCY-1];
    assign validOut = validOutR[LATENCY-1];

endmodule