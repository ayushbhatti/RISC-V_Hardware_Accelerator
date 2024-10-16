`timescale 1ns/1ns

module floating_point_add_tb;
    
    parameter CLK_PERIOD = 10;
    parameter RESET_TIME = 100;
    
    wire clk;
    wire rst;

    wire [31:0] dataA;
    wire [31:0] dataB;
    wire valid;
    
    wire sumValid;
    wire [31:0] sum;
    
    clk_gen #(.CLK_PERIOD(CLK_PERIOD)) clk_gen_i (.clkOut(clk));
    rst_gen #(.RESET_TIME(RESET_TIME)) rst_gen_i (.rstOut(rst));
    
    file_driver driver (
        .clkIn(clk),
        .rstIn(rst),
        .dataAOut(dataA),
        .dataBOut(dataB),
        .validOut(valid));
    
    floating_point_add add (
        .clkIn(clk),
        .rstIn(rst),
        .dataAIn(dataA),
        .dataBIn(dataB),
        .validIn(valid),
        .dataOut(sum),
        .validOut(sumValid));
    
    compare_to_file comp (
        .clkIn(clk),
        .rstIn(rst),
        .validIn(sumValid),
        .dataIn(sum));
    
endmodule