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
    localparam ALMOST_FULL = FIFO_DEPTH - FIFO_SKID;

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
                if (countR == (ALMOST_FULL - 1)) begin
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
                if (countR == ALMOST_FULL) begin
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
        rdData           <= ram[rdAddrR];
        if (wrEn) begin
            ram[wrAddrR] <= wrDataIn;
        end
    end
    
    // Read pipeline signals
    reg [DATA_WIDTH-1:0] rdPipeDataR [1:0];
    reg [1:0] rdPipeValidR;
    reg rdEnR;
    
    
    always @(posedge clkIn) begin
    
        if (rstIn) begin
            rdEnR           <= 0;
            rdPipeValidR    <= 0;
            rdPipeDataR[0]  <= 0;
            rdPipeDataR[1]  <= 0;
        end else begin
        
            // Data from memory is valid with 1 sample of delay
            rdEnR                   <= rdEn;
        
            // Advance pipeline on read
            if (rdEn) begin
                rdPipeValidR        <= {1'b0, rdPipeValidR[1]};
                rdPipeDataR[0]      <= rdPipeDataR[1];
            end
            
            // Data read from memory is valid
            if (rdEnR) begin
                // Place data at start of pipeline if there are no valid samples
                if (rdEn && !rdPipeValidR[1]) begin
                    rdPipeValidR[0] <= 1;
                    rdPipeDataR [0] <= rdData;
                // Place data at end of pipeline if last sample is invalid
                end else if (rdEn || !rdPipeValidR[1]) begin
                    rdPipeValidR[1] <= 1;
                    rdPipeDataR [1] <= rdData;
                end
            end
        
            // Place writes directly in read pipeline
            // Handles first few writes
            if (wrEn) begin
                if ((countR == 0) || ((countR == 1) && rdEn)) begin
                    rdPipeValidR[0] <= 1;
                    rdPipeDataR [0] <= wrDataIn;
                end else if (((countR == 1) & !rdEn) || ((countR == 2) && rdEn)) begin
                    rdPipeValidR[1] <= 1;
                    rdPipeDataR [1] <= wrDataIn;
                end
            end
        end
    end
    
    // Assign outputs
    assign wrReadyOut   = wrReadyR;
    assign rdDataOut    = rdPipeDataR[0];
    assign rdValidOut   = rdValidR;

endmodule