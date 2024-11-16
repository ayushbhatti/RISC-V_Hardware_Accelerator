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

    assign wrEn = wrValidIn & !fullR;
    assign rdEn = rdReadyIn & rdValidR;

    always @(posedge clkIn) begin
        if (rstIn) begin
            countR          <= 0;
            wrReadyR        <= 0;
            rdValidR        <= 0;
            fullR           <= 0;
            initR           <= 1;
            wrAddrR         <= 0;
            rdAddrR         <= 0;
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
            else if (!wrEn && rdEn) begin
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

            if (wrValidIn && fullR) begin
                $error("Fifo overflow detected at time %t", $realtime);
            end
        end
    end

    reg [DATA_WIDTH-1:0] ram [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rdDataR;

    always @(posedge clkIn) begin
        rdDataR <= ram[rdAddrR];
        if (wrEn) begin
            ram[wrAddrR] <= wrDataIn;
        end
    end

    assign wrReadyOut   = wrReadyR;
    assign rdDataOut    = rdDataR;
    assign rdValidOut   = rdValidR;

endmodule