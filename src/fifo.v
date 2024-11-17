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

    // Only write when there will be no overflows
    assign wrEn = wrValidIn & (!fullR | rdEn);
    
    // Only read when the data is valid
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
            
            // Determine next count and
            // control signals based on next count
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

            // Enable write ready as soon as reset is deasserted
            initR               <= 0;
            if (initR) begin
                wrReadyR        <= 1;
            end

            // Update write pointer
            if (wrEn) begin
                wrAddrR         <= wrAddrR + 1;
            end

            // Update read pointer
            if (rdEn) begin
                rdAddrR         <= rdAddrR + 1;
            end

            // Overflow detection
            if (wrValidIn && fullR && !rdEn) begin
                $error("Fifo overflow detected at time %t", $realtime);
            end
        end
    end

    // Ram signals
    reg [DATA_WIDTH-1:0] ram [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rdData;

    // Instantiate RAM
    always @(posedge clkIn) begin
        rdData      <= ram[rdAddrR];
        if (wrEn) begin
            ram[wrAddrR] <= wrDataIn;
        end
    end
    
    // Read pipeline signals
    reg [DATA_WIDTH-1:0] rdPipeR [1:0];
    reg [2:0] wrEnR;
    reg [1:0] rdStickyR;
    reg rdEnR;
    
    // Keep track of which address should be written next
    // Assumes no concurrent read
    always @(posedge clkIn) begin
        if (rstIn) begin
            wrEnR       <= 1;
            rdStickyR   <= 0;
        end else begin
            if (wrEn && !rdEn) begin
                wrEnR           <= 0;
                if (countR == 0) begin
                    wrEnR[1]    <= 1;
                end
                if (countR == 1) begin
                    wrEnR[2]    <= 1;
                end
            end else if (!wrEn && rdEn) begin
                wrEnR           <= 0;
                if (countR == 1) begin
                    wrEnR[0]    <= 1;
                end
                if (countR == 2) begin
                    wrEnR[1]    <= 1;
                end
                if (countR == 3) begin
                    wrEnR[2]    <= 1;
                end
            end
            
            if (rdEn) begin
                rdStickyR           <= {1'b0, rdStickyR[1]};
            end
            if (wrEn) begin
                if (wrEnR[0] || (wrEnR[1] && rdEn)) begin // nextCount == 1
                    rdStickyR[0]    <= 1;
                end else if ((wrEnR[1] & !rdEn) || (wrEnR[2] && rdEn)) begin // nextCount == 2
                    rdStickyR[1]    <= 1;
                end
            end
        end
    end
    
    // Manage read pipeline
    always @(posedge clkIn) begin
    
        // Determine if FIFO was read in the last cycle
        rdEnR               <= rdEn;

        // Handle reads from FIFO
        if (rdEn) begin
        
            // 2 reads in a row
            // Use data from RAM (assumes last 2 reads valid)
            if (rdEnR) begin
                if (rdStickyR[1]) begin
                    rdPipeR[0]  <= rdPipeR[1];
                end else begin
                    rdPipeR[0]  <= rdData;
                end
                rdPipeR[1]  <= rdData;
                
            // 1 read in a row
            // Take value in pipeline (addr + 1)
            // Update next value in pipeline with RAM data (addr + 2)
            end else begin
                rdPipeR[0]  <= rdPipeR[1];
                rdPipeR[1]  <= rdData;
            end
            
        // Last read was valid but current read was not
        // Take RAM value (addr + 1)
        end else if (rdEnR && !rdStickyR[1]) begin
            rdPipeR[1]      <= rdData;
        end
        
        // Handle FIFO empty or nearly empty
        if (wrEn) begin
            if (wrEnR[0] || (wrEnR[1] && rdEn)) begin // nextCount == 1
                rdPipeR[0]  <= wrDataIn;
            end else if ((wrEnR[1] & !rdEn) || (wrEnR[2] && rdEn)) begin // nextCount == 2
                rdPipeR[1]  <= wrDataIn;
            end
        end
    end
    
    // Assign outputs
    assign wrReadyOut   = wrReadyR;
    assign rdDataOut    = rdPipeR[0];
    assign rdValidOut   = rdValidR;

endmodule