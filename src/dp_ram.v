`timescale 1ns/1ns

module dp_ram (
    clkIn,
    rstIn,
    addrAIn,
    wrEnAIn,
    wrDataAIn,
    rdEnAIn,
    rdDataAOut,
    rdAckAOut,
    addrBIn,
    wrEnBIn,
    wrDataBIn,
    rdEnBIn,
    rdDataBOut,
    rdAckBOut);

    parameter DATA_WIDTH = 32;
    parameter RAM_DEPTH  = 512;

    localparam WREN_WIDTH = (DATA_WIDTH+7)/8;
    localparam RAM_WIDTH  = WREN_WIDTH*8;
    localparam ADDR_WIDTH = $clog2(RAM_DEPTH);
    localparam PAD_WIDTH  = RAM_WIDTH - DATA_WIDTH;

    input clkIn;
    input rstIn;
    
    input [ADDR_WIDTH-1:0] addrAIn;
    input [WREN_WIDTH-1:0] wrEnAIn;
    input [DATA_WIDTH-1:0] wrDataAIn;
    input rdEnAIn;
    
    output [DATA_WIDTH-1:0] rdDataAOut;
    output rdAckAOut;
    
    input [ADDR_WIDTH-1:0] addrBIn;
    input [WREN_WIDTH-1:0] wrEnBIn;
    input [DATA_WIDTH-1:0] wrDataBIn;
    input rdEnBIn;
    
    output [DATA_WIDTH-1:0] rdDataBOut;
    output rdAckBOut;
    
    reg [RAM_WIDTH-1:0] ram [0:(RAM_DEPTH-1)];

    reg rdAckAR;
    reg [DATA_WIDTH-1:0] rdDataAR;
    
    reg rdAckBR;
    reg [DATA_WIDTH-1:0] rdDataBR;
    
    wire [RAM_WIDTH-1:0] wrDataAPad;
    wire [RAM_WIDTH-1:0] wrDataBPad;
    
    assign wrDataAPad = {{PAD_WIDTH{1'b0}}, wrDataAIn};
    assign wrDataBPad = {{PAD_WIDTH{1'b0}}, wrDataBIn};

    integer i;
    
    always @(posedge clkIn) begin
        rdDataAR <= ram[addrAIn][DATA_WIDTH-1:0];
        for (i=0; i < WREN_WIDTH; i = i + 1) begin
            if (wrEnAIn[i]) begin
                ram[addrAIn][(8*i)+:8] = wrDataAPad[(8*i)+:8];
            end
        end
        rdDataBR <= ram[addrBIn][DATA_WIDTH-1:0];
        for (i=0; i < WREN_WIDTH; i = i + 1) begin
            if (wrEnBIn[i]) begin
                ram[addrBIn][(8*i)+:8] = wrDataBPad[(8*i)+:8];
            end
        end
    end

    always @(posedge clkIn or posedge rstIn) begin
        if (rstIn) begin
            rdAckAR <= 0;
            rdAckBR <= 0;
        end else begin
            rdAckAR <= rdEnAIn;
            rdAckBR <= rdEnBIn;
        end
    end

    assign rdDataAOut = rdDataAR;
    assign rdAckAOut  = rdAckAR;

    assign rdDataBOut = rdDataBR;
    assign rdAckBOut  = rdAckBR;
    
endmodule

