`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/20/2024 08:17:15 AM
// Design Name: 
// Module Name: floating_mult
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


module floating_point_mult (
     clkIn,
     rstIn,
     dataAIn,
     dataBIn,
     validIn,
     dataOut,
     validOut
);

    
    parameter FRAC_WIDTH = 23; // Mantissa width
    parameter EXP_WIDTH  = 8;  // Exponent width
    
    // Derived parameters
    localparam DATA_WIDTH = FRAC_WIDTH + EXP_WIDTH + 1;
    localparam BIAS = (1 << (EXP_WIDTH - 1)) - 1;
    input clkIn, rstIn;
    input [DATA_WIDTH-1:0] dataAIn;
    input [DATA_WIDTH-1:0] dataBIn;
    input validIn;
    
    output reg [DATA_WIDTH-1:0] dataOut;
    output reg validOut;
    
    wire aSign, bSign;
    wire [EXP_WIDTH-1:0] aExp, bExp;
    wire [FRAC_WIDTH:0] aMantissa, bMantissa;

    reg resultSign;
    reg [EXP_WIDTH-1:0] resultExp;
    reg [FRAC_WIDTH:0] resultMantissa;
    
    wire aZero, bZero;
    wire aInf, bInf;
    wire aNaN, bNaN;

    assign aSign     = dataAIn[DATA_WIDTH-1];
    assign bSign     = dataBIn[DATA_WIDTH-1];
    assign aExp      = dataAIn[DATA_WIDTH-2:FRAC_WIDTH];
    assign bExp      = dataBIn[DATA_WIDTH-2:FRAC_WIDTH];
    assign aMantissa = {1'b1, dataAIn[FRAC_WIDTH-1:0]}; // Add implicit leading 1
    assign bMantissa = {1'b1, dataBIn[FRAC_WIDTH-1:0]}; // Add implicit leading 1

    assign aZero = (aExp == 0) && (dataAIn[FRAC_WIDTH-1:0] == 0);
    assign bZero = (bExp == 0) && (dataBIn[FRAC_WIDTH-1:0] == 0);
    assign aInf  = (aExp == {EXP_WIDTH{1'b1}}) && (dataAIn[FRAC_WIDTH-1:0] == 0);
    assign bInf  = (bExp == {EXP_WIDTH{1'b1}}) && (dataBIn[FRAC_WIDTH-1:0] == 0);
    assign aNaN  = (aExp == {EXP_WIDTH{1'b1}}) && (dataAIn[FRAC_WIDTH-1:0] != 0);
    assign bNaN  = (bExp == {EXP_WIDTH{1'b1}}) && (dataBIn[FRAC_WIDTH-1:0] != 0);

    reg [2*FRAC_WIDTH+1:0] multMantissa;
    reg [EXP_WIDTH:0] sumExp;

    always @(posedge clkIn or posedge rstIn) begin
        if (rstIn) begin
            dataOut  <= 0;
            validOut <= 0;
        end else if (validIn) begin
            // Handle special cases
            if (aNaN || bNaN) begin
                dataOut <= {1'b0, {EXP_WIDTH{1'b1}}, 1'b1, {FRAC_WIDTH{1'b0}}}; // NaN
            end else if (aInf || bInf) begin
                if (aZero || bZero) begin
                    dataOut <= {1'b0, {EXP_WIDTH{1'b1}}, 1'b1, {FRAC_WIDTH{1'b0}}}; // NaN (0 * Inf)
                end else begin
                    dataOut <= {aSign ^ bSign, {EXP_WIDTH{1'b1}}, {FRAC_WIDTH{1'b0}}}; // Inf
                end
            end else if (aZero || bZero) begin
                dataOut <= {aSign ^ bSign, {EXP_WIDTH{1'b0}}, {FRAC_WIDTH{1'b0}}}; // Zero
            end else begin
                // Multiply mantissas
                multMantissa = aMantissa * bMantissa;

                // Add exponents (compensate for the bias)
                sumExp = aExp + bExp - BIAS;

                // Normalize result
                if (multMantissa[2*FRAC_WIDTH+1]) begin
                    resultMantissa = multMantissa[2*FRAC_WIDTH:FRAC_WIDTH+1];
                    resultExp = sumExp + 1;
                end else begin
                    resultMantissa = multMantissa[2*FRAC_WIDTH-1:FRAC_WIDTH];
                    resultExp = sumExp;
                end

                // Check for overflow and underflow
                if (resultExp >= {EXP_WIDTH{1'b1}}) begin
                    dataOut <= {resultSign, {EXP_WIDTH{1'b1}}, {FRAC_WIDTH{1'b0}}}; // Inf
                end else if (resultExp <= 0) begin
                    dataOut <= {resultSign, {EXP_WIDTH{1'b0}}, {FRAC_WIDTH{1'b0}}}; // Zero
                end else begin
                    dataOut <= {resultSign, resultExp[EXP_WIDTH-1:0], resultMantissa[FRAC_WIDTH-1:0]};
                end
            end
            validOut <= 1;
        end
    end
endmodule
