module floating_point_multiply_tb;
    
    parameter CLK_PERIOD = 10;
    parameter RESET_TIME = 100;
    
    wire clk;
    wire rst;

    wire [31:0] dataA;
    wire [31:0] dataB;
    wire valid;
    
    wire prodValid;
    wire [31:0] prod;
    wire error;
    
    clk_gen #(.CLK_PERIOD(CLK_PERIOD)) clk_gen_i (.clkOut(clk));
    rst_gen #(.RESET_TIME(RESET_TIME)) rst_gen_i (.rstOut(rst));
    
    file_driver driver (
        .clkIn(clk),
        .rstIn(rst),
        .dataAOut(dataA),
        .dataBOut(dataB),
        .validOut(valid));
    
    floating_point_multiply mult (
        .clkIn(clk),
        .rstIn(rst),
        .dataAIn(dataA),
        .dataBIn(dataB),
        .validIn(valid),
        .dataOut(prod),
        .validOut(prodValid));
    
    file_checker check (
        .clkIn(clk),
        .rstIn(rst),
        .validIn(prodValid),
        .dataIn(prod),
        .errorOut(error));
        
endmodule