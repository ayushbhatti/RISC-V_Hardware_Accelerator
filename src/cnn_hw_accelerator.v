module cnn_hw_accelator (
    clkIn,
    rstIn,
    addrIn,
    ;
    
    parameter VECTOR_LEN = 8;
    parameter DATA_WIDTH = 32;
    parameter RAM_DEPTH  = 512;
    parameter ADDR_WIDTH = $clog2(RAM_DEPTH);
    
    input clkIn;
    input rstIn;
    
    reg [ADDR_WIDTH-1:0] addrR;
    
    reg rdEnR;
    
    wire rdAck;
    
    genvar i;
    
    generate
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin
           
            sp_ram #(.DATA_WIDTH(DATA_WIDTH), .RAM_DEPTH(RAM_DEPTH)) data_ram_i(
                .clkIn(clkIn),
                .rstIn(rstIn),
                .addrIn(addrR),
                .wrEnIn(wrEn),
                .wrDataIn()
                .rdEnIn()
                .rdDataOut()
                .rdAckOut()
        end
    endgenerate
    
endmodule