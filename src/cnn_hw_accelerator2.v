module cnn_hw_accelerator (
    clkIn;
    rstIn;
    startIn;
    filtRowsIn;
    filtColsIn;
    dataRowsIn;
    dataColsIn;
    addrIn;
    wrEnIn;
    wrDataIn;
    readyIn;
    validOut;
    dataOut);

    // Configuration of RISCV bus interface
    parameter BUS_ADDR_WIDTH    = 32;
    parameter BUS_DATA_WIDTH    = 64;
    parameter BUS_WE_WIDTH      = BUS_DATA_WIDTH/8;
    
    // Floating-point hardware accelerator configuration
    // Standard single precision
    parameter FRAC_WIDTH        = 24;
    parameter EXP_WIDTH         = 8;
    
    // Multiply and accumulate input width
    parameter VECTOR_SIZE       = 8;
    
    // Maximum size of input matrices (in elements)
    parameter MAX_SIZE          = 4096;

    // Derived counter width
    parameter CNT_WIDTH         = $clog2(MAX_SIZE);

    // Derived vector size parameters
    localparam VECTOR_SIZE_LOG2 = $clog2(VECTOR_SIZE);
    
    // Derived RAM parameters
    localparam RAM_DEPTH        = MAX_SIZE/VECTOR_SIZE;
    localparam RAM_ADDR_WIDTH   = $clog2(RAM_DEPTH);
    localparam RAM_DATA_WIDTH   = FRAC_WIDTH + EXP_WIDTH;
    localparam RAM_WE_WIDTH     = RAM_DATA_WIDTH/8;
      
    // Input/Output Ports
    input clkIn;
    input rstIn;
    
    input startIn;
    input [CNT_WIDTH:0] filtRowsIn;
    input [CNT_WIDTH:0] filtColsIn;
    input [CNT_WIDTH:0] dataRowsIn;
    input [CNT_WIDTH:0] dataColsIn;
    
    input [BUS_ADDR_WIDTH-1:0] addrIn;
    input [  BUS_WE_WIDTH-1:0] wrEnIn;
    input [BUS_DATA_WIDTH-1:0] wrDataIn;
    
    input  readyIn;
    output validOut;
    output [RAM_DATA_WIDTH-1:0] dataOut;
    
    // Bus write registers
    reg [RAM_ADDR_WIDTH-1:0] busAddrR;
    reg [RAM_DATA_WIDTH-1:0] busDataR [0:VECTOR_SIZE-1];
    reg [  RAM_WE_WIDTH-1:0] busWrEnR [0:1][0:VECTOR_SIZE-1];
    
    // Map Bus Writes to Correct RAM Banks
    genvar i;
    generate
    
        // Constants for selecting relevant bits of address
        localparam NUM_BYTES    = RAM_WE_WIDTH*VECTOR_SIZE;
        localparam ADDR_LO      = $clog2(NUM_BYTES);
        localparam ADDR_HI      = RAM_ADDR_WIDTH + ADRR_LO;

        // Constant for selecting write select bits
        localparam WR_SEL_LO    = RAM_WE_WIDTH;
        localparam WR_SEL_HI    = WR_SEL_LO + VECTOR_SIZE - 1;
        
        // Constants for mapping write enable bits
        localparam GROUP_SIZE   = BUS_WE_WIDTH/RAM_WE_WIDTH
        localparam NUM_GROUPS   = NUM_BYTES/BUS_WE_WIDTH
    
        // Extract address and write select bits
        wire [RAM_ADDR_WIDTH:0] busAddr;
        wire [VECTOR_SIZE_LOG2-1:0] busWrSel;
        
        // Get address and write select bits (applies to all groups)
        assign busAddr  = addrIn[  ADDR_HI:ADDR_LO  ];
        assign busWrSel = addrIn[WR_SEL_HI:WR_SEL_LO];
        
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        
            // Determine indices of write enable bits
            localparam WE_LO   = (i % GROUP_SIZE) * RAM_WE_WIDTH;
            localparam WE_HI   = WE_LO + RAM_WE_WIDTH - 1;
            
            // Determine indices of data bits
            localparam DATA_LO = (i % GROUP_SIZE) * RAM_DATA_WIDTH;
            localparam DATA_HI = DATA_LO + RAM_DATA_WIDTH - 1;

            // Extracted data and write enable bits
            wire [  RAM_DATA_WIDTH-1:0] busWrData;
            wire [    RAM_WE_WIDTH-1:0] busWrEn;
            
            // Get write data and write enable bits for group
            assign busWrData = wrDataIn[DATA_HI:DATA_LO];
            assign busWrEn   = wrEnIn  [  WE_HI:WE_LO  ];

            // Map writes to correct set of write enable bits
            integer j;
            always @(posedge clkIn) begin
                busWrDataR[i] <= busWrData;
                for (j = 0; j < 2; j = j + 1) begin
                    busWrEnR[j][i] <= 0;
                    if ((busAddr[RAM_ADDR_WIDTH] == j) && (busWrSel == i)) begin
                        busWrEnR[j][i] <= busWrEn;
                    end
                end
            end
        end
        
        // Select only required bits of address
        always @(posedge clkIn) begin
            busWrAddrR <= busWrAddr[RAM_DATA_WIDTH-1:0];
        end        
    endgenerate
    
    // State Definitions
    localparam IDLE = 0;
    localparam INIT = 1;
    localparam CALC = 2;
    
    // Parameters for selecting subregions of column counts
    localparam COL_CNT_WIDTH = CNT_WIDTH - VECTOR_SIZE_LOG2;
    localparam COL_CNT_LO    = VECTOR_SIZE_LOG2;
    localparam COL_CNT_HI    = CNT_WIDTH - 1;
    
    // Number of input cells
    reg numCellsR;
    
    // FSM registers
    reg [1:0] stateR;
    reg validR;
    
    reg [VECTOR_SIZE_LOG2-1:0] lastRdCntR;
    reg [COL_CNT_WIDTH-1:0] maxColCntR;
    reg [CNT_WIDTH-1:0] maxRowCntR;
    reg [CNT_WIDTH-1:0] maxBaseCntR;
    
    // Column Index Counter
    wire colAdv;
    wire colClr;
    wire colDoneR;
    wire [COL_CNT_WIDTH-1:0] colCntR;
    
    // Row Index Counter
    wire rowAdv;
    wire rowClr;
    wire rowDoneR;
    wire [CNT_WIDTH-1:0] rowCntR;
    
    // Base Address Counter
    wire baseAdv;
    wire baseClr;
    wire baseDoneR;
    wire [CNT_WIDTH-1:0] baseCntR;
    
    // Done signal
    wire done;
    
    // Get number of input cells
    always @(posedge clkIn) begin
        numCellsR <= dataRowsIn * dataColsIn;
    end
    
    // Read state machine
    always @(posedge clkIn) begin
        if (rstIn) begin
            stateR      <= IDLE;
            validR      <= 0;
            lastRdCntR  <= 0;
            maxColCntR  <= 0;
            maxRowCntR  <= 0;
            maxBaseCntR <= 0;
        end else begin
            case (stateR)
                IDLE : begin
                    maxColCntR  <= filtColsIn[COL_CNT_HI:COL_CNT_LO] - 1;
                    lastRdCntR  <= filtColsIn[COL_CNT_LO-1:0] - 1;
                    maxRowCntR  <= filtRowsIn - 1;
                    if (startIn) begin
                        stateR  <= INIT;
                    end
                end
                INIT : begin
                    maxBaseCntR <= numCellsR - 1;
                    validR      <= 1;
                    stateR      <= CALC;
                end
                CALC : begin
                    if (done) begin
                        validR  <= 0;
                        stateR  <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Counter control signals
    assign baseAdv = colDoneR & rowDoneR & fifoWrReady;
    assign baseClr = !validR & fifoWrReady;
    
    assign rowAdv  = rowDoneR;
    assign rowClr  = baseClr | baseAdv;
    
    assign colAdv  = 1;
    assign colClr  = rowClr | (rowAdv & !rowClr);
       
    // Column Index Counter
    counter #(
        .CNT_WIDTH(COL_CNT_WIDTH)) col_cnt (
        .clkIn(clkIn),
        .rstIn(1'b0),
        .clrIn(colClr),
        .advIn(colAdv),
        .endValIn(maxColCntR),
        .cntOut(colCntR),
        .doneOut(colDoneR));
      
    // Row Index Counter
    counter #(
        .CNT_WIDTH(CNT_WIDTH)) row_cnt (
        .clkIn(clkIn),
        .rstIn(1'b0),
        .clrIn(rowClr),
        .advIn(rowAdv),
        .endValIn(maxRowCntR),
        .cntOut(rowCntR),
        .doneOut(rowDoneR));
        
    // Base Address Counter
    counter #(
        .CNT_WIDTH(CNT_WIDTH)) base_cnt (
        .clkIn(clkIn),
        .rstIn(1'b0),
        .clrIn(baseClr),
        .advIn(baseAdv),
        .endValIn(maxAddrR),
        .cntOut(baseCntR),
        .doneOut(baseDoneR));
    
    // Done signal for 2D Convolution 
    assign done = colDoneR & rowDoneR & baseDoneR;
    
    // Pipeline #2
    reg last2R;
    reg [CNT_WIDTH-1:0] addr2R;
    reg [CNT_WIDTH-1:0] offset2R;
    reg [CNT_WIDTH-1:0] colCnt2R;
    
    // Pipeline #3
    reg last3R;
    reg [CNT_WIDTH-1:0] dataAddr3R;
    reg [CNT_WIDTH-1:0] filtAddr3R;
    
    // Pipeline #4
    reg last4R;
    reg [VECTOR_SIZE_LOG2-1:0] dataShift4R;
    reg [VECTOR_SIZE_LOG2-1:0] filtShift4R;
    reg [CNT_WIDTH-1:0] dataAddrVar;
    reg [CNT_WIDTH-1:0] filtAddrVar;
    reg [CNT_WIDTH-1:0] dataAddr4R;
    reg [CNT_WIDTH-1:0] filtAddr4R;
    
    // Pipeline #5
    reg last5R;
    reg [VECTOR_SIZE_LOG2-1:0] dataShift5R;
    reg [VECTOR_SIZE_LOG2-1:0] filtShift5R;
    reg [CNT_WIDTH-1:0] dataAddr5R;
    reg [CNT_WIDTH-1:0] filtAddr5R;
    
    // Data Process
    always @(posedge clkIn) begin
    
        // Pipeline #2
        last2R   <= colDoneR & rowDoneR;
        addr2R   <= {colCntR, COL_CNT_LO{1'b0}} * rowCntR;
        offset2R <= {colCntR, COL_CNT_LO{1'b0}} + baseCntR:
        colCnt2R <= {colCntR, COL_CNT_LO{1'b0}};
        
        // Pipeline #3
        last3R      <= last2R;
        dataAddr3R  <= addr2R + offset2R;
        filtAddr3R  <= addr2R + colCnt2R;
        
        // Pipeline #4
        last4R      <= last3R;
        
        // Determine shift required to access correct RAM bank
        dataShift4R <= dataAddr3R[(VECTOR_SIZE_LOG2-1):0];
        filtShift4R <= filtAddr3R[(VECTOR_SIZE_LOG2-1):0];
        
        // Determine addresses for each RAM bank
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            dataAddrVar  = dataAddr3R + i;
            filtAddrVar  = filtAddr3R + i;
            
            dataAddr4R[(i*RAM_ADDR_WIDTH)+:RAM_ADDR_WIDTH] <= dataAddrVar[VECTOR_SIZE_LOG2+:RAM_ADDR_WIDTH];            
            filtAddr4R[(i*RAM_ADDR_WIDTH)+:RAM_ADDR_WIDTH] <= filtAddrVar[VECTOR_SIZE_LOG2+:RAM_ADDR_WIDTH];
        end
        
        // Pipeline #5
        last5R      <= last4R;
        dataShift5R <= dataShift4R;
        filtShift5R <= filtShift4R;
        
        // Circular shift
        dataAddr5R  <= (dataAddr4R << (dataShift4R*RAM_ADDR_WIDTH)) | (dataAddr4R >> ((VECTOR_SIZE - dataShift4R)*RAM_ADDR_WIDTH));
        filtAddr5R  <= (filtAddr4R << (filtShift4R*RAM_ADDR_WIDTH)) | (filtAddr4R >> ((VECTOR_SIZE - filtShift4R)*RAM_ADDR_WIDTH));
    end
    
    // Pipeline #2
    reg [VECTOR_SIZE-1:0] rdEn2R;
    
    // Pipeline #3
    reg [VECTOR_SIZE-1:0] rdEn3R;
    
    // Pipeline #4
    reg [VECTOR_SIZE-1:0] rdEn4R;
    
    // Pipeline #5
    reg [VECTOR_SIZE-1:0] dataRdEn5R;
    reg [VECTOR_SIZE-1:0] filtRdEn5R;
    
    // Read Enable Process
    always @(posedge clkIn) begin
        if (rstIn) begin
            rdEn2R      <= 0;
            rdEn3R      <= 0;
            rdEn4R      <= 0;
            dataRdEn5R  <= 0;
            filtRdEn5R  <= 0;
        end else begin
        
            // Pipeline #2
            // Determine which bits of read enable are high
            for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
                if (rowDoneR) begin
                    if (i < lastRdCntR) begin
                        rdEn2R[i] <= validR;
                    end else begin
                        rdEn2R[i] <= 0;
                    end
                end else begin
                    rdEn2R[i] <= validR;
                end
            end
            
            // Pipeline #3
            rdEn3R      <= rdEn2R;
            
            // Pipeline #4
            rdEn4R      <= rdEn3R;
            
            // Pipeline #5
            // Circular shift
            dataRdEn5R  <= (rdEn4R << dataShift4R) | (rdEn4R >> (VECTOR_SIZE - dataShift4R));
            filtRdEn5R  <= (rdEn4R << filtShift4R) | (rdEn4R >> (VECTOR_SIZE - filtShift4R));
        end
    end
    
    // RAM constants
    localparam WREN_ZERO  = {   VECTOR_SIZE{1'b0}};
    localparam DATA_ZERO  = {RAM_DATA_WIDTH{1'b0}};
    localparam RD_LATENCY = 1;
       
    // RAM Bank A
    wire [  RAM_DATA_WIDTH-1:0] dataA [0:VECTOR_SIZE-1];
    wire [VECTOR_SIZE_LOG2-1:0] dataAShift;
    
    // RAM Bank B
    wire [  RAM_DATA_WIDTH-1:0] dataB [0:VECTOR_SIZE-1];
    wire [VECTOR_SIZE_LOG2-1:0] dataBShift;
    
    // Common RAM signals
    wire [VECTOR_SIZE-1:0] valid;
    wire ramLast;
    
    // Generate Data RAM for each vector element
    generate
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        
            wire [RAM_ADDR_WIDTH-1:0] rdAddr;
            wire [RAM_DATA_WIDTH-1:0] rdData;
            
            assign rdAddr = dataAddr5R[i*RAM_ADDR_WIDTH+:RAM_ADDR_WIDTH];
            
            dp_ram #(
                .DATA_WIDTH(RAM_DATA_WIDTH),
                .RAM_DEPTH(RAM_DEPTH)) data_ram (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .addrAIn(busAddrR),
                .wrEnAIn(busWrEnR[0][i]),
                .wrDataAIn(busWrDataR[i]),
                .rdEnAIn(1'b0),
                .addrBIn(rdAddr),
                .wrEnBIn(WREN_ZERO),
                .wrDataBIn(DATA_ZERO),
                .rdEnBIn(dataRdEn5R[i]),
                .rdDataBOut(rdData),
                .rdAckBOut(valid[i]));
                
            assign dataA[RAM_DATA_WIDTH*i+:RAM_DATA_WIDTH] = rdData;
            
        end
            
        delay #(
            .LATENCY(RD_LATENCY),
            .DATA_WIDTH(VECTOR_SIZE_LOG2)) data_delay (
            .clkIn(clkIn),
            .rstIn(1'b0),
            .dataIn(dataRdShift5R),
            .dataOut(dataAShift)); 
    endgenerate
        
    // Generate Filter RAM for each vector element
    generate
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
        
            wire [RAM_ADDR_WIDTH-1:0] rdAddr;
            wire [RAM_DATA_WIDTH-1:0] rdData;
            
            assign rdAddr = filtAddr[i*RAM_ADDR_WIDTH+:RAM_ADDR_WIDTH];
            
            dp_ram #(
                .DATA_WIDTH(RAM_DATA_WIDTH),
                .RAM_DEPTH(RAM_DEPTH)) filt_ram (
                .clkIn(clkIn),
                .rstIn(rstIn),
                .addrAIn(busAddrR),
                .wrEnAIn(busWrEnR[1][i]),
                .wrDataAIn(busWrDataR[i]),
                .rdEnAIn(1'b0),
                .addrBIn(rdAddr),
                .wrEnBIn(WREN_ZERO),
                .wrDataBIn(DATA_ZERO),
                .rdEnBIn(dataRdEn5R[i]),
                .rdDataBOut(rdData));
                
            assign dataB[RAM_DATA_WIDTH*i+:RAM_DATA_WIDTH] = rdData;
            
        end
            
        delay #(
            .LATENCY(RD_LATENCY),
            .DATA_WIDTH(VECTOR_SIZE_LOG2)) filt_delay (
            .clkIn(clkIn),
            .rstIn(1'b0),
            .dataIn(filtRdShift5R),
            .dataOut(dataBShift)); 
    endgenerate
    
    // Delay last signal to match reads from RAM
    delay #(
        .LATENCY(RD_LATENCY),
        .DATA_WIDTH(1)) last_delay (
        .clkIn(clkIn),
        .rstIn(1'b0),
        .dataIn(last5R),
        .dataOut(ramLast));
    
    // RAM Output Pipeline Stage
    reg [VECTOR_SIZE-1:0] validR;
    reg [RAM_DATA_WIDTH*VECTOR_SIZE-1:0] dataAR;
    reg [RAM_DATA_WIDTH*VECTOR_SIZE-1:0] dataBR;
    
    // Valid Process
    always @(posedge clkIn) begin
        if (rstIn) begin
            validR  <= 0;
        end else begin
            // Circular shift
            validR  <= (valid >> dataAShift) | (valid << (VECTOR_SIZE - dataAShift));            
        end
    end
    
    // Data Process
    always @(posedge clkIn) begin
        ramLastR    <= ramLast;
        // Circular shift
        dataAR      <= (dataA >> (dataAShift*RAM_DATA_WIDTH)) | (dataA << ((VECTOR_SIZE - dataAShift)*RAM_DATA_WIDTH));
        dataBR      <= (dataB >> (dataBShift*RAM_DATA_WIDTH)) | (dataB << ((VECTOR_SIZE - dataBShift)*RAM_DATA_WIDTH));
    end
    
    // Multiply and accumulate results
    wire [RAM_DATA_WIDTH-1:0] macData;
    wire macValid;
    
    // Multiply and Accumulate
    multiply_and_accumulate #(
        .FRAC_WIDTH(FRAC_WIDTH),
        .EXP_WIDTH(EXP_WIDTH)) mac(
        .clkIn(clkIn),
        .rstIn(rstIn),
        .dataAIn(dataAR),
        .dataBIn(dataBR),
        .validIn(validR),
        .lastIn(ramLastR),
        .dataOut(macData),
        .validOut(macValid));
       
    // Output FIFO
    fifo #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .FIFO_SKID(128)) fifo_i(
        .clkIn(clkIn),
        .rstIn(rstIn),
        .wrDataIn(macData),
        .wrValidIn(macValid),
        .wrReadyOut(fifoWrReady),
        .rdDataOut(dataOut),
        .rdValidOut(validOut),
        .rdReadyIn(readyIn);
    
endmodule