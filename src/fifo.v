`timescale 1ns/1ns

module fifo (
    clkIn,
    rstIn,
    wrDataIn,
    wrValidIn,
    wrReadyOut,
    rdDataOut,
    rdValidOut,
    rdReadyIn);

    // Fifo parameters
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 512;
    parameter FIFO_SKID  = 0;

    // Derived FIFO parameters
    localparam ADDR_WIDTH  = $clog2(FIFO_DEPTH);
    localparam COUNT_WIDTH = $clog2(FIFO_DEPTH+1);
    localparam FULL_COUNT  = FIFO_DEPTH - FIFO_SKID;

    // Inputs and Outputs
    input  clkIn;
    input  rstIn;
    
    input  [DATA_WIDTH-1:0] wrDataIn;
    input  wrValidIn;
    output wrReadyOut;
    
    output [DATA_WIDTH-1:0] rdDataOut;
    output rdValidOut;
    input  rdReadyIn;
    
    // Control Registers
    reg [COUNT_WIDTH-1:0] countR;

    reg wrReadyR;
    reg rdValidR;
    reg fullR;
    reg initR;

    reg [ADDR_WIDTH-1:0] wrAddrR;
    reg [ADDR_WIDTH-1:0] rdAddrR;

    wire wrEn;
    wire rdEn;

    assign wrEn = wrValidIn & (!fullR | rdEn);
    assign rdEn = rdReadyIn & rdValidR;

    always @(posedge clkIn) begin
        if (rstIn) begin
            countR              <= 0;
            wrReadyR            <= 0;
            rdValidR            <= 0;
            fullR               <= 0;
            initR               <= 1;
            wrAddrR             <= 0;
            rdAddrR             <= 2;
        end else begin
            
            if (wrEn && !rdEn) begin
                countR          <= countR + 1;
                if (countR == (FULL_COUNT - 1)) begin
                    wrReadyR    <= 0;
                end
                if (countR == (FIFO_DEPTH - 1)) begin
                    fullR       <= 1;
                end
                if (countR == 0) begin
                    rdValidR    <= 1;
                end
            end else if (!wrEn && rdEn) begin
                countR          <= countR - 1;
                if (countR == FULL_COUNT) begin
                    wrReadyR    <= 1;
                end
                if (countR == FIFO_DEPTH) begin
                    fullR       <= 0;
                end
                if (countR == 1) begin
                    rdValidR    <= 0;
                end
            end

            initR               <= 0;
            if (initR) begin
                wrReadyR        <= 1;
                rdValidR        <= 0;
            end

            if (wrEn) begin
                wrAddrR         <= wrAddrR + 1;
            end

            if (rdEn) begin
                rdAddrR         <= rdAddrR + 1;
            end

            if (wrValidIn && fullR && !rdEn) begin
                $error("Fifo overflow detected at time %t", $realtime);
            end
        end
    end

    reg [DATA_WIDTH-1:0] ram [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rdData;

    always @(posedge clkIn) begin
        rdData      <= ram[rdAddrR];
        if (wrEn) begin
            ram[wrAddrR] <= wrDataIn;
        end
    end
    
    // reg [DATA_WIDTH-1:0] rdDataR;
    reg [DATA_WIDTH-1:0] rdPipeR [1:0];
    // reg [DATA_WIDTH-1:0] wrDataR;
    reg rdEnR;
    
    reg [COUNT_WIDTH-1:0] nextCount;
    
    always @(posedge clkIn) begin
    
        rdEnR           <= rdEn;
        
        /*if (wrEn) begin
            wrDataR     <= wrDataIn;
        end*/
        
        nextCount        = countR;
        if (wrEn) begin
            nextCount    = nextCount + 1;
        end
        if (rdEn) begin
            nextCount    = nextCount - 1;
        end
        
        /*if (nextCount < 3) begin
            if (wrEn) begin
                rdPipeR <= wrDataIn;
            end
        end else
            if (rdEn) begin
                
            end
        end*/
        
        /* if ((((countR == 1) && !rdEn) || ((countR == 2) && rdEn)) && wrEn) begin
            rdPipeR <= wrDataIn; // 2nd write to memory
        end else if (rdEn) begin
            rdPipeR <= rdData; // Last RAM read
        end
            
        if (rdEn) begin // Update on Read
            if (countR == 1) begin 
                rdDataR <= wrDataIn; // Accept any new inputs
            end else if (countR == 2) begin 
                rdDataR <= wrDataR; // Take last written value
            end else begin
                if (rdEnR) begin // Two reads
                    rdDataR <= rdData; // RAM read
                end else begin 
                    rdDataR <= rdPipeR;
                end
            end
        end else if (!rdValidR && wrEn) begin // Update on 1st Write
            rdDataR <= wrDataIn;
        end */
        
        
        if (rdEn) begin
            if (rdEnR) begin
                rdPipeR[0]  <= rdData; // +0
                rdPipeR[1]  <= rdData;
            end else begin
                rdPipeR[0]  <= rdPipeR[1]; // +0
                rdPipeR[1]  <= rdData; // +1
            end
        end else begin
            if (rdEnR) begin
                rdPipeR[1]  <= rdData; // +1
            end
        end
        if (wrEn) begin
            if (nextCount == 1) begin
                rdPipeR[0]  <= wrDataIn;
            end else if (nextCount == 2) begin
                rdPipeR[1]  <= wrDataIn;
            end
        end
    end
    
    assign wrReadyOut   = wrReadyR;
    assign rdDataOut    = rdPipeR[0];
    assign rdValidOut   = rdValidR;

endmodule